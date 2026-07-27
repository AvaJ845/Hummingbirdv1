import SwiftUI

/// Post-run surface: agree comparison first, then plain English, then the sketch.
struct ForecastResultsView: View {
    @Bindable var viewModel: ForecastViewModel
    let forecast: Forecast
    let entitlements: EntitlementStore
    @Bindable var watchlist: WatchlistStore
    let onUnlock: () -> Void
    var onCompareMethods: (() -> Void)? = nil
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Two-up metric tiles side by side normally; stacked at accessibility sizes
    /// so each value keeps full width and stays legible.
    private var metricLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 10))
            : AnyLayout(HStackLayout(spacing: 10))
    }

    var body: some View {
        VStack(spacing: 18) {
            if viewModel.usingSampleData {
                SampleDataBanner()
            }

            watchToggle

            // Hero beat — do the methods agree? (Fellow + DE ask)
            if !viewModel.modelPreviews.isEmpty {
                ModelDisagreementCard(
                    previews: viewModel.modelPreviews,
                    activeModelID: forecast.model.id,
                    isPro: entitlements.isPro,
                    easyMode: viewModel.easyMode,
                    bestRecentModelID: viewModel.bestRecentModelID,
                    onSelect: { model in _ = viewModel.selectModel(model) },
                    onUnlock: onUnlock
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if viewModel.easyMode {
                RetailSummaryCard(
                    symbol: viewModel.symbol,
                    forecast: forecast,
                    disagreementSpread: viewModel.disagreementSpread,
                    horizon: viewModel.horizon,
                    macro: forecast.macro
                )

                sketchCard(easyMode: true)

                compactMetrics
            } else {
                ModelInsightCard(
                    model: forecast.model,
                    macro: forecast.macro,
                    easyMode: false,
                    recentError: viewModel.preview(for: forecast.model)?.recentError
                )

                if forecast.macro.isActive {
                    MacroImpactCard(macro: forecast.macro, horizon: viewModel.horizon, easyMode: false)
                }

                sketchCard(easyMode: false)
                advancedMetrics
                ForecastDetailList(forecast: forecast)
            }

            EasyModeToggle(isOn: $viewModel.easyMode)

            if let onCompareMethods {
                Button(action: onCompareMethods) {
                    Text("Browse every method")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
                .accessibilityHint("Opens the full method list")
            }
        }
    }

    @ViewBuilder private var watchToggle: some View {
        if let item = viewModel.currentWatchItem {
            let isWatched = watchlist.contains(symbol: item.symbol, assetClass: item.assetClass)
            Button {
                watchlist.toggle(symbol: item.symbol, assetClass: item.assetClass, displayName: item.title)
                if let series = viewModel.loadedSeries,
                   let snapshot = WatchlistIntelligence.snapshot(for: item, series: series) {
                    watchlist.saveSnapshot(snapshot)
                }
            } label: {
                Label(isWatched ? "On your watchlist" : "Add to watchlist",
                      systemImage: isWatched ? "star.fill" : "star")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(isWatched ? Theme.accent : .secondary)
            .accessibilityHint(isWatched ? "Removes this asset from your watchlist" : "Saves this asset for glanceable updates")
        }
    }

    private func sketchCard(easyMode: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Text(easyMode ? "Price sketch" : viewModel.symbol.uppercased())
                    .font(.title3.weight(.semibold))
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    LiveStatusBadge(
                        label: viewModel.liveStatusLabel,
                        isLive: viewModel.isPriceLive,
                        lastUpdated: viewModel.lastUpdated,
                        isRefreshing: viewModel.isRefreshing
                    )
                    Text("\(forecast.model.name) · \(viewModel.horizon)d")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            ForecastChart(forecast: forecast)
                .frame(minHeight: 220)

            ChartLegend(easyMode: easyMode)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.accent.opacity(0.12), lineWidth: 1)
        )
    }

    private var compactMetrics: some View {
        let change = forecast.expectedChange
        return metricLayout {
            MetricTile(
                title: "Now",
                value: (forecast.lastClose ?? 0).asCurrency(),
                subtitle: "Last close"
            )
            .priceFlash(token: viewModel.priceUpdateToken, direction: viewModel.priceDirection)
            MetricTile(
                title: "Sketch",
                value: change?.asSignedPercent() ?? "—",
                subtitle: "In ~\(viewModel.horizon) days",
                valueColor: Theme.changeColor(change)
            )
        }
        .animation(.snappy(duration: 0.25), value: forecast.targetPrice)
    }

    private var advancedMetrics: some View {
        let change = forecast.expectedChange
        return VStack(spacing: 10) {
            metricLayout {
                MetricTile(
                    title: "Current",
                    value: (forecast.lastClose ?? 0).asCurrency(),
                    subtitle: "Last close"
                )
                .priceFlash(token: viewModel.priceUpdateToken, direction: viewModel.priceDirection)
                MetricTile(
                    title: "Projected",
                    value: (forecast.targetPrice ?? 0).asCurrency(),
                    subtitle: forecast.targetDate.map { $0.formatted(.dateTime.month().day()) },
                    valueColor: Theme.changeColor(change)
                )
            }
            metricLayout {
                MetricTile(
                    title: "Projected change",
                    value: change?.asSignedPercent() ?? "—",
                    subtitle: "Uncalibrated path · \(viewModel.horizon)d",
                    valueColor: Theme.changeColor(change)
                )
                MetricTile(
                    title: "Style",
                    value: forecast.model.confidence.retailLabel,
                    subtitle: forecast.model.familyLabel
                )
            }
        }
        .animation(.snappy(duration: 0.25), value: forecast.targetPrice)
    }
}

/// Small status pill: shows whether the loaded ticker is auto-updating live
/// (pulsing green dot) or the market is closed (steady grey dot), plus how long
/// ago the last price landed. Shows a spinner while a refresh is in flight.
struct LiveStatusBadge: View {
    var label: String = "Live"
    var isLive: Bool = true
    let lastUpdated: Date?
    let isRefreshing: Bool
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var dotColor: Color { isLive ? Theme.up : .secondary }

    var body: some View {
        HStack(spacing: 5) {
            if isRefreshing {
                ProgressView()
                    .controlSize(.mini)
            } else {
                Circle()
                    .fill(dotColor)
                    .frame(width: 6, height: 6)
                    .opacity(isLive && pulse ? 0.3 : 1)
                    .accessibilityHidden(true)
            }

            Group {
                if let lastUpdated {
                    Text("\(label) · ") + Text(lastUpdated, style: .relative)
                } else {
                    Text(label)
                }
            }
            .font(.caption2.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }
        .onAppear { startPulseIfNeeded() }
        .onChange(of: isLive) { _, _ in startPulseIfNeeded() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private func startPulseIfNeeded() {
        if isLive, !reduceMotion {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        } else {
            withAnimation(.default) { pulse = false }
        }
    }

    private var accessibilityText: String {
        if isRefreshing { return "Updating price" }
        return isLive ? "Live price, updates automatically" : "Market closed, showing last price"
    }
}

/// Briefly tints a view green (up) or red (down) when a new price lands, then
/// fades out. Respects Reduce Motion by using a gentler flash.
struct PriceFlash: ViewModifier {
    let token: Int
    let direction: ForecastViewModel.PriceDirection
    @State private var intensity: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var color: Color {
        switch direction {
        case .up: return Theme.up
        case .down: return Theme.down
        case .unchanged: return .clear
        }
    }

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(color.opacity(intensity))
                    .allowsHitTesting(false)
            )
            .onChange(of: token) { _, _ in
                guard direction != .unchanged else { return }
                intensity = reduceMotion ? 0.14 : 0.28
                withAnimation(.easeOut(duration: 0.9)) { intensity = 0 }
            }
    }
}

extension View {
    /// Flash the view when `token` changes, colored by price `direction`.
    func priceFlash(token: Int, direction: ForecastViewModel.PriceDirection) -> some View {
        modifier(PriceFlash(token: token, direction: direction))
    }
}

struct EasyModeToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Label(isOn ? "Easy mode" : "Details mode", systemImage: isOn ? "hand.tap.fill" : "slider.horizontal.3")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Toggle("Easy mode", isOn: $isOn)
                .labelsHidden()
                .tint(Theme.accent)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .accessibilityElement(children: .combine)
        .accessibilityHint("Easy mode uses plain English for retail investors")
    }
}

struct ChartLegend: View {
    var easyMode: Bool = true

    var body: some View {
        HStack(spacing: 16) {
            legendItem(color: .secondary, label: "History")
            legendItem(color: Theme.accent, label: easyMode ? "Sketch" : "Projection", dashed: true)
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.accent.opacity(0.18))
                    .frame(width: 16, height: 10)
                    .accessibilityHidden(true)
                Text(easyMode ? "Possible range" : "Projection band")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Chart legend: history, projection, and possible range")
    }

    private func legendItem(color: Color, label: String, dashed: Bool = false) -> some View {
        HStack(spacing: 5) {
            Rectangle()
                .fill(color)
                .frame(width: 16, height: 2)
                .opacity(dashed ? 0.9 : 1)
                .accessibilityHidden(true)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct ForecastDetailList: View {
    let forecast: Forecast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Card {
            DisclosureGroup {
                VStack(spacing: 0) {
                    ForEach(sampleIndices, id: \.self) { index in
                        let point = forecast.points[index]
                        HStack {
                            Text(point.date.formatted(.dateTime.month().day()))
                                .font(.subheadline)
                            Spacer()
                            Text(point.mean.asCurrency())
                                .font(.subheadline.weight(.medium))
                            if !dynamicTypeSize.isAccessibilitySize {
                                Text("±\(point.bandHalfWidth.asCurrency(maximumFractionDigits: 0))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 70, alignment: .trailing)
                            }
                        }
                        .padding(.vertical, 8)
                        .accessibilityElement(children: .combine)

                        if index != sampleIndices.last {
                            Divider()
                        }
                    }
                }
                .padding(.top, 8)
            } label: {
                Label("Projection detail", systemImage: "list.bullet.rectangle")
                    .font(.subheadline.weight(.semibold))
            }
            .tint(.primary)
        }
    }

    private var sampleIndices: [Int] {
        let count = forecast.points.count
        guard count > 0 else { return [] }
        let strideBy = max(1, count / 10)
        return Array(stride(from: 0, to: count, by: strideBy))
    }
}

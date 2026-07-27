import SwiftUI

/// Post-run surface: agree comparison first, then plain English, then the sketch.
struct ForecastResultsView: View {
    @Bindable var viewModel: ForecastViewModel
    let forecast: Forecast
    let entitlements: EntitlementStore
    let onUnlock: () -> Void
    var onCompareMethods: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 18) {
            if viewModel.usingSampleData {
                SampleDataBanner()
            }

            // Hero beat — do the methods agree? (Fellow + DE ask)
            if !viewModel.modelPreviews.isEmpty {
                ModelDisagreementCard(
                    previews: viewModel.modelPreviews,
                    activeModelID: forecast.model.id,
                    isPro: entitlements.isPro,
                    easyMode: viewModel.easyMode,
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
                ModelInsightCard(model: forecast.model, macro: forecast.macro, easyMode: false)

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

    private func sketchCard(easyMode: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(easyMode ? "Price sketch" : viewModel.symbol.uppercased())
                    .font(.title3.weight(.semibold))
                Spacer()
                Text("\(forecast.model.name) · \(viewModel.horizon)d")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
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
        return HStack(spacing: 10) {
            MetricTile(
                title: "Now",
                value: (forecast.lastClose ?? 0).asCurrency(),
                subtitle: "Last close"
            )
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
            HStack(spacing: 10) {
                MetricTile(
                    title: "Current",
                    value: (forecast.lastClose ?? 0).asCurrency(),
                    subtitle: "Last close"
                )
                MetricTile(
                    title: "Projected",
                    value: (forecast.targetPrice ?? 0).asCurrency(),
                    subtitle: forecast.targetDate.map { $0.formatted(.dateTime.month().day()) },
                    valueColor: Theme.changeColor(change)
                )
            }
            HStack(spacing: 10) {
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
                            Text("±\(point.bandHalfWidth.asCurrency(maximumFractionDigits: 0))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 70, alignment: .trailing)
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

import SwiftUI

/// Home entry point for the practice portfolio. Leads with the one honest
/// number — how the user's trading compares to holding their first picks —
/// never a green celebration of the balance going up.
struct PaperPortfolioCard: View {
    let report: PaperReport
    let hasStarted: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "chart.pie.fill")
                    .font(.title3).foregroundStyle(Theme.accentAlt).frame(width: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Practice portfolio").font(.subheadline.weight(.semibold))
                    Text(hasStarted ? subtitle : "Practice with $10,000 — no real money")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if hasStarted {
                    Text(report.value.asCurrency())
                        .font(.callout.weight(.semibold)).monospacedDigit()
                }
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(hasStarted
            ? "Practice portfolio, \(report.value.asCurrency()). \(subtitle)."
            : "Practice portfolio. Practice with ten thousand dollars, no real money.")
        .accessibilityHint("Opens your practice portfolio")
    }

    private var subtitle: String {
        let c = report.comparison
        if c.tradeCount == 0 { return "Holding your first picks · vs. buy-and-hold" }
        if abs(c.edge) < 0.0005 { return "Even with buy-and-hold" }
        return c.isBeatingHold
            ? "Beating buy-and-hold by \(c.edge.asSignedPercent())"
            : "Behind buy-and-hold by \((-c.edge).asPercent())"
    }
}

/// The practice portfolio itself: your value, the honest You-vs-buy-and-hold
/// headline, your open holdings, and the turnover the two strategies cost.
/// Prices are end-of-day only; this is a record of the past, never advice.
struct PaperPortfolioView: View {
    @Bindable var store: PaperPortfolioStore
    @Bindable var entitlements: EntitlementStore
    var currentSymbol: String?
    var currentAssetClass: AssetClass = .stock
    var onUnlock: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var showBuy = false
    @State private var pendingSell: PaperPosition?
    @State private var showReset = false
    @State private var shareImage: Image?

    private let service = MarketDataService()

    private var report: PaperReport { store.report }

    var body: some View {
        List {
            headerSection
            chartSection
            if store.portfolio.openPositions.isEmpty {
                startOrCashSection
            } else {
                holdingsSection
            }
            readsSection
            closedTradesSection
            actionsSection
            shareSection
            disclaimerSection
        }
        .navigationTitle("Practice portfolio")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.revalueDue(using: service) }
        .refreshable { await store.revalueDue(using: service, force: true) }
        .task(id: shareRenderKey) { shareImage = renderShareImage() }
        .sheet(isPresented: $showBuy) {
            OpenPositionSheet(
                cash: store.portfolio.cash,
                prefillSymbol: currentSymbol,
                prefillAssetClass: currentAssetClass,
                service: service
            ) { symbol, assetClass, amount, price, direction in
                _ = store.buy(symbol: symbol, assetClass: assetClass, cashAmount: amount,
                              price: price, direction: direction)
                Task { await store.revalueDue(using: service, force: true) }
            }
        }
        .confirmationDialog(sellPrompt, isPresented: sellDialogBinding, titleVisibility: .visible) {
            if let pos = pendingSell {
                let price = currentPrice(pos)
                let fresh = store.latestPrices[pos.assetKey] != nil
                Button(fresh ? "Sell at \(price.asCurrency())" : "Sell at cost · \(price.asCurrency())") {
                    _ = store.sell(positionID: pos.id, price: price)
                    pendingSell = nil
                }
                Button("Cancel", role: .cancel) { pendingSell = nil }
            }
        } message: {
            if let pos = pendingSell, store.latestPrices[pos.assetKey] == nil {
                Text("No fresh price yet — this would sell at your purchase price. Pull down to refresh for the latest close.")
            }
        }
        .alert("Start over?", isPresented: $showReset) {
            Button("Reset to $10,000", role: .destructive) { store.resetPortfolio() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This clears every practice position and returns your balance to $10,000. It can't be undone.")
        }
    }

    // MARK: - Header (the honest headline)

    private var headerSection: some View {
        Section {
            VStack(spacing: 6) {
                Text(report.value.asCurrency())
                    .font(.system(size: 40, weight: .bold, design: .rounded)).monospacedDigit()
                    .foregroundStyle(Theme.brandGradient)
                Text("Total value · \(store.portfolio.cash.asCurrency()) cash")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Total value \(report.value.asCurrency()), including \(store.portfolio.cash.asCurrency()) cash.")

            if store.hasStarted {
                vsHoldRow
            }
        } footer: {
            if store.hasStarted, report.comparison.tradeCount > 0 {
                Text("You've made \(report.comparison.tradeCount) trade\(report.comparison.tradeCount == 1 ? "" : "s"). Buy-and-hold makes zero — activity rarely wins.")
            }
        }
    }

    private var vsHoldRow: some View {
        let c = report.comparison
        return VStack(alignment: .leading, spacing: 4) {
            Text(vsHoldHeadline)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(headlineColor)
                .fixedSize(horizontal: false, vertical: true)
            Text("Your return \(c.yourReturn.asSignedPercent()) · holding your first picks \(c.holdReturn.asSignedPercent())")
                .font(.caption).foregroundStyle(.secondary).monospacedDigit()
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(vsHoldHeadline)
    }

    private var vsHoldHeadline: String {
        let c = report.comparison
        if c.tradeCount == 0 { return "You're holding your first picks — a real strategy." }
        if abs(c.edge) < 0.0005 { return "You're even with buy-and-hold." }
        return c.isBeatingHold
            ? "You're beating buy-and-hold by \(c.edge.asSignedPercent())."
            : "Buy-and-hold is ahead by \((-c.edge).asPercent()) — trading isn't free."
    }

    private var headlineColor: Color {
        let c = report.comparison
        if c.tradeCount == 0 || abs(c.edge) < 0.0005 { return .primary }
        return c.isBeatingHold ? Theme.up : Theme.warning
    }

    // MARK: - You vs. buy-and-hold chart (Pro)

    private var valuePoints: [PortfolioValuePoint] {
        PaperPortfolioEngine.valueSeries(store.portfolio, histories: store.histories)
    }

    @ViewBuilder private var chartSection: some View {
        if store.hasStarted {
            Section {
                if entitlements.isPro {
                    let points = valuePoints
                    if points.count >= 2, !store.histories.isEmpty {
                        PaperPortfolioChart(points: points)
                            .padding(.vertical, 4)
                    } else {
                        Text("Your chart fills in once prices load and there's a day or two of history.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    proChartTeaser
                }
            } header: {
                Text("You vs. buy-and-hold over time")
            }
        }
    }

    private var proChartTeaser: some View {
        Button(action: onUnlock) {
            HStack(spacing: 12) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.title3).foregroundStyle(Theme.accentAlt).frame(width: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("See your trades vs. buy-and-hold over time")
                        .font(.subheadline.weight(.semibold))
                    Text("Watch the two lines diverge — a Pro view of your record.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("Pro").font(.caption2.weight(.bold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Theme.accentAlt.opacity(0.15), in: Capsule())
                    .foregroundStyle(Theme.accentAlt)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Unlocks the You versus buy-and-hold chart with Pro")
    }

    // MARK: - Holdings

    private var holdingsSection: some View {
        Section("Holdings") {
            ForEach(store.portfolio.openPositions) { pos in
                Button {
                    pendingSell = pos
                    Task { await store.revalueDue(using: service, force: true) }
                } label: {
                    holdingRow(pos)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func holdingRow(_ pos: PaperPosition) -> some View {
        let price = currentPrice(pos)
        let value = pos.value(at: price)
        let change = pos.entryPrice != 0 ? (price - pos.entryPrice) / pos.entryPrice : 0
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(pos.symbol.uppercased()).font(.body.weight(.semibold))
                    leanChip(pos.direction)
                }
                Text("\(pos.shares.formatted(.number.precision(.fractionLength(0...4)))) sh · in at \(pos.entryPrice.asCurrency())")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(value.asCurrency()).font(.body.weight(.semibold)).monospacedDigit()
                Text(change.asSignedPercent())
                    .font(.caption2).monospacedDigit()
                    .foregroundStyle(abs(change) < 0.00005 ? .secondary : (change > 0 ? Theme.up : Theme.down))
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(pos.symbol.uppercased()), you leaned \(pos.direction.title), \(value.asCurrency()), \(change.asSignedPercent()). Tap to sell.")
    }

    /// Your stated lean, shown back on the holding so the call you made at buy
    /// time isn't write-only — you can watch it against the actual move.
    private func leanChip(_ dir: CallDirection) -> some View {
        let tint = dir == .higher ? Theme.up : Theme.down
        return HStack(spacing: 2) {
            Image(systemName: dir == .higher ? "arrow.up.right" : "arrow.down.right")
            Text(dir.title)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(tint.opacity(0.14), in: Capsule())
        .accessibilityHidden(true)
    }

    // MARK: - Directional reads (lean scoring) + closed trades

    @ViewBuilder private var readsSection: some View {
        if report.leanAccuracy.decided > 0, let rate = report.leanAccuracy.hitRate {
            Section {
                HStack {
                    Label("Your directional reads", systemImage: "scope").font(.subheadline)
                    Spacer()
                    Text("\(pctText(rate)) right").font(.subheadline.weight(.semibold)).monospacedDigit()
                    Text("· \(report.leanAccuracy.correct)/\(report.leanAccuracy.decided)")
                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Your directional reads: \(pctText(rate)) right, \(report.leanAccuracy.correct) of \(report.leanAccuracy.decided).")
            } footer: {
                Text("How often the price moved the way you leaned — your read, scored apart from your timing.")
            }
        }
    }

    @ViewBuilder private var closedTradesSection: some View {
        let closed = store.portfolio.positions.filter { !$0.isOpen }
            .sorted { ($0.closedAt ?? .distantPast) > ($1.closedAt ?? .distantPast) }
        if !closed.isEmpty {
            Section("Closed trades") {
                ForEach(closed) { closedRow($0) }
            }
        }
    }

    private func closedRow(_ pos: PaperPosition) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(pos.symbol.uppercased()).font(.body.weight(.semibold))
                    leanResultChip(pos)
                }
                Text("leaned \(pos.direction.title) · in \(pos.entryPrice.asCurrency()) → out \((pos.exitPrice ?? pos.entryPrice).asCurrency())")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let realized = pos.realizedReturn {
                Text(realized.asSignedPercent()).font(.body.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(abs(realized) < 0.00005 ? .secondary : (realized > 0 ? Theme.up : Theme.down))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(pos.symbol.uppercased()), leaned \(pos.direction.title), \(leanResultText(pos)), realized \(pos.realizedReturn?.asSignedPercent() ?? "flat").")
    }

    private func leanResultChip(_ pos: PaperPosition) -> some View {
        let color: Color = pos.leanWasRight == true ? Theme.up : (pos.leanWasRight == false ? Theme.down : .secondary)
        let icon = pos.leanWasRight == true ? "checkmark" : (pos.leanWasRight == false ? "xmark" : "minus")
        return HStack(spacing: 2) { Image(systemName: icon); Text(leanResultText(pos)) }
            .font(.caption2.weight(.semibold)).foregroundStyle(color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.14), in: Capsule())
            .accessibilityHidden(true)
    }

    private func leanResultText(_ pos: PaperPosition) -> String {
        switch pos.leanWasRight {
        case .some(true): "read right"
        case .some(false): "read wrong"
        case .none: "push"
        }
    }

    private func pctText(_ fraction: Double) -> String { String(format: "%.0f%%", fraction * 100) }

    // MARK: - Start / all-cash state

    @ViewBuilder private var startOrCashSection: some View {
        if store.hasStarted {
            Section {
                Text("No open positions — you're all in cash. Buy again, or leave it and see how holding would have gone.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } else {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Practice, honestly.").font(.subheadline.weight(.semibold))
                    Text("You've got $10,000 in play money. Buy a position, then watch whether your trading beats simply holding your first picks. No real money, no leaderboard — just an honest mirror.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        Section {
            Button {
                showBuy = true
            } label: {
                Label(store.hasStarted ? "Add a position" : "Buy your first position",
                      systemImage: "plus.circle.fill")
            }
            .disabled(store.portfolio.cash < 1 || store.portfolio.positions.count >= PaperPortfolioStore.maxPositions)

            if store.hasStarted {
                Button(role: .destructive) { showReset = true } label: {
                    Label("Start over", systemImage: "arrow.counterclockwise")
                }
            }
        } footer: {
            if store.portfolio.cash < 1 {
                Text("You're fully invested — sell a position to free up cash.")
            } else if store.portfolio.positions.count >= PaperPortfolioStore.maxPositions {
                Text("You've reached the practice limit of \(PaperPortfolioStore.maxPositions) positions.")
            }
        }
    }

    // MARK: - Share (Pro)

    @ViewBuilder private var shareSection: some View {
        if entitlements.isPro, store.hasStarted, let shareImage {
            Section {
                ShareLink(item: shareImage,
                          preview: SharePreview("My Hummingbird practice record", image: shareImage)) {
                    Label("Share your record", systemImage: "square.and.arrow.up")
                }
                .tint(Theme.accentAlt)
                .accessibilityHint("Shares how your practice trading compares to buy-and-hold, with the not-advice note included")
            }
        }
    }

    private var shareRenderKey: String {
        let c = report.comparison
        return "\(store.hasStarted)-\(Int(report.value))-\(Int(c.edge * 10000))-\(c.tradeCount)"
    }

    @MainActor private func renderShareImage() -> Image? {
        guard store.hasStarted else { return nil }
        let renderer = ImageRenderer(content: PaperPortfolioShareCard(report: report))
        renderer.scale = 3
        guard let uiImage = renderer.uiImage else { return nil }
        return Image(uiImage: uiImage)
    }

    private var disclaimerSection: some View {
        Section {
            Text("A record of practice trades, scored against buy-and-hold. End-of-day prices, on your device only. Never advice.")
                .font(.caption2).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)
        }
    }

    // MARK: - Helpers

    private func currentPrice(_ pos: PaperPosition) -> Double {
        store.latestPrices[pos.assetKey] ?? pos.entryPrice
    }

    private var sellDialogBinding: Binding<Bool> {
        Binding(get: { pendingSell != nil }, set: { if !$0 { pendingSell = nil } })
    }

    private var sellPrompt: String {
        guard let pos = pendingSell else { return "" }
        return "Sell \(pos.shares.formatted(.number.precision(.fractionLength(0...4)))) shares of \(pos.symbol.uppercased())?"
    }
}

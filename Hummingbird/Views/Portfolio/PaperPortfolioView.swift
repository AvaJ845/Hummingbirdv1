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
            ? "Ahead of buy-and-hold by \(c.edge.asSignedPercent())"
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
            concentrationSection
            if store.portfolio.openPositions.isEmpty {
                startOrCashSection
            } else {
                holdingsSection
            }
            readsSection
            vsMethodsSection
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
            ) { symbol, assetClass, amount, price, direction, methodDirections in
                _ = store.buy(symbol: symbol, assetClass: assetClass, cashAmount: amount,
                              price: price, direction: direction, methodDirections: methodDirections)
                Task { await store.revalueDue(using: service, force: true) }
            }
        }
        .confirmationDialog(sellPrompt, isPresented: sellDialogBinding, titleVisibility: .visible) {
            if let pos = pendingSell {
                let price = currentPrice(pos)
                let fresh = store.latestPrices[pos.assetKey] != nil
                Button(fresh ? "Sell all at \(price.asCurrency())" : "Sell all at cost · \(price.asCurrency())") {
                    _ = store.sell(positionID: pos.id, price: price)
                    pendingSell = nil
                }
                Button("Sell half at \(price.asCurrency())") {
                    _ = store.sell(positionID: pos.id, shares: pos.shares / 2, price: price)
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
                if let periodText {
                    Text(periodText).font(.caption2).foregroundStyle(.tertiary)
                }
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
                Text("You've made \(report.comparison.tradeCount) trade\(report.comparison.tradeCount == 1 ? "" : "s"). The buy-and-hold comparison makes none.")
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
            if let market = marketReturn {
                Text("The market (S&P) \(market.asSignedPercent()) over the same period.")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            if let dcaReturn {
                Text("Spread out instead of all at once, it'd be \(dcaReturn.asSignedPercent()) — dollar-cost averaging.")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(vsHoldHeadline)
    }

    /// Return of the starting cash if it had gone into the market (S&P) on day
    /// one. Nil until the market history loads.
    private var marketReturn: Double? {
        guard let market = valuePoints.last?.market, report.startingCash != 0 else { return nil }
        return (market - report.startingCash) / report.startingCash
    }

    /// "What if you'd spread the same day-one dollars over several buys
    /// instead?" — dollar-cost averaging, computed from data already fetched
    /// for the chart. Nil until there's enough history to make more than one
    /// possible buy date (see `PaperPortfolioEngine.dollarCostAverageValue`).
    private var dcaReturn: Double? {
        guard report.startingCash != 0,
              let dca = PaperPortfolioEngine.dollarCostAverageValue(store.portfolio, histories: store.histories)
        else { return nil }
        return (dca - report.startingCash) / report.startingCash
    }

    private var vsHoldHeadline: String {
        let c = report.comparison
        if c.tradeCount == 0 { return "You're holding your first picks." }
        if abs(c.edge) < 0.0005 { return "Even with buy-and-hold." }
        return c.isBeatingHold
            ? "Ahead of buy-and-hold by \(c.edge.asSignedPercent())."
            : "Behind buy-and-hold by \((-c.edge).asPercent())."
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

    // MARK: - Diversification (information, never advice)

    @ViewBuilder private var concentrationSection: some View {
        if let c = report.concentration {
            Section {
                HStack {
                    Label("Diversification", systemImage: "chart.pie").font(.subheadline)
                    Spacer()
                    Text(c.assetCount == 1 ? "1 asset" : "\(c.assetCount) assets")
                        .font(.subheadline.weight(.semibold)).monospacedDigit()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Diversification: \(c.assetCount) asset\(c.assetCount == 1 ? "" : "s") held, \(pctText(c.topFraction)) in \(c.topSymbol).")
            } footer: {
                Text(concentrationFooter(c))
            }
        }
    }

    private func concentrationFooter(_ c: ConcentrationInsight) -> String {
        if c.assetCount == 1 {
            return "All of it is in \(c.topSymbol). Diversification spreads risk across holdings — right now you have none."
        }
        return "\(pctText(c.topFraction)) is in \(c.topSymbol), your largest holding. Diversification spreads risk across holdings, for better or worse."
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
                    if let regime = PaperPortfolioEngine.regime(for: pos, histories: store.histories), regime.isNoteworthy {
                        regimeChip(regime)
                    }
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
        .accessibilityLabel(holdingAccessibilityLabel(pos, value: value, change: change))
    }

    private func holdingAccessibilityLabel(_ pos: PaperPosition, value: Double, change: Double) -> String {
        var label = "\(pos.symbol.uppercased()), you leaned \(pos.direction.title), \(value.asCurrency()), \(change.asSignedPercent())."
        if let regime = PaperPortfolioEngine.regime(for: pos, histories: store.histories), regime.isNoteworthy {
            label += " \(regime.title)."
        }
        return label + " Tap to sell."
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

    /// A quiet heads-up when a holding is currently more volatile than its own
    /// norm — same classifier and thresholds used for sketches elsewhere, so
    /// "elevated"/"high" means the same thing here as it does there.
    private func regimeChip(_ regime: VolatilityRegime) -> some View {
        HStack(spacing: 2) {
            Image(systemName: regime.symbol)
            Text(regime.shortLabel)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(regime.tint)
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(regime.tint.opacity(0.14), in: Capsule())
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

    /// Your positions vs. the app's own forecasting methods, head-to-head on
    /// the very same buys — the portfolio's version of "You vs. the methods."
    /// Pro depth; free sees a teaser once there's something to unlock.
    @ViewBuilder private var vsMethodsSection: some View {
        if let vs = PaperPortfolioEngine.vsMethods(store.portfolio) {
            Section {
                if entitlements.isPro {
                    HStack {
                        Text("You").font(.body.weight(.bold))
                        Spacer()
                        Text(pctText(vs.userHitRate)).font(.body.weight(.bold)).monospacedDigit()
                            .foregroundStyle(Theme.accent)
                        Text("·  \(vs.userDecided)").font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                    }
                    ForEach(vs.methods) { method in
                        HStack {
                            Text(method.methodName).font(.body).foregroundStyle(.secondary)
                            Spacer()
                            Text(pctText(method.hitRate)).font(.body.weight(.medium)).monospacedDigit()
                                .foregroundStyle(.secondary)
                            Image(systemName: vs.userHitRate > method.hitRate ? "checkmark" : "minus")
                                .font(.caption2)
                                .foregroundStyle(vs.userHitRate > method.hitRate ? Theme.up : Color.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(method.methodName): right \(pctText(method.hitRate)), you are \(vs.userHitRate > method.hitRate ? "ahead" : "not ahead")")
                    }
                } else {
                    Button(action: onUnlock) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Your trades vs. the methods", systemImage: "sparkles")
                                .font(.body.weight(.semibold)).foregroundStyle(Theme.brandGradient)
                            Text("See whether your own trades are beating the app's methods — scored on the very same positions. Pro.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("Your trades vs. the methods")
            } footer: {
                if entitlements.isPro {
                    Text("You're ahead of \(vs.methodsBeaten) of \(vs.methods.count) methods so far — a record of the past, never advice. Small samples wobble; keep trading.")
                }
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
            VStack(alignment: .trailing, spacing: 2) {
                if let realized = pos.realizedReturn {
                    Text(realized.asSignedPercent()).font(.body.weight(.semibold)).monospacedDigit()
                        .foregroundStyle(abs(realized) < 0.00005 ? .secondary : (realized > 0 ? Theme.up : Theme.down))
                }
                if let closedAt = pos.closedAt {
                    Text("sold \(closedAt.formatted(.dateTime.month(.abbreviated).day()))")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(pos.symbol.uppercased()), leaned \(pos.direction.title), \(leanResultText(pos)), realized \(pos.realizedReturn?.asSignedPercent() ?? "flat")\(pos.closedAt.map { ", sold \($0.formatted(.dateTime.month(.abbreviated).day()))" } ?? "").")
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

    private var practiceStart: Date? { store.portfolio.positions.map(\.openedAt).min() }

    private var periodText: String? {
        guard let start = practiceStart else { return nil }
        let days = max(1, Calendar.current.dateComponents([.day], from: start, to: Date()).day ?? 0)
        return "over \(days) day\(days == 1 ? "" : "s") · since \(start.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private var shareRenderKey: String {
        let c = report.comparison
        return "\(store.hasStarted)-\(Int(report.value))-\(Int(c.edge * 10000))-\(c.tradeCount)-\(Int((marketReturn ?? 0) * 10000))"
    }

    @MainActor private func renderShareImage() -> Image? {
        guard store.hasStarted else { return nil }
        let renderer = ImageRenderer(content: PaperPortfolioShareCard(
            report: report, marketReturn: marketReturn, startDate: practiceStart))
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

import Foundation
import Observation

/// Owns forecast inputs/outputs and orchestrates fetch → model → presentation.
@MainActor
@Observable
final class ForecastViewModel {
    // Inputs
    var assetClass: AssetClass = .crypto {
        didSet {
            if assetClass != oldValue {
                symbol = assetClass.placeholder
                recomputeForecast()
            }
        }
    }

    var symbol: String = "bitcoin"
    var horizon: Int = 30 {
        didSet {
            let clamped = entitlements.maxHorizon(requested: horizon)
            if clamped != horizon {
                horizon = clamped
                return
            }
            if horizon != oldValue { recomputeForecast() }
        }
    }

    var model: ForecastModel = .default {
        didSet {
            if model.id != oldValue.id { recomputeForecast() }
        }
    }

    /// Selected economic indicator IDs that tilt the forecast.
    var selectedIndicatorIDs: Set<String> = [] {
        didSet {
            if selectedIndicatorIDs != oldValue { recomputeForecast() }
        }
    }

    /// Retail default: plain-English bottom line. Details mode exposes technical copy.
    var easyMode: Bool = UserDefaults.standard.object(forKey: "hummingbird.easyMode") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(easyMode, forKey: "hummingbird.easyMode")
        }
    }

    // Outputs
    private(set) var series: PriceSeries?
    private(set) var forecast: Forecast? {
        didSet { updateSketchContext() }
    }
    /// Derived, at-a-glance context around the current sketch (regime,
    /// reliability, best-tracking method) — owned by the VM, rendered by the view.
    private(set) var sketchContext = SketchContext()
    private(set) var isLoading = false
    private(set) var isLoadingIndicators = false
    private(set) var errorMessage: String?
    private(set) var usingSampleData = false
    private(set) var indicatorSnapshots: [EconomicSnapshot] = []
    /// Bumps on each successful forecast so UI can fire sensory feedback.
    private(set) var forecastGeneration = 0
    /// True while a silent background price refresh is in flight (no full-screen spinner).
    private(set) var isRefreshing = false
    /// Timestamp of the most recent successful price load (initial run or auto-refresh).
    private(set) var lastUpdated: Date?
    /// Direction of the most recent auto-refresh price change (drives the flash).
    private(set) var priceDirection: PriceDirection = .unchanged
    /// Bumps only when an auto-refresh actually moves the displayed close.
    private(set) var priceUpdateToken = 0
    /// Set when the user hits a Pro gate — UI presents the paywall.
    var pendingPaywallReason: String?
    /// Set once, right when a streak first reaches 2 days — UI offers the
    /// reminder opt-in at the moment it's actually earned, instead of leaving
    /// it to be found in Settings. Carries the streak count for the message.
    var pendingStreakReminderOffer: Int?

    enum PriceDirection { case up, down, unchanged }

    var hasResult: Bool {
        guard let forecast else { return false }
        return !forecast.isEmpty
    }

    /// The asset currently loaded (from the fetched series, not the input field).
    var currentWatchItem: WatchlistItem? {
        guard let series else { return nil }
        return WatchlistItem(symbol: series.symbol, assetClass: series.assetClass)
    }

    /// Read-only access to the loaded series (for snapshot building).
    var loadedSeries: PriceSeries? { series }

    /// Load a saved asset and run it.
    func load(_ item: WatchlistItem) {
        assetClass = item.assetClass
        symbol = item.symbol
        run()
    }

    var selectedIndicatorCount: Int { selectedIndicatorIDs.count }

    var activeMacro: MacroAdjustment {
        macro(for: model)
    }

    var maxHorizonAllowed: Int {
        entitlements.isPro ? 90 : FreeTierLimits.maxHorizonDays
    }

    /// Side-by-side previews for every available model. Cached, and recomputed
    /// off the main actor only when the *configuration* changes (asset · horizon
    /// · macro selection) — not on every SwiftUI read or silent price tick.
    /// Previously a computed property that re-ran all-model forecasts *and*
    /// walk-forward backtests on the main thread ~5× per results render.
    private(set) var modelPreviews: [ModelForecastPreview] = []

    /// Model id with the lowest recent backtest error among entitlement-visible
    /// methods. Nil unless at least two methods have a comparable score.
    var bestRecentModelID: String? {
        let scored = modelPreviews
            .filter { entitlements.canUse(model: $0.model) }
            .compactMap { preview in preview.recentError.map { (id: preview.model.id, error: $0) } }
        guard scored.count >= 2 else { return nil }
        return scored.min(by: { $0.error < $1.error })?.id
    }

    /// Spread across currently visible (entitlement-aware) model projections.
    var disagreementSpread: Double? {
        let changes = modelPreviews
            .filter { entitlements.canUse(model: $0.model) }
            .map(\.expectedChange)
        guard let min = changes.min(), let max = changes.max(), changes.count > 1 else { return nil }
        return max - min
    }

    /// Adaptive auto-refresh cadence for the loaded asset:
    /// crypto trades 24/7 (fast); stocks refresh briskly only while the US
    /// market is open, and slowly off-hours when the last close won't move.
    var autoRefreshInterval: TimeInterval {
        guard let series else { return 60 }
        let base: TimeInterval
        switch series.assetClass {
        case .crypto:
            base = 30
        case .stock:
            base = MarketCalendar.isUSMarketOpen() ? 45 : 300
        }
        // Back off hard on Low Power Mode — near-live prices aren't worth the drain.
        return ProcessInfo.processInfo.isLowPowerModeEnabled ? max(base * 6, 300) : base
    }

    /// Whether the loaded asset's price is currently live (for the badge).
    var isPriceLive: Bool {
        guard let series else { return false }
        switch series.assetClass {
        case .crypto: return true
        case .stock: return MarketCalendar.isUSMarketOpen()
        }
    }

    var liveStatusLabel: String { isPriceLive ? "Live" : "Market closed" }

    /// Baseline close used to detect auto-refresh price moves; reset on each full run.
    private var lastObservedClose: Double?

    private let service: any MarketDataProviding
    private let economicService: any EconomicDataProviding
    private let entitlements: EntitlementStore
    private var runTask: Task<Void, Never>?
    private var indicatorTask: Task<Void, Never>?
    private var autoRefreshTask: Task<Void, Never>?

    let scorecard: SketchScorecardStore
    /// The user's "call" lifecycle lives in its own coordinator; `userCalls`
    /// stays as a passthrough so views keep reading the store directly.
    let calls: CallsCoordinator
    var userCalls: UserCallStore { calls.store }
    private var reliabilityTask: Task<Void, Never>?
    private var lastReliabilityKey: String?
    private var previewTask: Task<Void, Never>?
    private var lastPreviewKey: String?

    init(
        service: any MarketDataProviding = MarketDataService(),
        economicService: any EconomicDataProviding = EconomicDataService(),
        entitlements: EntitlementStore,
        scorecard: SketchScorecardStore = SketchScorecardStore(),
        userCalls: UserCallStore = UserCallStore()
    ) {
        self.service = service
        self.economicService = economicService
        self.entitlements = entitlements
        self.scorecard = scorecard
        self.calls = CallsCoordinator(store: userCalls, service: service)
    }

    /// A direction + confidence + horizon the user committed *before* the sketch
    /// reveals. The call horizon is its own short window (a tight return loop),
    /// independent of the sketch's display horizon.
    typealias PendingCall = (direction: CallDirection, confidence: CallConfidence, reason: CallReason?, horizonDays: Int)

    func run(loggingCall: PendingCall? = nil) {
        let trimmed = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = MarketDataError.emptySymbol.errorDescription
            return
        }
        guard model.status.isAvailable else {
            errorMessage = "\(model.name) isn't available yet. Pick a ready model."
            return
        }
        guard entitlements.canUse(model: model) else {
            pendingPaywallReason = "\(model.name) is a Pro method. Free includes Drift, Trend + weekday, Straight trend, and Holt."
            return
        }

        runTask?.cancel()
        runTask = Task { [weak self] in
            await self?.performRun(symbol: trimmed, loggingCall: loggingCall)
        }
    }

    @discardableResult
    func selectModel(_ model: ForecastModel) -> Bool {
        guard model.status.isAvailable else { return false }
        guard entitlements.canUse(model: model) else {
            pendingPaywallReason = "\(model.name) is a Pro method. Free includes Drift, Trend + weekday, Straight trend, and Holt."
            return false
        }
        self.model = model
        return true
    }

    func refreshIndicators() {
        indicatorTask?.cancel()
        indicatorTask = Task { [weak self] in
            await self?.performIndicatorRefresh()
        }
    }

    @discardableResult
    func toggleIndicator(_ id: String) -> Bool {
        if selectedIndicatorIDs.contains(id) {
            selectedIndicatorIDs.remove(id)
            return true
        }
        guard entitlements.canSelectMoreIndicators(currentCount: selectedIndicatorIDs.count) else {
            pendingPaywallReason = "Free includes \(FreeTierLimits.maxSelectedIndicators) economy what-ifs. Pro unlocks every knob — still just scenarios, not advice."
            return false
        }
        selectedIndicatorIDs.insert(id)
        return true
    }

    func preview(for model: ForecastModel) -> ModelForecastPreview? {
        modelPreviews.first { $0.model.id == model.id }
    }

    func macro(for model: ForecastModel) -> MacroAdjustment {
        MacroAdjuster.adjustment(
            from: indicatorSnapshots,
            selected: selectedIndicatorIDs,
            assetClass: assetClass,
            model: model
        )
    }

    /// Recompute from the already-fetched series (no network).
    func recomputeForecast() {
        guard let series else { return }
        guard model.status.isAvailable, entitlements.canUse(model: model) else { return }
        forecast = Forecaster.forecast(
            series: series,
            model: model,
            horizon: horizon,
            macro: activeMacro
        )
        refreshModelPreviewsIfNeeded()
    }

    // MARK: - Model previews (cached, off-main)

    /// Recompute the all-model previews only when the configuration changes
    /// (asset · horizon · macro inputs). The heavy work — a forecast plus a
    /// walk-forward backtest for every model — runs on a detached utility task,
    /// off the main actor. Macros are computed on-main first (cheap) so the
    /// detached closure captures only value types.
    private func refreshModelPreviewsIfNeeded() {
        guard let series, series.isForecastable else {
            modelPreviews = []
            previewTask?.cancel(); previewTask = nil; lastPreviewKey = nil
            return
        }
        let key = "\(series.symbol)|\(series.assetClass.rawValue)|\(horizon)|\(selectedIndicatorIDs.sorted().joined(separator: ","))|\(indicatorSnapshots.count)"
        guard key != lastPreviewKey else { return }
        lastPreviewKey = key

        previewTask?.cancel()
        let candidates = ForecastModel.available
        let macros = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, macro(for: $0)) })
        let loaded = series
        let h = horizon

        previewTask = Task { [weak self] in
            let previews = await Task.detached(priority: .userInitiated) {
                candidates.compactMap { candidate -> ModelForecastPreview? in
                    let result = Forecaster.forecast(
                        series: loaded, model: candidate, horizon: h,
                        macro: macros[candidate.id] ?? .none
                    )
                    guard let target = result.targetPrice, let change = result.expectedChange else { return nil }
                    return ModelForecastPreview(
                        model: candidate,
                        targetPrice: target,
                        expectedChange: change,
                        macroBias: result.macro.horizonBias,
                        recentError: Forecaster.walkForwardMAPE(series: loaded, model: candidate)
                    )
                }
            }.value
            guard let self, !Task.isCancelled else { return }
            self.modelPreviews = previews
        }
    }

    /// Suspends until the in-flight model-preview recompute (if any) has landed.
    /// A test seam — harmless in the app.
    func awaitModelPreviews() async {
        await previewTask?.value
    }

    // MARK: - Sketch context (regime · reliability · best method)

    /// Refresh the derived context whenever the forecast changes. Cheap parts
    /// (record, resolve, regime, best method) run every time; the expensive
    /// reliability backtests only recompute when the *configuration* changes
    /// (asset · model · horizon) — so a silent price tick never re-runs them.
    private func updateSketchContext() {
        guard let forecast, let series, hasResult else {
            sketchContext = SketchContext()
            reliabilityTask?.cancel()
            reliabilityTask = nil
            lastReliabilityKey = nil
            return
        }

        scorecard.record(forecast: forecast, symbol: series.symbol, assetClass: series.assetClass)
        scorecard.resolve(using: series)

        var context = sketchContext          // preserve the current reliability
        context.regime = RegimeClassifier.classify(series: series)
        context.bestModel = scorecard.bestModel(for: series.symbol, assetClass: series.assetClass)
        context.modelBreakdown = scorecard.modelPerformances(for: series.symbol, assetClass: series.assetClass)
        sketchContext = context

        refreshReliabilityIfNeeded(series: series, forecast: forecast)
    }

    private func refreshReliabilityIfNeeded(series: PriceSeries, forecast: Forecast) {
        let key = "\(series.symbol)|\(forecast.model.strategy.rawValue)|\(forecast.points.count)"
        guard key != lastReliabilityKey else { return }   // P0: skip on price ticks / same config
        lastReliabilityKey = key
        sketchContext.reliability = nil                    // drop the stale read until recomputed

        reliabilityTask?.cancel()
        let model = forecast.model
        let horizon = forecast.points.count
        reliabilityTask = Task { [weak self] in
            let score = await Task.detached(priority: .utility) {
                let inputs = ReliabilityInputs(
                    backtestMAPE: Forecaster.walkForwardMAPE(series: series, model: model),
                    regime: RegimeClassifier.classify(series: series),
                    modelDisagreement: Forecaster.modelDisagreement(series: series, horizon: horizon),
                    horizon: horizon,
                    historyCount: series.points.count
                )
                return ReliabilityEngine.score(inputs)
            }.value
            guard let self, !Task.isCancelled else { return }
            self.sketchContext.reliability = score
        }
    }

    /// Each method's directional prediction over the call's horizon, snapshotted
    /// at call time — the basis for the honest "you vs. the methods" comparison.
    private func methodDirectionSnapshot(series: PriceSeries, horizon: Int) -> [String: CallDirection] {
        var result: [String: CallDirection] = [:]
        for candidate in ForecastModel.available {
            let projection = Forecaster.forecast(series: series, model: candidate, horizon: horizon,
                                                 macro: macro(for: candidate))
            if let change = projection.expectedChange, change != 0 {
                result[candidate.strategy.rawValue] = change > 0 ? .higher : .lower
            }
        }
        return result
    }

    /// Resolve any calls whose horizon has passed. Cheap when nothing is due.
    /// Called on launch / foreground so the record fills in without opening
    /// "Your calls".
    func resolveDueCalls() async {
        await calls.resolveDue()
    }

    func enforceEntitlementsAfterPurchaseChange() {
        horizon = entitlements.maxHorizon(requested: horizon)
        if !entitlements.canUse(model: model), let fallback = ForecastModel.available.first(where: { entitlements.canUse(model: $0) }) {
            model = fallback
        }
        if !entitlements.isPro, selectedIndicatorIDs.count > FreeTierLimits.maxSelectedIndicators {
            selectedIndicatorIDs = Set(selectedIndicatorIDs.prefix(FreeTierLimits.maxSelectedIndicators))
        }
        recomputeForecast()
    }

    // MARK: - Auto refresh

    /// Begin periodic silent refreshes of the loaded ticker's latest price.
    /// Idempotent — a no-op if a loop is already running.
    func beginAutoRefresh() {
        guard autoRefreshTask == nil else { return }
        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                let interval = self?.autoRefreshInterval ?? 60
                try? await Task.sleep(for: .seconds(interval))
                guard let self, !Task.isCancelled else { break }
                await self.silentRefresh()
            }
        }
    }

    /// Stop the auto-refresh loop (e.g. when results clear or the app backgrounds).
    func endAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    /// Re-fetch the currently displayed asset's price without the full-screen
    /// loading state, then recompute the projection in place. Refreshes the
    /// *loaded* series (not the input field), and swallows failures so the last
    /// good result stays on screen.
    func silentRefresh() async {
        guard let current = series, hasResult, !isLoading, !isRefreshing else { return }
        guard model.status.isAvailable, entitlements.canUse(model: model) else { return }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let fetched = try await service.history(symbol: current.symbol, assetClass: current.assetClass)
            guard !Task.isCancelled, fetched.isForecastable else { return }
            // Bail if the user loaded a different asset while this was in flight.
            guard let now = series, now.symbol == current.symbol, now.assetClass == current.assetClass else { return }
            series = fetched
            usingSampleData = fetched.isSample
            recomputeForecast()
            lastUpdated = Date()
            // Detect a real price move to trigger the flash.
            if let newClose = forecast?.lastClose {
                if let prev = lastObservedClose, newClose != prev {
                    priceDirection = newClose > prev ? .up : .down
                    priceUpdateToken += 1
                }
                lastObservedClose = newClose
            }
        } catch {
            // Silent — keep showing the last good data on transient failures.
        }
    }

    private func performRun(symbol: String, loggingCall: PendingCall? = nil) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        async let priceTask = service.history(symbol: symbol, assetClass: assetClass)
        async let indicatorsTask = economicService.fetchSnapshots()

        do {
            let fetched = try await priceTask
            let snapshots = await indicatorsTask
            guard !Task.isCancelled else { return }

            indicatorSnapshots = snapshots
            // Drop toggles for series we couldn't fetch live.
            selectedIndicatorIDs = selectedIndicatorIDs.intersection(Set(snapshots.map(\.id)))

            guard fetched.isForecastable else {
                errorMessage = MarketDataError.insufficientHistory(Forecaster.minimumHistoryCount).errorDescription
                series = nil
                forecast = nil
                usingSampleData = false
                return
            }

            series = fetched
            usingSampleData = fetched.isSample
            forecast = Forecaster.forecast(
                series: fetched,
                model: model,
                horizon: horizon,
                macro: activeMacro
            )
            forecastGeneration += 1
            lastUpdated = Date()
            // Reset the flash baseline — a fresh run is not a "price move".
            lastObservedClose = forecast?.lastClose
            priceDirection = .unchanged
            refreshModelPreviewsIfNeeded()

            // Fill in any past calls now that we have fresh prices for this asset
            // (clearing their reminders), then log the user's pre-sketch call.
            calls.resolve(using: fetched)
            if let loggingCall, let spot = forecast?.lastClose {
                calls.record(direction: loggingCall.direction, confidence: loggingCall.confidence,
                             reason: loggingCall.reason,
                             horizonDays: loggingCall.horizonDays, symbol: fetched.symbol,
                             assetClass: fetched.assetClass, spot: spot,
                             methodDirections: methodDirectionSnapshot(series: fetched, horizon: loggingCall.horizonDays))
                // Today's call is in — cancel any pending "don't lose your
                // streak" reminder right away rather than waiting on the next
                // background cycle to notice.
                let streak = calls.store.currentStreak
                Task { await StreakReminder.rescheduleIfEnabled(streak: streak, calls: calls.store.calls) }

                // Offer the reminder opt-in at the exact moment it's earned —
                // right after the call that first builds a 2-day streak —
                // rather than leaving it to be found in Settings later.
                if StreakReminder.shouldOfferPrompt(streak: streak) {
                    StreakReminder.recordOffered()
                    pendingStreakReminderOffer = streak
                }
            }
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            series = nil
            forecast = nil
            usingSampleData = false
        }
    }

    private func performIndicatorRefresh() async {
        isLoadingIndicators = true
        defer { isLoadingIndicators = false }

        let snapshots = await economicService.fetchSnapshots()
        guard !Task.isCancelled else { return }
        indicatorSnapshots = snapshots
        selectedIndicatorIDs = selectedIndicatorIDs.intersection(Set(snapshots.map(\.id)))
        recomputeForecast()
    }
}

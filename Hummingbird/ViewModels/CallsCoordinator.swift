import Foundation

/// Owns the user's "call" lifecycle — record, resolve, and remind — so the
/// forecast view model doesn't have to. The forecasting side computes the method
/// snapshot (it owns the models + macro); everything else about calls lives here.
@MainActor
final class CallsCoordinator {
    let store: UserCallStore
    private let service: any MarketDataProviding

    init(store: UserCallStore = UserCallStore(), service: any MarketDataProviding = MarketDataService()) {
        self.store = store
        self.service = service
    }

    /// Log the user's pre-sketch call (with each method's snapshotted direction)
    /// and schedule its resolution reminder.
    func record(direction: CallDirection, confidence: CallConfidence, horizonDays: Int,
                symbol: String, assetClass: AssetClass, spot: Double,
                methodDirections: [String: CallDirection]) {
        let recorded = store.record(symbol: symbol, assetClass: assetClass, direction: direction,
                                    confidence: confidence, horizonDays: horizonDays, spot: spot,
                                    methodDirections: methodDirections)
        Task { await scheduleReminder(recorded) }
    }

    /// Resolve pending calls for this asset against a fresh series (on a run),
    /// clearing the reminders of any that resolved.
    func resolve(using series: PriceSeries) {
        for id in store.resolve(using: series) {
            NotificationService.cancelCallResolution(callID: id)
        }
    }

    /// Resolve any calls whose horizon has passed by fetching fresh prices
    /// (launch / foreground / background). Cheap when nothing is due.
    func resolveDue() async {
        for id in await store.resolveDue(using: service) {
            NotificationService.cancelCallResolution(callID: id)
        }
    }

    /// Ask (once) for notification permission and schedule the "your call is
    /// ready" nudge at the call's horizon.
    private func scheduleReminder(_ call: UserCall) async {
        var authorized = await NotificationService.isAuthorized()
        if !authorized { authorized = await NotificationService.requestAuthorization() }
        guard authorized else { return }
        await NotificationService.scheduleCallResolution(callID: call.id, symbol: call.symbol, at: call.targetDate)
    }
}

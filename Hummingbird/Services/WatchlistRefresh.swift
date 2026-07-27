import Foundation
import WidgetKit

/// Single source of truth for refreshing watchlist snapshots + firing movement
/// alerts. Used by the Watchlist screen, auto-refresh, and the background task
/// so behavior is identical everywhere. Reloads widget timelines when done.
@MainActor
enum WatchlistRefresh {
    /// Refresh every saved asset, then reload widgets. Sequential to stay gentle
    /// on the free public APIs (avoids rate limits).
    static func refreshAll(store: WatchlistStore, service: any MarketDataProviding = MarketDataService()) async {
        for item in store.items {
            await refresh(item, store: store, service: service)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Refresh a single asset: fetch → snapshot → (alert) → save. Returns whether
    /// a fresh snapshot was stored.
    @discardableResult
    static func refresh(
        _ item: WatchlistItem,
        store: WatchlistStore,
        service: any MarketDataProviding = MarketDataService()
    ) async -> Bool {
        let previousPrice = store.snapshot(for: item)?.price
        guard let series = try? await service.history(symbol: item.symbol, assetClass: item.assetClass),
              series.isForecastable,
              let snapshot = WatchlistIntelligence.snapshot(for: item, series: series) else { return false }

        // Honest movement alert (never a signal) if the asset moved since last check.
        let pref = store.alertPreference(for: item)
        if pref.enabled, let previousPrice,
           let alert = AlertEngine.evaluate(item: item, previousPrice: previousPrice,
                                            newPrice: snapshot.price, threshold: pref.thresholdPercent) {
            await NotificationService.deliver(alert, id: item.id)
        }

        store.saveSnapshot(snapshot)
        return true
    }
}

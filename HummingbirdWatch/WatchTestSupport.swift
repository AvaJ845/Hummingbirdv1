#if DEBUG
import Foundation

/// Launch-argument switch for deterministic watch-app screenshots, mirroring
/// `Hummingbird/Support/TestSupport.swift`.
///
/// A fresh watchOS simulator isn't paired to any iPhone, so its App Group
/// container starts empty and `WatchContentView` renders the "No watchlist"
/// empty state. `-WATCH_UITEST_SEED` writes a small, deterministic set of
/// `WatchlistItem` + `WatchlistSnapshot` entries into the same App Group keys
/// `SharedStorage`/`WatchContentView.reload()` read
/// (`hummingbird.watchlist.items` / `hummingbird.watchlist.snapshots`), in
/// the same shape the iOS app's `WatchlistIntelligence` writes, so the list
/// renders populated for a screenshot without needing a paired phone.
///
/// Entirely `#if DEBUG` — compiled out of Release, like `TestSupport.swift`.
enum WatchTestSupport {
    private static let arguments = ProcessInfo.processInfo.arguments

    static func applyLaunchArgumentsIfNeeded() {
        guard arguments.contains("-WATCH_UITEST_SEED") else { return }
        seedWatchlist()
    }

    /// Three deterministic watched assets — a stock, a crypto, and a second
    /// stock — so the watch list renders with a mix of tickers, prices, and
    /// up/down projections instead of the empty state.
    private static func seedWatchlist() {
        let items = [
            WatchlistItem(symbol: "AAPL", assetClass: .stock, displayName: "Apple"),
            WatchlistItem(symbol: "bitcoin", assetClass: .crypto, displayName: "Bitcoin"),
            WatchlistItem(symbol: "MSFT", assetClass: .stock, displayName: "Microsoft")
        ]

        let now = Date()
        let history: [Double] = [0.42, 0.48, 0.51, 0.47, 0.55, 0.60, 0.58]
        let upProjection: [Double] = [0.58, 0.63, 0.69, 0.74]
        let downProjection: [Double] = [0.58, 0.53, 0.49, 0.44]

        let snapshots = [
            WatchlistSnapshot(
                symbol: "AAPL", assetClass: .stock, title: "Apple",
                price: 227.52, projectedChange: 0.021,
                bestMethodName: "Trend + weekday", horizonDays: 7,
                historySpark: history, projectionSpark: upProjection,
                updatedAt: now
            ),
            WatchlistSnapshot(
                symbol: "bitcoin", assetClass: .crypto, title: "Bitcoin",
                price: 61250.30, projectedChange: -0.034,
                bestMethodName: "Drift", horizonDays: 7,
                historySpark: history, projectionSpark: downProjection,
                updatedAt: now
            ),
            WatchlistSnapshot(
                symbol: "MSFT", assetClass: .stock, title: "Microsoft",
                price: 415.88, projectedChange: 0.012,
                bestMethodName: "Holt", horizonDays: 7,
                historySpark: history, projectionSpark: upProjection,
                updatedAt: now
            )
        ]

        let defaults = AppGroup.defaults
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: SharedStorage.itemsKey)
        }
        if let data = try? JSONEncoder().encode(snapshots) {
            defaults.set(data, forKey: SharedStorage.snapshotsKey)
        }
        defaults.synchronize()
    }
}
#endif

import Foundation

/// Per-asset alert settings. Movement alerts only — Hummingbird never sends
/// buy/sell signals, only "this moved" and "open for a fresh sketch."
struct AlertPreference: Codable, Hashable, Sendable {
    var enabled: Bool = false
    /// Absolute move (as a fraction) since last check that triggers a notification.
    var thresholdPercent: Double = 0.05
}

/// A rendered movement notification.
struct MovementAlert: Equatable, Sendable {
    let title: String
    let body: String
    let changeFraction: Double
}

/// Decides whether an asset's move since the last check warrants a notification.
/// Pure and deterministic so it can be unit tested. Educational framing only.
enum AlertEngine {
    static func evaluate(
        item: WatchlistItem,
        previousPrice: Double,
        newPrice: Double,
        threshold: Double
    ) -> MovementAlert? {
        guard previousPrice > 0, threshold > 0 else { return nil }
        let change = (newPrice - previousPrice) / previousPrice
        guard abs(change) >= threshold else { return nil }

        let direction = change >= 0 ? "up" : "down"
        return MovementAlert(
            title: "\(item.title) moved \(change.asSignedPercent())",
            body: "\(item.title) is \(direction) \(abs(change).asPercent()) since your last check. Movement, not a signal — open Hummingbird for a fresh sketch.",
            changeFraction: change
        )
    }

    /// Same movement check, applied to practice-portfolio holdings instead of
    /// the watchlist. Grouped by symbol (not lot) so a partial sell doesn't
    /// fire the same alert twice, and only evaluates symbols present in both
    /// price snapshots — a first-ever fetch (no previous price yet) can't move.
    static func evaluatePortfolio(
        openPositions: [PaperPosition],
        previousPrices: [String: Double],
        newPrices: [String: Double],
        threshold: Double
    ) -> [MovementAlert] {
        var seen = Set<String>()
        var alerts: [MovementAlert] = []
        for pos in openPositions {
            guard seen.insert(pos.assetKey).inserted else { continue }
            guard let previous = previousPrices[pos.assetKey], let new = newPrices[pos.assetKey] else { continue }
            let item = WatchlistItem(symbol: pos.symbol, assetClass: pos.assetClass)
            if let alert = evaluate(item: item, previousPrice: previous, newPrice: new, threshold: threshold) {
                alerts.append(alert)
            }
        }
        return alerts
    }
}

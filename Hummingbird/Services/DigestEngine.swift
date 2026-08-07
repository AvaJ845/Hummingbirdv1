import Foundation

/// Composes the optional "morning read" — a calm, on-device summary of the
/// watchlist's current sketches. Educational projections, never predictions or
/// advice. Pure and deterministic so it's fully unit-tested; content is built
/// from the latest local snapshots (no server).
struct Digest: Equatable, Sendable {
    let title: String
    let body: String
}

enum DigestEngine {
    /// Build the digest, or nil when there's nothing to say (no watchlist).
    /// Ranks by the size of each asset's projected move; `notableThreshold`
    /// is the projected move worth calling out.
    static func compose(
        snapshots: [WatchlistSnapshot],
        notableThreshold: Double = 0.02
    ) -> Digest? {
        guard !snapshots.isEmpty else { return nil }

        let movers = snapshots
            .map { (title: $0.title, change: $0.projectedChange) }
            .sorted { abs($0.change) > abs($1.change) }

        let notable = movers.filter { abs($0.change) >= notableThreshold }

        if notable.isEmpty {
            let n = snapshots.count
            return Digest(
                title: "Your morning read",
                body: "Your \(n) watched \(n == 1 ? "asset's sketch is" : "assets' sketches are") close to flat today. Educational projections, not predictions."
            )
        }

        let top = notable.prefix(3).map { "\($0.title) \($0.change.asSignedPercent())" }.joined(separator: ", ")
        let more = notable.count > 3 ? " and \(notable.count - 3) more" : ""
        return Digest(
            title: "Your morning read",
            body: "Your latest sketches: \(top)\(more). Educational projections across your watchlist — not predictions or advice."
        )
    }
}

/// Reads the user's digest preference and (re)schedules with fresh content.
/// Called on app-background so the notification never carries stale sketches.
enum MorningDigest {
    static let enabledKey = "hb.digest.enabled"
    static let hourKey = "hb.digest.hour"
    static let minuteKey = "hb.digest.minute"

    static func rescheduleIfEnabled() async {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: enabledKey), await NotificationService.isAuthorized() else { return }
        let hour = defaults.object(forKey: hourKey) as? Int ?? 8
        let minute = defaults.integer(forKey: minuteKey)
        let digest = DigestEngine.compose(snapshots: SharedStorage.snapshots())
            ?? Digest(title: "Your morning read", body: "Add assets to your watchlist to get a morning summary.")
        await NotificationService.scheduleMorningDigest(digest, hour: hour, minute: minute)
    }
}

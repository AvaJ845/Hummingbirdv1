import Foundation

/// One shared, short-lived price cache for the whole app. It exists to *coalesce*
/// the many fetch paths (auto-refresh, call resolution, model previews, the
/// method snapshot) that ask for the same symbol at nearly the same moment:
/// - a fresh cached series (within `ttl`) is returned without touching the network
/// - concurrent identical requests are deduped to a single in-flight fetch
///
/// The TTL is deliberately short (seconds) so auto-refresh still gets fresh data;
/// this trims redundant bursts, not intentional refreshes. Only real (non-sample)
/// results are cached, so a transient offline fallback never gets pinned.
actor PriceCache {
    static let shared = PriceCache()

    private struct Entry { let series: PriceSeries; let at: Date }
    private var entries: [String: Entry] = [:]
    private var inFlight: [String: Task<PriceSeries, Error>] = [:]

    func series(
        key: String,
        ttl: TimeInterval,
        fetch: @Sendable @escaping () async throws -> PriceSeries
    ) async throws -> PriceSeries {
        if let entry = entries[key], Date().timeIntervalSince(entry.at) < ttl {
            return entry.series
        }
        if let existing = inFlight[key] {
            return try await existing.value   // dedupe: ride the in-flight fetch
        }

        let task = Task { try await fetch() }
        inFlight[key] = task
        defer { inFlight[key] = nil }

        let series = try await task.value
        if !series.isSample {
            entries[key] = Entry(series: series, at: Date())
        }
        return series
    }
}

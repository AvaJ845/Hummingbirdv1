import Foundation

/// Pure, deterministic selection of which past resolved call to resurface for
/// spaced-retrieval review, and when. No state, no I/O — the caller supplies
/// which (call, interval) pairs have already been reviewed.
///
/// The mechanic: testing recall of your own past reasoning strengthens
/// retention far more than passively re-reading it (Roediger & Karpicke,
/// 2006, "Test-Enhanced Learning," Psychological Science — the testing
/// effect), and spacing those tests at increasing gaps beats massing them
/// together (Cepeda, Pashler, Vul, Wixted & Rohrer, 2006, Psychological
/// Bulletin — a meta-analysis of 254 studies on distributed practice). This
/// is education, not a habit loop: nothing here is scored, ranked, or shown
/// as a streak — it exists purely to help a call actually stick as learning.
enum SpacedRecallEngine {
    /// Days after resolution at which a call is tested — short, medium, and
    /// long-term consolidation checkpoints. Gaps widen because a memory that
    /// survives a longer gap is more durably learned (Cepeda et al., 2006).
    static let intervalsDays = [3, 10, 30]

    /// How many days past the ideal interval a call is still eligible — the
    /// app isn't opened at the exact hour, so this is a catch window, not a
    /// hard deadline.
    static let windowDays = 4

    /// The single best (call, interval index) to resurface right now, if any
    /// — the earliest unmet interval first, so recall stays close to its
    /// intended spacing rather than always jumping to the oldest available
    /// call regardless of schedule. Only resolved calls are eligible: there's
    /// nothing to test recall of until the real outcome exists.
    static func due(
        calls: [UserCall],
        isReviewed: (UserCall, Int) -> Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> (call: UserCall, intervalIndex: Int)? {
        let resolved = calls.filter(\.isResolved)
        guard !resolved.isEmpty else { return nil }

        for (index, interval) in intervalsDays.enumerated() {
            if let match = eligibleCandidates(atTier: index, interval: interval, resolved: resolved,
                                              isReviewed: isReviewed, now: now, calendar: calendar).first {
                return (match, index)
            }
        }
        return nil
    }

    /// Up to `limit` due (call, interval index) pairs, mixing different
    /// symbols into one sitting rather than one call at a time — interleaved
    /// material strengthens retention more than the same amount of practice
    /// reviewed in isolation (Rohrer & Taylor, 2007, "The Shuffling of
    /// Mathematics Problems Improves Learning," Instructional Science).
    /// Still respects tier priority and within-tier recency exactly as
    /// `due` does; interleaving only decides which *symbols* fill the batch.
    static func dueBatch(
        calls: [UserCall],
        isReviewed: (UserCall, Int) -> Bool,
        now: Date = Date(),
        calendar: Calendar = .current,
        limit: Int = 3
    ) -> [(call: UserCall, intervalIndex: Int)] {
        let resolved = calls.filter(\.isResolved)
        guard !resolved.isEmpty else { return [] }

        func fill(preferringNewSymbols: Bool, into batch: inout [(call: UserCall, intervalIndex: Int)]) {
            var seenSymbols = Set(batch.map(\.call.symbol))
            for (index, interval) in intervalsDays.enumerated() {
                guard batch.count < limit else { return }
                let candidates = eligibleCandidates(atTier: index, interval: interval, resolved: resolved,
                                                    isReviewed: isReviewed, now: now, calendar: calendar)
                for call in candidates {
                    guard batch.count < limit else { return }
                    guard !batch.contains(where: { $0.call.id == call.id && $0.intervalIndex == index }) else { continue }
                    if preferringNewSymbols {
                        guard !seenSymbols.contains(call.symbol) else { continue }
                        seenSymbols.insert(call.symbol)
                    }
                    batch.append((call, index))
                }
            }
        }

        var batch: [(call: UserCall, intervalIndex: Int)] = []
        fill(preferringNewSymbols: true, into: &batch)
        // Only one symbol had anything due — fill remaining slots without
        // the variety constraint rather than shipping a short batch.
        fill(preferringNewSymbols: false, into: &batch)
        return batch
    }

    /// Resolved calls eligible at one tier, oldest-waiting first.
    private static func eligibleCandidates(
        atTier index: Int, interval: Int, resolved: [UserCall],
        isReviewed: (UserCall, Int) -> Bool, now: Date, calendar: Calendar
    ) -> [UserCall] {
        resolved.filter { call in
            guard let resolvedAt = call.resolvedAt, !isReviewed(call, index) else { return false }
            let daysSince = calendar.dateComponents([.day], from: resolvedAt, to: now).day ?? 0
            return daysSince >= interval && daysSince <= interval + windowDays
        }
        .sorted { ($0.resolvedAt ?? .distantPast) < ($1.resolvedAt ?? .distantPast) }
    }
}

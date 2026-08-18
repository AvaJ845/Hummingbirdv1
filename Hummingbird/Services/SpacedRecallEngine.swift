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
            let candidates = resolved.filter { call in
                guard let resolvedAt = call.resolvedAt, !isReviewed(call, index) else { return false }
                let daysSince = calendar.dateComponents([.day], from: resolvedAt, to: now).day ?? 0
                return daysSince >= interval && daysSince <= interval + windowDays
            }
            // Earliest-resolved first within a tier: the call that's been
            // waiting longest for this checkpoint goes first.
            if let match = candidates.min(by: { ($0.resolvedAt ?? .distantPast) < ($1.resolvedAt ?? .distantPast) }) {
                return (match, index)
            }
        }
        return nil
    }
}

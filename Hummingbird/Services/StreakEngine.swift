import Foundation

/// Pure, deterministic streak math over the user's own calls — no state, no I/O.
///
/// Counts **participation**, never correctness: a streak is "you showed up and
/// made a call," not "you were right." A correctness-based streak would read as
/// a claim about predictive skill, which is exactly what Hummingbird never
/// claims about its own sketches — the same standard applies to the user's own
/// record. Derived entirely from `UserCall.createdAt`; no new persistence.
enum StreakEngine {
    /// Consecutive calendar days, ending today or yesterday, with at least one
    /// call logged. If no call has been made yet today, the streak is still
    /// "alive" through yesterday (it isn't broken until a full day passes with
    /// no call). Returns 0 for no calls or a lapsed streak.
    ///
    /// `freezesAvailable` forgives that many missed days along the walk back
    /// (a Pro perk — see `ProFeature.streakFreeze`) without counting them
    /// toward the streak length. It's a pure function of the current calls,
    /// not a persisted, depleting resource: pass `isPro ? 1 : 0` fresh each
    /// call. A single freeze bridges at most one recent gap; a second gap
    /// still breaks the chain, so daily habit pressure survives an occasional
    /// miss without becoming skippable-every-other-day.
    static func currentStreak(
        _ calls: [UserCall],
        freezesAvailable: Int = 0,
        asOf: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        guard !calls.isEmpty else { return 0 }

        let days = Set(calls.map { calendar.startOfDay(for: $0.createdAt) })
        var cursor = calendar.startOfDay(for: asOf)

        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }

        var streak = 0
        var freezesLeft = freezesAvailable
        while true {
            if days.contains(cursor) {
                streak += 1
            } else if freezesLeft > 0 {
                freezesLeft -= 1
            } else {
                break
            }
            guard let prior = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prior
        }
        return streak
    }
}

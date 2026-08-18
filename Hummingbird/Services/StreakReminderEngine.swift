import Foundation

/// Composes an optional same-day reminder when the user has an active streak
/// they haven't extended yet today — loss aversion on progress already made,
/// the single strongest lever for daily return in habit-forming apps.
/// Participation framing only, same discipline as the streak itself: never a
/// claim about being right, never pressure to trade.
enum StreakReminderEngine {
    /// nil when there's nothing to remind about — no active streak, or
    /// today's call is already made.
    static func compose(
        streak: Int,
        calls: [UserCall],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Digest? {
        guard streak >= 1 else { return nil }

        let today = calendar.startOfDay(for: now)
        let calledToday = calls.contains { calendar.startOfDay(for: $0.createdAt) == today }
        guard !calledToday else { return nil }

        let body = "Don't lose your \(streak)-day streak — call something before the day's out. A record of showing up, never advice."
        // A question opens more often than a flat statement (Loewenstein,
        // 1994, "The Psychology of Curiosity") — the body still states the
        // real stakes plainly underneath, so this is a hook, not a tease.
        return Digest(title: "Still time to keep it going?", body: body)
    }
}

/// Reads the streak-reminder preference and (re)schedules a same-day, one-shot
/// evening nudge — cancelled automatically once today's call is made or the
/// streak lapses. No BGTask of its own; piggybacks on the same BackgroundRefresh
/// wake-up as the other notifications.
enum StreakReminder {
    static let enabledKey = "hb.streakReminder.enabled"
    /// Set the moment the contextual opt-in prompt is shown (regardless of the
    /// user's answer) — a one-time offer, never re-asked, so declining once
    /// doesn't mean being asked again on every future streak.
    static let hasOfferedKey = "hb.streakReminder.hasOffered"

    /// Whether the contextual "want a reminder?" prompt should fire right now
    /// — a real streak worth protecting, not already on, and never asked
    /// before. Doesn't itself mark the offer as made; call `recordOffered()`
    /// when the prompt actually appears.
    static func shouldOfferPrompt(streak: Int, defaults: UserDefaults = .standard) -> Bool {
        guard streak >= 2 else { return false }
        guard !defaults.bool(forKey: enabledKey) else { return false }
        guard !defaults.bool(forKey: hasOfferedKey) else { return false }
        return true
    }

    static func recordOffered(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: hasOfferedKey)
    }

    static func rescheduleIfEnabled(streak: Int, calls: [UserCall]) async {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: enabledKey) else { return }
        guard await NotificationService.isAuthorized() else { return }

        guard let digest = StreakReminderEngine.compose(streak: streak, calls: calls) else {
            NotificationService.cancelStreakReminder()
            return
        }
        await NotificationService.scheduleStreakReminder(digest)
    }
}

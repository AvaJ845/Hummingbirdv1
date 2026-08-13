import Foundation

/// Caps same-day, deliver-now notifications so a volatile morning that moves
/// several watchlist assets at once can't stack up more than a handful of
/// pushes in one go.
///
/// Scheduled, future-dated notifications — the morning digest, the weekly
/// recap, a call-resolution nudge — don't go through this gate. Each of those
/// already self-limits by construction (once a day, once a week, once per
/// call), so a shared counter would either double-restrict something that's
/// already bounded or fight a schedule set days in advance. The one path that
/// can genuinely fan out in a single moment is movement alerts, fired
/// back-to-back as `WatchlistRefresh.refreshAll` evaluates an entire
/// watchlist — that's what this throttles.
enum NotificationBudget {
    static let dailyDiscretionaryCap = 3

    private static let countKey = "hb.notificationBudget.count"
    private static let dayKey = "hb.notificationBudget.day"

    /// Whether another discretionary notification may be sent today. Doesn't
    /// itself record the send — pair with `recordSent()`.
    static func canSendDiscretionary(
        defaults: UserDefaults = .standard,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        count(defaults: defaults, now: now, calendar: calendar) < dailyDiscretionaryCap
    }

    static func recordSent(
        defaults: UserDefaults = .standard,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        let current = count(defaults: defaults, now: now, calendar: calendar)
        defaults.set(current + 1, forKey: countKey)
        defaults.set(calendar.startOfDay(for: now), forKey: dayKey)
    }

    /// Today's count so far, resetting to 0 once the stored day rolls over.
    private static func count(defaults: UserDefaults, now: Date, calendar: Calendar) -> Int {
        let today = calendar.startOfDay(for: now)
        guard let storedDay = defaults.object(forKey: dayKey) as? Date,
              calendar.isDate(storedDay, inSameDayAs: today) else {
            return 0
        }
        return defaults.integer(forKey: countKey)
    }
}

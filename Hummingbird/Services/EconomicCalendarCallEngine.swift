import Foundation

/// A recurring, well-known macro-data event worth calling before it lands.
/// Deliberately limited to cadences that are exact and permanent by
/// definition (a fixed weekday-of-month rule) — never a hardcoded table of
/// specific yearly release dates, which would quietly go stale. CPI and FOMC
/// dates vary year to year and aren't included for exactly that reason.
enum EconomicCalendarEvent: String, CaseIterable, Sendable {
    /// U.S. jobs report (nonfarm payrolls) — always the first Friday of the
    /// month, released 8:30am ET.
    case jobsReport

    var title: String {
        switch self {
        case .jobsReport: "Jobs Report"
        }
    }
}

/// Pure day-level scheduling math — no state, no I/O, no data source beyond
/// the calendar itself.
enum EconomicCalendarEngine {
    /// The next date on or after `today` that matches `event`'s recurrence.
    static func nextOccurrence(
        of event: EconomicCalendarEvent,
        onOrAfter today: Date,
        calendar: Calendar = .current
    ) -> Date {
        var probe = calendar.startOfDay(for: today)
        for _ in 0..<40 {   // any monthly cadence lands within ~5 weeks
            if matches(event, date: probe, calendar: calendar) { return probe }
            probe = calendar.date(byAdding: .day, value: 1, to: probe) ?? probe
        }
        return probe
    }

    /// Whether `date` is itself a scheduled occurrence of `event`.
    static func matches(_ event: EconomicCalendarEvent, date: Date, calendar: Calendar = .current) -> Bool {
        switch event {
        case .jobsReport:
            // First Friday of the month: weekday is Friday and it falls
            // within the month's first 7 days.
            return calendar.component(.weekday, from: date) == 6
                && calendar.component(.day, from: date) <= 7
        }
    }
}

/// Composes an optional same-day prompt inviting a call before a scheduled
/// macro release lands — an appointment-based trigger cued by something the
/// user already knows matters, rather than a cadence the app invents.
/// Strictly "predict, then see how you did": never trade-readiness language,
/// same disclaimer discipline as every other call.
enum EconomicCalendarCallEngine {
    static func compose(
        calls: [UserCall],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Digest? {
        guard EconomicCalendarEngine.matches(.jobsReport, date: now, calendar: calendar) else { return nil }

        let today = calendar.startOfDay(for: now)
        let calledToday = calls.contains { calendar.startOfDay(for: $0.createdAt) == today }
        guard !calledToday else { return nil }

        return Digest(
            title: "Jobs Report today — call it first?",
            body: "New jobs numbers land this morning. Predict which way the market leans before you see it react — a record of your own call, never advice."
        )
    }
}

/// Reads the economic-calendar-call preference and (re)schedules a same-day,
/// one-shot morning nudge — cancelled automatically once today's call is
/// made or it isn't a scheduled release day. No BGTask of its own; piggybacks
/// on the same wake-up as the other notifications.
enum EconomicCalendarCall {
    static let enabledKey = "hb.economicCalendarCall.enabled"

    static func rescheduleIfEnabled(calls: [UserCall]) async {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: enabledKey) else { return }
        guard await NotificationService.isAuthorized() else { return }

        guard let digest = EconomicCalendarCallEngine.compose(calls: calls) else {
            NotificationService.cancelEconomicCalendarCall()
            return
        }
        await NotificationService.scheduleEconomicCalendarCall(digest)
    }
}

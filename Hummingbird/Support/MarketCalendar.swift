import Foundation

/// Lightweight US-equities session check for pacing auto-refresh.
/// Regular session: 9:30–16:00 America/New_York, Monday–Friday.
/// (Does not model market holidays — a slow off-hours cadence covers those safely.)
enum MarketCalendar {
    private static let eastern = TimeZone(identifier: "America/New_York")

    static func isUSMarketOpen(at date: Date = .now) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        if let eastern { calendar.timeZone = eastern }
        let comps = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        // Calendar weekday: 1 = Sunday … 7 = Saturday. Trading days are Mon(2)–Fri(6).
        guard let weekday = comps.weekday, (2...6).contains(weekday) else { return false }
        let minutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        let open = 9 * 60 + 30
        let close = 16 * 60
        return minutes >= open && minutes < close
    }
}

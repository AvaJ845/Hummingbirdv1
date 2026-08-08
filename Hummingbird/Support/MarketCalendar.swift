import Foundation

/// US-equities session + trading-calendar helper.
///
/// Two jobs:
/// 1. `isUSMarketOpen` — intraday session check (paces auto-refresh).
/// 2. `tradingDates` — the forward calendar a sketch is drawn on. Stocks only
///    trade on weekdays the exchange is open, so a stock projection must skip
///    weekends and market holidays; **crypto trades every day**, so its
///    projection steps one calendar day at a time.
///
/// Regular session: 9:30–16:00 America/New_York, Monday–Friday.
/// The holiday set covers the regular NYSE closures (fixed dates observed with
/// the Sat→Fri / Sun→Mon rule, the floating Monday/Thursday holidays, and Good
/// Friday). It is an honest approximation — it does not model rare ad-hoc
/// closures — but it keeps stock sketches off closed days.
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

    // MARK: - Trading calendar

    /// True if `date` is a regular US-equities trading day (a weekday the
    /// exchange isn't closed for a holiday).
    static func isTradingDay(_ date: Date, calendar: Calendar = gregorian) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        guard (2...6).contains(weekday) else { return false }   // Mon–Fri
        return !holidayStamps(year: calendar.component(.year, from: date), calendar: calendar)
            .contains(dayStamp(date, calendar))
    }

    /// The `count` forward dates a projection should be drawn on, starting the
    /// day after `start`. Crypto steps every calendar day; stocks step to the
    /// next open trading day (skipping weekends and market holidays). Always
    /// returns exactly `count` dates (unless `count <= 0`).
    static func tradingDates(after start: Date, count: Int, assetClass: AssetClass) -> [Date] {
        guard count > 0 else { return [] }
        let calendar = gregorian
        var out: [Date] = []
        out.reserveCapacity(count)
        var cursor = start
        // Safety bound: even all-holidays can't exceed ~2 skips per trading day.
        let maxIterations = count * 8 + 16
        var iterations = 0

        while out.count < count, iterations < maxIterations {
            iterations += 1
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
            switch assetClass {
            case .crypto:
                out.append(cursor)
            case .stock:
                if isTradingDay(cursor, calendar: calendar) { out.append(cursor) }
            }
        }
        return out
    }

    // MARK: - Holidays

    /// Shared gregorian calendar (device time zone, matching the rest of the
    /// forecasting date math) so weekday/holiday checks and the projected dates
    /// stay on one clock.
    static let gregorian = Calendar(identifier: .gregorian)

    private static func dayStamp(_ date: Date, _ calendar: Calendar) -> Int {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return (c.year ?? 0) * 10_000 + (c.month ?? 0) * 100 + (c.day ?? 0)
    }

    /// `yyyymmdd` stamps of the regular NYSE closures for a given year.
    private static func holidayStamps(year: Int, calendar: Calendar) -> Set<Int> {
        func stamp(_ month: Int, _ day: Int) -> Int { year * 10_000 + month * 100 + day }

        /// Fixed-date holiday shifted to the observed trading closure:
        /// Saturday → prior Friday, Sunday → following Monday.
        func observed(_ month: Int, _ day: Int) -> Int {
            guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
                return stamp(month, day)
            }
            switch calendar.component(.weekday, from: date) {
            case 1: return dayStamp(calendar.date(byAdding: .day, value: 1, to: date) ?? date, calendar) // Sun → Mon
            case 7: return dayStamp(calendar.date(byAdding: .day, value: -1, to: date) ?? date, calendar) // Sat → Fri
            default: return stamp(month, day)
            }
        }

        func nthWeekday(_ weekday: Int, _ n: Int, month: Int) -> Int {
            guard let first = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else { return stamp(month, 1) }
            let firstWeekday = calendar.component(.weekday, from: first)
            let offset = (weekday - firstWeekday + 7) % 7 + (n - 1) * 7
            let date = calendar.date(byAdding: .day, value: offset, to: first) ?? first
            return dayStamp(date, calendar)
        }

        func lastWeekday(_ weekday: Int, month: Int) -> Int {
            guard let firstNext = calendar.date(from: DateComponents(year: year, month: month + 1, day: 1)),
                  let lastDay = calendar.date(byAdding: .day, value: -1, to: firstNext) else { return stamp(month, 28) }
            let lastWeekdayNum = calendar.component(.weekday, from: lastDay)
            let back = (lastWeekdayNum - weekday + 7) % 7
            let date = calendar.date(byAdding: .day, value: -back, to: lastDay) ?? lastDay
            return dayStamp(date, calendar)
        }

        var stamps: Set<Int> = [
            observed(1, 1),                 // New Year's Day
            nthWeekday(2, 3, month: 1),     // MLK Jr. — 3rd Monday Jan
            nthWeekday(2, 3, month: 2),     // Washington's Birthday — 3rd Monday Feb
            lastWeekday(2, month: 5),       // Memorial Day — last Monday May
            observed(7, 4),                 // Independence Day
            nthWeekday(2, 1, month: 9),     // Labor Day — 1st Monday Sep
            nthWeekday(5, 4, month: 11),    // Thanksgiving — 4th Thursday Nov
            observed(12, 25),               // Christmas
        ]
        if year >= 2022 { stamps.insert(observed(6, 19)) } // Juneteenth (NYSE from 2022)
        if let goodFriday = goodFridayStamp(year: year, calendar: calendar) { stamps.insert(goodFriday) }
        return stamps
    }

    /// Good Friday = Easter Sunday − 2 days (Easter via the Anonymous Gregorian
    /// "Computus" algorithm).
    private static func goodFridayStamp(year: Int, calendar: Calendar) -> Int? {
        let a = year % 19
        let b = year / 100, c = year % 100
        let d = b / 4, e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4, k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = ((h + l - 7 * m + 114) % 31) + 1
        guard let easter = calendar.date(from: DateComponents(year: year, month: month, day: day)),
              let goodFriday = calendar.date(byAdding: .day, value: -2, to: easter) else { return nil }
        return dayStamp(goodFriday, calendar)
    }
}

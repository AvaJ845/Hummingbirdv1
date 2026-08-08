import XCTest
@testable import Hummingbird

/// Fix #1: stock sketches follow the trading calendar (skip weekends + market
/// holidays); crypto steps every calendar day. Values/counts are unchanged —
/// only the date each projected point lands on.
final class TradingCalendarTests: XCTestCase {
    private let cal = Calendar(identifier: .gregorian)

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    /// A forecastable series whose last bar lands exactly on `last`.
    private func series(_ assetClass: AssetClass, endingOn last: Date, count: Int = 40) -> PriceSeries {
        let points = (0..<count).map { i -> PricePoint in
            let date = cal.date(byAdding: .day, value: -(count - 1 - i), to: last)!
            return PricePoint(date: date, close: 100 + Double(i))
        }
        return PriceSeries(symbol: "TEST", assetClass: assetClass, points: points, isSample: true)
    }

    private func monthDay(_ date: Date) -> [Int] {
        let c = cal.dateComponents([.month, .day], from: date)
        return [c.month!, c.day!]
    }

    func testStockProjectionNeverLandsOnAWeekend() {
        let f = Forecaster.forecast(series: series(.stock, endingOn: day(2025, 6, 27)), // Friday
                                    model: .default, horizon: 20)
        XCTAssertEqual(f.points.count, 20, "point count must still equal the horizon")
        for point in f.points {
            let weekday = cal.component(.weekday, from: point.date)
            XCTAssertTrue((2...6).contains(weekday), "projected \(point.date) is a weekend")
        }
    }

    func testStockProjectionSkipsMarketHoliday() {
        // Fri 2025-07-04 is Independence Day — it must not appear in a stock sketch.
        let f = Forecaster.forecast(series: series(.stock, endingOn: day(2025, 6, 27)),
                                    model: .default, horizon: 8)
        XCTAssertFalse(f.points.contains { monthDay($0.date) == [7, 4] }, "July 4 leaked into a stock sketch")
        // First five trading days after Fri 6/27: 6/30, 7/1, 7/2, 7/3, then 7/7 (7/4 skipped).
        XCTAssertEqual(f.points.prefix(5).map { monthDay($0.date) }, [[6, 30], [7, 1], [7, 2], [7, 3], [7, 7]])
    }

    func testCryptoProjectionUsesEveryCalendarDayIncludingWeekends() {
        let f = Forecaster.forecast(series: series(.crypto, endingOn: day(2025, 6, 27)), // Friday
                                    model: .default, horizon: 5)
        let expected = (1...5).map { cal.date(byAdding: .day, value: $0, to: day(2025, 6, 27))! }
        XCTAssertEqual(f.points.map(\.date), expected)
        XCTAssertTrue(f.points.contains { [1, 7].contains(cal.component(.weekday, from: $0.date)) },
                      "crypto sketch should include weekend days")
    }

    func testIsTradingDayHolidaysAndWeekends() {
        XCTAssertFalse(MarketCalendar.isTradingDay(day(2025, 6, 28)))  // Saturday
        XCTAssertFalse(MarketCalendar.isTradingDay(day(2025, 6, 29)))  // Sunday
        XCTAssertFalse(MarketCalendar.isTradingDay(day(2025, 1, 1)))   // New Year's Day
        XCTAssertFalse(MarketCalendar.isTradingDay(day(2025, 4, 18)))  // Good Friday 2025
        XCTAssertFalse(MarketCalendar.isTradingDay(day(2025, 7, 4)))   // Independence Day
        XCTAssertFalse(MarketCalendar.isTradingDay(day(2025, 11, 27))) // Thanksgiving 2025
        XCTAssertFalse(MarketCalendar.isTradingDay(day(2025, 12, 25))) // Christmas
        XCTAssertTrue(MarketCalendar.isTradingDay(day(2025, 6, 27)))   // ordinary Friday
        XCTAssertTrue(MarketCalendar.isTradingDay(day(2025, 6, 30)))   // ordinary Monday
    }

    func testTradingDatesReturnExactCountAndAreAllOpen() {
        let stock = MarketCalendar.tradingDates(after: day(2025, 6, 27), count: 12, assetClass: .stock)
        XCTAssertEqual(stock.count, 12)
        XCTAssertTrue(stock.allSatisfy { MarketCalendar.isTradingDay($0) })

        let crypto = MarketCalendar.tradingDates(after: day(2025, 6, 27), count: 12, assetClass: .crypto)
        XCTAssertEqual(crypto.count, 12)
    }
}

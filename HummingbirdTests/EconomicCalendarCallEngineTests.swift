import XCTest
@testable import Hummingbird

final class EconomicCalendarCallEngineTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    // 2024-01-05 is a Friday and the first Friday of January 2024.
    private var firstFridayOfMonth: Date {
        calendar.date(from: DateComponents(year: 2024, month: 1, day: 5))!
    }

    private func call(daysAgo: Int, from date: Date) -> UserCall {
        UserCall(id: UUID(), symbol: "AAPL", assetClass: .stock,
                 createdAt: calendar.date(byAdding: .day, value: -daysAgo, to: date)!,
                 horizonDays: 7, spotAtCall: 100, direction: .higher, confidence: .hunch,
                 actualClose: nil, resolvedAt: nil)
    }

    // MARK: - EconomicCalendarEngine day math

    func testMatchesFirstFridayOfMonth() {
        XCTAssertTrue(EconomicCalendarEngine.matches(.jobsReport, date: firstFridayOfMonth, calendar: calendar))
    }

    func testDoesNotMatchSecondFriday() {
        let secondFriday = calendar.date(byAdding: .day, value: 7, to: firstFridayOfMonth)!
        XCTAssertFalse(EconomicCalendarEngine.matches(.jobsReport, date: secondFriday, calendar: calendar))
    }

    func testDoesNotMatchFirstOfMonthWhenNotFriday() {
        // 2024-02-01 is a Thursday, not the first Friday of February.
        let feb1 = calendar.date(from: DateComponents(year: 2024, month: 2, day: 1))!
        XCTAssertFalse(EconomicCalendarEngine.matches(.jobsReport, date: feb1, calendar: calendar))
    }

    func testNextOccurrenceReturnsSameDayWhenTodayMatches() {
        let result = EconomicCalendarEngine.nextOccurrence(of: .jobsReport, onOrAfter: firstFridayOfMonth, calendar: calendar)
        XCTAssertEqual(calendar.startOfDay(for: result), calendar.startOfDay(for: firstFridayOfMonth))
    }

    func testNextOccurrenceAdvancesToNextMonth() {
        let dayAfter = calendar.date(byAdding: .day, value: 1, to: firstFridayOfMonth)!
        let result = EconomicCalendarEngine.nextOccurrence(of: .jobsReport, onOrAfter: dayAfter, calendar: calendar)
        // Next first Friday is in February 2024 (2024-02-02).
        let expected = calendar.date(from: DateComponents(year: 2024, month: 2, day: 2))!
        XCTAssertEqual(calendar.startOfDay(for: result), calendar.startOfDay(for: expected))
    }

    // MARK: - EconomicCalendarCallEngine.compose

    func testNilWhenNotAScheduledDay() {
        let notScheduled = calendar.date(byAdding: .day, value: 3, to: firstFridayOfMonth)!
        XCTAssertNil(EconomicCalendarCallEngine.compose(calls: [], now: notScheduled, calendar: calendar))
    }

    func testPromptsOnScheduledDayWithNoCallYet() {
        let digest = EconomicCalendarCallEngine.compose(calls: [], now: firstFridayOfMonth, calendar: calendar)
        XCTAssertNotNil(digest)
        XCTAssertTrue(digest!.title.contains("Jobs Report"))
    }

    func testNilWhenAlreadyCalledToday() {
        let calls = [call(daysAgo: 0, from: firstFridayOfMonth)]
        XCTAssertNil(EconomicCalendarCallEngine.compose(calls: calls, now: firstFridayOfMonth, calendar: calendar))
    }

    func testStillPromptsWhenOnlyPastDaysHaveCalls() {
        let calls = [call(daysAgo: 1, from: firstFridayOfMonth)]
        XCTAssertNotNil(EconomicCalendarCallEngine.compose(calls: calls, now: firstFridayOfMonth, calendar: calendar))
    }

    func testNeverAdviceCaveatPresent() {
        let digest = EconomicCalendarCallEngine.compose(calls: [], now: firstFridayOfMonth, calendar: calendar)
        XCTAssertTrue(digest!.body.lowercased().contains("never advice"))
    }

    func testCopyNeverImpliesTradeReadiness() {
        let digest = EconomicCalendarCallEngine.compose(calls: [], now: firstFridayOfMonth, calendar: calendar)
        let lower = digest!.body.lowercased() + digest!.title.lowercased()
        XCTAssertFalse(lower.contains("buy"))
        XCTAssertFalse(lower.contains("sell"))
        XCTAssertFalse(lower.contains("trade"))
    }
}

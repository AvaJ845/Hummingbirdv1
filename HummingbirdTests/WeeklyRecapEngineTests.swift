import XCTest
@testable import Hummingbird

final class WeeklyRecapEngineTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func call(daysAgo: Int, actual: Double? = nil, direction: CallDirection = .higher) -> UserCall {
        UserCall(id: UUID(), symbol: "AAPL", assetClass: .stock,
                 createdAt: calendar.date(byAdding: .day, value: -daysAgo, to: now)!,
                 horizonDays: 1, spotAtCall: 100, direction: direction, confidence: .hunch,
                 actualClose: actual, resolvedAt: actual == nil ? nil : now)
    }

    func testNilWithNoCallsInTheTrailingWeek() {
        let calls = [call(daysAgo: 10)]
        XCTAssertNil(WeeklyRecapEngine.compose(calls: calls, streak: 0, now: now, calendar: calendar))
    }

    func testCountsOnlyCallsWithinTheTrailingWeek() {
        let calls = [call(daysAgo: 1), call(daysAgo: 3), call(daysAgo: 10)]
        let digest = WeeklyRecapEngine.compose(calls: calls, streak: 0, now: now, calendar: calendar)
        XCTAssertNotNil(digest)
        XCTAssertTrue(digest!.body.contains("2 calls made"))
    }

    func testIncludesResolvedAccuracyWhenPresent() {
        let calls = [
            call(daysAgo: 1, actual: 110, direction: .higher), // correct
            call(daysAgo: 2, actual: 90, direction: .higher),  // wrong
            call(daysAgo: 3)                                    // unresolved
        ]
        let digest = WeeklyRecapEngine.compose(calls: calls, streak: 0, now: now, calendar: calendar)
        XCTAssertNotNil(digest)
        XCTAssertTrue(digest!.body.contains("3 calls made"))
        XCTAssertTrue(digest!.body.contains("1 of 2 resolved calls right (50%)"))
    }

    func testMentionsStreakOnlyWhenTwoOrMore() {
        let calls = [call(daysAgo: 0)]
        XCTAssertFalse(WeeklyRecapEngine.compose(calls: calls, streak: 1, now: now, calendar: calendar)!.body.contains("streak"))
        XCTAssertTrue(WeeklyRecapEngine.compose(calls: calls, streak: 3, now: now, calendar: calendar)!.body.contains("3-day streak"))
    }

    func testNeverAdviceCaveatAlwaysPresent() {
        let digest = WeeklyRecapEngine.compose(calls: [call(daysAgo: 0)], streak: 0, now: now, calendar: calendar)
        XCTAssertTrue(digest!.body.contains("never advice"))
    }

    func testMentionsJournalOnlyWhenFlagged() {
        let calls = [call(daysAgo: 0)]
        XCTAssertFalse(WeeklyRecapEngine.compose(calls: calls, streak: 0, now: now, calendar: calendar)!.body.contains("journal"))
        XCTAssertTrue(WeeklyRecapEngine.compose(calls: calls, streak: 0, hasJournalActivity: true, now: now, calendar: calendar)!.body.contains("journal"))
    }

    func testJournalFlagDoesNotConjureADigestOnItsOwn() {
        // No calls this week — still nil even if journal activity exists,
        // since this notification is anchored to the calls recap firing at all.
        let calls = [call(daysAgo: 10)]
        XCTAssertNil(WeeklyRecapEngine.compose(calls: calls, streak: 0, hasJournalActivity: true, now: now, calendar: calendar))
    }
}

import XCTest
@testable import Hummingbird

final class StreakReminderEngineTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func call(daysAgo: Int) -> UserCall {
        UserCall(id: UUID(), symbol: "AAPL", assetClass: .stock,
                 createdAt: calendar.date(byAdding: .day, value: -daysAgo, to: now)!,
                 horizonDays: 7, spotAtCall: 100, direction: .higher, confidence: .hunch,
                 actualClose: nil, resolvedAt: nil)
    }

    func testNilWithNoStreak() {
        XCTAssertNil(StreakReminderEngine.compose(streak: 0, calls: [], now: now, calendar: calendar))
    }

    func testNilWhenAlreadyCalledToday() {
        let calls = [call(daysAgo: 0), call(daysAgo: 1)]
        XCTAssertNil(StreakReminderEngine.compose(streak: 2, calls: calls, now: now, calendar: calendar))
    }

    func testRemindsWhenStreakActiveButNotCalledToday() {
        // Streak alive through yesterday's call, nothing logged yet today.
        let calls = [call(daysAgo: 1), call(daysAgo: 2)]
        let digest = StreakReminderEngine.compose(streak: 2, calls: calls, now: now, calendar: calendar)
        XCTAssertNotNil(digest)
        XCTAssertTrue(digest!.body.contains("2-day streak"))
    }

    func testNeverAdviceCaveatPresent() {
        let calls = [call(daysAgo: 1)]
        let digest = StreakReminderEngine.compose(streak: 1, calls: calls, now: now, calendar: calendar)
        XCTAssertTrue(digest!.body.contains("never advice"))
    }
}

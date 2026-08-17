import XCTest
@testable import Hummingbird

/// Streak math is participation-only — never correctness. These pin that a
/// streak counts *days a call was made*, independent of whether any of them
/// resolved right or wrong.
final class StreakEngineTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private let today = Date(timeIntervalSince1970: 1_700_000_000) // arbitrary fixed "now"

    private func call(daysAgo: Int) -> UserCall {
        UserCall(id: UUID(), symbol: "AAPL", assetClass: .stock,
                 createdAt: calendar.date(byAdding: .day, value: -daysAgo, to: today)!,
                 horizonDays: 7, spotAtCall: 100, direction: .higher, confidence: .hunch,
                 actualClose: nil, resolvedAt: nil)
    }

    func testEmptyCallsIsZero() {
        XCTAssertEqual(StreakEngine.currentStreak([], asOf: today, calendar: calendar), 0)
    }

    func testConsecutiveDaysCountUp() {
        let calls = [call(daysAgo: 0), call(daysAgo: 1), call(daysAgo: 2)]
        XCTAssertEqual(StreakEngine.currentStreak(calls, asOf: today, calendar: calendar), 3)
    }

    func testGapBreaksTheStreak() {
        // Called today and 1 day ago, but skipped 2 days ago — streak stops at 2.
        let calls = [call(daysAgo: 0), call(daysAgo: 1), call(daysAgo: 3)]
        XCTAssertEqual(StreakEngine.currentStreak(calls, asOf: today, calendar: calendar), 2)
    }

    func testStreakStaysAliveBeforeTodaysCall() {
        // No call yet today, but yesterday and the day before were both covered —
        // the streak isn't broken until a full day passes with nothing logged.
        let calls = [call(daysAgo: 1), call(daysAgo: 2)]
        XCTAssertEqual(StreakEngine.currentStreak(calls, asOf: today, calendar: calendar), 2)
    }

    func testLapsedStreakResetsToZero() {
        // Nothing today or yesterday — even a long past run doesn't count.
        let calls = [call(daysAgo: 2), call(daysAgo: 3), call(daysAgo: 4)]
        XCTAssertEqual(StreakEngine.currentStreak(calls, asOf: today, calendar: calendar), 0)
    }

    func testMultipleCallsSameDayCountOnce() {
        let calls = [call(daysAgo: 0), call(daysAgo: 0), call(daysAgo: 0)]
        XCTAssertEqual(StreakEngine.currentStreak(calls, asOf: today, calendar: calendar), 1)
    }

    func testStreakIsIndependentOfCorrectness() {
        // Same participation pattern, only the (irrelevant) resolution differs.
        let losingStreak = [call(daysAgo: 0), call(daysAgo: 1)].map { c -> UserCall in
            var updated = c
            updated.actualClose = 50 // wrong, if it mattered — it shouldn't
            updated.resolvedAt = today
            return updated
        }
        XCTAssertEqual(StreakEngine.currentStreak(losingStreak, asOf: today, calendar: calendar), 2)
    }

    // MARK: - Streak freeze (Pro perk)

    func testDefaultHasNoFreezeAndMatchesOriginalBehavior() {
        let calls = [call(daysAgo: 0), call(daysAgo: 1), call(daysAgo: 3)]
        XCTAssertEqual(StreakEngine.currentStreak(calls, asOf: today, calendar: calendar), 2)
    }

    func testFreezeBridgesOneGapDay() {
        // Called today and yesterday, skipped 2 days ago, called 3 and 4 days ago.
        let calls = [call(daysAgo: 0), call(daysAgo: 1), call(daysAgo: 3), call(daysAgo: 4)]
        XCTAssertEqual(
            StreakEngine.currentStreak(calls, freezesAvailable: 1, asOf: today, calendar: calendar), 4,
            "One freeze should bridge the single missed day (2 days ago) and keep counting."
        )
    }

    func testFreezeDoesNotBridgeTwoGapDays() {
        // Gaps at both 2 and 4 days ago — only the nearer one gets forgiven.
        let calls = [call(daysAgo: 0), call(daysAgo: 1), call(daysAgo: 3), call(daysAgo: 5)]
        XCTAssertEqual(
            StreakEngine.currentStreak(calls, freezesAvailable: 1, asOf: today, calendar: calendar), 3,
            "A single freeze must not forgive a second gap — the chain still breaks there."
        )
    }

    func testUnusedFreezeDoesNotInflateAPerfectStreak() {
        let calls = [call(daysAgo: 0), call(daysAgo: 1), call(daysAgo: 2)]
        XCTAssertEqual(StreakEngine.currentStreak(calls, freezesAvailable: 1, asOf: today, calendar: calendar), 3)
    }

    func testMultipleFreezesBridgeMultipleGaps() {
        // Called days 0, 2, 4 ago — gaps at 1 and 3 days ago. The streak counts
        // actual call days reached (3), not the calendar span bridged — frozen
        // gap days don't themselves count toward the length.
        let calls = [call(daysAgo: 0), call(daysAgo: 2), call(daysAgo: 4)]
        XCTAssertEqual(
            StreakEngine.currentStreak(calls, freezesAvailable: 2, asOf: today, calendar: calendar), 3,
            "Two freezes should bridge both gap days (1 and 3 days ago) without breaking the chain."
        )
        XCTAssertEqual(
            StreakEngine.currentStreak(calls, freezesAvailable: 1, asOf: today, calendar: calendar), 2,
            "One freeze only bridges the first gap (1 day ago); the chain still breaks at the second."
        )
    }
}

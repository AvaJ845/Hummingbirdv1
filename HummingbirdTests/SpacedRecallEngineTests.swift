import XCTest
@testable import Hummingbird

final class SpacedRecallEngineTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func call(daysAgoResolved: Int, symbol: String = "AAPL") -> UserCall {
        let resolvedAt = calendar.date(byAdding: .day, value: -daysAgoResolved, to: now)!
        return UserCall(id: UUID(), symbol: symbol, assetClass: .stock,
                        createdAt: resolvedAt, horizonDays: 7, spotAtCall: 100,
                        direction: .higher, confidence: .hunch,
                        actualClose: 110, resolvedAt: resolvedAt)
    }

    func testNoResolvedCallsReturnsNil() {
        XCTAssertNil(SpacedRecallEngine.due(calls: [], isReviewed: { _, _ in false }, now: now, calendar: calendar))
    }

    func testUnresolvedCallNeverDue() {
        let c = UserCall(id: UUID(), symbol: "AAPL", assetClass: .stock, createdAt: now,
                         horizonDays: 7, spotAtCall: 100, direction: .higher, confidence: .hunch,
                         actualClose: nil, resolvedAt: nil)
        XCTAssertNil(SpacedRecallEngine.due(calls: [c], isReviewed: { _, _ in false }, now: now, calendar: calendar))
    }

    func testDueAtFirstInterval() {
        let c = call(daysAgoResolved: 3)
        let result = SpacedRecallEngine.due(calls: [c], isReviewed: { _, _ in false }, now: now, calendar: calendar)
        XCTAssertEqual(result?.call.id, c.id)
        XCTAssertEqual(result?.intervalIndex, 0)
    }

    func testNotDueBeforeInterval() {
        let c = call(daysAgoResolved: 1)
        XCTAssertNil(SpacedRecallEngine.due(calls: [c], isReviewed: { _, _ in false }, now: now, calendar: calendar))
    }

    func testNotDueAfterWindowExpiresForThatTier() {
        // Tier 0 window is days 3-7; tier 1 doesn't open until day 10 — day 8
        // falls in the gap between them.
        let c = call(daysAgoResolved: 8)
        XCTAssertNil(SpacedRecallEngine.due(calls: [c], isReviewed: { _, _ in false }, now: now, calendar: calendar))
    }

    func testAlreadyReviewedIntervalIsSkipped() {
        let c = call(daysAgoResolved: 3)
        let result = SpacedRecallEngine.due(calls: [c], isReviewed: { _, idx in idx == 0 }, now: now, calendar: calendar)
        XCTAssertNil(result)
    }

    func testDueAgainAtSecondIntervalAfterFirstReviewed() {
        let c = call(daysAgoResolved: 10)
        let result = SpacedRecallEngine.due(calls: [c], isReviewed: { _, idx in idx == 0 }, now: now, calendar: calendar)
        XCTAssertEqual(result?.intervalIndex, 1)
    }

    func testEarliestTierPreferredOverLaterTier() {
        let earlyTierCall = call(daysAgoResolved: 3, symbol: "AAPL")
        let laterTierCall = call(daysAgoResolved: 10, symbol: "BTC")
        let result = SpacedRecallEngine.due(calls: [laterTierCall, earlyTierCall], isReviewed: { _, _ in false }, now: now, calendar: calendar)
        XCTAssertEqual(result?.call.symbol, "AAPL")
        XCTAssertEqual(result?.intervalIndex, 0)
    }

    func testEarliestResolvedWinsWithinSameTier() {
        let older = call(daysAgoResolved: 4, symbol: "OLDER") // still inside tier-0 window (3-7)
        let newer = call(daysAgoResolved: 3, symbol: "NEWER")
        let result = SpacedRecallEngine.due(calls: [newer, older], isReviewed: { _, _ in false }, now: now, calendar: calendar)
        XCTAssertEqual(result?.call.symbol, "OLDER")
    }

    func testAllIntervalsReviewedReturnsNil() {
        let c = call(daysAgoResolved: 30)
        XCTAssertNil(SpacedRecallEngine.due(calls: [c], isReviewed: { _, _ in true }, now: now, calendar: calendar))
    }
}

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

    // MARK: - dueBatch (interleaved mixed review)

    func testDueBatchEmptyWhenNoResolvedCalls() {
        let result = SpacedRecallEngine.dueBatch(calls: [], isReviewed: { _, _ in false }, now: now, calendar: calendar)
        XCTAssertTrue(result.isEmpty)
    }

    func testDueBatchMixesDistinctSymbols() {
        let calls = [
            call(daysAgoResolved: 3, symbol: "AAPL"),
            call(daysAgoResolved: 4, symbol: "BTC"),
            call(daysAgoResolved: 5, symbol: "TSLA"),
        ]
        let result = SpacedRecallEngine.dueBatch(calls: calls, isReviewed: { _, _ in false }, now: now, calendar: calendar, limit: 3)
        XCTAssertEqual(Set(result.map(\.call.symbol)), ["AAPL", "BTC", "TSLA"])
    }

    func testDueBatchRespectsLimit() {
        let calls = [
            call(daysAgoResolved: 3, symbol: "AAPL"),
            call(daysAgoResolved: 4, symbol: "BTC"),
            call(daysAgoResolved: 5, symbol: "TSLA"),
        ]
        let result = SpacedRecallEngine.dueBatch(calls: calls, isReviewed: { _, _ in false }, now: now, calendar: calendar, limit: 2)
        XCTAssertEqual(result.count, 2)
    }

    func testDueBatchFallsBackToRepeatingSymbolWhenNoVarietyAvailable() {
        // Two AAPL calls, both due at tier 0 — only one symbol exists at all,
        // so the batch should still fill rather than stay short.
        let calls = [
            call(daysAgoResolved: 3, symbol: "AAPL"),
            call(daysAgoResolved: 4, symbol: "AAPL"),
        ]
        let result = SpacedRecallEngine.dueBatch(calls: calls, isReviewed: { _, _ in false }, now: now, calendar: calendar, limit: 2)
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.allSatisfy { $0.call.symbol == "AAPL" })
    }

    func testDueBatchOldestWithinTierFirstWhenSameSymbol() {
        let calls = [
            call(daysAgoResolved: 3, symbol: "AAPL"),
            call(daysAgoResolved: 4, symbol: "AAPL"),
        ]
        let result = SpacedRecallEngine.dueBatch(calls: calls, isReviewed: { _, _ in false }, now: now, calendar: calendar, limit: 1)
        XCTAssertEqual(result.first?.call.symbol, "AAPL")
        // daysAgoResolved 4 means it's been waiting longer than the 3-day one.
        let resolvedDaysAgo4 = calendar.date(byAdding: .day, value: -4, to: now)!
        XCTAssertEqual(result.first?.call.resolvedAt, resolvedDaysAgo4)
    }

    func testDueBatchSkipsAlreadyReviewedInterval() {
        let calls = [call(daysAgoResolved: 3, symbol: "AAPL")]
        let result = SpacedRecallEngine.dueBatch(calls: calls, isReviewed: { _, idx in idx == 0 }, now: now, calendar: calendar)
        XCTAssertTrue(result.isEmpty)
    }

    func testDueBatchSingleResultMatchesDue() {
        let calls = [
            call(daysAgoResolved: 3, symbol: "AAPL"),
            call(daysAgoResolved: 10, symbol: "BTC"),
        ]
        let single = SpacedRecallEngine.due(calls: calls, isReviewed: { _, _ in false }, now: now, calendar: calendar)
        let batch = SpacedRecallEngine.dueBatch(calls: calls, isReviewed: { _, _ in false }, now: now, calendar: calendar, limit: 1)
        XCTAssertEqual(batch.first?.call.symbol, single?.call.symbol)
        XCTAssertEqual(batch.first?.intervalIndex, single?.intervalIndex)
    }
}

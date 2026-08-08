import XCTest
@testable import Hummingbird

/// The accountability loop's scoring: resolving a user's call against real
/// prices, direction correctness, and honest confidence calibration.
final class UserCallEngineTests: XCTestCase {
    private let created = Date(timeIntervalSince1970: 1_700_000_000)

    private func call(_ direction: CallDirection, _ confidence: CallConfidence,
                      spot: Double = 100, horizon: Int = 7,
                      actual: Double? = nil) -> UserCall {
        UserCall(id: UUID(), symbol: "AAPL", assetClass: .stock, createdAt: created,
                 horizonDays: horizon, spotAtCall: spot, direction: direction,
                 confidence: confidence, actualClose: actual,
                 resolvedAt: actual == nil ? nil : created)
    }

    private func series(closeAt targetOffsetDays: Int, close: Double) -> PriceSeries {
        let date = created.addingTimeInterval(Double(targetOffsetDays) * 86_400)
        return PriceSeries(symbol: "AAPL", assetClass: .stock,
                           points: [PricePoint(date: date, close: close)], isSample: true)
    }

    func testDirectionCorrectness() {
        XCTAssertEqual(call(.higher, .hunch, actual: 110).wasCorrect, true)   // up call, went up
        XCTAssertEqual(call(.higher, .hunch, actual: 90).wasCorrect, false)   // up call, went down
        XCTAssertEqual(call(.lower, .hunch, actual: 90).wasCorrect, true)     // down call, went down
        XCTAssertNil(call(.higher, .hunch, actual: 100).wasCorrect)           // flat → push, excluded
        XCTAssertNil(call(.higher, .hunch, actual: nil).wasCorrect)           // unresolved
    }

    func testResolveMatchesNearestCloseWhenDue() {
        // Target is 7 days out; a real close 8 days out is within tolerance.
        let c = call(.higher, .confident, horizon: 7)
        let resolved = UserCallEngine.resolve(c, against: series(closeAt: 8, close: 115),
                                              now: created.addingTimeInterval(20 * 86_400))
        XCTAssertEqual(resolved.actualClose, 115)
        XCTAssertEqual(resolved.wasCorrect, true)
    }

    func testDoesNotResolveBeforeTargetDate() {
        let c = call(.higher, .confident, horizon: 7)
        // "now" is only 2 days after the call — target hasn't arrived.
        let resolved = UserCallEngine.resolve(c, against: series(closeAt: 2, close: 115),
                                              now: created.addingTimeInterval(2 * 86_400))
        XCTAssertFalse(resolved.isResolved)
    }

    func testReportOverallAndConfidenceCalibration() {
        let calls = [
            call(.higher, .confident, actual: 110),   // correct
            call(.higher, .confident, actual: 95),    // wrong  → Confident: 1/2
            call(.lower, .fairlySure, actual: 90),    // correct → Fairly sure: 1/1
            call(.higher, .hunch, actual: 105),       // correct
            call(.higher, .hunch, actual: 90),        // wrong  → Hunch: 1/2
            call(.higher, .hunch, actual: nil),       // unresolved, ignored
        ]
        let report = UserCallEngine.report(calls)

        XCTAssertEqual(report.total, 6)
        XCTAssertEqual(report.resolved, 5)
        XCTAssertEqual(report.overall.decided, 5)
        XCTAssertEqual(report.overall.correct, 3)
        XCTAssertEqual(report.overall.hitRate ?? 0, 3.0 / 5.0, accuracy: 1e-9)

        // Sorted least → most sure, with honest per-level hit rates.
        XCTAssertEqual(report.byConfidence.map(\.confidence), [.hunch, .fairlySure, .confident])
        XCTAssertEqual(report.byConfidence.first { $0.confidence == .confident }?.hitRate ?? 0, 0.5, accuracy: 1e-9)
        XCTAssertEqual(report.byConfidence.first { $0.confidence == .hunch }?.hitRate ?? 0, 0.5, accuracy: 1e-9)
        XCTAssertEqual(report.byConfidence.first { $0.confidence == .fairlySure }?.hitRate ?? 0, 1.0, accuracy: 1e-9)
    }
}

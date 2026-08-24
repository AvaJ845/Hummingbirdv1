import XCTest
@testable import Hummingbird

final class LessonsCalibrationEngineTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)
    private var before: Date { start.addingTimeInterval(-86_400) }
    private var after: Date { start.addingTimeInterval(86_400) }

    /// spot 100, direction .higher: actual 110 = correct, 90 = wrong,
    /// 100 = push (undecidable), nil = unresolved.
    private func call(created: Date, actual: Double?) -> UserCall {
        UserCall(id: UUID(), symbol: "AAPL", assetClass: .stock, createdAt: created,
                 horizonDays: 7, spotAtCall: 100, direction: .higher, confidence: .fairlySure,
                 reason: nil, methodDirections: nil,
                 actualClose: actual, resolvedAt: actual == nil ? nil : created)
    }

    func testNilWhenLessonsNeverStarted() {
        let calls = (0..<10).map { _ in call(created: after, actual: 110) }
        XCTAssertNil(LessonsCalibrationEngine.insight(calls: calls, lessonsStartedAt: nil))
    }

    func testNilWhenNotEnoughOnEachSide() {
        var calls = (0..<3).map { _ in call(created: before, actual: 110) }   // only 3 before
        calls += (0..<10).map { _ in call(created: after, actual: 110) }
        XCTAssertNil(LessonsCalibrationEngine.insight(calls: calls, lessonsStartedAt: start))
    }

    func testComputesBeforeAndAfterHitRates() {
        var calls: [UserCall] = []
        // Before: 6 decided → 3 correct = 0.5
        calls += (0..<3).map { _ in call(created: before, actual: 110) }
        calls += (0..<3).map { _ in call(created: before, actual: 90) }
        // After: 5 decided → 4 correct = 0.8
        calls += (0..<4).map { _ in call(created: after, actual: 110) }
        calls += [call(created: after, actual: 90)]

        let insight = LessonsCalibrationEngine.insight(calls: calls, lessonsStartedAt: start)
        XCTAssertNotNil(insight)
        XCTAssertEqual(insight?.beforeDecided, 6)
        XCTAssertEqual(insight?.afterDecided, 5)
        XCTAssertEqual(insight?.beforeRate ?? 0, 0.5, accuracy: 1e-9)
        XCTAssertEqual(insight?.afterRate ?? 0, 0.8, accuracy: 1e-9)
        XCTAssertEqual(insight?.delta ?? 0, 0.3, accuracy: 1e-9)
        XCTAssertEqual(insight?.improved, true)
    }

    func testUnresolvedAndPushesAreExcluded() {
        var calls: [UserCall] = []
        calls += (0..<5).map { _ in call(created: before, actual: 110) }   // 5 decided before
        calls += (0..<5).map { _ in call(created: after, actual: 90) }     // 5 decided after (all wrong)
        // Noise that must not count:
        calls += (0..<4).map { _ in call(created: before, actual: nil) }   // unresolved
        calls += (0..<4).map { _ in call(created: after, actual: 100) }    // pushes (flat)

        let insight = LessonsCalibrationEngine.insight(calls: calls, lessonsStartedAt: start)
        XCTAssertEqual(insight?.beforeDecided, 5)
        XCTAssertEqual(insight?.afterDecided, 5)
        XCTAssertEqual(insight?.beforeRate ?? -1, 1.0, accuracy: 1e-9)
        XCTAssertEqual(insight?.afterRate ?? -1, 0.0, accuracy: 1e-9)
        XCTAssertEqual(insight?.improved, false)
    }
}

import XCTest
@testable import Hummingbird

final class CalibrationInsightEngineTests: XCTestCase {
    private func bucket(_ confidence: CallConfidence, decided: Int, hitRate: Double) -> ConfidenceCalibration {
        ConfidenceCalibration(confidence: confidence, decided: decided, hitRate: hitRate)
    }

    func testNilWhenNoConfidentBucket() {
        let result = CalibrationInsightEngine.insight(from: [bucket(.hunch, decided: 5, hitRate: 0.8)])
        XCTAssertNil(result)
    }

    func testNilWhenConfidentBucketTooSmall() {
        let result = CalibrationInsightEngine.insight(from: [
            bucket(.confident, decided: 2, hitRate: 0.3),
            bucket(.hunch, decided: 5, hitRate: 0.8),
        ])
        XCTAssertNil(result)
    }

    func testNilWhenNoLowerBucketMeetsMinimum() {
        let result = CalibrationInsightEngine.insight(from: [
            bucket(.confident, decided: 5, hitRate: 0.3),
            bucket(.hunch, decided: 2, hitRate: 0.9),
        ])
        XCTAssertNil(result)
    }

    func testNilWhenGapTooSmall() {
        let result = CalibrationInsightEngine.insight(from: [
            bucket(.confident, decided: 5, hitRate: 0.55),
            bucket(.hunch, decided: 5, hitRate: 0.60),
        ])
        XCTAssertNil(result)
    }

    func testGapAtExactThresholdCounts() {
        let result = CalibrationInsightEngine.insight(from: [
            bucket(.confident, decided: 5, hitRate: 0.40),
            bucket(.hunch, decided: 5, hitRate: 0.55),
        ])
        XCTAssertNotNil(result)
    }

    func testDetectsOverconfidenceAgainstStrongestLowerBucket() {
        let result = CalibrationInsightEngine.insight(from: [
            bucket(.confident, decided: 5, hitRate: 0.40),
            bucket(.fairlySure, decided: 5, hitRate: 0.55),
            bucket(.hunch, decided: 5, hitRate: 0.75),
        ])
        XCTAssertEqual(result, .overconfident(confidentRate: 0.40, lowerRate: 0.75, lowerLabel: "Hunch"))
    }

    func testNilWhenConfidentIsActuallyBest() {
        let result = CalibrationInsightEngine.insight(from: [
            bucket(.confident, decided: 5, hitRate: 0.90),
            bucket(.hunch, decided: 5, hitRate: 0.40),
        ])
        XCTAssertNil(result)
    }

    // MARK: - Copy stays honest

    func testMessageNeverImpliesAdvice() {
        let insight = CalibrationInsight.overconfident(confidentRate: 0.4, lowerRate: 0.75, lowerLabel: "Hunch")
        XCTAssertFalse(insight.message.lowercased().contains("buy"))
        XCTAssertFalse(insight.message.lowercased().contains("sell"))
    }

    // MARK: - Signature changes with the numbers

    func testSignatureChangesWhenRatesShift() {
        let a = CalibrationInsight.overconfident(confidentRate: 0.4, lowerRate: 0.75, lowerLabel: "Hunch")
        let b = CalibrationInsight.overconfident(confidentRate: 0.45, lowerRate: 0.75, lowerLabel: "Hunch")
        XCTAssertNotEqual(a.signature, b.signature)
    }

    func testSignatureStableForSameRates() {
        let a = CalibrationInsight.overconfident(confidentRate: 0.4, lowerRate: 0.75, lowerLabel: "Hunch")
        let b = CalibrationInsight.overconfident(confidentRate: 0.4, lowerRate: 0.75, lowerLabel: "Hunch")
        XCTAssertEqual(a.signature, b.signature)
    }

    // MARK: - Throttle persistence

    private let suiteName = "hummingbird.tests.calibrationInsight"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testThrottleNilInitially() {
        XCTAssertNil(CalibrationInsightThrottle.lastShownSignature(defaults: defaults))
    }

    func testThrottleRoundTrips() {
        CalibrationInsightThrottle.recordShown("overconfident-Hunch-40-75", defaults: defaults)
        XCTAssertEqual(CalibrationInsightThrottle.lastShownSignature(defaults: defaults), "overconfident-Hunch-40-75")
    }
}

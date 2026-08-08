import XCTest
@testable import Hummingbird

final class ReliabilityEngineTests: XCTestCase {

    private func inputs(
        mape: Double? = 0.04,
        regime: VolatilityRegime? = VolatilityRegime.normal,
        disagreement: Double? = 0.02,
        horizon: Int = 14,
        history: Int = 120
    ) -> ReliabilityInputs {
        ReliabilityInputs(backtestMAPE: mape, regime: regime,
                          modelDisagreement: disagreement, horizon: horizon, historyCount: history)
    }

    func testScoreIsBounded() {
        let worst = ReliabilityEngine.score(inputs(mape: 0.9, regime: .high, disagreement: 0.9, horizon: 365, history: 8))
        let best = ReliabilityEngine.score(inputs(mape: 0.0, regime: .calm, disagreement: 0.0, horizon: 7, history: 400))
        XCTAssertTrue((0...100).contains(worst.value))
        XCTAssertTrue((0...100).contains(best.value))
        XCTAssertGreaterThan(best.value, worst.value)
    }

    func testTierThresholds() {
        XCTAssertEqual(ReliabilityEngine.score(inputs(mape: 0.0, regime: .calm, disagreement: 0.0, horizon: 7, history: 400)).tier, .good)
        XCTAssertEqual(ReliabilityEngine.score(inputs(mape: 0.9, regime: .high, disagreement: 0.9, horizon: 365, history: 8)).tier, .low)
    }

    func testWorseInputsLowerTheScore() {
        let baseline = ReliabilityEngine.score(inputs()).value
        XCTAssertLessThan(ReliabilityEngine.score(inputs(mape: 0.12)).value, baseline, "worse backtest lowers score")
        XCTAssertLessThan(ReliabilityEngine.score(inputs(regime: .high)).value, baseline, "high volatility lowers score")
        XCTAssertLessThan(ReliabilityEngine.score(inputs(disagreement: 0.10)).value, baseline, "disagreement lowers score")
        XCTAssertLessThan(ReliabilityEngine.score(inputs(horizon: 90)).value, baseline, "long horizon lowers score")
        XCTAssertLessThan(ReliabilityEngine.score(inputs(history: 12)).value, baseline, "thin history lowers score")
    }

    func testNilBacktestFallsBackToNeutralBase() {
        let s = ReliabilityEngine.score(inputs(mape: nil, regime: .calm, disagreement: 0.0, horizon: 7, history: 400))
        XCTAssertTrue(s.factors.contains { $0.name == "How well it's tracked" && $0.detail.contains("Not enough") })
        // With no penalties, neutral base 50 → moderate.
        XCTAssertEqual(s.tier, .moderate)
    }

    func testFactorsAndHeadlinePresent() {
        let s = ReliabilityEngine.score(inputs(regime: .high, disagreement: 0.08, horizon: 60, history: 15))
        XCTAssertFalse(s.factors.isEmpty)
        XCTAssertFalse(s.headline.isEmpty)
        // Penalties should be negative-impact factors.
        XCTAssertTrue(s.factors.contains { $0.name == "Volatility" && $0.impact < 0 })
    }

    func testLedgerFootsToScore() {
        // The displayed breakdown must add up: value == 50 + Σ(impacts) (clamped).
        for i in [inputs(),
                  inputs(mape: 0.07, regime: .elevated, disagreement: 0.05, horizon: 30, history: 60),
                  inputs(mape: nil, regime: .high, disagreement: 0.02, horizon: 45, history: 20)] {
            let s = ReliabilityEngine.score(i)
            let summed = max(0, min(100, 50 + s.factors.reduce(0) { $0 + $1.impact }))
            XCTAssertEqual(s.value, summed, "ledger must foot to the score")
        }
    }

    // MARK: - Forecaster.modelDisagreement

    func testModelDisagreementIsFiniteAndNonNegative() {
        let series = SampleData.series(symbol: "AAPL", assetClass: .stock, days: 120)
        let d = Forecaster.modelDisagreement(series: series, horizon: 30)
        XCTAssertNotNil(d)
        XCTAssertTrue(d!.isFinite)
        XCTAssertGreaterThanOrEqual(d!, 0)
    }

    func testModelDisagreementNilWithoutEnoughHistory() {
        let points = (0..<5).map { PricePoint(date: Date(timeIntervalSince1970: Double($0) * 86_400), close: 100) }
        let series = PriceSeries(symbol: "TINY", assetClass: .stock, points: points, isSample: true)
        // Each model returns empty forecast (below minimum history) → no expected change.
        XCTAssertNil(Forecaster.modelDisagreement(series: series, horizon: 14))
    }
}

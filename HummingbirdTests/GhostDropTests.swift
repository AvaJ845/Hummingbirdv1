import XCTest
@testable import Hummingbird

/// P0 regression: the forecast must be **continuous with the real-time spot
/// price**. A gap-up (earnings breakout) must never produce a "ghost drop" —
/// a first projection node far below the last real close.
final class GhostDropTests: XCTestCase {

    /// A low-volatility history that ends with a violent gap-up to `spot`,
    /// mirroring the MSFT case in the report (calm ~450, then jump to 486.53).
    private func gapUpSeries(spot: Double = 486.53, base: Double = 450) -> PriceSeries {
        var points: [PricePoint] = []
        for offset in 0..<59 {
            // Tiny deterministic wiggle → small rolling σ, so the final jump
            // is unambiguously a >3σ event.
            let close = base + sin(Double(offset) * 0.7) * 1.5
            points.append(PricePoint(date: Date(timeIntervalSince1970: Double(offset) * 86_400),
                                     close: close))
        }
        points.append(PricePoint(date: Date(timeIntervalSince1970: 59 * 86_400), close: spot))
        return PriceSeries(symbol: "MSFT", assetClass: .stock, points: points, isSample: true)
    }

    private var allModels: [ForecastModel] {
        ForecastStrategy.allCases.compactMap { ForecastModel.model(id: $0.rawValue) }
    }

    /// DoD #1: zero discontinuity between the last real close and the first
    /// projection node — for **every** model.
    func testNoGhostDropAcrossModelsOnGapUp() {
        let series = gapUpSeries()
        let spot = series.points.last!.close

        for model in allModels {
            let forecast = Forecaster.forecast(series: series, model: model, horizon: 14)
            guard let first = forecast.points.first else {
                XCTFail("\(model.name): no forecast points"); continue
            }
            let jump = abs(first.mean - spot) / spot
            XCTAssertLessThan(
                jump, 0.05,
                "\(model.name): first node \(first.mean) is \(String(format: "%.1f%%", jump * 100)) "
                + "from spot \(spot) — a ghost drop."
            )
        }
    }

    /// The Holt and linear models were the worst offenders (report: 452.66 vs
    /// 486.53). Pin them tight.
    func testHoltAndLinearAnchorToSpot() {
        let series = gapUpSeries()
        let spot = series.points.last!.close
        for strategy in [ForecastStrategy.holt, .linear] {
            let model = ForecastModel.model(id: strategy.rawValue)!
            let first = Forecaster.forecast(series: series, model: model, horizon: 14).points.first!
            XCTAssertEqual(first.mean, spot, accuracy: spot * 0.03,
                           "\(model.name) must start at spot, not the lagging baseline.")
        }
    }

    /// DoD #3: switching between Holt, Drift, and Momentum is a smooth visual
    /// transition — their first nodes cluster around spot, not scatter.
    func testModelsTransitionSmoothlyAtOrigin() {
        let series = gapUpSeries()
        let spot = series.points.last!.close
        let firsts = [ForecastStrategy.holt, .drift, .momentum].map { strategy -> Double in
            let model = ForecastModel.model(id: strategy.rawValue)!
            return Forecaster.forecast(series: series, model: model, horizon: 14).points.first!.mean
        }
        let spread = (firsts.max()! - firsts.min()!) / spot
        XCTAssertLessThan(spread, 0.03, "Model origins scatter by \(spread) of spot.")
    }

    /// Anchoring is a parallel shift: it fixes the origin without distorting a
    /// model's trend. Drift's day-to-day step stays equal to its drift.
    func testAnchoringPreservesTrendShape() {
        let series = gapUpSeries()
        let model = ForecastModel.model(id: ForecastStrategy.drift.rawValue)!
        let pts = Forecaster.forecast(series: series, model: model, horizon: 5).points
        for i in 1..<pts.count {
            XCTAssertEqual(pts[i].mean - pts[i - 1].mean, pts[1].mean - pts[0].mean, accuracy: 1e-6,
                           "Drift steps should be uniform after anchoring.")
        }
    }

    /// Earnings cut both ways: a miss gaps the price DOWN. Anchoring must be
    /// symmetric — no artificial jump UP from a lower spot either.
    func testNoGhostSpikeOnEarningsMiss() {
        let series = gapUpSeries(spot: 418.0, base: 450)  // −7% gap down
        let spot = series.points.last!.close
        for model in allModels {
            guard let first = Forecaster.forecast(series: series, model: model, horizon: 14).points.first else {
                XCTFail("\(model.name): no points"); continue
            }
            XCTAssertLessThan(abs(first.mean - spot) / spot, 0.05,
                              "\(model.name): first node \(first.mean) diverges from a gap-down spot \(spot).")
        }
    }

    /// Adversarial / degenerate inputs must never yield NaN, Inf, or negative
    /// prices (a crash or garbage chart is both a UX and a robustness failure).
    func testForecastStaysFiniteOnDegenerateInputs() {
        let flat = (0..<20).map { PricePoint(date: Date(timeIntervalSince1970: Double($0) * 86_400), close: 100) }
        let cases: [PriceSeries] = [
            PriceSeries(symbol: "FLAT", assetClass: .stock, points: flat, isSample: true),
            gapUpSeries(spot: 0.01, base: 450),     // near-zero spot
            gapUpSeries(spot: 9_999, base: 1),      // extreme gap up
        ]
        for series in cases {
            for model in allModels {
                for point in Forecaster.forecast(series: series, model: model, horizon: 30).points {
                    XCTAssertTrue(point.mean.isFinite && point.lower.isFinite && point.upper.isFinite,
                                  "\(model.name): non-finite output")
                    XCTAssertGreaterThanOrEqual(point.mean, 0, "\(model.name): negative price")
                    XCTAssertLessThanOrEqual(point.lower, point.upper, "\(model.name): inverted band")
                }
            }
        }
    }

    /// Action 2: Holt snaps its level to a gap instead of lagging behind it.
    func testHoltSnapsLevelOnGap() {
        var values = (0..<40).map { 100.0 + sin(Double($0) * 0.6) * 0.8 }  // calm ~100
        values.append(140)                                                 // +40 gap

        let lagging = Math.holtLinear(values, alpha: 0.3, beta: 0.1)                       // no gap handling
        let snapped = Math.holtLinear(values, alpha: 0.3, beta: 0.1, gapSigmaThreshold: 3) // gap-aware

        XCTAssertLessThan(abs(snapped.level - 140), abs(lagging.level - 140),
                          "Gap-aware Holt should land closer to the post-gap price.")
        XCTAssertEqual(snapped.level, 140, accuracy: 5, "Snapped level should sit near spot.")
    }
}

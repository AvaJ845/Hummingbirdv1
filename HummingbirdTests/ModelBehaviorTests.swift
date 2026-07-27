import XCTest
@testable import Hummingbird

/// Verifies each strategy's output matches the math it advertises.
final class ModelBehaviorTests: XCTestCase {

    private func series(_ closes: [Double], assetClass: AssetClass = .stock) -> PriceSeries {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let start = cal.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        let points = closes.enumerated().map { index, close in
            PricePoint(date: cal.date(byAdding: .day, value: index, to: start)!, close: close)
        }
        return PriceSeries(symbol: "TEST", assetClass: assetClass, points: points, isSample: false)
    }

    private func model(_ strategy: ForecastStrategy) -> ForecastModel {
        ForecastModel.model(id: strategy.rawValue)!
    }

    // Drift = last close + h × average daily change (random walk with drift).
    func testDriftContinuesAverageDailyChange() {
        let s = series([100, 102, 101, 105, 104, 108, 107, 110])
        let f = Forecaster.forecast(series: s, model: model(.drift), horizon: 5)
        let drift = (110.0 - 100.0) / 7.0 // telescoping sum of daily diffs / (n-1)
        for (i, point) in f.points.enumerated() {
            XCTAssertEqual(point.mean, 110 + drift * Double(i + 1), accuracy: 1e-6,
                           "Drift step \(i + 1) should be last + drift×h")
        }
    }

    // Straight trend = ordinary least-squares line, extended.
    func testLinearReproducesTheFittedLine() {
        let s = series([100, 101, 102, 103, 104, 105, 106, 107]) // slope 1, intercept 100
        let f = Forecaster.forecast(series: s, model: model(.linear), horizon: 5)
        for (i, point) in f.points.enumerated() {
            XCTAssertEqual(point.mean, 107 + Double(i + 1), accuracy: 1e-4,
                           "Linear step \(i + 1) should extend the fitted line")
        }
    }

    // Mean reversion pulls a stretched price back toward its moving average.
    func testReversionMovesTowardMovingAverage() {
        let s = series([100, 100, 100, 100, 100, 100, 100, 130])
        let sma = (100 * 7 + 130) / 8.0 // 103.75
        let target = Forecaster.forecast(series: s, model: model(.reversion), horizon: 30).targetPrice!
        XCTAssertLessThan(target, 130, "Should pull down from the stretched last price")
        XCTAssertGreaterThan(target, sma, "Should not overshoot past the average")
    }

    // Momentum leans in the direction of recent strength.
    func testMomentumLeansWithUptrend() {
        let s = series((0..<15).map { 100 + Double($0) }) // steady uptrend
        let last = s.points.last!.close
        let target = Forecaster.forecast(series: s, model: model(.momentum), horizon: 10).targetPrice!
        XCTAssertGreaterThan(target, last, "Uptrend momentum should project higher")
    }

    // Holt (level + trend) extends an uptrend upward.
    func testHoltExtendsTrendUpward() {
        let s = series((0..<20).map { 100 + Double($0) })
        let last = s.points.last!.close
        let target = Forecaster.forecast(series: s, model: model(.holt), horizon: 10).targetPrice!
        XCTAssertGreaterThan(target, last, "Holt should carry the upward trend forward")
    }

    // Uncertainty band widens monotonically with the horizon.
    func testBandWidensWithHorizon() {
        let s = series([100, 102, 101, 105, 104, 108, 107, 110])
        let f = Forecaster.forecast(series: s, model: model(.drift), horizon: 10)
        let widths = f.points.map(\.bandHalfWidth)
        for i in 1..<widths.count {
            XCTAssertGreaterThanOrEqual(widths[i], widths[i - 1], "Band should not shrink with horizon")
        }
    }

    // Blend = equal-weight average of Trend+weekday, Straight trend, and Momentum.
    func testBlendIsAverageOfItsThreeConstituents() {
        let s = series([100, 103, 102, 106, 108, 107, 110, 113, 112, 116])
        let horizon = 12
        let a = Forecaster.forecast(series: s, model: model(.trendSeasonal), horizon: horizon).targetPrice!
        let b = Forecaster.forecast(series: s, model: model(.linear), horizon: horizon).targetPrice!
        let c = Forecaster.forecast(series: s, model: model(.momentum), horizon: horizon).targetPrice!
        let blend = Forecaster.forecast(series: s, model: model(.ensemble), horizon: horizon).targetPrice!
        XCTAssertEqual(blend, (a + b + c) / 3, accuracy: 1e-6)
    }
}

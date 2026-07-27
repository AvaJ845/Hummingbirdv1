import XCTest
@testable import Hummingbird

final class PriceSanitizerTests: XCTestCase {

    private func series(_ closes: [Double]) -> PriceSeries {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let start = cal.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        let points = closes.enumerated().map { i, c in
            PricePoint(date: cal.date(byAdding: .day, value: i, to: start)!, close: c)
        }
        return PriceSeries(symbol: "TEST", assetClass: .stock, points: points, isSample: false)
    }

    func testRemovesIsolatedSpike() {
        // A single wildly-wrong print in an otherwise smooth series.
        var closes = Array(repeating: 100.0, count: 11)
        closes[5] = 100_000 // fat-finger tick
        let cleaned = PriceSanitizer.clean(series(closes))
        XCTAssertEqual(cleaned.points[5].close, 100.0, accuracy: 0.001, "Spike should be replaced by local median")
        // Neighbors untouched.
        XCTAssertEqual(cleaned.points[4].close, 100.0, accuracy: 0.001)
        XCTAssertEqual(cleaned.points[6].close, 100.0, accuracy: 0.001)
    }

    func testLeavesCleanSeriesUnchanged() {
        let closes = (0..<30).map { 100 + Double($0) * 0.5 } // gentle trend, no ticks
        let cleaned = PriceSanitizer.clean(series(closes))
        for (original, point) in zip(closes, cleaned.points) {
            XCTAssertEqual(point.close, original, accuracy: 0.0001)
        }
    }

    func testPreservesGenuineSustainedMove() {
        // A real step-change (e.g. gap up) that persists must NOT be flattened.
        let closes = Array(repeating: 100.0, count: 8) + Array(repeating: 130.0, count: 8)
        let cleaned = PriceSanitizer.clean(series(closes))
        // Late points should keep the elevated level.
        XCTAssertEqual(cleaned.points.last!.close, 130.0, accuracy: 0.001)
        XCTAssertEqual(cleaned.points[12].close, 130.0, accuracy: 0.001)
    }
}

final class BacktestTests: XCTestCase {

    private func series(_ closes: [Double]) -> PriceSeries {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let start = cal.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        let points = closes.enumerated().map { i, c in
            PricePoint(date: cal.date(byAdding: .day, value: i, to: start)!, close: c)
        }
        return PriceSeries(symbol: "TEST", assetClass: .stock, points: points, isSample: false)
    }

    func testBacktestReturnsNilWithoutEnoughHistory() {
        let s = series((0..<10).map { 100 + Double($0) }) // 10 < min(8) + holdout(14)
        XCTAssertNil(Forecaster.backtestMAPE(series: s, model: .default, holdout: 14))
    }

    func testDriftBacktestIsNearZeroOnPerfectlyLinearData() {
        // On a constant-slope series, drift should reproduce it → tiny MAPE.
        let s = series((0..<60).map { 100 + Double($0) })
        let drift = ForecastModel.model(id: ForecastStrategy.drift.rawValue)!
        let mape = Forecaster.backtestMAPE(series: s, model: drift, holdout: 14)
        XCTAssertNotNil(mape)
        XCTAssertLessThan(mape!, 0.02, "Drift should track a linear series almost exactly")
    }

    func testBacktestIsFiniteNonNegativeForEveryModel() {
        let s = SampleData.series(symbol: "AAPL", assetClass: .stock, days: 120)
        for model in ForecastModel.available {
            let mape = Forecaster.backtestMAPE(series: s, model: model)
            XCTAssertNotNil(mape, model.name)
            XCTAssertGreaterThanOrEqual(mape!, 0, model.name)
            XCTAssertTrue(mape!.isFinite, model.name)
        }
    }
}

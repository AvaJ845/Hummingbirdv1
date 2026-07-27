import XCTest
@testable import Hummingbird

final class ForecasterTests: XCTestCase {
    func testForecastProducesHorizonPoints() {
        let series = SampleData.series(symbol: "bitcoin", assetClass: .crypto, days: 120)
        let forecast = Forecaster.forecast(series: series, model: .default, horizon: 30)

        XCTAssertEqual(forecast.points.count, 30)
        XCTAssertEqual(forecast.history.count, series.points.count)
        XCTAssertNotNil(forecast.targetPrice)
        XCTAssertNotNil(forecast.expectedChange)
    }

    func testInsufficientHistoryReturnsEmptyForecast() {
        let points = (0..<4).map { offset in
            PricePoint(date: Date(timeIntervalSince1970: Double(offset) * 86_400), close: 100 + Double(offset))
        }
        let series = PriceSeries(symbol: "TINY", assetClass: .stock, points: points, isSample: true)
        let forecast = Forecaster.forecast(series: series, model: .default, horizon: 14)

        XCTAssertTrue(forecast.points.isEmpty)
    }

    func testPhoenixEnsembleIsReadyAndFinite() {
        guard let phoenix = ForecastModel.model(id: ForecastStrategy.ensemble.rawValue) else {
            return XCTFail("Phoenix missing from catalogue")
        }

        XCTAssertTrue(phoenix.status.isAvailable)

        let series = SampleData.series(symbol: "AAPL", assetClass: .stock, days: 90)
        let forecast = Forecaster.forecast(series: series, model: phoenix, horizon: 21)

        XCTAssertEqual(forecast.points.count, 21)
        for point in forecast.points {
            XCTAssertTrue(point.mean.isFinite)
            XCTAssertLessThanOrEqual(point.lower, point.mean)
            XCTAssertGreaterThanOrEqual(point.upper, point.mean)
        }
    }

    func testSampleDataIsDeterministic() {
        let a = SampleData.series(symbol: "ethereum", assetClass: .crypto, days: 60)
        let b = SampleData.series(symbol: "ethereum", assetClass: .crypto, days: 60)

        XCTAssertEqual(a.points.map(\.close), b.points.map(\.close))
        XCTAssertTrue(a.isSample)
    }

    func testStableSeedIsCaseInsensitive() {
        XCTAssertEqual(SampleData.stableSeed(for: "AAPL"), SampleData.stableSeed(for: "aapl"))
        XCTAssertNotEqual(SampleData.stableSeed(for: "AAPL"), SampleData.stableSeed(for: "MSFT"))
    }

    func testLinearFitKnownLine() {
        let x = [0.0, 1.0, 2.0, 3.0]
        let y = [1.0, 3.0, 5.0, 7.0]
        let (slope, intercept) = Math.linearFit(x: x, y: y)

        XCTAssertEqual(slope, 2.0, accuracy: 1e-9)
        XCTAssertEqual(intercept, 1.0, accuracy: 1e-9)
    }

    func testDriftContinuesAverageDailyChange() {
        // Prices rise by exactly +2 each day → drift = 2; 10-day ahead = last + 20.
        let points = (0..<30).map { offset in
            PricePoint(
                date: Date(timeIntervalSince1970: Double(offset) * 86_400),
                close: 100 + Double(offset) * 2
            )
        }
        let series = PriceSeries(symbol: "DRIFT", assetClass: .stock, points: points, isSample: true)
        let model = ForecastModel.model(id: ForecastStrategy.drift.rawValue)!
        let forecast = Forecaster.forecast(series: series, model: model, horizon: 10)

        XCTAssertEqual(forecast.targetPrice ?? -1, 100 + 29 * 2 + 20, accuracy: 1e-9)
        XCTAssertEqual(model.name, "Drift")
        XCTAssertEqual(model.nickname, "Starling")
    }

    func testHoltLinearProducesFinitePath() {
        let series = SampleData.series(symbol: "AAPL", assetClass: .stock, days: 90)
        let model = ForecastModel.model(id: ForecastStrategy.holt.rawValue)!
        let forecast = Forecaster.forecast(series: series, model: model, horizon: 14)

        XCTAssertEqual(model.name, "Holt")
        XCTAssertEqual(model.nickname, "Osprey")
        XCTAssertEqual(forecast.points.count, 14)
        XCTAssertTrue(forecast.points.allSatisfy { $0.mean.isFinite && $0.mean >= 0 })
    }

    func testHoltMathOnStraightLine() {
        let values = (0..<20).map { 10.0 + Double($0) }
        let result = Math.holtLinear(values, alpha: 0.5, beta: 0.5)
        // After fitting a unit slope line, trend should stay near 1 and level near last value.
        XCTAssertEqual(result.trend, 1.0, accuracy: 0.15)
        XCTAssertEqual(result.level, values.last!, accuracy: 1.0)
    }
}

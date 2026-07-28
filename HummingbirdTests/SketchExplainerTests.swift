import XCTest
@testable import Hummingbird

final class SketchExplainerTests: XCTestCase {
    private func series(_ closes: [Double]) -> PriceSeries {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let start = cal.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        let points = closes.enumerated().map { i, c in
            PricePoint(date: cal.date(byAdding: .day, value: i, to: start)!, close: c)
        }
        return PriceSeries(symbol: "TEST", assetClass: .stock, points: points, isSample: false)
    }

    func testDriversMentionMethodAndCarryNotAdviceLine() {
        let s = series((0..<60).map { 100 + Double($0) * 0.5 })
        let forecast = Forecaster.forecast(series: s, model: .default, horizon: 30)
        let drivers = SketchExplainer.drivers(forecast: forecast, disagreementSpread: 0.04)

        XCTAssertGreaterThanOrEqual(drivers.count, 3)
        XCTAssertTrue(drivers.first?.contains(forecast.model.name) ?? false, "leads with the method")
        XCTAssertTrue(drivers.contains { $0.lowercased().contains("buy or sell") },
                      "must always carry the not-advice line")
    }

    func testEveryStrategyProducesADriverSentence() {
        let s = series((0..<80).map { 100 + Double($0) })
        for model in ForecastModel.available {
            let forecast = Forecaster.forecast(series: s, model: model, horizon: 20)
            let drivers = SketchExplainer.drivers(forecast: forecast, disagreementSpread: nil)
            XCTAssertGreaterThanOrEqual(drivers.count, 3, model.name)
        }
    }
}

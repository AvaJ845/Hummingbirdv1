import XCTest
@testable import Hummingbird

final class StockPriceParsingTests: XCTestCase {
    func testParseYahooChartBuildsSeries() throws {
        let json = """
        {
          "chart": {
            "result": [{
              "timestamp": [1704153600, 1704240000, 1704326400],
              "indicators": {
                "quote": [{
                  "close": [185.5, null, 187.1]
                }]
              }
            }]
          }
        }
        """.data(using: .utf8)!

        let series = try StockPriceParsing.parseYahooChart(json, ticker: "AAPL", days: 30)

        XCTAssertEqual(series.points.count, 2)
        XCTAssertEqual(series.points[0].close, 185.5, accuracy: 0.0001)
        XCTAssertEqual(series.points[1].close, 187.1, accuracy: 0.0001)
        XCTAssertEqual(series.symbol, "AAPL")
        XCTAssertFalse(series.isSample)
    }

    func testParseYahooChartUnknownSymbol() {
        let json = """
        { "chart": { "result": null, "error": { "code": "Not Found", "description": "No data found" } } }
        """.data(using: .utf8)!

        XCTAssertThrowsError(
            try StockPriceParsing.parseYahooChart(json, ticker: "ZZZZZ", days: 30)
        ) { error in
            XCTAssertEqual(error as? MarketDataError, .notFound("ZZZZZ"))
        }
    }
}

/// Every bird must produce finite stock + crypto sketches (sample + live).
final class AllModelsAssetCoverageTests: XCTestCase {
    func testEveryModelWorksOnSampleStockAndCrypto() {
        let cases: [(String, AssetClass)] = [
            ("AAPL", .stock),
            ("MSFT", .stock),
            ("bitcoin", .crypto),
            ("ethereum", .crypto)
        ]

        for (symbol, assetClass) in cases {
            let series = SampleData.series(symbol: symbol, assetClass: assetClass, days: 120)
            XCTAssertTrue(series.isForecastable, "\(symbol) sample should be forecastable")

            for model in ForecastModel.available {
                let forecast = Forecaster.forecast(series: series, model: model, horizon: 30)
                assertUsableForecast(forecast, model: model, symbol: symbol, assetClass: assetClass)
            }
        }
    }

    func testEveryModelRespectsStockAndCryptoMacroTilt() {
        let snapshot = EconomicSnapshot(
            kind: .fedFunds,
            value: 5.25,
            previousValue: 4.25,
            asOf: .now,
            source: "Test",
            isSample: false
        )
        let selected: Set<String> = [snapshot.kind.id]

        for assetClass in AssetClass.allCases {
            let series = SampleData.series(
                symbol: assetClass == .stock ? "AAPL" : "bitcoin",
                assetClass: assetClass,
                days: 100
            )

            for model in ForecastModel.available {
                let macro = MacroAdjuster.adjustment(
                    from: [snapshot],
                    selected: selected,
                    assetClass: assetClass,
                    model: model
                )
                XCTAssertTrue(macro.isActive, "\(model.name) \(assetClass) should tilt")

                let base = Forecaster.forecast(series: series, model: model, horizon: 21, macro: .none)
                let tilted = Forecaster.forecast(series: series, model: model, horizon: 21, macro: macro)

                guard let baseTarget = base.targetPrice, let tiltedTarget = tilted.targetPrice else {
                    return XCTFail("\(model.name) \(assetClass) missing target")
                }
                XCTAssertLessThan(tiltedTarget, baseTarget, "\(model.name) \(assetClass) rising rates should pull down")
                XCTAssertTrue(tilted.points.allSatisfy { $0.mean.isFinite && $0.lower.isFinite && $0.upper.isFinite })
            }
        }
    }

    private func assertUsableForecast(
        _ forecast: Forecast,
        model: ForecastModel,
        symbol: String,
        assetClass: AssetClass
    ) {
        let label = "\(model.name) on \(symbol) (\(assetClass.rawValue))"
        XCTAssertEqual(forecast.points.count, 30, label)
        XCTAssertEqual(forecast.model.id, model.id, label)
        guard let target = forecast.targetPrice, let change = forecast.expectedChange else {
            return XCTFail("\(label) missing target/change")
        }
        XCTAssertTrue(target.isFinite && target > 0, "\(label) target \(target)")
        XCTAssertTrue(change.isFinite, "\(label) change \(change)")
        for point in forecast.points {
            XCTAssertTrue(point.mean.isFinite && point.mean >= 0, "\(label) mean")
            XCTAssertTrue(point.lower.isFinite && point.lower >= 0, "\(label) lower")
            XCTAssertTrue(point.upper.isFinite && point.upper >= point.mean, "\(label) upper")
        }
    }
}

@MainActor
final class LiveMarketAllModelsTests: XCTestCase {
    func testLiveStockAAPLAllModels() async throws {
        let service = MarketDataService()
        let series = try await service.history(symbol: "AAPL", assetClass: .stock, days: 120)
        XCTAssertFalse(series.isSample, "Expected live AAPL")
        XCTAssertTrue(series.isForecastable)

        for model in ForecastModel.available {
            let forecast = Forecaster.forecast(series: series, model: model, horizon: 30)
            XCTAssertEqual(forecast.points.count, 30, model.name)
            XCTAssertNotNil(forecast.targetPrice, model.name)
            XCTAssertTrue(forecast.points.allSatisfy { $0.mean.isFinite && $0.mean > 0 }, model.name)
        }
    }

    func testLiveCryptoBitcoinAllModels() async throws {
        let service = MarketDataService()
        let series = try await service.history(symbol: "bitcoin", assetClass: .crypto, days: 120)
        XCTAssertFalse(series.isSample, "Expected live bitcoin")
        XCTAssertEqual(series.assetClass, .crypto)
        XCTAssertTrue(series.isForecastable)

        for model in ForecastModel.available {
            let forecast = Forecaster.forecast(series: series, model: model, horizon: 30)
            XCTAssertEqual(forecast.points.count, 30, model.name)
            XCTAssertNotNil(forecast.targetPrice, model.name)
            XCTAssertTrue(forecast.points.allSatisfy { $0.mean.isFinite && $0.mean > 0 }, model.name)
        }
    }
}

@MainActor
final class StockMarketDataServiceTests: XCTestCase {
    func testLiveYahooStockHistoryForAAPL() async throws {
        let service = MarketDataService()
        let series = try await service.history(symbol: "AAPL", assetClass: .stock, days: 90)

        XCTAssertEqual(series.symbol, "AAPL")
        XCTAssertEqual(series.assetClass, .stock)
        XCTAssertFalse(series.isSample, "Expected live Yahoo data, got sample fallback")
        XCTAssertGreaterThanOrEqual(series.points.count, 40)
        XCTAssertTrue(series.isForecastable)

        let forecast = Forecaster.forecast(series: series, model: .default, horizon: 30)
        XCTAssertEqual(forecast.points.count, 30)
        XCTAssertNotNil(forecast.targetPrice)
    }

    func testUnknownStockSymbolSurfacesNotFoundOrSample() async throws {
        let service = MarketDataService()
        do {
            let series = try await service.history(symbol: "NOTAREALTICKERZZZ", assetClass: .stock, days: 30)
            // Some upstreams soft-fail into sample; that must be labeled.
            XCTAssertTrue(series.isSample)
        } catch let error as MarketDataError {
            XCTAssertEqual(error, .notFound("NOTAREALTICKERZZZ"))
        }
    }
}

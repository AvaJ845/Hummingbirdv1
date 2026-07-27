import XCTest
@testable import Hummingbird

final class RetailExplainerTests: XCTestCase {
    func testHeadlineIsSimpleDirectionOverHorizon() {
        let series = SampleData.series(symbol: "AAPL", assetClass: .stock, days: 120)
        let forecast = Forecaster.forecast(series: series, model: .default, horizon: 30)
        let text = RetailExplainer.headline(symbol: "AAPL", forecast: forecast, horizon: 30)

        XCTAssertTrue(text.contains("AAPL"))
        XCTAssertTrue(text.contains("30"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("backtest"))
    }

    func testBottomLineExplainsHistoryProjectionNotAdvice() {
        let series = SampleData.series(symbol: "AAPL", assetClass: .stock, days: 120)
        let forecast = Forecaster.forecast(series: series, model: .default, horizon: 30)
        let text = RetailExplainer.bottomLine(
            symbol: "AAPL",
            forecast: forecast,
            disagreementSpread: 0.08,
            horizon: 30
        )

        XCTAssertTrue(text.localizedCaseInsensitiveContains("public prices"))
        XCTAssertTrue(text.localizedCaseInsensitiveContains("explore") || text.localizedCaseInsensitiveContains("sketch"))
        XCTAssertTrue(text.localizedCaseInsensitiveContains("possible range") || text.contains("$"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("backtest"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("walk-forward"))
    }

    func testPhoenixPlainEnglishIsBeginnerFriendly() {
        let phoenix = ForecastModel.model(id: ForecastStrategy.ensemble.rawValue)!
        XCTAssertEqual(phoenix.name, "Blend")
        XCTAssertEqual(phoenix.nickname, "Phoenix")
        XCTAssertTrue(phoenix.plainEnglish.localizedCaseInsensitiveContains("averages")
                      || phoenix.plainEnglish.localizedCaseInsensitiveContains("smoother"))
        XCTAssertTrue(phoenix.plainEnglish.localizedCaseInsensitiveContains("momentum"))
        XCTAssertFalse(phoenix.plainEnglish.localizedCaseInsensitiveContains("swift"))
        XCTAssertFalse(phoenix.plainEnglish.contains("≠"))
        XCTAssertEqual(phoenix.familyLabel, "Blend")
        XCTAssertEqual(phoenix.confidence, .experimental)
        XCTAssertEqual(phoenix.status, .beta)
    }

    func testRetailConfidenceLabelsAvoidHighConfidenceTheater() {
        XCTAssertEqual(ForecastModel.Confidence.high.retailLabel, "Steady")
        XCTAssertEqual(ForecastModel.Confidence.medium.retailLabel, "Typical")
        XCTAssertEqual(ForecastModel.Confidence.experimental.retailLabel, "Experimental")
    }

    func testScenarioNudgePlainWhenInactive() {
        let text = RetailExplainer.scenarioNudgePlain(.none, horizon: 30)
        XCTAssertTrue(text.localizedCaseInsensitiveContains("price history"))
    }

    func testCryptoSymbolMapResolvesCommonCoins() {
        XCTAssertEqual(CryptoSymbolMap.yahooTicker(for: "bitcoin"), "BTC-USD")
        XCTAssertEqual(CryptoSymbolMap.yahooTicker(for: "ETH"), "ETH-USD")
        XCTAssertNil(CryptoSymbolMap.yahooTicker(for: "not-a-real-coin-xyz"))
    }

    func testAdviceCopyIsBeginnerFriendly() {
        XCTAssertEqual(RetailExplainer.adviceTitle, "Not financial advice")
        XCTAssertTrue(RetailExplainer.adviceBody.localizedCaseInsensitiveContains("public history"))
        XCTAssertFalse(RetailExplainer.adviceBody.localizedCaseInsensitiveContains("backtest"))
    }
}

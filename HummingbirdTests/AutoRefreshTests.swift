import XCTest
@testable import Hummingbird

@MainActor
final class AutoRefreshTests: XCTestCase {

    func testSilentRefreshUpdatesPriceInPlaceWithoutLoadingState() async {
        let entitlements = EntitlementStore()
        let market = CountingMarketData()
        let viewModel = ForecastViewModel(
            service: market,
            economicService: StubEconomic(),
            entitlements: entitlements
        )

        viewModel.run()
        try? await Task.sleep(nanoseconds: 120_000_000)

        XCTAssertTrue(viewModel.hasResult, "Initial run should produce a projection")
        XCTAssertNotNil(viewModel.lastUpdated, "Initial run should stamp lastUpdated")
        let firstClose = viewModel.forecast?.lastClose
        let firstStamp = viewModel.lastUpdated

        await viewModel.silentRefresh()

        XCTAssertFalse(viewModel.isLoading, "Silent refresh must not show the full-screen loading state")
        XCTAssertFalse(viewModel.isRefreshing, "isRefreshing should reset after the refresh completes")
        XCTAssertTrue(viewModel.hasResult, "Result should remain on screen after refresh")

        let secondClose = viewModel.forecast?.lastClose
        XCTAssertNotEqual(firstClose ?? 0, secondClose ?? 0, accuracy: 0.000_001,
                          "Refreshed price should replace the previous close in place")
        if let a = firstStamp, let b = viewModel.lastUpdated {
            XCTAssertGreaterThanOrEqual(b, a, "lastUpdated should advance on refresh")
        }
    }

    func testSilentRefreshIsNoOpWithoutAResult() async {
        let viewModel = ForecastViewModel(
            service: CountingMarketData(),
            economicService: StubEconomic(),
            entitlements: EntitlementStore()
        )

        await viewModel.silentRefresh()

        XCTAssertFalse(viewModel.hasResult)
        XCTAssertNil(viewModel.lastUpdated, "No refresh should happen before a projection is loaded")
        XCTAssertFalse(viewModel.isRefreshing)
    }
}

/// Market stub whose price grows on each call so a refresh is observable.
private actor CountingMarketData: MarketDataProviding {
    private var calls = 0

    func history(symbol: String, assetClass: AssetClass, days: Int) async throws -> PriceSeries {
        calls += 1
        let base = SampleData.series(symbol: symbol, assetClass: assetClass, days: max(days, 120))
        let factor = 1.0 + 0.05 * Double(calls)
        let points = base.points.map { PricePoint(date: $0.date, close: $0.close * factor) }
        return PriceSeries(symbol: base.symbol, assetClass: base.assetClass, points: points, isSample: base.isSample)
    }
}

private struct StubEconomic: EconomicDataProviding {
    func fetchSnapshots() async -> [EconomicSnapshot] { [] }
}

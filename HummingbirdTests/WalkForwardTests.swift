import XCTest
@testable import Hummingbird

final class WalkForwardTests: XCTestCase {
    private func series(_ closes: [Double]) -> PriceSeries {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let start = cal.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        let points = closes.enumerated().map { i, c in
            PricePoint(date: cal.date(byAdding: .day, value: i, to: start)!, close: c)
        }
        return PriceSeries(symbol: "TEST", assetClass: .stock, points: points, isSample: false)
    }

    func testWalkForwardNilWithoutEnoughHistory() {
        let s = series((0..<12).map { 100 + Double($0) }) // one fold needs 8 + 7 = 15
        XCTAssertNil(Forecaster.walkForwardMAPE(series: s, model: .default, step: 7, folds: 4))
    }

    func testWalkForwardDriftNearZeroOnLinearData() {
        let s = series((0..<80).map { 100 + Double($0) })
        let drift = ForecastModel.model(id: ForecastStrategy.drift.rawValue)!
        let mape = Forecaster.walkForwardMAPE(series: s, model: drift)
        XCTAssertNotNil(mape)
        XCTAssertLessThan(mape!, 0.02, "Drift should track a linear series across every fold")
    }

    func testWalkForwardFiniteForEveryModel() {
        let s = SampleData.series(symbol: "AAPL", assetClass: .stock, days: 120)
        for model in ForecastModel.available {
            let mape = Forecaster.walkForwardMAPE(series: s, model: model)
            XCTAssertNotNil(mape, model.name)
            XCTAssertGreaterThanOrEqual(mape!, 0, model.name)
            XCTAssertTrue(mape!.isFinite, model.name)
        }
    }
}

@MainActor
final class BestRecentModelTests: XCTestCase {
    func testBestRecentModelHasLowestError() async {
        let entitlements = EntitlementStore()
        entitlements.setDebugUnlocked(true)
        let vm = ForecastViewModel(
            service: SampleMarket(),
            economicService: NoEconomic(),
            entitlements: entitlements
        )
        vm.run()
        try? await Task.sleep(nanoseconds: 150_000_000)

        XCTAssertTrue(vm.hasResult)
        let scored = vm.modelPreviews
            .filter { entitlements.canUse(model: $0.model) }
            .compactMap { $0.recentError }
        guard scored.count >= 2, let bestID = vm.bestRecentModelID else {
            return XCTFail("Expected at least two scored models and a best pick")
        }
        let bestError = vm.modelPreviews.first { $0.model.id == bestID }?.recentError
        XCTAssertEqual(bestError, scored.min(), "Best pick must have the minimum recent error")
    }
}

private actor SampleMarket: MarketDataProviding {
    func history(symbol: String, assetClass: AssetClass, days: Int) async throws -> PriceSeries {
        SampleData.series(symbol: symbol, assetClass: assetClass, days: max(days, 120))
    }
}

private struct NoEconomic: EconomicDataProviding {
    func fetchSnapshots() async -> [EconomicSnapshot] { [] }
}

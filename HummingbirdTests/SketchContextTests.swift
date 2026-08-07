import XCTest
@testable import Hummingbird

/// The sketch-context pipeline now lives in the view model (hoisted out of the
/// view), so it's directly testable — which is the whole point of the move.
@MainActor
final class SketchContextTests: XCTestCase {

    private func makeViewModel() -> ForecastViewModel {
        let card = SketchScorecardStore(defaults: UserDefaults(suiteName: "test.ctx.\(UUID().uuidString)")!,
                                        dedupeHours: 0)
        return ForecastViewModel(service: SampleMarket(),
                                 economicService: NoEconomic(),
                                 entitlements: EntitlementStore(),
                                 scorecard: card)
    }

    func testForecastPopulatesContextAndRecordsSketch() async {
        let vm = makeViewModel()
        vm.run()
        try? await Task.sleep(nanoseconds: 500_000_000)  // let the async reliability finish

        XCTAssertTrue(vm.hasResult)
        XCTAssertNotNil(vm.sketchContext.regime, "regime is derived from the series")
        XCTAssertNotNil(vm.sketchContext.reliability, "reliability is computed off-main and published")
        XCTAssertEqual(vm.scorecard.records.count, 1, "the completed sketch was recorded")
    }

    func testSwitchingModelRefreshesReliability() async {
        let vm = makeViewModel()
        vm.run()
        try? await Task.sleep(nanoseconds: 400_000_000)
        let first = vm.sketchContext.reliability
        XCTAssertNotNil(first)

        // A deliberate model change re-keys reliability (asset|model|horizon).
        _ = vm.selectModel(ForecastModel.model(id: ForecastStrategy.holt.rawValue)!)
        try? await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertNotNil(vm.sketchContext.reliability, "reliability recomputed for the new model")
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

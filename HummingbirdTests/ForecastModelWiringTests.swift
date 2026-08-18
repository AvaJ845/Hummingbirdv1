import XCTest
@testable import Hummingbird

final class ForecastModelWiringTests: XCTestCase {
    func testEveryAvailableModelProducesDistinctStrategyPath() {
        let series = SampleData.series(symbol: "MSFT", assetClass: .stock, days: 120)
        var targets: [String: Double] = [:]

        for model in ForecastModel.available {
            let forecast = Forecaster.forecast(series: series, model: model, horizon: 30)
            XCTAssertEqual(forecast.points.count, 30, "\(model.name) should project horizon")
            XCTAssertEqual(forecast.model.id, model.id)
            guard let target = forecast.targetPrice else {
                return XCTFail("\(model.name) missing target")
            }
            targets[model.id] = target
        }

        let unique = Set(targets.values.map { ($0 * 100).rounded() / 100 })
        XCTAssertGreaterThan(unique.count, 1, "Models should not all yield the same projection")
    }

    func testPeregrineAmplifiesMacroMoreThanKingfisher() {
        let snapshot = EconomicSnapshot(
            kind: .fedFunds,
            value: 5.25,
            previousValue: 4.25,
            asOf: .now,
            source: "Test",
            isSample: false
        )
        let selected: Set<String> = [snapshot.kind.id]
        let peregrine = ForecastModel.model(id: ForecastStrategy.momentum.rawValue)!
        let kingfisher = ForecastModel.model(id: ForecastStrategy.reversion.rawValue)!

        XCTAssertEqual(peregrine.name, "Momentum")
        XCTAssertEqual(peregrine.nickname, "Peregrine")
        XCTAssertFalse(ForecastModel.all.contains { $0.name == "Swift" || $0.nickname == "Swift" })

        let peregrineMacro = MacroAdjuster.adjustment(
            from: [snapshot],
            selected: selected,
            assetClass: .stock,
            model: peregrine
        )
        let kingMacro = MacroAdjuster.adjustment(
            from: [snapshot],
            selected: selected,
            assetClass: .stock,
            model: kingfisher
        )

        XCTAssertLessThan(peregrineMacro.horizonBias, 0)
        XCTAssertLessThan(kingMacro.horizonBias, 0)
        XCTAssertGreaterThan(abs(peregrineMacro.horizonBias), abs(kingMacro.horizonBias))
    }

    func testPhoenixIsAverageOfConstituentsWithoutMacro() {
        let series = SampleData.series(symbol: "AAPL", assetClass: .stock, days: 100)
        let skylark = Forecaster.forecast(
            series: series,
            model: ForecastModel.model(id: ForecastStrategy.trendSeasonal.rawValue)!,
            horizon: 20
        )
        let meadow = Forecaster.forecast(
            series: series,
            model: ForecastModel.model(id: ForecastStrategy.linear.rawValue)!,
            horizon: 20
        )
        let peregrine = Forecaster.forecast(
            series: series,
            model: ForecastModel.model(id: ForecastStrategy.momentum.rawValue)!,
            horizon: 20
        )
        let phoenix = Forecaster.forecast(
            series: series,
            model: ForecastModel.model(id: ForecastStrategy.ensemble.rawValue)!,
            horizon: 20
        )

        guard
            let a = skylark.targetPrice,
            let b = meadow.targetPrice,
            let c = peregrine.targetPrice,
            let p = phoenix.targetPrice
        else {
            return XCTFail("Missing targets")
        }

        let expected = (a + b + c) / 3
        XCTAssertEqual(p, expected, accuracy: 0.05)
    }

    func testAdvancedModelsRequirePro() {
        XCTAssertFalse(ForecastModel.default.requiresPro)
        XCTAssertFalse(ForecastModel.model(id: ForecastStrategy.drift.rawValue)!.requiresPro)
        XCTAssertFalse(ForecastModel.model(id: ForecastStrategy.holt.rawValue)!.requiresPro)
        XCTAssertTrue(ForecastModel.model(id: ForecastStrategy.momentum.rawValue)!.requiresPro)
        XCTAssertTrue(ForecastModel.model(id: ForecastStrategy.ensemble.rawValue)!.requiresPro)
    }
}

@MainActor
final class ForecastViewModelModelWiringTests: XCTestCase {
    func testRunLoggingCallRecordsTheUsersCall() async {
        let entitlements = EntitlementStore()
        entitlements.setDebugUnlocked(true)
        let calls = UserCallStore(defaults: UserDefaults(suiteName: "test.vm.calls.\(UUID().uuidString)")!)
        let viewModel = ForecastViewModel(
            service: StubMarketData(),
            economicService: StubEconomicData(),
            entitlements: entitlements,
            userCalls: calls
        )
        viewModel.horizon = 30                       // sketch horizon
        viewModel.run(loggingCall: (.higher, .confident, .technical, 7))  // call's own short window
        try? await Task.sleep(nanoseconds: 120_000_000)

        XCTAssertTrue(viewModel.hasResult)
        XCTAssertEqual(calls.calls.count, 1)
        let call = calls.calls.first
        XCTAssertEqual(call?.direction, .higher)
        XCTAssertEqual(call?.confidence, .confident)
        XCTAssertEqual(call?.horizonDays, 7)          // call horizon, not the sketch's 30
        XCTAssertEqual(call?.spotAtCall, viewModel.forecast?.lastClose)
    }

    func testResolveDueCallsFillsInPastCalls() async {
        let made = Date(timeIntervalSince1970: 1_700_000_000)   // long past → due now
        let calls = UserCallStore(defaults: UserDefaults(suiteName: "test.vm.due.\(UUID().uuidString)")!)
        calls.record(symbol: "AAPL", assetClass: .stock, direction: .higher,
                     confidence: .hunch, horizonDays: 7, spot: 100, now: made)

        let viewModel = ForecastViewModel(
            service: DueCallStub(date: made.addingTimeInterval(7 * 86_400), close: 120),
            economicService: StubEconomicData(),
            entitlements: EntitlementStore(),
            userCalls: calls
        )
        await viewModel.resolveDueCalls()

        XCTAssertTrue(calls.pending.isEmpty)
        XCTAssertEqual(calls.report.overall.correct, 1)   // higher, 120 > 100
    }

    func testSelectModelRecomputesForecast() async {
        let entitlements = EntitlementStore()
        entitlements.setDebugUnlocked(true)
        let viewModel = ForecastViewModel(
            service: StubMarketData(),
            economicService: StubEconomicData(),
            entitlements: entitlements
        )
        viewModel.run()
        try? await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertTrue(viewModel.hasResult)
        let firstTarget = viewModel.forecast?.targetPrice

        let peregrine = ForecastModel.model(id: ForecastStrategy.momentum.rawValue)!
        XCTAssertTrue(viewModel.selectModel(peregrine))

        XCTAssertEqual(viewModel.model.id, peregrine.id)
        XCTAssertEqual(viewModel.forecast?.model.id, peregrine.id)
        XCTAssertNotEqual(viewModel.forecast?.targetPrice ?? 0, firstTarget ?? 0, accuracy: 0.000_000_1)
        await viewModel.awaitModelPreviews()
        XCTAssertEqual(viewModel.modelPreviews.count, ForecastModel.available.count)
    }

    func testFreeTierGatesProModelAndHorizon() async {
        let entitlements = EntitlementStore()
        entitlements.setDebugUnlocked(false)
        let viewModel = ForecastViewModel(
            service: StubMarketData(),
            economicService: StubEconomicData(),
            entitlements: entitlements
        )

        let phoenix = ForecastModel.model(id: ForecastStrategy.ensemble.rawValue)!
        XCTAssertFalse(viewModel.selectModel(phoenix))
        XCTAssertNotNil(viewModel.pendingPaywallReason)

        viewModel.pendingPaywallReason = nil

        // Both daily rate knobs are free.
        XCTAssertTrue(viewModel.toggleIndicator("fedfunds"))
        XCTAssertTrue(viewModel.toggleIndicator("t10y"))
        XCTAssertNil(viewModel.pendingPaywallReason)

        viewModel.horizon = 90
        XCTAssertEqual(viewModel.horizon, FreeTierLimits.maxHorizonDays)
    }
}

/// Returns a one-point series at a fixed date — enough to resolve a due call.
private struct DueCallStub: MarketDataProviding {
    let date: Date
    let close: Double
    func history(symbol: String, assetClass: AssetClass, days: Int) async throws -> PriceSeries {
        PriceSeries(symbol: symbol, assetClass: assetClass,
                    points: [PricePoint(date: date, close: close)], isSample: true)
    }
}

private struct StubMarketData: MarketDataProviding {
    func history(symbol: String, assetClass: AssetClass, days: Int) async throws -> PriceSeries {
        SampleData.series(symbol: symbol, assetClass: assetClass, days: max(days, 90))
    }
}

private struct StubEconomicData: EconomicDataProviding {
    func fetchSnapshots() async -> [EconomicSnapshot] {
        EconomicIndicatorKind.allCases.map(SampleMacro.snapshot)
    }
}

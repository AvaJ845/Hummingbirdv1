import XCTest
@testable import Hummingbird

final class MarketCalendarTests: XCTestCase {
    private func eastern(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        return cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    func testOpenDuringWeekdaySession() {
        // Wednesday 2024-06-12, 11:00 ET → open.
        XCTAssertTrue(MarketCalendar.isUSMarketOpen(at: eastern(2024, 6, 12, 11, 0)))
    }

    func testClosedBeforeOpenAndAfterClose() {
        XCTAssertFalse(MarketCalendar.isUSMarketOpen(at: eastern(2024, 6, 12, 9, 0)))   // pre-market
        XCTAssertFalse(MarketCalendar.isUSMarketOpen(at: eastern(2024, 6, 12, 16, 1)))  // after close
    }

    func testClosedOnWeekend() {
        // Saturday 2024-06-15, midday.
        XCTAssertFalse(MarketCalendar.isUSMarketOpen(at: eastern(2024, 6, 15, 12, 0)))
    }

    func testBoundaryOpenAtExactly930() {
        XCTAssertTrue(MarketCalendar.isUSMarketOpen(at: eastern(2024, 6, 12, 9, 30)))
    }
}

@MainActor
final class AdaptiveRefreshTests: XCTestCase {
    private func makeViewModel(_ assetClass: AssetClass) async -> ForecastViewModel {
        let entitlements = EntitlementStore()
        let vm = ForecastViewModel(
            service: TrackingMarket(),
            economicService: EmptyEconomic(),
            entitlements: entitlements
        )
        vm.assetClass = assetClass
        vm.symbol = assetClass == .crypto ? "bitcoin" : "AAPL"
        vm.run()
        try? await Task.sleep(nanoseconds: 120_000_000)
        return vm
    }

    func testCryptoUsesFastCadence() async {
        let vm = await makeViewModel(.crypto)
        XCTAssertTrue(vm.hasResult)
        XCTAssertEqual(vm.autoRefreshInterval, 30, "Crypto trades 24/7 → fast cadence")
        XCTAssertTrue(vm.isPriceLive)
    }

    func testStockCadenceMatchesMarketHours() async {
        let vm = await makeViewModel(.stock)
        XCTAssertTrue(vm.hasResult)
        let open = MarketCalendar.isUSMarketOpen()
        XCTAssertEqual(vm.autoRefreshInterval, open ? 45 : 300)
        XCTAssertEqual(vm.isPriceLive, open)
    }

    func testPriceMoveBumpsFlashTokenWithDirection() async {
        let vm = await makeViewModel(.crypto)
        XCTAssertEqual(vm.priceUpdateToken, 0, "A fresh run is not a price move")
        XCTAssertEqual(vm.priceDirection, .unchanged)

        await vm.silentRefresh() // TrackingMarket raises price each call
        XCTAssertEqual(vm.priceUpdateToken, 1)
        XCTAssertEqual(vm.priceDirection, .up)
    }
}

/// Market stub whose price rises on each call.
private actor TrackingMarket: MarketDataProviding {
    private var calls = 0
    func history(symbol: String, assetClass: AssetClass, days: Int) async throws -> PriceSeries {
        calls += 1
        let base = SampleData.series(symbol: symbol, assetClass: assetClass, days: max(days, 120))
        let factor = 1.0 + 0.03 * Double(calls)
        let points = base.points.map { PricePoint(date: $0.date, close: $0.close * factor) }
        return PriceSeries(symbol: base.symbol, assetClass: base.assetClass, points: points, isSample: base.isSample)
    }
}

private struct EmptyEconomic: EconomicDataProviding {
    func fetchSnapshots() async -> [EconomicSnapshot] { [] }
}

import XCTest
@testable import Hummingbird

final class PaperPortfolioStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "hummingbird.tests.paperPortfolio"
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Trading

    @MainActor func testBuyDeductsCashAndAddsPosition() {
        let store = PaperPortfolioStore(defaults: defaults)
        let lot = store.buy(symbol: "AAPL", assetClass: .stock, cashAmount: 2_000, price: 100, direction: .higher)
        XCTAssertNotNil(lot)
        XCTAssertEqual(store.portfolio.cash, 8_000, accuracy: 1e-6)
        XCTAssertEqual(store.portfolio.positions.count, 1)
        XCTAssertEqual(lot?.shares ?? 0, 20, accuracy: 1e-6)
        XCTAssertTrue(store.hasStarted)
    }

    @MainActor func testCannotBuyMoreThanCash() {
        let store = PaperPortfolioStore(defaults: defaults)
        XCTAssertNil(store.buy(symbol: "AAPL", assetClass: .stock, cashAmount: 20_000, price: 100, direction: .higher))
        XCTAssertEqual(store.portfolio.cash, 10_000, accuracy: 1e-6)
        XCTAssertTrue(store.portfolio.positions.isEmpty)
    }

    @MainActor func testRejectsInvalidInputs() {
        let store = PaperPortfolioStore(defaults: defaults)
        XCTAssertNil(store.buy(symbol: "  ", assetClass: .stock, cashAmount: 100, price: 100, direction: .higher))
        XCTAssertNil(store.buy(symbol: "AAPL", assetClass: .stock, cashAmount: 100, price: 0, direction: .higher))
        XCTAssertNil(store.buy(symbol: "AAPL", assetClass: .stock, cashAmount: -5, price: 100, direction: .higher))
        XCTAssertTrue(store.portfolio.positions.isEmpty)
    }

    @MainActor func testSellReturnsProceedsToCash() {
        let store = PaperPortfolioStore(defaults: defaults)
        let lot = store.buy(symbol: "AAPL", assetClass: .stock, cashAmount: 1_000, price: 100, direction: .higher)!
        XCTAssertTrue(store.sell(positionID: lot.id, price: 150))
        // cash: 9000 remaining + 10 shares * 150 = 10500
        XCTAssertEqual(store.portfolio.cash, 10_500, accuracy: 1e-6)
        XCTAssertTrue(store.portfolio.openPositions.isEmpty)
        XCTAssertFalse(store.portfolio.positions.isEmpty)   // closed lot is retained
    }

    @MainActor func testPartialSellSplitsLot() {
        let store = PaperPortfolioStore(defaults: defaults)
        let lot = store.buy(symbol: "AAPL", assetClass: .stock, cashAmount: 1_000, price: 100, direction: .higher)!
        // sell half (5 of 10 shares) at 150
        XCTAssertTrue(store.sell(positionID: lot.id, shares: 5, price: 150))
        // cash: 9000 + 5*150 = 9750
        XCTAssertEqual(store.portfolio.cash, 9_750, accuracy: 1e-6)
        // one open remainder (5 sh, same id) + one closed lot (5 sh)
        let open = store.portfolio.openPositions
        XCTAssertEqual(open.count, 1)
        XCTAssertEqual(open.first?.id, lot.id)
        XCTAssertEqual(open.first?.shares ?? 0, 5, accuracy: 1e-9)
        let closed = store.portfolio.positions.filter { !$0.isOpen }
        XCTAssertEqual(closed.count, 1)
        XCTAssertEqual(closed.first?.shares ?? 0, 5, accuracy: 1e-9)
        XCTAssertEqual(closed.first?.exitPrice, 150)
    }

    @MainActor func testCannotSellMoreThanHeld() {
        let store = PaperPortfolioStore(defaults: defaults)
        let lot = store.buy(symbol: "AAPL", assetClass: .stock, cashAmount: 1_000, price: 100, direction: .higher)!
        XCTAssertFalse(store.sell(positionID: lot.id, shares: 999, price: 150))
        XCTAssertEqual(store.portfolio.openPositions.count, 1)   // unchanged
    }

    @MainActor func testSellUnknownOrClosedIsNoOp() {
        let store = PaperPortfolioStore(defaults: defaults)
        let lot = store.buy(symbol: "AAPL", assetClass: .stock, cashAmount: 1_000, price: 100, direction: .higher)!
        XCTAssertFalse(store.sell(positionID: UUID(), price: 150))     // unknown
        XCTAssertTrue(store.sell(positionID: lot.id, price: 150))
        XCTAssertFalse(store.sell(positionID: lot.id, price: 160))     // already closed
    }

    // MARK: - Persistence & reset

    @MainActor func testPersistsAcrossInstances() {
        let first = PaperPortfolioStore(defaults: defaults)
        _ = first.buy(symbol: "AAPL", assetClass: .stock, cashAmount: 2_500, price: 100, direction: .higher)

        let second = PaperPortfolioStore(defaults: defaults)
        XCTAssertEqual(second.portfolio.positions.count, 1)
        XCTAssertEqual(second.portfolio.cash, 7_500, accuracy: 1e-6)
    }

    @MainActor func testResetStartsFreshTenThousand() {
        let store = PaperPortfolioStore(defaults: defaults)
        _ = store.buy(symbol: "AAPL", assetClass: .stock, cashAmount: 2_000, price: 100, direction: .higher)
        store.resetPortfolio()
        XCTAssertEqual(store.portfolio.cash, 10_000, accuracy: 1e-6)
        XCTAssertTrue(store.portfolio.positions.isEmpty)
        XCTAssertTrue(store.latestPrices.isEmpty)
    }

    // MARK: - Revaluation (EOD only, throttled, capped)

    @MainActor func testRevalueFetchesClosesForHeldAssets() async {
        let store = PaperPortfolioStore(defaults: defaults)
        _ = store.buy(symbol: "AAPL", assetClass: .stock, cashAmount: 1_000, price: 100, direction: .higher)
        let stub = PriceStub(["aapl": 130])
        await store.revalueDue(using: stub, now: t0)
        XCTAssertEqual(store.latestPrices["Stock:aapl"], 130)
        // report values the open lot at the fresh close: cash 9000 + 10sh*130
        XCTAssertEqual(store.report.value, 9_000 + 1_300, accuracy: 1e-6)
    }

    @MainActor func testRevalueIsThrottled() async {
        let store = PaperPortfolioStore(defaults: defaults)
        _ = store.buy(symbol: "AAPL", assetClass: .stock, cashAmount: 1_000, price: 100, direction: .higher)
        let stub = PriceStub(["aapl": 130])
        await store.revalueDue(using: stub, now: t0)
        await store.revalueDue(using: stub, now: t0.addingTimeInterval(60))     // within 10-min throttle
        var count = await stub.count()
        XCTAssertEqual(count, 1)
        await store.revalueDue(using: stub, now: t0.addingTimeInterval(700))    // past throttle
        count = await stub.count()
        XCTAssertEqual(count, 2)
    }

    @MainActor func testRevalueForceBypassesThrottle() async {
        let store = PaperPortfolioStore(defaults: defaults)
        _ = store.buy(symbol: "AAPL", assetClass: .stock, cashAmount: 1_000, price: 100, direction: .higher)
        let stub = PriceStub(["aapl": 130])
        await store.revalueDue(using: stub, now: t0)
        await store.revalueDue(using: stub, now: t0.addingTimeInterval(1), force: true)
        let count = await stub.count()
        XCTAssertEqual(count, 2)
    }

    @MainActor func testRevalueIsCappedPerPass() async {
        let store = PaperPortfolioStore(defaults: defaults)
        _ = store.buy(symbol: "AAA", assetClass: .stock, cashAmount: 1_000, price: 100, direction: .higher)
        _ = store.buy(symbol: "BBB", assetClass: .stock, cashAmount: 1_000, price: 100, direction: .higher)
        _ = store.buy(symbol: "CCC", assetClass: .stock, cashAmount: 1_000, price: 100, direction: .higher)
        let stub = PriceStub(["aaa": 110, "bbb": 110, "ccc": 110])
        await store.revalueDue(using: stub, now: t0, maxAssets: 2)
        let count = await stub.count()
        XCTAssertEqual(count, 2)               // capped
        XCTAssertEqual(store.latestPrices.count, 2)
    }

    // Regression: after a day-one pick is SOLD it has no open lot, but the
    // buy-and-hold benchmark still holds it — so revalueDue must fetch its
    // current price. Missing this valued sold day-one picks at cost and computed
    // the headline comparison wrong.
    @MainActor func testRevaluePricesSoldDayOnePicksForBenchmark() async {
        let store = PaperPortfolioStore(defaults: defaults)
        let lot = store.buy(symbol: "AAPL", assetClass: .stock, cashAmount: 5_000, price: 100,
                            direction: .higher, now: t0)!
        XCTAssertTrue(store.sell(positionID: lot.id, price: 110, now: t0))   // now no open lots
        XCTAssertTrue(store.portfolio.openPositions.isEmpty)

        let stub = PriceStub(["aapl": 130])
        await store.revalueDue(using: stub, now: t0)
        XCTAssertEqual(store.latestPrices["Stock:aapl"], 130)               // fetched despite no open lot

        // hold benchmark: 50 sh * 130 + residual cash 5000 = 11500
        XCTAssertEqual(store.report.comparison.holdValue, 11_500, accuracy: 1e-6)
        // you: cash 5000 (kept) + 5000 (sale proceeds 50*110) = 10500 → lagging hold
        XCTAssertEqual(store.report.comparison.yourValue, 10_500, accuracy: 1e-6)
        XCTAssertFalse(store.report.comparison.isBeatingHold)
    }

    @MainActor func testRevalueIgnoresSampleData() async {
        let store = PaperPortfolioStore(defaults: defaults)
        _ = store.buy(symbol: "AAPL", assetClass: .stock, cashAmount: 1_000, price: 100, direction: .higher)
        let stub = PriceStub(["aapl": 130], isSample: true)   // synthetic fallback
        await store.revalueDue(using: stub, now: t0)
        XCTAssertTrue(store.latestPrices.isEmpty)              // never cache fake prices
    }
}

/// Counts fetches so throttle/cap behavior can be asserted. Returns a one-point
/// series at the configured close per symbol.
private actor PriceStub: MarketDataProviding {
    private let prices: [String: Double]
    private let isSample: Bool
    private var fetchCount = 0

    init(_ prices: [String: Double], isSample: Bool = false) {
        self.prices = prices
        self.isSample = isSample
    }

    func history(symbol: String, assetClass: AssetClass, days: Int) async throws -> PriceSeries {
        fetchCount += 1
        let close = prices[symbol.lowercased()] ?? 100
        return PriceSeries(symbol: symbol, assetClass: assetClass,
                           points: [PricePoint(date: Date(), close: close)], isSample: isSample)
    }

    func count() -> Int { fetchCount }
}

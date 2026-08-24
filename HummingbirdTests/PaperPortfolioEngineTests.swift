import XCTest
@testable import Hummingbird

final class PaperPortfolioEngineTests: XCTestCase {
    private let cal = Calendar(identifier: .gregorian)
    private let day1 = Date(timeIntervalSince1970: 1_700_000_000)  // a Wednesday
    private var day3: Date { cal.date(byAdding: .day, value: 2, to: day1)! }

    private func position(_ symbol: String, entry: Double, shares: Double,
                          opened: Date, reason: CallReason? = nil,
                          exit: Double? = nil, closed: Date? = nil,
                          direction: CallDirection = .higher) -> PaperPosition {
        PaperPosition(id: UUID(), symbol: symbol, assetClass: .stock, openedAt: opened,
                      entryPrice: entry, shares: shares, direction: direction,
                      reason: reason, closedAt: closed, exitPrice: exit)
    }

    private func portfolio(cash: Double, _ positions: [PaperPosition]) -> PaperPortfolio {
        var p = PaperPortfolio(createdAt: day1)
        p.cash = cash
        p.positions = positions
        return p
    }

    // Nothing bought yet → all cash, benchmark == cash, no edge.
    func testEmptyPortfolioValuesAtStartingCash() {
        let p = PaperPortfolio(createdAt: day1)   // $10k, no positions
        let c = PaperPortfolioEngine.comparison(p, prices: [:], calendar: cal)
        XCTAssertEqual(c.yourValue, 10_000, accuracy: 1e-6)
        XCTAssertEqual(c.holdValue, 10_000, accuracy: 1e-6)
        XCTAssertEqual(c.edge, 0, accuracy: 1e-9)
        XCTAssertEqual(c.tradeCount, 0)
    }

    // Bought $10k of AAPL @100 on day one, never traded, price now 120.
    // You == buy-and-hold, edge 0, zero turnover.
    func testNeverTradedEqualsBuyAndHold() {
        let p = portfolio(cash: 0, [position("AAPL", entry: 100, shares: 100, opened: day1)])
        let prices = ["Stock:aapl": 120.0]
        let c = PaperPortfolioEngine.comparison(p, prices: prices, calendar: cal)
        XCTAssertEqual(c.yourValue, 12_000, accuracy: 1e-6)
        XCTAssertEqual(c.holdValue, 12_000, accuracy: 1e-6)
        XCTAssertEqual(c.edge, 0, accuracy: 1e-9)
        XCTAssertEqual(c.tradeCount, 0)
        XCTAssertFalse(c.isBeatingHold)   // tie is not "beating"
    }

    // Sold your day-one pick, then it kept rising: you sat in cash and LAGGED
    // buy-and-hold. This is the core lesson the feature must be able to show.
    func testSellingThenMissingTheRallyLagsBuyAndHold() {
        // Bought @100, sold @110 (closed), price now 130.
        let sold = position("AAPL", entry: 100, shares: 100, opened: day1,
                            exit: 110, closed: day3)
        let p = portfolio(cash: 11_000, [sold])   // proceeds 100*110 in cash, no open lots
        let prices = ["Stock:aapl": 130.0]
        let c = PaperPortfolioEngine.comparison(p, prices: prices, calendar: cal)
        XCTAssertEqual(c.yourValue, 11_000, accuracy: 1e-6)      // all cash
        XCTAssertEqual(c.holdValue, 13_000, accuracy: 1e-6)      // 100 sh * 130
        XCTAssertLessThan(c.edge, 0)
        XCTAssertFalse(c.isBeatingHold)
        XCTAssertEqual(c.tradeCount, 1)                          // one sell
    }

    // Sold high before a fall: your trading BEAT buy-and-hold.
    func testSellingHighBeforeAFallBeatsBuyAndHold() {
        let sold = position("AAPL", entry: 100, shares: 100, opened: day1,
                            exit: 120, closed: day3)
        let p = portfolio(cash: 12_000, [sold])
        let prices = ["Stock:aapl": 90.0]   // fell after you sold
        let c = PaperPortfolioEngine.comparison(p, prices: prices, calendar: cal)
        XCTAssertEqual(c.yourValue, 12_000, accuracy: 1e-6)   // cash
        XCTAssertEqual(c.holdValue, 9_000, accuracy: 1e-6)    // 100 sh * 90
        XCTAssertGreaterThan(c.edge, 0)
        XCTAssertTrue(c.isBeatingHold)
        XCTAssertEqual(c.tradeCount, 1)
    }

    // A later buy (day 3) is turnover, and is NOT part of the frozen day-one
    // benchmark.
    func testLaterBuyIsTurnoverAndExcludedFromBenchmark() {
        let dayOne = position("AAPL", entry: 100, shares: 50, opened: day1)   // $5k
        let later  = position("MSFT", entry: 200, shares: 25, opened: day3)   // $5k on day 3
        let p = portfolio(cash: 0, [dayOne, later])
        let prices = ["Stock:aapl": 110.0, "Stock:msft": 260.0]
        let c = PaperPortfolioEngine.comparison(p, prices: prices, calendar: cal)
        // You: 50*110 + 25*260 = 5500 + 6500 = 12000
        XCTAssertEqual(c.yourValue, 12_000, accuracy: 1e-6)
        // Hold benchmark: only day-one AAPL (50*110) + residual cash (10000-5000)
        XCTAssertEqual(c.holdValue, 5_500 + 5_000, accuracy: 1e-6)
        XCTAssertEqual(c.tradeCount, 1)   // the later buy
        XCTAssertTrue(c.isBeatingHold)
    }

    // An unpriced holding is valued at cost — no fabricated P/L.
    func testUnpricedHoldingFallsBackToEntryPrice() {
        let p = portfolio(cash: 0, [position("AAPL", entry: 100, shares: 100, opened: day1)])
        let c = PaperPortfolioEngine.comparison(p, prices: [:], calendar: cal)
        XCTAssertEqual(c.yourValue, 10_000, accuracy: 1e-6)
        XCTAssertEqual(c.holdValue, 10_000, accuracy: 1e-6)
    }

    // Report surfaces value + the buy-and-hold comparison (reason calibration is
    // deliberately kept on calls, not the portfolio).
    func testReportSurfacesValueAndComparison() {
        let p = portfolio(cash: 0, [position("AAPL", entry: 100, shares: 100, opened: day1)])
        let report = PaperPortfolioEngine.report(p, prices: ["Stock:aapl": 120], calendar: cal)
        XCTAssertEqual(report.value, 12_000, accuracy: 1e-6)
        XCTAssertEqual(report.openPositionCount, 1)
        XCTAssertEqual(report.comparison.holdValue, 12_000, accuracy: 1e-6)
    }
}

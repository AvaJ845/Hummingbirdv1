import XCTest
@testable import Hummingbird

final class PaperPortfolioEngineTests: XCTestCase {
    private let cal = Calendar(identifier: .gregorian)
    private let day1 = Date(timeIntervalSince1970: 1_700_000_000)  // a Wednesday
    private var day3: Date { cal.date(byAdding: .day, value: 2, to: day1)! }

    private func position(_ symbol: String, entry: Double, shares: Double,
                          opened: Date, reason: CallReason? = nil,
                          exit: Double? = nil, closed: Date? = nil,
                          direction: CallDirection = .higher,
                          methodDirections: [String: CallDirection]? = nil) -> PaperPosition {
        PaperPosition(id: UUID(), symbol: symbol, assetClass: .stock, openedAt: opened,
                      entryPrice: entry, shares: shares, direction: direction,
                      reason: reason, closedAt: closed, exitPrice: exit,
                      methodDirections: methodDirections)
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

    // MARK: - Value series (the You-vs-hold chart)

    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c
    }

    private func aaplHistory(_ closes: [(Date, Double)]) -> [String: PriceSeries] {
        let pts = closes.map { PricePoint(date: $0.0, close: $0.1) }
        return ["Stock:aapl": PriceSeries(symbol: "AAPL", assetClass: .stock, points: pts, isSample: false)]
    }

    func testValueSeriesEmptyWhenNothingBought() {
        XCTAssertTrue(PaperPortfolioEngine.valueSeries(PaperPortfolio(createdAt: day1),
                                                       histories: [:], calendar: utc).isEmpty)
    }

    // Never traded → your line and the buy-and-hold line are identical at every
    // sample (you ARE holding your first picks).
    func testValueSeriesNeverTradedTracksHold() {
        let d0 = utc.startOfDay(for: day1)
        let d1 = d0.addingTimeInterval(86_400), d2 = d0.addingTimeInterval(2 * 86_400)
        let hist = aaplHistory([(d0, 100), (d1, 110), (d2, 120)])
        let p = portfolio(cash: 5_000, [position("AAPL", entry: 100, shares: 50, opened: d0)])

        let pts = PaperPortfolioEngine.valueSeries(p, histories: hist, now: d2, calendar: utc)
        XCTAssertEqual(pts.count, 3)
        for pt in pts { XCTAssertEqual(pt.you, pt.hold, accuracy: 1e-6) }
        XCTAssertEqual(pts.last?.you ?? 0, 11_000, accuracy: 1e-6)   // 5000 cash + 50*120
    }

    // Sold the day-one pick on day 1, then it kept rising: your line flattens in
    // cash while the hold line climbs — the divergence the chart exists to show.
    func testValueSeriesSellingThenRallyDivergesFromHold() {
        let d0 = utc.startOfDay(for: day1)
        let d1 = d0.addingTimeInterval(86_400), d2 = d0.addingTimeInterval(2 * 86_400)
        let hist = aaplHistory([(d0, 100), (d1, 110), (d2, 120)])
        let sold = position("AAPL", entry: 100, shares: 50, opened: d0, exit: 110, closed: d1)
        let p = portfolio(cash: 5_000 + 50 * 110, [sold])   // proceeds already in cash

        let pts = PaperPortfolioEngine.valueSeries(p, histories: hist, now: d2, calendar: utc)
        // hold ignores the sale: 5000 residual + 50 * close
        XCTAssertEqual(pts.first?.hold ?? 0, 10_000, accuracy: 1e-6)  // d0: 5000 + 50*100
        XCTAssertEqual(pts.last?.hold ?? 0, 11_000, accuracy: 1e-6)   // d2: 5000 + 50*120
        // you: sat in cash after selling at 110 → 5000 + 5500 = 10500, flat by d2
        XCTAssertEqual(pts.last?.you ?? 0, 10_500, accuracy: 1e-6)
        XCTAssertLessThan(pts.last!.you, pts.last!.hold)             // lagging buy-and-hold
    }

    // Market line: startingCash into the S&P on day one, held.
    func testValueSeriesMarketLine() {
        let d0 = utc.startOfDay(for: day1)
        let d1 = d0.addingTimeInterval(86_400), d2 = d0.addingTimeInterval(2 * 86_400)
        var hist = aaplHistory([(d0, 100), (d1, 110), (d2, 120)])
        hist["Stock:spy"] = PriceSeries(symbol: "SPY", assetClass: .stock,
            points: [PricePoint(date: d0, close: 400), PricePoint(date: d1, close: 420), PricePoint(date: d2, close: 440)],
            isSample: false)
        let p = portfolio(cash: 5_000, [position("AAPL", entry: 100, shares: 50, opened: d0)])

        let pts = PaperPortfolioEngine.valueSeries(p, histories: hist, now: d2, calendar: utc)
        XCTAssertEqual(pts.first?.market ?? 0, 10_000, accuracy: 1e-6)   // 10000 * 400/400
        XCTAssertEqual(pts.last?.market ?? 0, 11_000, accuracy: 1e-6)    // 10000 * 440/400
    }

    func testValueSeriesMarketNilWithoutSpy() {
        let d0 = utc.startOfDay(for: day1); let d2 = d0.addingTimeInterval(2 * 86_400)
        let hist = aaplHistory([(d0, 100), (d2, 120)])
        let p = portfolio(cash: 5_000, [position("AAPL", entry: 100, shares: 50, opened: d0)])
        XCTAssertNil(PaperPortfolioEngine.valueSeries(p, histories: hist, now: d2, calendar: utc).last?.market)
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

    // MARK: - Lean scoring

    func testLeanWasRightAcrossCases() {
        // higher lean, sold higher -> right
        XCTAssertEqual(position("A", entry: 100, shares: 1, opened: day1, exit: 120, closed: day3,
                                direction: .higher).leanWasRight, true)
        // higher lean, sold lower -> wrong
        XCTAssertEqual(position("A", entry: 100, shares: 1, opened: day1, exit: 90, closed: day3,
                                direction: .higher).leanWasRight, false)
        // lower lean, sold lower -> right
        XCTAssertEqual(position("A", entry: 100, shares: 1, opened: day1, exit: 90, closed: day3,
                                direction: .lower).leanWasRight, true)
        // flat exit -> push (nil)
        XCTAssertNil(position("A", entry: 100, shares: 1, opened: day1, exit: 100, closed: day3,
                              direction: .higher).leanWasRight)
        // still open -> nil
        XCTAssertNil(position("A", entry: 100, shares: 1, opened: day1, direction: .higher).leanWasRight)
    }

    func testReportLeanAccuracyOverClosedLots() {
        let p = portfolio(cash: 0, [
            position("A", entry: 100, shares: 1, opened: day1, exit: 120, closed: day3, direction: .higher), // right
            position("B", entry: 100, shares: 1, opened: day1, exit: 90,  closed: day3, direction: .higher), // wrong
            position("C", entry: 100, shares: 1, opened: day1, exit: 80,  closed: day3, direction: .lower),  // right
            position("D", entry: 100, shares: 1, opened: day1, exit: 100, closed: day3, direction: .higher), // push (excluded)
            position("E", entry: 100, shares: 1, opened: day1, direction: .higher),                           // open (excluded)
        ])
        let report = PaperPortfolioEngine.report(p, prices: [:], calendar: cal)
        XCTAssertEqual(report.leanAccuracy.decided, 3)   // pushes + open excluded
        XCTAssertEqual(report.leanAccuracy.correct, 2)
        XCTAssertEqual(report.leanAccuracy.hitRate ?? 0, 2.0/3.0, accuracy: 1e-9)
    }

    // MARK: - Concentration (diversification meter)

    func testConcentrationNilWithNoOpenPositions() {
        XCTAssertNil(PaperPortfolioEngine.concentration(PaperPortfolio(createdAt: day1), prices: [:]))
        // an all-closed portfolio also has nothing open to measure
        let closedOnly = portfolio(cash: 0, [position("A", entry: 100, shares: 1, opened: day1, exit: 110, closed: day3)])
        XCTAssertNil(PaperPortfolioEngine.concentration(closedOnly, prices: [:]))
    }

    func testConcentrationSingleAssetIsFullyConcentrated() {
        let p = portfolio(cash: 0, [position("AAPL", entry: 100, shares: 100, opened: day1)])
        let c = PaperPortfolioEngine.concentration(p, prices: ["Stock:aapl": 120])
        XCTAssertEqual(c?.topSymbol, "AAPL")
        XCTAssertEqual(c?.topFraction ?? 0, 1.0, accuracy: 1e-9)
        XCTAssertEqual(c?.assetCount, 1)
    }

    func testConcentrationSplitsAcrossDistinctSymbols() {
        // 8000 in AAPL, 2000 in MSFT -> 80/20, AAPL is the top.
        let p = portfolio(cash: 0, [
            position("AAPL", entry: 100, shares: 80, opened: day1),
            position("MSFT", entry: 100, shares: 20, opened: day1),
        ])
        let c = PaperPortfolioEngine.concentration(p, prices: ["Stock:aapl": 100, "Stock:msft": 100])
        XCTAssertEqual(c?.topSymbol, "AAPL")
        XCTAssertEqual(c?.topFraction ?? 0, 0.8, accuracy: 1e-9)
        XCTAssertEqual(c?.assetCount, 2)
    }

    // A partial sell splits one symbol into two lots (see PaperPortfolioStoreTests
    // testPartialSellSplitsLot) — concentration must still count that as ONE asset.
    func testConcentrationGroupsMultipleLotsOfSameSymbolAsOneAsset() {
        let p = portfolio(cash: 0, [
            position("AAPL", entry: 100, shares: 30, opened: day1),
            position("AAPL", entry: 100, shares: 20, opened: day1),   // remainder of a partial sell
            position("MSFT", entry: 100, shares: 50, opened: day1),
        ])
        let c = PaperPortfolioEngine.concentration(p, prices: ["Stock:aapl": 100, "Stock:msft": 100])
        XCTAssertEqual(c?.assetCount, 2)          // AAPL counted once despite two lots
        XCTAssertEqual(c?.topFraction ?? 0, 0.5, accuracy: 1e-9)   // 50/50 once merged
    }

    // MARK: - Per-holding volatility regime

    func testRegimeNilWithoutHistory() {
        let pos = position("AAPL", entry: 100, shares: 1, opened: day1)
        XCTAssertNil(PaperPortfolioEngine.regime(for: pos, histories: [:]))
    }

    func testRegimeClassifiesFromTheHoldingsOwnHistory() {
        // Calm: flat closes throughout.
        let calmCloses = (0..<30).map { i in
            PricePoint(date: day1.addingTimeInterval(TimeInterval(i) * 86_400), close: 100)
        }
        let hist = ["Stock:aapl": PriceSeries(symbol: "AAPL", assetClass: .stock, points: calmCloses, isSample: false)]
        let pos = position("AAPL", entry: 100, shares: 1, opened: day1)
        XCTAssertEqual(PaperPortfolioEngine.regime(for: pos, histories: hist), .calm)
    }

    // MARK: - Dollar-cost-average comparison

    func testDCANilWhenNothingBought() {
        XCTAssertNil(PaperPortfolioEngine.dollarCostAverageValue(PaperPortfolio(createdAt: day1), histories: [:]))
    }

    func testDCANilWhenOnlyOnePossibleInterval() {
        // "today" is the same day as the first buy -> only one possible interval,
        // DCA and lump sum would be identical, so there's nothing to compare.
        let d0 = utc.startOfDay(for: day1)
        let hist = aaplHistory([(d0, 100)])
        let p = portfolio(cash: 0, [position("AAPL", entry: 100, shares: 100, opened: d0)])
        XCTAssertNil(PaperPortfolioEngine.dollarCostAverageValue(p, histories: hist, now: d0, calendar: utc))
    }

    // A steadily RISING market: buying gradually means paying higher prices for
    // the later chunks, so DCA should end up with FEWER shares (lower value)
    // than the lump sum that bought everything on day one at the low price.
    func testDCAUnderperformsLumpSumInARisingMarket() {
        let d0 = utc.startOfDay(for: day1)
        let closes = (0...28).map { i in (d0.addingTimeInterval(TimeInterval(i) * 86_400), 100.0 + Double(i)) }
        let hist = aaplHistory(closes)
        let p = portfolio(cash: 0, [position("AAPL", entry: 100, shares: 100, opened: d0)])   // $10,000 lump sum
        let today = d0.addingTimeInterval(28 * 86_400)

        let lumpSum = PaperPortfolioEngine.buyAndHoldValue(p, prices: ["Stock:aapl": 128], calendar: utc)
        let dca = PaperPortfolioEngine.dollarCostAverageValue(p, histories: hist, intervalDays: 7, now: today, calendar: utc)
        XCTAssertNotNil(dca)
        XCTAssertLessThan(dca!, lumpSum)
    }

    // A market that DIPS then fully RECOVERS to the same final price: DCA buys
    // extra shares cheaply during the dip, so it should end up AHEAD of the lump
    // sum even though both start and end at the identical price.
    func testDCACanBeatLumpSumThroughADipAndRecovery() {
        let d0 = utc.startOfDay(for: day1)
        // day 0: 100, day 7: 60 (dip), day 14: 100 (recovered) — flat overall.
        let closes: [(Date, Double)] = [
            (d0, 100), (d0.addingTimeInterval(7 * 86_400), 60), (d0.addingTimeInterval(14 * 86_400), 100),
        ]
        let hist = aaplHistory(closes)
        let p = portfolio(cash: 0, [position("AAPL", entry: 100, shares: 100, opened: d0)])
        let today = d0.addingTimeInterval(14 * 86_400)

        let lumpSum = PaperPortfolioEngine.buyAndHoldValue(p, prices: ["Stock:aapl": 100], calendar: utc)
        XCTAssertEqual(lumpSum, 10_000, accuracy: 1e-6)   // flat round-trip: unchanged
        let dca = PaperPortfolioEngine.dollarCostAverageValue(p, histories: hist, intervalDays: 7, now: today, calendar: utc)
        XCTAssertNotNil(dca)
        XCTAssertGreaterThan(dca!, lumpSum)   // the dip-bought shares are pure upside
    }

    // Residual (never-invested) cash must still be included, matching buyAndHoldValue.
    func testDCAIncludesResidualCash() {
        let d0 = utc.startOfDay(for: day1)
        let hist = aaplHistory([(d0, 100), (d0.addingTimeInterval(7 * 86_400), 100)])
        // Helper defaults startingCash to $10,000; $5,000 of it went into AAPL,
        // leaving $5,000 residual — matches buyAndHoldValue's own residual math.
        let p = portfolio(cash: 5_000, [position("AAPL", entry: 100, shares: 50, opened: d0)])
        let today = d0.addingTimeInterval(7 * 86_400)
        let dca = PaperPortfolioEngine.dollarCostAverageValue(p, histories: hist, intervalDays: 7, now: today, calendar: utc)
        XCTAssertEqual(dca ?? 0, 10_000, accuracy: 1e-6)   // flat price, so DCA == lump sum == starting cash
    }

    // MARK: - Method-direction scoring ("portfolio vs. the methods")

    func testMethodWasCorrectAcrossCases() {
        // drift called Higher, exit was higher -> right
        XCTAssertEqual(position("A", entry: 100, shares: 1, opened: day1, exit: 120, closed: day3,
                                methodDirections: ["drift": .higher]).methodWasCorrect("drift"), true)
        // drift called Higher, exit was lower -> wrong
        XCTAssertEqual(position("A", entry: 100, shares: 1, opened: day1, exit: 90, closed: day3,
                                methodDirections: ["drift": .higher]).methodWasCorrect("drift"), false)
        // method never snapshotted -> nil
        XCTAssertNil(position("A", entry: 100, shares: 1, opened: day1, exit: 120, closed: day3,
                              methodDirections: ["drift": .higher]).methodWasCorrect("holt"))
        // still open -> nil
        XCTAssertNil(position("A", entry: 100, shares: 1, opened: day1,
                              methodDirections: ["drift": .higher]).methodWasCorrect("drift"))
        // flat exit (push) -> nil
        XCTAssertNil(position("A", entry: 100, shares: 1, opened: day1, exit: 100, closed: day3,
                              methodDirections: ["drift": .higher]).methodWasCorrect("drift"))
    }

    func testVsMethodsNilBelowMinResolved() {
        let closed = (0..<4).map { _ in
            position("A", entry: 100, shares: 1, opened: day1, exit: 110, closed: day3,
                    methodDirections: ["drift": .higher])
        }
        let p = portfolio(cash: 0, closed)
        XCTAssertNil(PaperPortfolioEngine.vsMethods(p, minResolved: 5))
    }

    func testVsMethodsExcludesPositionsWithoutASnapshot() {
        var positions = (0..<5).map { _ in
            position("A", entry: 100, shares: 1, opened: day1, exit: 110, closed: day3,
                    methodDirections: ["drift": .higher])
        }
        // A closed, decidable position with no method snapshot at all — must not count.
        positions.append(position("B", entry: 100, shares: 1, opened: day1, exit: 90, closed: day3))
        let p = portfolio(cash: 0, positions)
        let vs = PaperPortfolioEngine.vsMethods(p, minResolved: 5)
        XCTAssertEqual(vs?.userDecided, 5)
    }

    func testVsMethodsComputesHitRatesAndRanksBestFirst() {
        // 5 positions, all leaned Higher, all closed higher (user 100% right).
        // "drift" always said Higher (right, 100%). "holt" always said Lower (wrong, 0%).
        let positions = (0..<5).map { _ in
            position("A", entry: 100, shares: 1, opened: day1, exit: 110, closed: day3,
                    methodDirections: ["drift": .higher, "holt": .lower])
        }
        let p = portfolio(cash: 0, positions)
        let vs = PaperPortfolioEngine.vsMethods(p, minResolved: 5)
        XCTAssertNotNil(vs)
        XCTAssertEqual(vs?.userHitRate ?? 0, 1.0, accuracy: 1e-9)
        XCTAssertEqual(vs?.userDecided, 5)
        XCTAssertEqual(vs?.methods.count, 2)
        // Best hit rate sorts first.
        XCTAssertEqual(vs?.methods.first?.methodId, "drift")
        XCTAssertEqual(vs?.methods.first?.hitRate ?? 0, 1.0, accuracy: 1e-9)
        XCTAssertEqual(vs?.methods.last?.methodId, "holt")
        XCTAssertEqual(vs?.methods.last?.hitRate ?? 0, 0.0, accuracy: 1e-9)
        // methodsBeaten requires STRICTLY higher — tied with drift at 100%
        // doesn't count as beating it, only holt (0%) does.
        XCTAssertEqual(vs?.methodsBeaten, 1)
    }

    // A missing history for one day-one symbol (a data gap) must fall back to
    // its entry price — same convention as valueSeries/buyAndHoldValue — never
    // silently drop that position's value to zero.
    func testDCAFallsBackToEntryPriceOnMissingHistory() {
        let d0 = utc.startOfDay(for: day1)
        // AAPL has full history; MSFT has none in `histories` at all.
        let hist = aaplHistory([(d0, 100), (d0.addingTimeInterval(7 * 86_400), 100)])
        let p = portfolio(cash: 0, [
            position("AAPL", entry: 100, shares: 50, opened: d0),
            position("MSFT", entry: 200, shares: 25, opened: d0),
        ])
        let today = d0.addingTimeInterval(7 * 86_400)
        let dca = PaperPortfolioEngine.dollarCostAverageValue(p, histories: hist, intervalDays: 7, now: today, calendar: utc)
        // AAPL flat at 100 -> unchanged $5,000. MSFT has no data -> falls back
        // to its $5,000 entry cost rather than vanishing. Total: $10,000.
        XCTAssertEqual(dca ?? 0, 10_000, accuracy: 1e-6)
    }
}

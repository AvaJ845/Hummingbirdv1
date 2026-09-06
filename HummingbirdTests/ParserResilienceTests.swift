import XCTest
@testable import Hummingbird

/// Malformed / hostile API-response fuzz for every parsing + sanitising layer.
/// The bar: **never crash, never force-unwrap into a trap**, and return either
/// nil / empty / a filtered-but-valid series. Degenerate input must not be
/// `isForecastable`.
final class ParserResilienceTests: XCTestCase {

    // MARK: - Fixtures

    private func data(_ s: String) -> Data { Data(s.utf8) }

    private let garbageBodies: [String] = [
        "",
        "   ",
        "{}",
        "[]",
        "null",
        "\"a string\"",
        "12345",
        "<html><body>500 Internal Server Error</body></html>",
        "{ \"chart\": ",                                   // truncated JSON
        "{ \"chart\": { \"result\": [} }",                 // broken JSON
        "{ \"unexpected\": { \"nested\": true } }",        // missing keys
        "{ \"chart\": { \"result\": [] } }",               // empty result
        "{ \"chart\": { \"result\": null } }",             // null result
        "{ \"chart\": { \"result\": [{ \"timestamp\": [1,2,3], \"indicators\": { \"quote\": [] } }] } }",
        "{ \"chart\": { \"result\": [{ \"timestamp\": \"nope\", \"indicators\": { \"quote\": [{ \"close\": [1,2] }] } }] } }",
        "{ \"chart\": { \"result\": [{ \"timestamp\": [1], \"indicators\": { \"quote\": [{ \"close\": [\"x\",\"y\"] }] } }] } }",
        "{ \"prices\": \"not-an-array\" }",
        "{ \"prices\": [[1]] }",                           // wrong arity
        "{ \"prices\": [[1, null]] }",
    ]

    // MARK: - StockPriceParsing.parseYahooChart

    func testYahooChartNeverCrashesOnGarbage() {
        for body in garbageBodies {
            // Must throw a typed MarketDataError, never trap.
            XCTAssertThrowsError(try StockPriceParsing.parseYahooChart(data(body), ticker: "AAPL", days: 30)) { error in
                XCTAssertTrue(error is MarketDataError, "unexpected \(error) for body: \(body.prefix(40))")
            }
        }
    }

    func testYahooChartSingleValidPoint() throws {
        let json = "{ \"chart\": { \"result\": [{ \"timestamp\": [1704153600], \"indicators\": { \"quote\": [{ \"close\": [185.5] }] } }] } }"
        let series = try StockPriceParsing.parseYahooChart(data(json), ticker: "AAPL", days: 30)
        XCTAssertEqual(series.points.count, 1)
        XCTAssertFalse(series.isForecastable, "a one-point series is not forecastable")
    }

    func testYahooChartFiltersNonPositiveAndNull() throws {
        let json = """
        { "chart": { "result": [{
          "timestamp": [1,2,3,4,5],
          "indicators": { "quote": [{ "close": [-10.0, 0.0, null, 100.0, 101.0] }] } }] } }
        """
        let series = try StockPriceParsing.parseYahooChart(data(json), ticker: "AAPL", days: 30)
        XCTAssertEqual(series.points.count, 2, "negative, zero and null closes are dropped")
        XCTAssertTrue(series.points.allSatisfy { $0.close.isFinite && $0.close > 0 })
    }

    func testYahooChartOutOfOrderAndDuplicateTimestamps() throws {
        let json = """
        { "chart": { "result": [{
          "timestamp": [1704326400, 1704153600, 1704240000, 1704240000, 0],
          "indicators": { "quote": [{ "close": [3.0, 1.0, 2.0, 2.0, 9.0] }] } }] } }
        """
        let series = try StockPriceParsing.parseYahooChart(data(json), ticker: "AAPL", days: 30)
        // Sorted ascending by date defensively.
        XCTAssertEqual(series.points.map(\.date), series.points.map(\.date).sorted())
    }

    func testYahooChartHugeInputCompletesQuickly() throws {
        let n = 100_000
        let ts = (0..<n).map { String(1_600_000_000 + $0 * 86_400) }.joined(separator: ",")
        let closes = (0..<n).map { _ in "100.0" }.joined(separator: ",")
        let json = "{ \"chart\": { \"result\": [{ \"timestamp\": [\(ts)], \"indicators\": { \"quote\": [{ \"close\": [\(closes)] }] } }] } }"
        let started = Date()
        let series = try StockPriceParsing.parseYahooChart(data(json), ticker: "AAPL", days: 400)
        XCTAssertLessThan(Date().timeIntervalSince(started), 3.0)
        XCTAssertLessThanOrEqual(series.points.count, 400, "trimmed to the requested window")
    }

    // MARK: - EconomicParsing.parseYahooPercent

    func testEconomicParsingNeverCrashesOnGarbage() {
        for body in garbageBodies {
            XCTAssertThrowsError(try EconomicParsing.parseYahooPercent(data(body), kind: .treasury10Y)) { error in
                XCTAssertTrue(error is MarketDataError || error is DecodingError, "unexpected \(error)")
            }
        }
    }

    func testEconomicParsingFiltersHugeAndNonPositive() throws {
        let json = """
        { "chart": { "result": [{
          "timestamp": [1,2,3,4],
          "indicators": { "quote": [{ "close": [-1.0, 0.0, 1000000000.0, 4.25] }] } }] } }
        """
        let snap = try EconomicParsing.parseYahooPercent(data(json), kind: .treasury10Y)
        XCTAssertTrue(snap.value.isFinite && snap.value > 0)
        XCTAssertEqual(snap.value, 4.25, accuracy: 0.0001, "1e9 rate is nonsense and is filtered")
    }

    func testEconomicParsingSinglePoint() throws {
        let json = "{ \"chart\": { \"result\": [{ \"timestamp\": [1704153600], \"indicators\": { \"quote\": [{ \"close\": [4.25] }] } }] } }"
        let snap = try EconomicParsing.parseYahooPercent(data(json), kind: .fedFunds)
        XCTAssertEqual(snap.value, 4.25, accuracy: 0.0001)
        XCTAssertNil(snap.previousValue, "no previous point to compare against")
    }

    // MARK: - PriceSanitizer.clean

    private func series(_ closes: [Double], sample: Bool = false) -> PriceSeries {
        let base = Date(timeIntervalSince1970: 1_600_000_000)
        let points = closes.enumerated().map {
            PricePoint(date: base.addingTimeInterval(Double($0.offset) * 86_400), close: $0.element)
        }
        return PriceSeries(symbol: "TEST", assetClass: .stock, points: points, isSample: sample)
    }

    func testSanitizerDropsNonFiniteAndNonPositive() {
        // NaN, ±Inf, negative, zero, and an absurd (≥1e12) close are all dropped;
        // only 100/101/102/103/104 survive.
        let dirty = series([100, .nan, 101, .infinity, -5, 0, 102, -.infinity, 103, Double.greatestFiniteMagnitude, 104])
        let cleaned = PriceSanitizer.clean(dirty)
        XCTAssertEqual(cleaned.points.count, 5, "only the 5 finite, positive, in-range closes survive")
        XCTAssertEqual(cleaned.points.map(\.close), [100, 101, 102, 103, 104])
        XCTAssertTrue(cleaned.points.allSatisfy { $0.close.isFinite && $0.close > 0 && $0.close < 1e12 })
    }

    func testSanitizerEmptyAndSinglePoint() {
        XCTAssertTrue(PriceSanitizer.clean(series([])).points.isEmpty)
        XCTAssertEqual(PriceSanitizer.clean(series([100])).points.count, 1)
        XCTAssertFalse(PriceSanitizer.clean(series([.nan])).isForecastable)
    }

    func testSanitizerAllIdenticalAndAllZero() {
        let flat = PriceSanitizer.clean(series(Array(repeating: 50.0, count: 40)))
        XCTAssertEqual(flat.points.count, 40)
        let zeros = PriceSanitizer.clean(series(Array(repeating: 0.0, count: 40)))
        XCTAssertTrue(zeros.points.isEmpty, "all-zero prices are degenerate → filtered out")
        XCTAssertFalse(zeros.isForecastable)
    }

    func testSanitizerHugeInputCompletesQuickly() {
        var rng = SystemRandomNumberGenerator()
        let closes = (0..<100_000).map { _ in Double.random(in: 10...500, using: &rng) }
        let started = Date()
        let cleaned = PriceSanitizer.clean(series(closes))
        XCTAssertLessThan(Date().timeIntervalSince(started), 2.0)
        XCTAssertEqual(cleaned.points.count, 100_000)
    }

    func testSanitizerSpikeCorrection() {
        var closes = Array(repeating: 100.0, count: 30)
        closes[15] = 100_000 // fat-finger print
        let cleaned = PriceSanitizer.clean(series(closes))
        XCTAssertEqual(cleaned.points[15].close, 100.0, accuracy: 1.0, "lone spike pulled back to the local median")
    }

    // MARK: - PriceResolution.nearestClose

    func testPriceResolutionEmptyAndDegenerate() {
        let empty = PriceSeries(symbol: "X", assetClass: .stock, points: [], isSample: false)
        XCTAssertNil(PriceResolution.nearestClose(in: empty, to: Date(), toleranceDays: 3))

        let far = series([1, 2, 3, 4, 5])
        XCTAssertNil(PriceResolution.nearestClose(in: far, to: Date.distantFuture, toleranceDays: 1))
    }

    func testPriceResolutionEpochAndFarFutureTargets() {
        let s = series(Array(repeating: 10.0, count: 20))
        // Never crashes for extreme target dates.
        _ = PriceResolution.nearestClose(in: s, to: Date(timeIntervalSince1970: 0), toleranceDays: 3)
        _ = PriceResolution.nearestClose(in: s, to: Date.distantFuture, toleranceDays: 1_000_000)
        _ = PriceResolution.nearestClose(in: s, to: Date.distantPast, toleranceDays: -5)
    }

    func testPriceResolutionPicksNearest() {
        let base = Date(timeIntervalSince1970: 1_600_000_000)
        let s = PriceSeries(symbol: "X", assetClass: .stock, points: [
            PricePoint(date: base, close: 1),
            PricePoint(date: base.addingTimeInterval(86_400), close: 2),
            PricePoint(date: base.addingTimeInterval(2 * 86_400), close: 3),
        ], isSample: false)
        XCTAssertEqual(PriceResolution.nearestClose(in: s, to: base.addingTimeInterval(86_400 + 100), toleranceDays: 2), 2)
    }

    // MARK: - CryptoSymbolMap.yahooTicker

    func testCryptoSymbolMapHostileInput() {
        let hostile = [
            "", "   ", "\n\t", "\u{0000}", "../../etc/passwd", "bitcoin/../x",
            "?q=1", "#frag", "javascript:alert(1)", "file:///", "%2e%2e%2f",
            "'; DROP TABLE coins;--", String(repeating: "a", count: 10_000),
            "é", "🚀", "\u{200B}", "\u{202E}evil",
        ]
        for input in hostile {
            let out = CryptoSymbolMap.yahooTicker(for: input)
            if let out {
                // If it resolves anything, it must be a clean {TICKER}-USD token.
                XCTAssertTrue(out.hasSuffix("-USD"))
                XCTAssertTrue(out.dropLast(4).allSatisfy { $0.isLetter && $0.isUppercase })
                XCTAssertTrue(MarketDataService.isValidSymbol(out) || out.count <= 9)
            }
        }
    }

    func testCryptoSymbolMapKnownAndShortTicker() {
        XCTAssertEqual(CryptoSymbolMap.yahooTicker(for: " Bitcoin "), "BTC-USD")
        XCTAssertEqual(CryptoSymbolMap.yahooTicker(for: "eth"), "ETH-USD")
        XCTAssertEqual(CryptoSymbolMap.yahooTicker(for: "SOL"), "SOL-USD")
        XCTAssertNil(CryptoSymbolMap.yahooTicker(for: "totally-unknown-coin"))
    }
}

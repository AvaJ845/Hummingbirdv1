import XCTest
@testable import Hummingbird

final class SymbolSecurityTests: XCTestCase {

    func testAllowlistAcceptsRealSymbols() {
        for good in ["AAPL", "MSFT", "BRK-B", "bitcoin", "ethereum-classic", "binance-usd"] {
            XCTAssertTrue(MarketDataService.isValidSymbol(good), "\(good) should be valid")
        }
    }

    func testAllowlistRejectsUrlManipulation() {
        for bad in [
            "bitcoin/../global",       // path traversal
            "AAPL/quote",              // extra path segment
            "..",                      // dot-run: path-segment collapse
            "coin..gecko",             // dot-run inside allowlisted chars
            "AAPL?range=max",          // query injection
            "AAPL#frag",               // fragment injection
            "some symbol",             // space
            "coin\u{0000}",            // control char
            "",                        // empty
            String(repeating: "a", count: 64) // absurd length
        ] {
            XCTAssertFalse(MarketDataService.isValidSymbol(bad), "\(bad) must be rejected")
        }
    }

    /// A malicious symbol must be rejected *before* any network request is made.
    func testHistoryRejectsMaliciousSymbolWithoutNetwork() async {
        let service = MarketDataService(session: .shared,
                                        sampleProvider: { _, _, _ in
            XCTFail("sample/network path must not be reached for an invalid symbol")
            return SampleData.series(symbol: "x", assetClass: .stock, days: 10)
        })
        do {
            _ = try await service.history(symbol: "bitcoin/../global", assetClass: .crypto)
            XCTFail("expected rejection")
        } catch let error as MarketDataError {
            XCTAssertEqual(error, .notFound("bitcoin/../global"))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}

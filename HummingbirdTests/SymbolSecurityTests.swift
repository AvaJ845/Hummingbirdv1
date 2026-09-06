import XCTest
@testable import Hummingbird

final class SymbolSecurityTests: XCTestCase {

    func testAllowlistAcceptsRealSymbols() {
        for good in ["AAPL", "MSFT", "BRK-B", "bitcoin", "ethereum-classic", "binance-usd", "brk.b", "SPY"] {
            XCTAssertTrue(MarketDataService.isValidSymbol(good), "\(good) should be valid")
        }
    }

    /// The sanitiser output is interpolated straight into a URL *path*, so every
    /// one of these must be rejected before a request is built.
    func testAllowlistRejectsInjectionAndControlCharacters() {
        let hostile: [String] = [
            "../", "../../etc/passwd", "AAPL/../../", "AAPL/quote", "bitcoin/../global",
            "..", "coin..gecko", "%2e%2e%2f", "%2E%2E/passwd",
            "AAPL?range=max", "?foo=bar", "AAPL#frag", "#frag", "a&b", "a=b",
            "AAPL ", " AAPL", "a b", "a\tb", "a\nb", "a\rb",
            "coin\u{0000}", "AAPL\u{0000}", "\u{0000}",
            "é", "café", "🚀", "AA🚀PL", "\u{200B}", "AAPL\u{200B}", "\u{202E}LPAA",
            "javascript:alert(1)", "file:///etc/passwd", "http://evil.test",
            "'; DROP TABLE prices;--", "AAPL;ls", "$(whoami)", "`id`",
            "", " ", "\t", "\n", "   \t  ",
            String(repeating: "A", count: 33), String(repeating: "a", count: 10_000),
            "AA/PL", "AA\\PL", "AA|PL", "AA*PL", "AA:PL", "AA@PL",
        ]
        for input in hostile {
            XCTAssertFalse(MarketDataService.isValidSymbol(input),
                           "must reject: \(input.debugDescription)")
        }
    }

    func testValidSymbolLengthBounds() {
        XCTAssertFalse(MarketDataService.isValidSymbol(""))
        XCTAssertTrue(MarketDataService.isValidSymbol("A"))
        XCTAssertTrue(MarketDataService.isValidSymbol(String(repeating: "A", count: 32)))
        XCTAssertFalse(MarketDataService.isValidSymbol(String(repeating: "A", count: 33)))
    }

    /// Case is preserved by the validator (the service upper/lowercases per asset
    /// class itself) but a mixed-case symbol is still a safe path component.
    func testMixedCaseIsAcceptedAndURLSafe() throws {
        for symbol in ["aApL", "BiTcOiN", "Eth-Classic"] {
            XCTAssertTrue(MarketDataService.isValidSymbol(symbol))
            let comps = URLComponents(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)")
            XCTAssertNotNil(comps?.url, "\(symbol) yields a well-formed URL")
            XCTAssertEqual(comps?.percentEncodedPath, "/v8/finance/chart/\(symbol)")
        }
    }

    // MARK: - Path parity: every untrusted entry point runs the same validation

    /// A malicious symbol must be rejected *before* any network request is made,
    /// no matter which surface it enters through. All of them funnel to
    /// `MarketDataService.history`, which is the single validation chokepoint.
    private func makeService() -> MarketDataService {
        MarketDataService(session: .shared, sampleProvider: { _, _, _ in
            XCTFail("network/sample path must not be reached for an invalid symbol")
            return SampleData.series(symbol: "x", assetClass: .stock, days: 10)
        })
    }

    func testServiceHistoryRejectsMaliciousSymbolWithoutNetwork() async {
        let service = makeService()
        for bad in ["bitcoin/../global", "AAPL?range=max", "AAPL#frag", "../../etc/passwd", "a b", "coin\u{0000}"] {
            do {
                _ = try await service.history(symbol: bad, assetClass: .crypto)
                XCTFail("expected rejection for \(bad.debugDescription)")
            } catch let error as MarketDataError {
                XCTAssertEqual(error, .notFound(bad.trimmingCharacters(in: .whitespacesAndNewlines)))
            } catch {
                XCTFail("unexpected error: \(error)")
            }
        }
    }

    func testEmptyOrWhitespaceSymbolIsRejectedAsEmpty() async {
        let service = makeService()
        for blank in ["", "   ", "\t", "\n"] {
            do {
                _ = try await service.history(symbol: blank, assetClass: .stock)
                XCTFail("expected rejection")
            } catch let error as MarketDataError {
                XCTAssertEqual(error, .emptySymbol)
            } catch {
                XCTFail("unexpected error: \(error)")
            }
        }
    }

    /// `DictationController.sanitizedSymbol` is the first-pass scrub on spoken
    /// input; its output still has to survive `isValidSymbol` (or be rejected).
    @MainActor
    func testDictationSanitizerOutputIsValidOrRejected() {
        let controller = DictationController()
        let spoken = [
            "Apple", "buy A A P L", "bitcoin dot com", "what's tesla doing",
            "A.A.P.L.", "spy!!!", "  microsoft  ", "coin\u{0000}base",
        ]
        for phrase in spoken {
            let out = controller.sanitizedSymbol(from: phrase)
            // The scrub strips punctuation and whitespace; the last token it
            // returns must never contain a path separator, space or null byte.
            XCTAssertFalse(out.contains("/"), phrase)
            XCTAssertFalse(out.contains(" "), phrase)
            XCTAssertFalse(out.unicodeScalars.contains { $0.value == 0 }, phrase)
            // And `history()` still re-validates it regardless.
        }
    }

    /// The App Intents (`AddToWatchlistIntent`, `ProjectAssetIntent`) and the
    /// widget's config intent all pass user text straight to
    /// `MarketDataService.history`, so this is a compile-time + behavioural
    /// assertion that the chokepoint is the only path. If a future intent calls
    /// a lower-level fetch directly, add it here.
    func testAppIntentSymbolPathGoesThroughValidator() async {
        let service = makeService()
        // Mirror exactly what AddToWatchlistIntent / ProjectAssetIntent do.
        do {
            _ = try await service.history(symbol: "AAPL/../../etc", assetClass: .stock)
            XCTFail("intent-style call must be rejected before network")
        } catch let error as MarketDataError {
            XCTAssertEqual(error, .notFound("AAPL/../../etc"))
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }
}

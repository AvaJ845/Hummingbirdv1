import XCTest
@testable import Hummingbird

/// The store the "Call it" UI will sit on: record → resolve → persist, plus the
/// pending queue and wipe.
@MainActor
final class UserCallStoreTests: XCTestCase {
    private func freshStore() -> (UserCallStore, UserDefaults) {
        let defaults = UserDefaults(suiteName: "test.calls.\(UUID().uuidString)")!
        return (UserCallStore(defaults: defaults), defaults)
    }

    func testRecordResolveAndReport() {
        let (store, _) = freshStore()
        let made = Date(timeIntervalSince1970: 1_700_000_000)  // well in the past → resolvable now

        store.record(symbol: "AAPL", assetClass: .stock, direction: .higher,
                     confidence: .confident, horizonDays: 7, spot: 100, now: made)
        XCTAssertEqual(store.calls.count, 1)
        XCTAssertEqual(store.pending.count, 1)
        XCTAssertEqual(store.report.resolved, 0)

        // A real close ~7 days after the call, higher than spot.
        let target = made.addingTimeInterval(7 * 86_400)
        let series = PriceSeries(symbol: "AAPL", assetClass: .stock,
                                 points: [PricePoint(date: target, close: 115)], isSample: true)
        store.resolve(using: series)

        XCTAssertTrue(store.pending.isEmpty)
        XCTAssertEqual(store.report.resolved, 1)
        XCTAssertEqual(store.report.overall.correct, 1)
        XCTAssertEqual(store.report.overall.hitRate ?? 0, 1.0, accuracy: 1e-9)
    }

    func testPersistsAcrossReopen() {
        let defaults = UserDefaults(suiteName: "test.calls.\(UUID().uuidString)")!
        let store = UserCallStore(defaults: defaults)
        store.record(symbol: "btc", assetClass: .crypto, direction: .lower,
                     confidence: .hunch, horizonDays: 14, spot: 50_000)
        XCTAssertEqual(store.calls.count, 1)

        let reopened = UserCallStore(defaults: defaults)
        XCTAssertEqual(reopened.calls.count, 1)
        XCTAssertEqual(reopened.calls.first?.direction, .lower)
        XCTAssertEqual(reopened.calls.first?.confidence, .hunch)
    }

    func testResolveReturnsNewlyResolvedIDsOnce() {
        let (store, _) = freshStore()
        let made = Date(timeIntervalSince1970: 1_700_000_000)
        let call = store.record(symbol: "AAPL", assetClass: .stock, direction: .lower,
                                confidence: .confident, horizonDays: 7, spot: 100, now: made)
        let target = made.addingTimeInterval(7 * 86_400)
        let series = PriceSeries(symbol: "AAPL", assetClass: .stock,
                                 points: [PricePoint(date: target, close: 90)], isSample: true)

        XCTAssertEqual(store.resolve(using: series), [call.id])
        XCTAssertTrue(store.resolve(using: series).isEmpty)   // already resolved
        XCTAssertEqual(store.report.overall.correct, 1)       // lower call, went down
    }

    func testResolveDueFetchesEachDueAsset() async {
        let (store, _) = freshStore()
        let made = Date(timeIntervalSince1970: 1_700_000_000)
        store.record(symbol: "AAPL", assetClass: .stock, direction: .higher,
                     confidence: .hunch, horizonDays: 7, spot: 100, now: made)
        let now = made.addingTimeInterval(20 * 86_400)

        XCTAssertEqual(store.dueAssets(now: now).count, 1)
        let resolved = await store.resolveDue(using: StubCallService(close: 115, offsetDays: 7, base: made), now: now)

        XCTAssertEqual(resolved.count, 1)
        XCTAssertTrue(store.pending.isEmpty)
        XCTAssertEqual(store.report.overall.correct, 1)
    }

    func testResolveDueIsCappedPerPass() async {
        let (store, _) = freshStore()
        let made = Date(timeIntervalSince1970: 1_700_000_000)
        for sym in ["AAPL", "MSFT", "NVDA"] {
            store.record(symbol: sym, assetClass: .stock, direction: .higher,
                         confidence: .hunch, horizonDays: 7, spot: 100, now: made)
        }
        let now = made.addingTimeInterval(20 * 86_400)
        XCTAssertEqual(store.dueAssets(now: now).count, 3)

        let resolved = await store.resolveDue(using: StubCallService(close: 115, offsetDays: 7, base: made),
                                              now: now, maxAssets: 2)
        XCTAssertEqual(resolved.count, 2)        // only 2 of 3 assets fetched this pass
        XCTAssertEqual(store.pending.count, 1)   // the third still waits for the next pass
    }

    func testClearAllWipes() {
        let (store, _) = freshStore()
        store.record(symbol: "AAPL", assetClass: .stock, direction: .higher,
                     confidence: .hunch, horizonDays: 7, spot: 100)
        store.clearAll()
        XCTAssertTrue(store.calls.isEmpty)
        XCTAssertEqual(store.report.total, 0)
    }
}

/// Returns a one-point series with a close `offsetDays` after `base` — enough to
/// resolve a call whose target lands there.
private struct StubCallService: MarketDataProviding {
    let close: Double
    let offsetDays: Int
    let base: Date
    func history(symbol: String, assetClass: AssetClass, days: Int) async throws -> PriceSeries {
        PriceSeries(symbol: symbol, assetClass: assetClass,
                    points: [PricePoint(date: base.addingTimeInterval(Double(offsetDays) * 86_400), close: close)],
                    isSample: true)
    }
}

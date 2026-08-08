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

    func testClearAllWipes() {
        let (store, _) = freshStore()
        store.record(symbol: "AAPL", assetClass: .stock, direction: .higher,
                     confidence: .hunch, horizonDays: 7, spot: 100)
        store.clearAll()
        XCTAssertTrue(store.calls.isEmpty)
        XCTAssertEqual(store.report.total, 0)
    }
}

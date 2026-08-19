import XCTest
@testable import Hummingbird

@MainActor
final class WatchlistRefreshTests: XCTestCase {
    func testRefreshStoresSnapshotForItem() async {
        let store = WatchlistStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        store.add(symbol: "bitcoin", assetClass: .crypto)
        let item = store.items[0]
        XCTAssertNil(store.snapshot(for: item))

        let ok = await WatchlistRefresh.refresh(item, store: store, service: StubRefreshMarket())
        XCTAssertTrue(ok)

        let snapshot = store.snapshot(for: item)
        XCTAssertNotNil(snapshot)
        XCTAssertFalse(snapshot?.bestMethodName.isEmpty ?? true)
    }

    func testSharedStorageExposesSavedItemsForWidgetPicker() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = WatchlistStore(defaults: defaults)
        store.add(symbol: "bitcoin", assetClass: .crypto)
        store.add(symbol: "AAPL", assetClass: .stock)

        // The widget's configuration EntityQuery reads exactly this.
        let shared = SharedStorage.items(defaults: defaults)
        XCTAssertEqual(shared.count, 2)
        XCTAssertEqual(Set(shared.map(\.title)), ["Bitcoin", "AAPL"])
    }

    func testSharedStorageTrackRecordRoundTrips() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        XCTAssertNil(SharedStorage.trackRecord(defaults: defaults))

        let snapshot = TrackRecordSnapshot(streak: 5, hitRate: 0.6, decided: 10, updatedAt: Date(timeIntervalSince1970: 1_700_000_000))
        SharedStorage.saveTrackRecord(snapshot, defaults: defaults)

        let read = SharedStorage.trackRecord(defaults: defaults)
        XCTAssertEqual(read?.streak, 5)
        XCTAssertEqual(read?.hitRate, 0.6)
        XCTAssertEqual(read?.decided, 10)
    }

    func testBackgroundTaskIdentifierMatchesInfoPlist() {
        // Guards against the scheduler identifier drifting from the Info.plist entry.
        XCTAssertEqual(BackgroundRefresh.taskIdentifier, "com.avaresearch.hummingbird.refresh")
        let permitted = Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String]
        XCTAssertTrue(permitted?.contains(BackgroundRefresh.taskIdentifier) ?? false,
                      "Info.plist must permit the background refresh identifier")
    }
}

private actor StubRefreshMarket: MarketDataProviding {
    func history(symbol: String, assetClass: AssetClass, days: Int) async throws -> PriceSeries {
        SampleData.series(symbol: symbol, assetClass: assetClass, days: max(days, 120))
    }
}

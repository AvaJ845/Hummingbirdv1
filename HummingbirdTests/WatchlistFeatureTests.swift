import XCTest
@testable import Hummingbird

@MainActor
final class WatchlistStoreTests: XCTestCase {
    private func freshStore(_ suite: String = UUID().uuidString) -> WatchlistStore {
        WatchlistStore(defaults: UserDefaults(suiteName: suite)!)
    }

    func testAddContainsDedupeAndToggle() {
        let store = freshStore()
        XCTAssertFalse(store.contains(symbol: "bitcoin", assetClass: .crypto))

        store.add(symbol: "bitcoin", assetClass: .crypto)
        XCTAssertTrue(store.contains(symbol: "BITCOIN", assetClass: .crypto), "id is case-insensitive")
        XCTAssertEqual(store.items.count, 1)

        store.add(symbol: "bitcoin", assetClass: .crypto) // duplicate ignored
        XCTAssertEqual(store.items.count, 1)

        // stock and crypto with same text are distinct
        store.add(symbol: "bitcoin", assetClass: .stock)
        XCTAssertEqual(store.items.count, 2)

        XCTAssertFalse(store.toggle(symbol: "bitcoin", assetClass: .crypto), "toggling an existing item removes it")
        XCTAssertFalse(store.contains(symbol: "bitcoin", assetClass: .crypto))
    }

    func testItemsAndAlertsPersistAcrossInstances() {
        let suite = UUID().uuidString
        let store = freshStore(suite)
        store.add(symbol: "AAPL", assetClass: .stock)
        let item = store.items[0]
        store.setAlert(enabled: true, threshold: 0.08, for: item)

        let reloaded = freshStore(suite)
        XCTAssertEqual(reloaded.items.count, 1)
        XCTAssertTrue(reloaded.isAlerting(item))
        XCTAssertEqual(reloaded.alertPreference(for: item).thresholdPercent, 0.08, accuracy: 1e-9)
    }

    func testSnapshotSaveAndRead() {
        let store = freshStore()
        store.add(symbol: "bitcoin", assetClass: .crypto)
        let item = store.items[0]
        let series = SampleData.series(symbol: "bitcoin", assetClass: .crypto, days: 120)
        guard let snapshot = WatchlistIntelligence.snapshot(for: item, series: series) else {
            return XCTFail("Expected a snapshot")
        }
        store.saveSnapshot(snapshot)
        XCTAssertEqual(store.snapshot(for: item)?.price, snapshot.price)
    }
}

final class AlertEngineTests: XCTestCase {
    private let item = WatchlistItem(symbol: "bitcoin", assetClass: .crypto)

    func testFiresOnLargeUpMove() {
        let alert = AlertEngine.evaluate(item: item, previousPrice: 100, newPrice: 106, threshold: 0.05)
        XCTAssertNotNil(alert)
        XCTAssertGreaterThan(alert!.changeFraction, 0)
    }

    func testFiresOnLargeDownMove() {
        let alert = AlertEngine.evaluate(item: item, previousPrice: 100, newPrice: 90, threshold: 0.05)
        XCTAssertNotNil(alert)
        XCTAssertLessThan(alert!.changeFraction, 0)
    }

    func testSilentBelowThreshold() {
        XCTAssertNil(AlertEngine.evaluate(item: item, previousPrice: 100, newPrice: 103, threshold: 0.05))
    }

    func testGuardsInvalidInputs() {
        XCTAssertNil(AlertEngine.evaluate(item: item, previousPrice: 0, newPrice: 100, threshold: 0.05))
        XCTAssertNil(AlertEngine.evaluate(item: item, previousPrice: 100, newPrice: 200, threshold: 0))
    }
}

final class WatchlistIntelligenceTests: XCTestCase {
    func testSnapshotIsWellFormed() {
        let series = SampleData.series(symbol: "AAPL", assetClass: .stock, days: 120)
        let item = WatchlistItem(symbol: "AAPL", assetClass: .stock)
        guard let snapshot = WatchlistIntelligence.snapshot(for: item, series: series) else {
            return XCTFail("Expected snapshot")
        }
        XCTAssertEqual(snapshot.price, series.points.last!.close, accuracy: 1e-6)
        XCTAssertFalse(snapshot.bestMethodName.isEmpty)
        XCTAssertEqual(snapshot.projectionSpark.count, snapshot.horizonDays)
        XCTAssertTrue(snapshot.historySpark.allSatisfy { $0 >= 0 && $0 <= 1 }, "history normalized 0...1")
        XCTAssertTrue(snapshot.projectionSpark.allSatisfy { $0 >= 0 && $0 <= 1 }, "projection normalized 0...1")
    }

    func testBestReturnsAModelForForecastableSeries() {
        let series = SampleData.series(symbol: "bitcoin", assetClass: .crypto, days: 120)
        XCTAssertNotNil(WatchlistIntelligence.best(for: series))
    }
}

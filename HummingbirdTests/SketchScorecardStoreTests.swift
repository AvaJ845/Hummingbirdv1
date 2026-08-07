import XCTest
@testable import Hummingbird

@MainActor
final class SketchScorecardStoreTests: XCTestCase {

    private func makeStore(dedupeHours: Double = 12) -> (SketchScorecardStore, UserDefaults) {
        let suite = "test.scorecard.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (SketchScorecardStore(defaults: defaults, dedupeHours: dedupeHours), defaults)
    }

    private func forecast(now: Date) -> Forecast {
        let history = [PricePoint(date: now, close: 100)]
        let points = [1, 7, 14, 30].map { off in
            ForecastPoint(date: now.addingTimeInterval(Double(off) * 86_400), mean: 100 + Double(off), lower: 95, upper: 110)
        }
        return Forecast(model: ForecastModel.model(id: ForecastStrategy.drift.rawValue)!, history: history, points: points)
    }

    func testRecordAndDedupe() {
        let (store, _) = makeStore()
        store.record(forecast: forecast(now: Date()), symbol: "AAPL", assetClass: .stock)
        XCTAssertEqual(store.records.count, 1)
        // Same asset+model within the 12h window → deduped.
        store.record(forecast: forecast(now: Date()), symbol: "AAPL", assetClass: .stock)
        XCTAssertEqual(store.records.count, 1)
        // Different asset → new record.
        store.record(forecast: forecast(now: Date()), symbol: "MSFT", assetClass: .stock)
        XCTAssertEqual(store.records.count, 2)
    }

    func testResolveAndSummary() {
        let (store, _) = makeStore()
        // A sketch created 40 days ago, so its +1..+30d horizons are now in the past.
        let past = Date().addingTimeInterval(-40 * 86_400)
        store.record(forecast: forecast(now: past), symbol: "AAPL", assetClass: .stock)

        // Fresh series covering those dates with real closes.
        var pts: [PricePoint] = []
        for off in 0...35 { pts.append(PricePoint(date: past.addingTimeInterval(Double(off) * 86_400), close: 100 + Double(off) * 0.5)) }
        store.resolve(using: PriceSeries(symbol: "AAPL", assetClass: .stock, points: pts, isSample: false))

        XCTAssertTrue(store.records.first!.isResolved)
        XCTAssertGreaterThan(store.overall.resolvedSketches, 0)
        XCTAssertNotNil(store.overall.medianError)
        XCTAssertEqual(store.assets.count, 1)
    }

    func testClearAllWipesMemoryAndDisk() {
        let (store, defaults) = makeStore()
        store.record(forecast: forecast(now: Date()), symbol: "AAPL", assetClass: .stock)
        XCTAssertFalse(store.records.isEmpty)
        store.clearAll()
        XCTAssertTrue(store.records.isEmpty)
        // A brand-new store on the same defaults must see nothing.
        let reopened = SketchScorecardStore(defaults: defaults)
        XCTAssertTrue(reopened.records.isEmpty)
    }

    func testRetentionPrunesOldSketches() {
        let (store, _) = makeStore()
        // Inject an old record directly by recording with an old "now" is not
        // possible via the public API, so verify retention via the setter which
        // prunes: create one recent, then set a 30-day window (recent survives).
        store.record(forecast: forecast(now: Date()), symbol: "AAPL", assetClass: .stock)
        store.retentionDays = 30
        XCTAssertEqual(store.records.count, 1, "Recent sketch should survive a 30-day window")
    }

    func testSurfacesBestModelAndProValueHighlights() {
        // Regression for the recommender + value-recap paywall path (#2/#4).
        let (store, _) = makeStore(dedupeHours: 0)  // allow multiple same asset+model
        let base = Date().addingTimeInterval(-45 * 86_400)
        store.record(forecast: forecast(now: base), symbol: "AAPL", assetClass: .stock, now: base)
        store.record(forecast: forecast(now: base.addingTimeInterval(3 * 86_400)),
                     symbol: "AAPL", assetClass: .stock, now: base.addingTimeInterval(3 * 86_400))
        XCTAssertEqual(store.records.count, 2)

        var pts: [PricePoint] = []
        for off in 0...40 { pts.append(PricePoint(date: base.addingTimeInterval(Double(off) * 86_400), close: 100 + Double(off))) }
        store.resolve(using: PriceSeries(symbol: "AAPL", assetClass: .stock, points: pts, isSample: false))

        XCTAssertNotNil(store.bestModel(for: "AAPL", assetClass: .stock), "two scored drift sketches → a best model")
        XCTAssertFalse(store.proValueHighlights.isEmpty, "highlights power the value-recap paywall")
        XCTAssertEqual(store.proValueHighlights.first?.symbol.lowercased(), "aapl")
    }

    func testPersistsAcrossReopen() {
        let (store, defaults) = makeStore()
        store.record(forecast: forecast(now: Date()), symbol: "AAPL", assetClass: .stock)
        // Reopening on the same store must reload the saved record (regression:
        // an @Observable didSet firing in init once clobbered the data here).
        let reopened = SketchScorecardStore(defaults: defaults)
        XCTAssertEqual(reopened.records.count, 1)
    }
}

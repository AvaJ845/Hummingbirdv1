import XCTest
@testable import Hummingbird

final class SketchJournalEngineTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func snapshot(symbol: String, change: Double, daysAgo: Int, method: String = "Holt") -> WatchlistSnapshot {
        WatchlistSnapshot(
            symbol: symbol, assetClass: .stock, title: symbol.uppercased(), price: 100,
            projectedChange: change, bestMethodName: method, horizonDays: 7,
            historySpark: [0, 0.5, 1], projectionSpark: [1, 1.2],
            updatedAt: calendar.date(byAdding: .day, value: -daysAgo, to: now)!
        )
    }

    private func record(daysAgo: Int, actual: Double? = nil, spot: Double = 100) -> SketchRecord {
        let created = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
        var projection = SketchProjection(targetDate: created, projectedMean: 105, projectedBandHalfWidth: 2)
        if let actual {
            projection.actualClose = actual
            projection.resolvedAt = now
        }
        return SketchRecord(id: UUID(), symbol: "AAPL", assetClass: .stock, modelId: "holt",
                            modelName: "Holt", createdAt: created, spotAtCreation: spot,
                            projections: [projection])
    }

    func testNilWithNoActivityInTheTrailingWeek() {
        let journal = SketchJournalEngine.compose(
            snapshots: [snapshot(symbol: "AAPL", change: 0.02, daysAgo: 10)],
            records: [record(daysAgo: 10)],
            now: now, calendar: calendar
        )
        XCTAssertNil(journal)
    }

    func testMoversSortedByAbsoluteChangeDescending() {
        let snapshots = [
            snapshot(symbol: "AAPL", change: 0.01, daysAgo: 1),
            snapshot(symbol: "BTC", change: -0.08, daysAgo: 2),
            snapshot(symbol: "NVDA", change: 0.04, daysAgo: 3)
        ]
        let journal = SketchJournalEngine.compose(snapshots: snapshots, records: [], now: now, calendar: calendar)
        XCTAssertEqual(journal?.movers.map(\.symbol), ["BTC", "NVDA", "AAPL"])
    }

    func testMoversCappedAtFive() {
        let snapshots = (0..<8).map { snapshot(symbol: "SYM\($0)", change: Double($0) * 0.01, daysAgo: 1) }
        let journal = SketchJournalEngine.compose(snapshots: snapshots, records: [], now: now, calendar: calendar)
        XCTAssertEqual(journal?.movers.count, 5)
    }

    func testExcludesSnapshotsOutsideTheTrailingWeek() {
        let snapshots = [snapshot(symbol: "AAPL", change: 0.05, daysAgo: 10)]
        let journal = SketchJournalEngine.compose(snapshots: snapshots, records: [], now: now, calendar: calendar)
        XCTAssertNil(journal)
    }

    func testMedianAccuracyOnlyFromResolvedRecordsThisWeek() {
        let records = [
            record(daysAgo: 1, actual: 110), // spot 100, projected 105 -> APE = |105-110|/110 ≈ 4.5%
            record(daysAgo: 2, actual: nil), // unresolved, excluded
            record(daysAgo: 10, actual: 106) // outside the week, excluded
        ]
        let journal = SketchJournalEngine.compose(
            snapshots: [snapshot(symbol: "AAPL", change: 0.01, daysAgo: 1)],
            records: records, now: now, calendar: calendar
        )
        XCTAssertNotNil(journal?.medianAccuracy)
        XCTAssertEqual(journal?.sketchesRun, 2) // both this-week records count, resolved or not
    }

    func testSomeActivityIsEnoughEvenWithoutTheOther() {
        // Sketches ran this week but no watchlist snapshot refreshed — still a journal.
        let journal = SketchJournalEngine.compose(snapshots: [], records: [record(daysAgo: 1)], now: now, calendar: calendar)
        XCTAssertNotNil(journal)
        XCTAssertTrue(journal!.movers.isEmpty)
    }
}

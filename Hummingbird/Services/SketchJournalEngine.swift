import Foundation

/// One watched asset's move this week, for the journal's "movers" list.
struct JournalMover: Identifiable, Equatable, Sendable {
    let symbol: String
    let title: String
    let assetClass: AssetClass
    let projectedChange: Double
    let bestMethodName: String
    var id: String { "\(assetClass.rawValue):\(symbol.lowercased())" }
}

/// A week's rollup across the whole watchlist — sketch activity and how the
/// app's own methods have tracked, distinct from the user's own call record
/// (that's `WeeklyRecapEngine`). A record of the past, never a promise.
struct SketchJournal: Equatable, Sendable {
    /// Watched assets refreshed this week, biggest projected move first.
    let movers: [JournalMover]
    /// Median backtest error across sketches created this week, if any resolved.
    let medianAccuracy: Double?
    let sketchesRun: Int
}

enum SketchJournalEngine {
    private static let moverLimit = 5

    /// nil when there's no watchlist or sketch activity in the trailing week.
    static func compose(
        snapshots: [WatchlistSnapshot],
        records: [SketchRecord],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> SketchJournal? {
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else { return nil }

        let recentSnapshots = snapshots.filter { $0.updatedAt >= weekAgo && $0.updatedAt <= now }
        let recentRecords = records.filter { $0.createdAt >= weekAgo && $0.createdAt <= now }
        guard !recentSnapshots.isEmpty || !recentRecords.isEmpty else { return nil }

        let movers = recentSnapshots
            .sorted { abs($0.projectedChange) > abs($1.projectedChange) }
            .prefix(moverLimit)
            .map {
                JournalMover(symbol: $0.symbol, title: $0.title, assetClass: $0.assetClass,
                            projectedChange: $0.projectedChange, bestMethodName: $0.bestMethodName)
            }

        let errors = recentRecords.compactMap(\.representativeError).sorted()

        return SketchJournal(
            movers: Array(movers),
            medianAccuracy: ScorecardEngine.median(sorted: errors),
            sketchesRun: recentRecords.count
        )
    }
}

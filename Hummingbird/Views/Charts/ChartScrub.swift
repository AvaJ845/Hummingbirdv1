import Foundation

/// Pure helpers for chart scrubbing, kept out of the View so they're testable.
enum ChartScrub {
    /// Index of the date closest to `target`, or nil if empty.
    static func nearestIndex(to target: Date, in dates: [Date]) -> Int? {
        guard !dates.isEmpty else { return nil }
        return dates.indices.min {
            abs(dates[$0].timeIntervalSince(target)) < abs(dates[$1].timeIntervalSince(target))
        }
    }
}

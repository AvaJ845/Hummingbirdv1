import Foundation

/// The single source of truth for resolving a dated prediction against a real
/// price series. Both the sketch scorecard and the user's own calls resolve the
/// same way — nearest real close to a target date, within a tolerance — so the
/// logic lives here once instead of being copied per engine.
enum PriceResolution {
    /// The close nearest `date` in `series`, within `toleranceDays`. Nil if the
    /// series has no point close enough.
    static func nearestClose(in series: PriceSeries, to date: Date, toleranceDays: Int) -> Double? {
        let tolerance = TimeInterval(toleranceDays * 86_400)
        var best: (delta: TimeInterval, close: Double)?
        for point in series.points {
            let delta = abs(point.date.timeIntervalSince(date))
            guard delta <= tolerance else { continue }
            if let current = best, current.delta <= delta { continue }
            best = (delta, point.close)
        }
        return best?.close
    }
}

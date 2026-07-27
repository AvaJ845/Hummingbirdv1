import Foundation

/// Guards real feed data against isolated bad ticks (fat-finger prints, feed
/// glitches) using a Hampel filter: each close is compared to the median of a
/// local window, and points deviating by more than `threshold × MAD` are
/// replaced with that median. Genuine sustained moves survive because they move
/// the local median with them; only lone spikes are corrected.
enum PriceSanitizer {
    static func clean(_ series: PriceSeries, window: Int = 3, threshold: Double = 5) -> PriceSeries {
        let points = series.points
        guard points.count >= 5 else { return series }

        let closes = points.map(\.close)
        var cleaned = closes

        for i in closes.indices {
            let lo = max(0, i - window)
            let hi = min(closes.count - 1, i + window)
            let neighborhood = Array(closes[lo...hi])
            let med = median(neighborhood)
            let mad = median(neighborhood.map { abs($0 - med) })
            // 1.4826 scales MAD to a normal-consistent standard-deviation estimate.
            let sigma = 1.4826 * mad
            let deviation = abs(closes[i] - med)
            if sigma > 0 {
                if deviation > threshold * sigma { cleaned[i] = med }
            } else if med > 0, deviation / med > 0.5 {
                // Degenerate flat window (MAD = 0): only a clearly-wrong tick
                // (>50% off the local median) is treated as a bad print.
                cleaned[i] = med
            }
        }

        guard cleaned != closes else { return series }
        let newPoints = zip(points, cleaned).map { PricePoint(date: $0.date, close: $1) }
        return PriceSeries(
            symbol: series.symbol,
            assetClass: series.assetClass,
            points: newPoints,
            isSample: series.isSample
        )
    }

    private static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count % 2 == 0 { return (sorted[mid - 1] + sorted[mid]) / 2 }
        return sorted[mid]
    }
}

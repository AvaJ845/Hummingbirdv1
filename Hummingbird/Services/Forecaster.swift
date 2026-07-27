import Foundation

/// On-device forecasting engine. Replaces the original Python/Prophet backend
/// with lightweight statistical models that run entirely on the phone.
enum Forecaster {

    /// Produce a forecast for the given series, model and horizon (in days).
    static func forecast(series: PriceSeries, model: ForecastModel, horizon: Int) -> Forecast {
        let points = series.points
        guard points.count >= 8 else {
            return Forecast(model: model, history: points, points: [])
        }

        let closes = points.map { $0.close }
        let n = closes.count
        let xs = (0..<n).map { Double($0) }

        // Least-squares linear trend over the whole window.
        let (slope, intercept) = linearFit(x: xs, y: closes)

        // Residuals against the trend, used for seasonality + uncertainty.
        let fitted = xs.map { slope * $0 + intercept }
        let residuals = zip(closes, fitted).map { $0 - $1 }
        let residualStd = standardDeviation(residuals)

        // Day-of-week seasonal component (average residual per weekday).
        let seasonal = weekdaySeasonality(points: points, residuals: residuals)

        // Model-specific starting point and drift per day.
        let lastClose = closes[n - 1]
        let ema = exponentialMovingAverage(closes, period: min(20, n / 2))
        let sma = simpleMovingAverage(closes, period: min(20, n))

        let calendar = Calendar(identifier: .gregorian)
        let lastDate = points[n - 1].date

        var result: [ForecastPoint] = []
        for step in 1...horizon {
            guard let date = calendar.date(byAdding: .day, value: step, to: lastDate) else { continue }
            let futureX = Double(n - 1 + step)

            let baseline: Double
            switch model.id {
            case "linear":
                baseline = slope * futureX + intercept
            case "momentum":
                // Lean into recent EMA slope.
                let recentSlope = (lastClose - ema) / Double(max(1, min(20, n / 2)))
                baseline = lastClose + recentSlope * Double(step) * 1.5
            case "reversion":
                // Decay from last close toward the moving average.
                let decay = 1.0 - exp(-Double(step) / 10.0)
                baseline = lastClose + (sma - lastClose) * decay
            default: // "trend-seasonal" and fallback
                let weekday = calendar.component(.weekday, from: date)
                baseline = slope * futureX + intercept + (seasonal[weekday] ?? 0)
            }

            // Uncertainty widens with the square root of the horizon.
            let band = residualStd * sqrt(Double(step)) * 1.28 // ~80% interval
            result.append(ForecastPoint(
                date: date,
                mean: max(0, baseline),
                lower: max(0, baseline - band),
                upper: max(0, baseline + band)
            ))
        }

        return Forecast(model: model, history: points, points: result)
    }

    // MARK: - Math helpers

    private static func linearFit(x: [Double], y: [Double]) -> (slope: Double, intercept: Double) {
        let n = Double(x.count)
        guard n > 0 else { return (0, 0) }
        let sumX = x.reduce(0, +)
        let sumY = y.reduce(0, +)
        let sumXY = zip(x, y).reduce(0) { $0 + $1.0 * $1.1 }
        let sumXX = x.reduce(0) { $0 + $1 * $1 }
        let denom = n * sumXX - sumX * sumX
        guard denom != 0 else { return (0, sumY / n) }
        let slope = (n * sumXY - sumX * sumY) / denom
        let intercept = (sumY - slope * sumX) / n
        return (slope, intercept)
    }

    private static func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count - 1)
        return sqrt(variance)
    }

    private static func weekdaySeasonality(points: [PricePoint], residuals: [Double]) -> [Int: Double] {
        let calendar = Calendar(identifier: .gregorian)
        var buckets: [Int: [Double]] = [:]
        for (point, residual) in zip(points, residuals) {
            let weekday = calendar.component(.weekday, from: point.date)
            buckets[weekday, default: []].append(residual)
        }
        return buckets.mapValues { $0.reduce(0, +) / Double($0.count) }
    }

    private static func exponentialMovingAverage(_ values: [Double], period: Int) -> Double {
        guard !values.isEmpty else { return 0 }
        let p = max(1, period)
        let k = 2.0 / (Double(p) + 1.0)
        var ema = values[0]
        for v in values.dropFirst() {
            ema = v * k + ema * (1 - k)
        }
        return ema
    }

    private static func simpleMovingAverage(_ values: [Double], period: Int) -> Double {
        guard !values.isEmpty else { return 0 }
        let p = max(1, min(period, values.count))
        let window = values.suffix(p)
        return window.reduce(0, +) / Double(window.count)
    }
}

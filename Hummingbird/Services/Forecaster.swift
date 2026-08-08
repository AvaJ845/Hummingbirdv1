import Foundation

/// On-device forecasting engine. Lightweight statistical models that run
/// entirely on device — no server, no API keys, no account.
///
/// Includes classic literature methods (drift, Holt) plus simple bird sketches.
enum Forecaster {
    static let minimumHistoryCount = 8

    /// Produce a forecast for the given series, model, and horizon (in days).
    static func forecast(
        series: PriceSeries,
        model: ForecastModel,
        horizon: Int,
        macro: MacroAdjustment = .none
    ) -> Forecast {
        let clampedHorizon = max(1, min(horizon, 365))
        let points = series.points

        guard points.count >= minimumHistoryCount else {
            return Forecast(model: model, history: points, points: [], macro: macro)
        }

        let context = TrendContext(points: points)
        let strategy = model.strategy

        var forecastPoints: [ForecastPoint]
        if strategy == .ensemble {
            forecastPoints = ensemblePoints(context: context, horizon: clampedHorizon, assetClass: series.assetClass)
        } else {
            forecastPoints = project(context: context, strategy: strategy, horizon: clampedHorizon, assetClass: series.assetClass)
        }

        if macro.isActive {
            forecastPoints = applyMacro(forecastPoints, macro: macro, horizon: clampedHorizon)
        }

        return Forecast(model: model, history: points, points: forecastPoints, macro: macro)
    }

    // MARK: - Backtest

    /// Single-holdout backtest error: fit on all but the last `holdout` days,
    /// project that many days, and return the Mean Absolute Percentage Error
    /// versus the actual held-out closes. A backtest of past behavior, NOT a
    /// guarantee of future accuracy. Nil when there isn't enough history.
    static func backtestMAPE(series: PriceSeries, model: ForecastModel, holdout: Int = 14) -> Double? {
        let points = series.points
        let h = max(1, holdout)
        return holdoutError(points: points, series: series, model: model,
                            trainCount: points.count - h, horizon: h)
    }

    /// Walk-forward backtest error: average MAPE across several rolling origins
    /// for a sturdier accuracy read than a single window. Each fold fits on an
    /// expanding history and scores the next `step` days. Averages as many folds
    /// (up to `folds`) as the history allows; nil if none fit.
    static func walkForwardMAPE(
        series: PriceSeries,
        model: ForecastModel,
        step: Int = 7,
        folds: Int = 4
    ) -> Double? {
        let points = series.points
        let s = max(1, step)
        var errors: [Double] = []

        for fold in 0..<max(1, folds) {
            let testEnd = points.count - s * fold
            let trainCount = testEnd - s
            guard trainCount >= minimumHistoryCount else { break }
            if let error = holdoutError(points: points, series: series, model: model,
                                        trainCount: trainCount, horizon: s) {
                errors.append(error)
            }
        }

        guard !errors.isEmpty else { return nil }
        return errors.reduce(0, +) / Double(errors.count)
    }

    /// Fit on `prefix(trainCount)`, project `horizon` days, and return MAPE
    /// versus the actual closes that follow. Shared by both backtest APIs.
    private static func holdoutError(
        points: [PricePoint],
        series: PriceSeries,
        model: ForecastModel,
        trainCount: Int,
        horizon: Int
    ) -> Double? {
        guard horizon > 0,
              trainCount >= minimumHistoryCount,
              trainCount + horizon <= points.count else { return nil }

        let train = Array(points.prefix(trainCount))
        let actual = Array(points[trainCount..<trainCount + horizon])
        let trainSeries = PriceSeries(
            symbol: series.symbol,
            assetClass: series.assetClass,
            points: train,
            isSample: series.isSample
        )

        // Backtest the raw method (no macro tilt) so it reflects the model itself.
        let projected = forecast(series: trainSeries, model: model, horizon: horizon).points
        guard projected.count == horizon else { return nil }

        var errorSum = 0.0
        var counted = 0
        for (predicted, real) in zip(projected, actual) where real.close != 0 {
            errorSum += abs(predicted.mean - real.close) / abs(real.close)
            counted += 1
        }
        guard counted > 0 else { return nil }
        return errorSum / Double(counted)
    }

    // MARK: - Model agreement

    /// How much the base methods disagree about the horizon outcome — the
    /// standard deviation of their expected % change. Higher = less agreement
    /// = a less reliable read. Nil when fewer than two methods produce a result.
    /// (Excludes the ensemble, which is itself a blend of the others.)
    static func modelDisagreement(series: PriceSeries, horizon: Int) -> Double? {
        let strategies: [ForecastStrategy] = [.drift, .trendSeasonal, .linear, .holt, .momentum, .reversion]
        let changes = strategies.compactMap { strategy -> Double? in
            guard let model = ForecastModel.model(id: strategy.rawValue) else { return nil }
            return forecast(series: series, model: model, horizon: horizon).expectedChange
        }
        guard changes.count >= 2 else { return nil }
        return Math.standardDeviation(changes)
    }

    // MARK: - Macro tilt

    /// Scales each step toward `horizonBias` by step/horizon and widens bands.
    private static func applyMacro(
        _ points: [ForecastPoint],
        macro: MacroAdjustment,
        horizon: Int
    ) -> [ForecastPoint] {
        guard horizon > 0 else { return points }
        return points.enumerated().map { index, point in
            let progress = Double(index + 1) / Double(horizon)
            let factor = 1 + macro.horizonBias * progress
            let mean = max(0, point.mean * factor)
            let half = (point.upper - point.mean) * macro.bandScale
            return ForecastPoint(
                date: point.date,
                mean: mean,
                lower: max(0, mean - half),
                upper: max(0, mean + half)
            )
        }
    }

    // MARK: - Projection

    private static func project(
        context: TrendContext,
        strategy: ForecastStrategy,
        horizon: Int,
        assetClass: AssetClass
    ) -> [ForecastPoint] {
        var result: [ForecastPoint] = []
        let bandScale = context.bandScale(for: strategy)

        // Spot anchoring (t0 ≡ Pspot): re-center the whole projection so its
        // step-0 value lands exactly on the last real price, then let each
        // model's own trend/shape carry forward. Without this, smoothed or
        // fitted models (Holt, linear, trend+seasonal) start on a lagging
        // baseline and render a "ghost drop" from spot after a gap event.
        let anchorOffset = context.lastClose
            - context.baseline(strategy: strategy, step: 0, date: context.lastDate)

        // Each step is one *trading day* ahead — the unit every model is fit in
        // (drift = mean per-trading-day change, Holt trend per step, etc.). The
        // dates come from the asset's trading calendar so a stock sketch never
        // lands a point on a weekend/holiday (crypto trades every day), and the
        // date each value is shown on matches the step it was computed for.
        let dates = MarketCalendar.tradingDates(after: context.lastDate, count: horizon, assetClass: assetClass)
        result.reserveCapacity(dates.count)

        for (index, date) in dates.enumerated() {
            let step = index + 1
            let baseline = context.baseline(strategy: strategy, step: step, date: date) + anchorOffset
            // Uncalibrated residual band — educational range, not a verified PI.
            let band = bandScale * sqrt(Double(step)) * 1.28

            result.append(
                ForecastPoint(
                    date: date,
                    mean: max(0, baseline),
                    lower: max(0, baseline - band),
                    upper: max(0, baseline + band)
                )
            )
        }

        return result
    }

    /// Phoenix: equal-weight blend of Skylark, Meadowlark, and Peregrine.
    private static func ensemblePoints(context: TrendContext, horizon: Int, assetClass: AssetClass) -> [ForecastPoint] {
        let constituents: [ForecastStrategy] = [.trendSeasonal, .linear, .momentum]
        let series = constituents.map { project(context: context, strategy: $0, horizon: horizon, assetClass: assetClass) }
        guard let first = series.first, !first.isEmpty else { return [] }

        return first.indices.map { index in
            let means = series.map { $0[index].mean }
            let lowers = series.map { $0[index].lower }
            let uppers = series.map { $0[index].upper }
            let count = Double(constituents.count)

            return ForecastPoint(
                date: first[index].date,
                mean: means.reduce(0, +) / count,
                lower: lowers.reduce(0, +) / count,
                upper: uppers.reduce(0, +) / count
            )
        }
    }
}

// MARK: - Trend context

private struct TrendContext {
    let closes: [Double]
    let count: Int
    let slope: Double
    let intercept: Double
    let residualStd: Double
    let seasonal: [Int: Double]
    let lastClose: Double
    let ema: Double
    let sma: Double
    let lastDate: Date
    /// Average one-step change (random-walk-with-drift).
    let drift: Double
    let diffStd: Double
    /// Holt linear level & trend at the end of history.
    let holtLevel: Double
    let holtTrend: Double
    let holtResidualStd: Double

    init(points: [PricePoint]) {
        let closes = points.map(\.close)
        let n = closes.count
        let xs = (0..<n).map(Double.init)
        let (slope, intercept) = Math.linearFit(x: xs, y: closes)
        let fitted = xs.map { slope * $0 + intercept }
        let residuals = zip(closes, fitted).map { $0 - $1 }

        var diffs: [Double] = []
        if n > 1 {
            diffs.reserveCapacity(n - 1)
            for i in 1..<n {
                diffs.append(closes[i] - closes[i - 1])
            }
        }
        let drift = diffs.isEmpty ? 0 : diffs.reduce(0, +) / Double(diffs.count)
        let diffStd = Math.standardDeviation(diffs)

        // 3σ gap detection over a ~21-day lookback so an earnings breakout
        // re-baselines the level instantly instead of lagging behind spot.
        let holt = Math.holtLinear(closes, alpha: 0.3, beta: 0.1, gapSigmaThreshold: 3)

        self.closes = closes
        self.count = n
        self.slope = slope
        self.intercept = intercept
        self.residualStd = Math.standardDeviation(residuals)
        self.seasonal = Math.weekdaySeasonality(points: points, residuals: residuals)
        self.lastClose = closes[n - 1]
        self.ema = Math.exponentialMovingAverage(closes, period: min(20, n / 2))
        self.sma = Math.simpleMovingAverage(closes, period: min(20, n))
        self.lastDate = points[n - 1].date
        self.drift = drift
        self.diffStd = diffStd
        self.holtLevel = holt.level
        self.holtTrend = holt.trend
        self.holtResidualStd = holt.residualStd
    }

    /// Per-model uncertainty scale — each family's band reflects *its own* error,
    /// not one borrowed from the linear fit.
    func bandScale(for strategy: ForecastStrategy) -> Double {
        switch strategy {
        case .drift, .momentum, .reversion:
            // Level extrapolations from spot — scale by one-step price-change
            // volatility (the random-walk step size).
            return diffStd > 0 ? diffStd : residualStd
        case .holt:
            // Holt's own one-step smoothing residuals.
            return holtResidualStd > 0 ? holtResidualStd : residualStd
        case .linear, .trendSeasonal, .ensemble:
            // Trend fits — deviation from the fitted line.
            return residualStd
        }
    }

    func baseline(strategy: ForecastStrategy, step: Int, date: Date) -> Double {
        let futureX = Double(count - 1 + step)

        switch strategy {
        case .drift:
            return lastClose + drift * Double(step)

        case .holt:
            return holtLevel + holtTrend * Double(step)

        case .linear:
            return slope * futureX + intercept

        case .momentum:
            // Extrapolate how far price sits above/below its EMA, per step. No
            // amplifier — the raw recent slope, so momentum doesn't structurally
            // exaggerate beyond what the data shows.
            let lookback = max(1, min(20, count / 2))
            let recentSlope = (lastClose - ema) / Double(lookback)
            return lastClose + recentSlope * Double(step)

        case .reversion:
            let decay = 1.0 - exp(-Double(step) / 10.0)
            return lastClose + (sma - lastClose) * decay

        case .trendSeasonal, .ensemble:
            let weekday = Calendar(identifier: .gregorian).component(.weekday, from: date)
            return slope * futureX + intercept + (seasonal[weekday] ?? 0)
        }
    }
}

// MARK: - Math

enum Math {
    static func linearFit(x: [Double], y: [Double]) -> (slope: Double, intercept: Double) {
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

    static func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count - 1)
        return sqrt(variance)
    }

    static func weekdaySeasonality(points: [PricePoint], residuals: [Double]) -> [Int: Double] {
        let calendar = Calendar(identifier: .gregorian)
        var buckets: [Int: [Double]] = [:]
        for (point, residual) in zip(points, residuals) {
            let weekday = calendar.component(.weekday, from: point.date)
            buckets[weekday, default: []].append(residual)
        }
        return buckets.mapValues { $0.reduce(0, +) / Double($0.count) }
    }

    static func exponentialMovingAverage(_ values: [Double], period: Int) -> Double {
        guard !values.isEmpty else { return 0 }
        let p = max(1, period)
        let k = 2.0 / (Double(p) + 1.0)
        var ema = values[0]
        for value in values.dropFirst() {
            ema = value * k + ema * (1 - k)
        }
        return ema
    }

    static func simpleMovingAverage(_ values: [Double], period: Int) -> Double {
        guard !values.isEmpty else { return 0 }
        let p = max(1, min(period, values.count))
        let window = values.suffix(p)
        return window.reduce(0, +) / Double(window.count)
    }

    /// Holt’s linear (additive trend) exponential smoothing.
    ///
    /// When `gapSigmaThreshold` is set, a one-step change larger than
    /// `threshold ×` the rolling standard deviation of recent changes (over
    /// `gapLookback` steps) is treated as a **discontinuity** — an earnings
    /// gap or overnight breakout. On such a step the level snaps straight to
    /// the new price (equivalent to α→1 for that transition) and the trend is
    /// held at its pre-gap value, so a one-off jump neither lags behind spot
    /// nor inflates into a runaway trend.
    static func holtLinear(
        _ values: [Double],
        alpha: Double,
        beta: Double,
        gapSigmaThreshold: Double? = nil,
        gapLookback: Int = 21
    ) -> (level: Double, trend: Double, residualStd: Double) {
        guard let first = values.first else { return (0, 0, 0) }
        guard values.count > 1 else { return (first, 0, 0) }

        var level = first
        var trend = values[1] - values[0]
        var residuals: [Double] = []
        residuals.reserveCapacity(values.count - 1)
        var diffs: [Double] = []

        for value in values.dropFirst() {
            let forecast = level + trend
            residuals.append(value - forecast)
            let prevLevel = level
            let change = value - prevLevel

            var isGap = false
            if let threshold = gapSigmaThreshold, diffs.count >= 2 {
                let window = Array(diffs.suffix(gapLookback))
                let sd = standardDeviation(window)
                if sd > 0, abs(change) > threshold * sd { isGap = true }
            }

            if isGap {
                level = value            // accept the new baseline instantly (α→1)
                // trend held: don't let a one-off gap become a runaway slope
            } else {
                level = alpha * value + (1 - alpha) * (prevLevel + trend)
                trend = beta * (level - prevLevel) + (1 - beta) * trend
            }
            diffs.append(change)
        }

        return (level, trend, standardDeviation(residuals))
    }
}

import Foundation

/// Picks the method that has tracked a given asset best recently (lowest
/// walk-forward error) and builds the compact snapshot the widget/Siri render.
/// This is an honest track-record read of the past — never a buy/sell signal.
enum WatchlistIntelligence {
    static let defaultHorizon = 30
    private static let sparkPoints = 24

    /// Lowest walk-forward-error available model for a series, plus its forecast.
    static func best(for series: PriceSeries, horizon: Int = defaultHorizon) -> (model: ForecastModel, forecast: Forecast)? {
        guard series.isForecastable else { return nil }
        let scored = ForecastModel.available.compactMap { model -> (ForecastModel, Double)? in
            guard let error = Forecaster.walkForwardMAPE(series: series, model: model) else { return nil }
            return (model, error)
        }
        let model = scored.min(by: { $0.1 < $1.1 })?.0 ?? .default
        return (model, Forecaster.forecast(series: series, model: model, horizon: horizon))
    }

    static func snapshot(for item: WatchlistItem, series: PriceSeries, horizon: Int = defaultHorizon) -> WatchlistSnapshot? {
        guard let last = series.points.last,
              let (model, forecast) = best(for: series, horizon: horizon) else { return nil }

        let historyTail = Array(series.points.suffix(sparkPoints)).map(\.close)
        let projection = forecast.points.map(\.mean)
        let combined = historyTail + projection
        guard let lo = combined.min(), let hi = combined.max() else { return nil }

        func normalize(_ values: [Double]) -> [Double] {
            hi > lo ? values.map { ($0 - lo) / (hi - lo) } : values.map { _ in 0.5 }
        }

        return WatchlistSnapshot(
            symbol: item.symbol,
            assetClass: item.assetClass,
            title: item.title,
            price: last.close,
            projectedChange: forecast.expectedChange ?? 0,
            bestMethodName: model.name,
            horizonDays: horizon,
            historySpark: normalize(historyTail),
            projectionSpark: normalize(projection),
            updatedAt: .now
        )
    }
}

import Foundation

/// A single daily observation.
struct PricePoint: Identifiable, Hashable, Sendable {
    var id: Date { date }
    let date: Date
    let close: Double
}

/// Historical series returned by the data layer.
struct PriceSeries: Sendable {
    let symbol: String
    let assetClass: AssetClass
    let points: [PricePoint]
    /// True when the series is synthetic sample data (network unavailable).
    let isSample: Bool

    var last: PricePoint? { points.last }
    var first: PricePoint? { points.first }

    var isForecastable: Bool { points.count >= Forecaster.minimumHistoryCount }
}

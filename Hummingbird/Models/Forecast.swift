import Foundation

/// A single forecasted day with an uncertainty band.
struct ForecastPoint: Identifiable, Hashable, Sendable {
    var id: Date { date }
    let date: Date
    let mean: Double
    let lower: Double
    let upper: Double

    var bandHalfWidth: Double { max(0, upper - mean) }
}

/// Complete forecast result for a chosen model and horizon.
struct Forecast: Sendable {
    let model: ForecastModel
    let history: [PricePoint]
    let points: [ForecastPoint]
    let macro: MacroAdjustment

    init(
        model: ForecastModel,
        history: [PricePoint],
        points: [ForecastPoint],
        macro: MacroAdjustment = .none
    ) {
        self.model = model
        self.history = history
        self.points = points
        self.macro = macro
    }

    var targetPrice: Double? { points.last?.mean }
    var targetDate: Date? { points.last?.date }
    var lastClose: Double? { history.last?.close }

    /// Expected total change over the horizon, as a fraction.
    var expectedChange: Double? {
        guard let last = lastClose, let target = targetPrice, last != 0 else { return nil }
        return (target - last) / last
    }

    var isEmpty: Bool { points.isEmpty }
}

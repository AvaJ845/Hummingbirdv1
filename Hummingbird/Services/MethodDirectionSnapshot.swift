import Foundation

/// Snapshot what each available forecasting method calls the direction over a
/// horizon, from an already-fetched series — no network. Shared by the call
/// logging flow (`ForecastViewModel`, with the user's selected macro context)
/// and the practice-portfolio buy flow (no macro context — that flow has no
/// indicator-selection UI of its own), so "what did the methods say" means the
/// same thing in both places.
enum MethodDirectionSnapshot {
    static func compute(
        series: PriceSeries, horizon: Int,
        macro: (ForecastModel) -> MacroAdjustment = { _ in .none }
    ) -> [String: CallDirection] {
        var result: [String: CallDirection] = [:]
        for candidate in ForecastModel.available {
            let projection = Forecaster.forecast(series: series, model: candidate, horizon: horizon,
                                                 macro: macro(candidate))
            if let change = projection.expectedChange, change != 0 {
                result[candidate.strategy.rawValue] = change > 0 ? .higher : .lower
            }
        }
        return result
    }
}

import Foundation

/// Plain-English, honest explanation of *why* a projection looks the way it does.
/// Describes the drivers (trend, method behavior, macro nudge, disagreement) —
/// never a reason to act. Pure and testable.
enum SketchExplainer {
    static func drivers(forecast: Forecast, disagreementSpread: Double?) -> [String] {
        var lines: [String] = []

        let change = forecast.expectedChange ?? 0
        let direction = change >= 0 ? "higher" : "lower"
        lines.append("\(forecast.model.name) projects \(change.asSignedPercent()) over \(forecast.points.count) days — it reads the recent path as pointing \(direction).")

        switch forecast.model.strategy {
        case .trendSeasonal:
            lines.append("It fits a straight trend through recent closes and adds a small weekday pattern.")
        case .linear:
            lines.append("It fits one straight line through recent prices and extends it.")
        case .drift:
            lines.append("It carries forward the average day-to-day change from recent history.")
        case .holt:
            lines.append("It smooths a separate level and trend, then extends both forward.")
        case .momentum:
            lines.append("Recent prices have been running above or below their short average, so it leans that way.")
        case .reversion:
            lines.append("Prices look stretched from their average, so it eases back toward it.")
        case .ensemble:
            lines.append("It averages several simple methods into one smoother path.")
        }

        if forecast.macro.isActive {
            lines.append("Your selected rate what-ifs nudge the path by \(forecast.macro.displayBias).")
        }

        if let spread = disagreementSpread {
            lines.append("The methods disagree by \(spread.asSignedPercent()) — wider disagreement means less certainty.")
        }

        lines.append("This explains the sketch — it isn't a reason to buy or sell.")
        return lines
    }
}

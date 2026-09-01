import Foundation

/// Plain-language copy for newcomers — Robinhood-simple, not academic.
enum RetailExplainer {
    /// Short headline: direction over the horizon.
    static func headline(
        symbol: String,
        forecast: Forecast,
        horizon: Int
    ) -> String {
        let name = symbol.uppercased()
        guard let change = forecast.expectedChange else {
            return "Not enough price history yet for \(name)."
        }

        let direction: String
        if change > 0.01 {
            direction = "a bit higher"
        } else if change < -0.01 {
            direction = "a bit lower"
        } else {
            direction = "about the same"
        }

        return "\(name) over the next \(horizon) days: \(direction) (\(change.asSignedPercent()))."
    }

    /// One short supporting paragraph — what the app actually did.
    static func bottomLine(
        symbol: String,
        forecast: Forecast,
        disagreementSpread: Double?,
        horizon: Int
    ) -> String {
        let name = symbol.uppercased()
        guard forecast.expectedChange != nil,
              let low = forecast.points.last?.lower,
              let high = forecast.points.last?.upper else {
            return "We need more public price history for \(name) before we can show a projection."
        }

        var text = "We looked at recent public prices for \(name) and used \(forecast.model.name) to sketch a path about \(horizon) days ahead. "
        text += "The shaded area is a possible range from \(low.asCurrency()) to \(high.asCurrency()). "

        if let spread = disagreementSpread, spread > 0.02 {
            text += "Other methods in the app see a different path (about \(spread.asSignedPercent()) apart) — that’s normal; compare them below. "
        } else if disagreementSpread != nil {
            text += "The methods we compared are pointing in a similar direction right now. "
        }

        text += "Explore the sketch — markets can move differently."
        return text
    }

    static func bandCaption(for forecast: Forecast) -> String {
        guard let last = forecast.points.last else {
            return "Range unavailable"
        }
        return "\(last.lower.asCurrency()) – \(last.upper.asCurrency())"
    }

    static func disagreementPlain(_ spread: Double?) -> String {
        guard let spread else {
            return "Run a projection to compare methods."
        }
        if spread < 0.015 {
            return "Close — methods are roughly aligned."
        }
        if spread < 0.05 {
            return "Some difference — check more than one method."
        }
        return "Quite different — look at a few methods, not just one."
    }

    static func scenarioNudgePlain(_ macro: MacroAdjustment, horizon: Int) -> String {
        guard macro.isActive else {
            return "Off — projection uses price history only."
        }
        let tone: String
        if macro.horizonBias > 0.005 {
            tone = "a little more upbeat"
        } else if macro.horizonBias < -0.005 {
            tone = "a little more cautious"
        } else {
            tone = "almost unchanged"
        }
        return "Your economy toggles make this \(horizon)-day path \(tone) (\(macro.displayBias)). Optional context only."
    }
}

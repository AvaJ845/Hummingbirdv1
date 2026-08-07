import Foundation
import SwiftUI

/// The North Star made quantitative: an honest, calibrated read on **how much
/// to trust a given sketch right now** — blending the model's own backtest
/// accuracy, the current volatility regime, how much the methods agree, the
/// horizon, and how much history we have. Pure and deterministic.
enum ReliabilityTier: String, Sendable {
    case low, moderate, good

    var title: String {
        switch self {
        case .good: "Reasonably reliable"
        case .moderate: "Read with caution"
        case .low: "Rough sketch"
        }
    }

    var color: Color {
        switch self {
        case .good: Theme.up
        case .moderate: Color(red: 0.95, green: 0.68, blue: 0.20)
        case .low: Theme.down
        }
    }

    var symbol: String {
        switch self {
        case .good: "checkmark.seal"
        case .moderate: "exclamationmark.circle"
        case .low: "questionmark.circle"
        }
    }
}

struct ReliabilityFactor: Identifiable, Hashable, Sendable {
    let name: String
    let detail: String
    /// Signed contribution to the score (negative = reduces reliability).
    let impact: Int
    var id: String { name }
}

struct ReliabilityScore: Equatable, Sendable {
    let value: Int              // 0…100
    let tier: ReliabilityTier
    let headline: String
    let factors: [ReliabilityFactor]
}

struct ReliabilityInputs: Sendable {
    let backtestMAPE: Double?      // e.g. 0.05 = 5% typical backtest error
    let regime: VolatilityRegime?
    let modelDisagreement: Double? // std of expected % change across methods (fraction)
    let horizon: Int
    let historyCount: Int
}

enum ReliabilityEngine {
    static func score(_ inputs: ReliabilityInputs) -> ReliabilityScore {
        // Integer impacts so the on-screen ledger foots exactly:
        // value == 50 + Σ(impacts), clamped.
        var factors: [ReliabilityFactor] = []

        // Base: the model's own tracked backtest accuracy, as a swing from 50.
        if let mape = inputs.backtestMAPE {
            let level = min(98, max(5, 100 - mape * 500))   // 5% error → 75, 10% → 50
            factors.append(ReliabilityFactor(
                name: "Backtest accuracy",
                detail: String(format: "Typical backtest error %.1f%%", mape * 100),
                impact: Int(level.rounded()) - 50))
        } else {
            factors.append(ReliabilityFactor(name: "Backtest accuracy",
                                             detail: "Not enough history to backtest", impact: 0))
        }

        // Volatility regime.
        let regimeImpact: Int = {
            switch inputs.regime {
            case .high: return -25
            case .elevated: return -12
            default: return 0
            }
        }()
        if regimeImpact != 0 {
            factors.append(ReliabilityFactor(name: "Volatility",
                                             detail: "\(inputs.regime?.title ?? "Elevated") right now",
                                             impact: regimeImpact))
        }

        // How much the methods disagree.
        if let disagreement = inputs.modelDisagreement {
            let impact = -Int(min(25, disagreement * 250).rounded())
            if impact != 0 {
                factors.append(ReliabilityFactor(
                    name: "Method agreement",
                    detail: String(format: "Methods differ by ~%.1f%%", disagreement * 100),
                    impact: impact))
            }
        }

        // Longer horizons are less reliable.
        let horizonImpact = -Int(min(15, max(0, Double(inputs.horizon - 14) * 0.3)).rounded())
        if horizonImpact != 0 {
            factors.append(ReliabilityFactor(name: "Horizon",
                                             detail: "\(inputs.horizon)-day projection", impact: horizonImpact))
        }

        // Thin history is less reliable.
        let historyImpact = -Int(min(10, max(0, Double(30 - inputs.historyCount) * 0.5)).rounded())
        if historyImpact != 0 {
            factors.append(ReliabilityFactor(name: "History depth",
                                             detail: "\(inputs.historyCount) days of history", impact: historyImpact))
        }

        let value = max(0, min(100, 50 + factors.reduce(0) { $0 + $1.impact }))
        let tier: ReliabilityTier = value >= 70 ? .good : (value >= 45 ? .moderate : .low)
        return ReliabilityScore(value: value, tier: tier, headline: headline(for: tier), factors: factors)
    }

    static func headline(for tier: ReliabilityTier) -> String {
        switch tier {
        case .good:
            return "This method has tracked well and conditions are steady. Still a sketch, not a prediction."
        case .moderate:
            return "A few things lower confidence right now — read this sketch with wider error bars."
        case .low:
            return "Low reliability right now. Treat this as a very rough sketch, nothing more."
        }
    }
}

import Foundation

/// Translates selected live rate snapshots into a transparent *scenario nudge*.
///
/// This is a what-if mood ring with citations — not identification of β.
/// Each selected series contributes a signed bias; the active model scales
/// how strongly that nudge is applied (momentum leans in, reversion dampens).
enum MacroAdjuster {
    /// Maximum absolute horizon impact from the scenario nudge (±8%).
    static let maxHorizonBias = 0.08

    static func adjustment(
        from snapshots: [EconomicSnapshot],
        selected: Set<String>,
        assetClass: AssetClass,
        model: ForecastModel = .default
    ) -> MacroAdjustment {
        let active = snapshots.filter { selected.contains($0.kind.id) }
        guard !active.isEmpty else { return .none }

        let riskScale = assetClass == .crypto ? 1.25 : 1.0
        let modelScale = max(0, model.macroSensitivity)
        var contributions: [MacroContribution] = []

        for snapshot in active {
            let (raw, rationale) = signal(for: snapshot)
            let bias = raw * riskScale * modelScale * snapshot.kind.cadenceWeight * 0.035
            contributions.append(
                MacroContribution(
                    indicatorID: snapshot.kind.id,
                    name: snapshot.kind.name,
                    bias: bias,
                    rationale: rationale
                )
            )
        }

        let meanBias = contributions.map(\.bias).reduce(0, +) / Double(contributions.count)
        let horizonBias = clamp(meanBias, min: -maxHorizonBias, max: maxHorizonBias)

        let signs = Set(contributions.map { $0.bias == 0 ? 0 : ($0.bias > 0 ? 1 : -1) })
        let conflict = signs.contains(1) && signs.contains(-1)
        let bandScale = 1.0
            + min(0.35, abs(horizonBias) * 2.5)
            + (conflict ? 0.15 : 0)

        return MacroAdjustment(
            horizonBias: horizonBias,
            bandScale: bandScale,
            contributions: contributions
        )
    }

    /// Returns a unitless signal roughly in [-1, 1] plus a short rationale.
    static func signal(for snapshot: EconomicSnapshot) -> (Double, String) {
        let change = snapshot.change ?? 0

        switch snapshot.kind {
        case .fedFunds:
            let level = -clamp((snapshot.value - 2.5) / 4.0, min: -1, max: 1)
            let trend = -clamp(change / 0.5, min: -1, max: 1)
            let signal = clamp(0.65 * level + 0.35 * trend, min: -1, max: 1)
            let rationale = change >= 0
                ? "Short rates elevated/rising — tighter conditions."
                : "Short rates easing — more supportive for risk."
            return (signal, rationale)

        case .treasury10Y:
            let level = -clamp((snapshot.value - 3.0) / 3.0, min: -1, max: 1)
            let trend = -clamp(change / 0.4, min: -1, max: 1)
            let signal = clamp(0.6 * level + 0.4 * trend, min: -1, max: 1)
            let rationale = change >= 0
                ? "Long yields rising — weighs on valuations."
                : "Long yields falling — supports valuations."
            return (signal, rationale)
        }
    }

    private static func clamp(_ value: Double, min: Double, max: Double) -> Double {
        Swift.min(max, Swift.max(min, value))
    }
}

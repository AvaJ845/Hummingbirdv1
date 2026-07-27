import Foundation

/// Live daily rate series only — annual macros were removed (too stale for ≤90d sketches).
enum EconomicIndicatorKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case fedFunds = "fedfunds"
    case treasury10Y = "t10y"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .fedFunds: "Fed Funds Proxy"
        case .treasury10Y: "10-Year Treasury"
        }
    }

    var detail: String {
        switch self {
        case .fedFunds:
            "Yahoo ^IRX (13-week T-bill) as a short-rate proxy. Rising yields can pressure risk assets."
        case .treasury10Y:
            "Yahoo ^TNX. Higher long yields can weigh on stocks and crypto."
        }
    }

    var systemImage: String {
        switch self {
        case .fedFunds: "building.columns"
        case .treasury10Y: "percent"
        }
    }

    var sourceLabel: String { "Yahoo Finance" }

    /// Reporting cadence — daily yields only.
    var cadence: String { "Daily" }

    /// How strongly this cadence should influence a short-horizon sketch (≤90d).
    var cadenceWeight: Double { 1.0 }
}

/// A live observation used both in the picker and in macro tilt math.
struct EconomicSnapshot: Identifiable, Hashable, Sendable {
    var id: String { kind.id }
    let kind: EconomicIndicatorKind
    /// Current level in percent terms (e.g. 4.25 means 4.25%).
    let value: Double
    /// Prior comparable observation for trend (may be nil).
    let previousValue: Double?
    let asOf: Date
    let source: String
    let isSample: Bool

    var change: Double? {
        guard let previousValue else { return nil }
        return value - previousValue
    }

    var displayValue: String {
        String(format: "%.2f%%", value)
    }

    var displayChange: String? {
        guard let change else { return nil }
        return String(format: "%@%.2f pp", change >= 0 ? "+" : "", change)
    }

    var asOfLabel: String {
        if isSample { return "Unavailable · \(kind.cadence)" }
        return "\(asOf.formatted(.dateTime.year().month().day())) · \(kind.cadence) · \(source)"
    }
}

/// One indicator's contribution to the macro tilt.
struct MacroContribution: Identifiable, Hashable, Sendable {
    var id: String { indicatorID }
    let indicatorID: String
    let name: String
    /// Share of total horizon bias attributed to this indicator (fraction).
    let bias: Double
    let rationale: String
}

/// Aggregate macro effect applied on top of the statistical forecast.
struct MacroAdjustment: Hashable, Sendable {
    /// Expected total price impact over the full horizon (fraction, e.g. -0.02 = −2%).
    let horizonBias: Double
    /// Multiplier on uncertainty bands (≥ 1).
    let bandScale: Double
    let contributions: [MacroContribution]

    static let none = MacroAdjustment(horizonBias: 0, bandScale: 1, contributions: [])

    var isActive: Bool { !contributions.isEmpty && abs(horizonBias) > 0.0005 }

    var displayBias: String { horizonBias.asSignedPercent() }
}

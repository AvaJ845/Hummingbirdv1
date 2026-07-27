import Foundation

/// Paid capabilities. Free tier stays useful for literacy; Pro unlocks comparison depth.
enum ProFeature: String, CaseIterable, Identifiable, Sendable {
    case advancedModels
    case longHorizon
    case disagreementLab

    var id: String { rawValue }

    var title: String {
        switch self {
        case .advancedModels: "More methods to compare"
        case .longHorizon: "Longer sketch windows"
        case .disagreementLab: "Compare every method"
        }
    }

    var detail: String {
        switch self {
        case .advancedModels:
            "Compare Momentum, Mean reversion, and Blend beside the free methods — same public data, more paths to compare."
        case .longHorizon:
            "Stretch sketches from 30 days up to 90 days. Wider window, same honesty."
        case .disagreementLab:
            "See every method’s path side by side — check whether they agree."
        }
    }

    var systemImage: String {
        switch self {
        case .advancedModels: "arrow.left.arrow.right"
        case .longHorizon: "calendar"
        case .disagreementLab: "square.split.2x1"
        }
    }
}

enum FreeTierLimits {
    static let maxHorizonDays = 30
    /// Both live daily rate knobs are free (catalogue is only two series).
    static let maxSelectedIndicators = EconomicIndicatorKind.allCases.count
    static let freeModelIDs: Set<String> = [
        ForecastStrategy.drift.rawValue,
        ForecastStrategy.trendSeasonal.rawValue,
        ForecastStrategy.linear.rawValue,
        ForecastStrategy.holt.rawValue
    ]
}

extension ForecastModel {
    var requiresPro: Bool {
        !FreeTierLimits.freeModelIDs.contains(id)
    }
}

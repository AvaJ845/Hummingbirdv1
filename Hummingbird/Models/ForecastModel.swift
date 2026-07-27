import Foundation

/// Catalogue of on-device projection strategies.
/// UI leads with plain method titles. Bird nicknames are internal-only (never “Swift”, never shown in UI).
struct ForecastModel: Identifiable, Hashable, Sendable {
    let id: String
    /// Primary UI label — plain method name (Drift, Holt, Momentum…).
    let name: String
    /// Internal nickname for tests / docs — not shown in the product UI.
    let nickname: String
    let tagline: String
    /// One sentence a retail investor can understand.
    let plainEnglish: String
    /// Short family label: Trend / Momentum / Reversion / Blend / Classic.
    let familyLabel: String
    let methodSummary: String
    let confidence: Confidence
    let status: Status
    let systemImage: String
    /// How strongly selected scenario nudges affect this model (1.0 = baseline).
    let macroSensitivity: Double

    enum Confidence: String, Sendable {
        case high = "High"
        case medium = "Medium"
        case experimental = "Experimental"

        /// Retail-facing label — avoids implying statistical confidence.
        var retailLabel: String {
            switch self {
            case .high: "Steady"
            case .medium: "Typical"
            case .experimental: "Experimental"
            }
        }
    }

    enum Status: String, Sendable {
        case ready = "Ready"
        case beta = "Beta"

        var isAvailable: Bool { true }
    }

    var strategy: ForecastStrategy {
        ForecastStrategy(rawValue: id) ?? .trendSeasonal
    }

    static let all: [ForecastModel] = [
        ForecastModel(
            id: ForecastStrategy.drift.rawValue,
            name: "Drift",
            nickname: "Starling",
            tagline: "Classic baseline: keep the recent average daily change going.",
            plainEnglish: "Takes the average day-to-day change from recent prices and continues that pace. A common textbook starting point.",
            familyLabel: "Classic",
            methodSummary: "Random walk with drift — last price plus h × average historical daily change. Standard forecasting baseline.",
            confidence: .medium,
            status: .ready,
            systemImage: "arrow.right",
            macroSensitivity: 0.6
        ),
        ForecastModel(
            id: ForecastStrategy.trendSeasonal.rawValue,
            name: "Trend + weekday",
            nickname: "Skylark",
            tagline: "Follows the recent trend, with a weekly wiggle.",
            plainEnglish: "Draws a trend line through recent prices and adds a small weekday pattern.",
            familyLabel: "Trend",
            methodSummary: "Fits a trend through recent closes, adds a small weekday pattern, and shows a possible range around the path.",
            confidence: .medium,
            status: .ready,
            systemImage: "waveform.path.ecg",
            macroSensitivity: 1.0
        ),
        ForecastModel(
            id: ForecastStrategy.linear.rawValue,
            name: "Straight trend",
            nickname: "Meadowlark",
            tagline: "The simplest trend line — smooth and calm.",
            plainEnglish: "Fits one straight trend through recent prices and extends it.",
            familyLabel: "Trend",
            methodSummary: "Straight-line trend through history, extended forward. Simple and easy to read.",
            confidence: .medium,
            status: .ready,
            systemImage: "line.diagonal.arrow",
            macroSensitivity: 0.7
        ),
        ForecastModel(
            id: ForecastStrategy.holt.rawValue,
            name: "Holt",
            nickname: "Osprey",
            tagline: "Smooths level and trend the way classic forecast textbooks do.",
            plainEnglish: "Separates a smooth level and a smooth trend from recent prices, then extends both forward.",
            familyLabel: "Classic",
            methodSummary: "Holt’s linear exponential smoothing (level + trend). Classic ETS-family method used widely in forecasting courses.",
            confidence: .medium,
            status: .ready,
            systemImage: "water.waves",
            macroSensitivity: 0.9
        ),
        ForecastModel(
            id: ForecastStrategy.momentum.rawValue,
            name: "Momentum",
            nickname: "Peregrine",
            tagline: "Assumes recent direction keeps going for a bit.",
            plainEnglish: "If price has been running above or below its recent average, this leans that way for a while.",
            familyLabel: "Momentum",
            methodSummary: "Leans with recent strength or weakness versus a short moving average.",
            confidence: .medium,
            status: .ready,
            systemImage: "bolt.fill",
            macroSensitivity: 1.3
        ),
        ForecastModel(
            id: ForecastStrategy.reversion.rawValue,
            name: "Mean reversion",
            nickname: "Kingfisher",
            tagline: "Assumes extremes fade back toward average.",
            plainEnglish: "If price looks stretched from its average, this gently pulls it back toward that average.",
            familyLabel: "Reversion",
            methodSummary: "Pulls stretched prices back toward a short moving average over time.",
            confidence: .experimental,
            status: .beta,
            systemImage: "arrow.uturn.down",
            macroSensitivity: 0.4
        ),
        ForecastModel(
            id: ForecastStrategy.ensemble.rawValue,
            name: "Blend",
            nickname: "Phoenix",
            tagline: "Averages three methods into one smoother path.",
            plainEnglish: "Averages Trend + weekday, Straight trend, and Momentum into one smoother path. Handy overview — still just a sketch.",
            familyLabel: "Blend",
            methodSummary: "Average of three simple methods. Smoother to look at; still built from the same public history.",
            confidence: .experimental,
            status: .beta,
            systemImage: "sparkles",
            macroSensitivity: 1.0
        )
    ]

    static let `default` = all.first { $0.id == ForecastStrategy.trendSeasonal.rawValue } ?? all[0]

    static var available: [ForecastModel] {
        all.filter(\.status.isAvailable)
    }

    static func model(id: String) -> ForecastModel? {
        all.first { $0.id == id }
    }
}

enum ForecastStrategy: String, CaseIterable, Sendable {
    case drift = "drift"
    case trendSeasonal = "trend-seasonal"
    case linear = "linear"
    case holt = "holt"
    case momentum = "momentum"
    case reversion = "reversion"
    case ensemble = "ensemble"
}

struct ModelForecastPreview: Identifiable, Hashable, Sendable {
    var id: String { model.id }
    let model: ForecastModel
    let targetPrice: Double
    let expectedChange: Double
    let macroBias: Double
}

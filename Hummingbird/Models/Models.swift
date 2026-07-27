import Foundation

// MARK: - Asset

enum AssetClass: String, CaseIterable, Identifiable, Codable {
    case stock = "Stock"
    case crypto = "Crypto"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .stock: return "chart.line.uptrend.xyaxis"
        case .crypto: return "bitcoinsign.circle"
        }
    }

    var placeholder: String {
        switch self {
        case .stock: return "AAPL"
        case .crypto: return "bitcoin"
        }
    }

    var hint: String {
        switch self {
        case .stock: return "Ticker symbol, e.g. AAPL, MSFT, NVDA"
        case .crypto: return "Coin id, e.g. bitcoin, ethereum, solana"
        }
    }
}

/// A single daily observation.
struct PricePoint: Identifiable, Hashable {
    var id: Date { date }
    let date: Date
    let close: Double
}

/// Historical series returned by the data layer.
struct PriceSeries {
    let symbol: String
    let assetClass: AssetClass
    let points: [PricePoint]
    /// True when the series is synthetic sample data (network unavailable).
    let isSample: Bool

    var last: PricePoint? { points.last }
    var first: PricePoint? { points.first }
}

// MARK: - Forecast

/// A single forecasted day with an uncertainty band.
struct ForecastPoint: Identifiable, Hashable {
    var id: Date { date }
    let date: Date
    let mean: Double
    let lower: Double
    let upper: Double
}

struct Forecast {
    let model: ForecastModel
    let history: [PricePoint]
    let points: [ForecastPoint]

    var targetPrice: Double? { points.last?.mean }
    var targetDate: Date? { points.last?.date }
    var lastClose: Double? { history.last?.close }

    /// Expected total change over the horizon, as a fraction.
    var expectedChange: Double? {
        guard let last = lastClose, let target = targetPrice, last != 0 else { return nil }
        return (target - last) / last
    }
}

// MARK: - Models catalogue (mirrors the original "model selection" UI)

struct ForecastModel: Identifiable, Hashable {
    let id: String
    let name: String
    let tagline: String
    let confidence: Confidence
    let status: Status
    let systemImage: String

    enum Confidence: String {
        case high = "High"
        case medium = "Medium"
        case experimental = "Experimental"
    }

    enum Status: String {
        case ready = "Ready"
        case beta = "Beta"
        case comingSoon = "Coming soon"

        var isAvailable: Bool { self != .comingSoon }
    }

    static let all: [ForecastModel] = [
        ForecastModel(
            id: "trend-seasonal",
            name: "Skylark",
            tagline: "Linear trend with weekly seasonality — the balanced default.",
            confidence: .high,
            status: .ready,
            systemImage: "waveform.path.ecg"
        ),
        ForecastModel(
            id: "linear",
            name: "Meadowlark",
            tagline: "Pure least-squares trend. Smooth and conservative.",
            confidence: .medium,
            status: .ready,
            systemImage: "line.diagonal.arrow"
        ),
        ForecastModel(
            id: "momentum",
            name: "Swift",
            tagline: "EMA momentum model that leans into recent direction.",
            confidence: .medium,
            status: .ready,
            systemImage: "bolt.fill"
        ),
        ForecastModel(
            id: "reversion",
            name: "Kingfisher",
            tagline: "Mean-reversion toward the moving average.",
            confidence: .experimental,
            status: .beta,
            systemImage: "arrow.uturn.down"
        ),
        ForecastModel(
            id: "ensemble",
            name: "Phoenix",
            tagline: "Blended ensemble of all models. In active development.",
            confidence: .experimental,
            status: .comingSoon,
            systemImage: "sparkles"
        )
    ]

    static let `default` = all[0]
}

// MARK: - Economic indicators (context, mirrors FRED panel)

struct EconomicIndicator: Identifiable, Hashable {
    let id: String
    let name: String
    let detail: String
    let systemImage: String

    static let all: [EconomicIndicator] = [
        EconomicIndicator(id: "fedfunds", name: "Fed Funds Rate", detail: "Overnight policy rate. Higher rates pressure risk assets.", systemImage: "building.columns"),
        EconomicIndicator(id: "cpi", name: "Inflation (CPI)", detail: "Consumer price index, year over year.", systemImage: "cart"),
        EconomicIndicator(id: "unrate", name: "Unemployment", detail: "Civilian unemployment rate.", systemImage: "person.2"),
        EconomicIndicator(id: "t10y", name: "10-Year Treasury", detail: "Benchmark long-term yield.", systemImage: "percent"),
        EconomicIndicator(id: "gdp", name: "Real GDP", detail: "Quarterly growth of the economy.", systemImage: "chart.bar")
    ]
}

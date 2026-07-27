import Foundation

/// The kind of market instrument the user is forecasting.
enum AssetClass: String, CaseIterable, Identifiable, Codable, Sendable {
    case stock = "Stock"
    case crypto = "Crypto"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .stock: "chart.line.uptrend.xyaxis"
        case .crypto: "bitcoinsign.circle"
        }
    }

    var placeholder: String {
        switch self {
        case .stock: "AAPL"
        case .crypto: "bitcoin"
        }
    }

    var hint: String {
        switch self {
        case .stock: "Ticker symbol, e.g. AAPL, MSFT, NVDA"
        case .crypto: "Coin id, e.g. bitcoin, ethereum, solana"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .stock: "Stock ticker"
        case .crypto: "Cryptocurrency"
        }
    }
}

import Foundation

/// Abstraction over historical price providers — enables testing and offline fallbacks.
protocol MarketDataProviding: Sendable {
    func history(symbol: String, assetClass: AssetClass, days: Int) async throws -> PriceSeries
}

extension MarketDataProviding {
    func history(symbol: String, assetClass: AssetClass) async throws -> PriceSeries {
        try await history(symbol: symbol, assetClass: assetClass, days: 180)
    }
}

enum MarketDataError: LocalizedError, Equatable, Sendable {
    case emptySymbol
    case invalidURL
    case notFound(String)
    case decodingFailed
    case insufficientHistory(Int)

    var errorDescription: String? {
        switch self {
        case .emptySymbol:
            "Enter a symbol to forecast."
        case .invalidURL:
            "Couldn't build a request for that symbol."
        case .notFound(let symbol):
            "Couldn't find data for \"\(symbol)\"."
        case .decodingFailed:
            "Price data arrived in an unexpected format."
        case .insufficientHistory(let count):
            "Need at least \(count) days of history to forecast."
        }
    }
}

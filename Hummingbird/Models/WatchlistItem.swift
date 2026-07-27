import Foundation

/// A saved asset the user wants to keep an eye on.
struct WatchlistItem: Codable, Identifiable, Hashable, Sendable {
    var id: String { "\(assetClass.rawValue):\(symbol.lowercased())" }
    let symbol: String
    let assetClass: AssetClass
    var displayName: String?
    var addedAt: Date = .now

    var title: String {
        displayName ?? (assetClass == .stock ? symbol.uppercased() : symbol.capitalized)
    }
}

/// Compact, Codable snapshot the app writes to the App Group after each run so
/// the widget and Siri can render without recomputing. Educational only.
struct WatchlistSnapshot: Codable, Identifiable, Hashable, Sendable {
    var id: String { "\(assetClass.rawValue):\(symbol.lowercased())" }
    let symbol: String
    let assetClass: AssetClass
    let title: String
    let price: Double
    /// Best-method projected change over the standard horizon, as a fraction.
    let projectedChange: Double
    let bestMethodName: String
    let horizonDays: Int
    /// Normalized (0...1) recent history for a sparkline.
    let historySpark: [Double]
    /// Normalized (0...1) projection continuation for a sparkline.
    let projectionSpark: [Double]
    let updatedAt: Date
}

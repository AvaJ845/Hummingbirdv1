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

    init(symbol: String, assetClass: AssetClass, displayName: String? = nil, addedAt: Date = .now) {
        self.symbol = symbol
        self.assetClass = assetClass
        self.displayName = displayName
        self.addedAt = addedAt
    }

    // Backward-compatible decoding: a synthesized `Decodable` treats a property
    // with a default as *required*, so a watchlist saved before `addedAt` /
    // `displayName` existed would fail to decode and the store's `try?` load
    // would silently wipe the list. Decode both defensively.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        symbol = try c.decode(String.self, forKey: .symbol)
        assetClass = try c.decode(AssetClass.self, forKey: .assetClass)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        addedAt = try c.decodeIfPresent(Date.self, forKey: .addedAt) ?? .now
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

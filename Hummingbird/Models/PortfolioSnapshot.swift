import Foundation

/// Compact, Codable snapshot of the practice portfolio's value and its edge
/// over buy-and-hold — written to the App Group so the widget can show it
/// without opening the app. `edge` mirrors `BuyAndHoldComparison.edge`
/// (your return minus holding your first picks); nil until the portfolio has
/// been started. A record of the past, never advice.
struct PortfolioSnapshot: Codable, Hashable, Sendable {
    let value: Double
    let edge: Double?
    let tradeCount: Int
    let updatedAt: Date
}

/// Widget kind identifier — same one-source-of-truth pattern as
/// `TrackRecordWidgetKind`.
enum PortfolioWidgetKind {
    static let identifier = "HummingbirdPortfolio"
}

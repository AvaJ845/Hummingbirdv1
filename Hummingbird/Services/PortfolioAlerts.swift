import Foundation

/// Settings for movement alerts on practice-portfolio holdings — the same
/// honest "this moved, not a signal" alert the watchlist already sends,
/// extended to symbols you actually hold. One portfolio-wide on/off, not
/// per-asset configuration, to keep this a simple toggle like the app's other
/// notification preferences.
enum PortfolioAlerts {
    static let enabledKey = "hb.portfolioAlerts.enabled"
    /// Same default magnitude as the watchlist's per-asset default.
    static let defaultThreshold: Double = 0.05
}

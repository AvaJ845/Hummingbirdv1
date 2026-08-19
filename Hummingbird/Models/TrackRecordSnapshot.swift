import Foundation

/// Compact, Codable snapshot of the user's own honesty ledger — participation
/// streak and accuracy — written to the App Group so the widget and watch
/// complication can show it without opening the app. The widget deliberately
/// shows the raw participation streak (no Pro freeze bonus applied): that
/// nuance lives in-app where entitlements are already loaded and observed,
/// keeping this a simple, dependency-free read for a background context.
struct TrackRecordSnapshot: Codable, Hashable, Sendable {
    let streak: Int
    /// Fraction right of decided (resolved, non-push) calls — nil until at
    /// least one call has resolved.
    let hitRate: Double?
    let decided: Int
    let updatedAt: Date
}

/// Shared widget kind identifiers — one source of truth for the strings used
/// both when reloading a widget's timeline (main app) and when declaring its
/// configuration (widget/complication extension). The iOS widget and the
/// watch complication get distinct kinds, mirroring how the existing
/// watchlist widget ("HummingbirdWatchlist") and complication
/// ("HummingbirdWatchComplication") are already named separately.
enum TrackRecordWidgetKind {
    static let identifier = "HummingbirdTrackRecord"
    static let watchIdentifier = "HummingbirdTrackRecordComplication"
}

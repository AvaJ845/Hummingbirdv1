import SwiftUI

/// Brand tokens for Hummingbird. Prefer semantic system colors for surfaces;
/// accents carry the product identity.
enum Theme {
    /// Hummingbird green — primary interactive accent.
    static let accent = Color(red: 0.30, green: 0.78, blue: 0.55)
    /// Iridescent blue — secondary brand note.
    static let accentAlt = Color(red: 0.16, green: 0.55, blue: 0.90)
    static let up = Color(red: 0.20, green: 0.78, blue: 0.50)
    static let down = Color(red: 0.95, green: 0.36, blue: 0.38)

    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [accentAlt, accent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func changeColor(_ change: Double?) -> Color {
        guard let change else { return .secondary }
        return change >= 0 ? up : down
    }
}

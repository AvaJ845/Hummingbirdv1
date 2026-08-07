import SwiftUI
import UIKit

/// Brand tokens for Hummingbird. Prefer semantic system colors for surfaces;
/// accents carry the product identity. Direction/status colors are **adaptive**
/// (distinct light/dark variants) so contrast holds in both themes, and they're
/// always paired with a sign, symbol, or label in the UI so meaning never rests
/// on hue alone (colorblind-safe).
enum Theme {
    /// Hummingbird green — primary interactive accent.
    static let accent = Color(red: 0.30, green: 0.78, blue: 0.55)
    /// Iridescent blue — secondary brand note.
    static let accentAlt = Color(red: 0.16, green: 0.55, blue: 0.90)

    /// Up / positive — deeper in light for contrast on white, brighter in dark.
    static let up = adaptive(
        light: UIColor(red: 0.11, green: 0.58, blue: 0.35, alpha: 1),
        dark:  UIColor(red: 0.33, green: 0.86, blue: 0.56, alpha: 1)
    )
    /// Down / negative.
    static let down = adaptive(
        light: UIColor(red: 0.80, green: 0.20, blue: 0.22, alpha: 1),
        dark:  UIColor(red: 1.00, green: 0.46, blue: 0.48, alpha: 1)
    )
    /// Caution / "read with care" — amber.
    static let warning = adaptive(
        light: UIColor(red: 0.76, green: 0.50, blue: 0.02, alpha: 1),
        dark:  UIColor(red: 1.00, green: 0.74, blue: 0.24, alpha: 1)
    )

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

    /// One place to build a light/dark adaptive color.
    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

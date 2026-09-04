import SwiftUI
import UIKit

/// Brand tokens for Hummingbird. Prefer semantic system colors for surfaces;
/// accents carry the product identity. Direction/status colors are **adaptive**
/// (distinct light/dark variants) so contrast holds in both themes, and they're
/// always paired with a sign, symbol, or label in the UI so meaning never rests
/// on hue alone (colorblind-safe).
enum Theme {
    /// Hummingbird green — primary interactive accent. **Adaptive**, like the
    /// status colors: the light value is deepened so accent-colored text and
    /// controls clear 4.5:1 on white (the old flat `rgb(0.30, 0.78, 0.55)` was
    /// ~2.1:1); the dark value keeps that brighter mint, which already clears
    /// ~9.8:1 on black. Same recognisable green — see `ThemeContrastTests`.
    static let accent = adaptive(
        light: UIColor(red: 0.06, green: 0.50, blue: 0.38, alpha: 1),
        dark:  UIColor(red: 0.30, green: 0.78, blue: 0.55, alpha: 1)
    )
    /// Iridescent blue — secondary brand note.
    static let accentAlt = Color(red: 0.16, green: 0.55, blue: 0.90)

    /// Up / positive — deeper in light for contrast on white, brighter in dark.
    /// Light value is tuned to clear 4.5:1 against white (WCAG AA body text) —
    /// see `ThemeContrastTests`.
    static let up = adaptive(
        light: UIColor(red: 0.08, green: 0.50, blue: 0.30, alpha: 1),
        dark:  UIColor(red: 0.33, green: 0.86, blue: 0.56, alpha: 1)
    )
    /// Down / negative.
    static let down = adaptive(
        light: UIColor(red: 0.80, green: 0.20, blue: 0.22, alpha: 1),
        dark:  UIColor(red: 1.00, green: 0.46, blue: 0.48, alpha: 1)
    )
    /// Caution / "read with care" — amber. Light value tuned to clear 4.5:1
    /// against white (WCAG AA body text) — see `ThemeContrastTests`.
    static let warning = adaptive(
        light: UIColor(red: 0.62, green: 0.40, blue: 0.02, alpha: 1),
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

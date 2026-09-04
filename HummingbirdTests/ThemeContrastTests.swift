import XCTest
import SwiftUI
import UIKit
@testable import Hummingbird

/// Pins Theme's adaptive status colors to a minimum WCAG AA contrast ratio so a
/// future palette tweak fails here instead of waiting on a manual review.
///
/// `up`/`down`/`warning` are mostly used as short colored text (captions, price
/// deltas, badges) rather than large headings, so this holds every pair to the
/// 4.5:1 "normal text" AA threshold, not the looser 3:1 "large text" one.
/// Backgrounds are approximated as pure white (light) / pure black (dark) — the
/// actual grouped background is slightly softer in both directions, so this is
/// a conservative (harder-to-pass) proxy, never an optimistic one.
final class ThemeContrastTests: XCTestCase {
    private let minimumBodyTextContrast = 4.5

    func testUpClearsAABodyTextContrast() {
        assertContrast(Theme.up, name: "up")
    }

    func testDownClearsAABodyTextContrast() {
        assertContrast(Theme.down, name: "down")
    }

    func testWarningClearsAABodyTextContrast() {
        assertContrast(Theme.warning, name: "warning")
    }

    func testAccentClearsAABodyTextContrast() {
        // accent is the app-wide interactive tint and is also used as short
        // colored text ("Pro active", counts, links) — hold it to the same
        // 4.5:1 bar as the status colors.
        assertContrast(Theme.accent, name: "accent")
    }

    // MARK: - Helpers

    private func assertContrast(_ color: Color, name: String) {
        let light = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        let dark = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))

        let lightRatio = contrastRatio(light, .white)
        let darkRatio = contrastRatio(dark, .black)

        XCTAssertGreaterThanOrEqual(lightRatio, minimumBodyTextContrast,
            "Theme.\(name) (light) is \(lightRatio) : 1 against white — below AA body text (4.5:1)")
        XCTAssertGreaterThanOrEqual(darkRatio, minimumBodyTextContrast,
            "Theme.\(name) (dark) is \(darkRatio) : 1 against black — below AA body text (4.5:1)")
    }

    /// WCAG 2.1 contrast ratio: (L1 + 0.05) / (L2 + 0.05), L1 the lighter.
    private func contrastRatio(_ a: UIColor, _ b: UIColor) -> Double {
        let la = relativeLuminance(a)
        let lb = relativeLuminance(b)
        let (lighter, darker) = la > lb ? (la, lb) : (lb, la)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func relativeLuminance(_ color: UIColor) -> Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)

        func linearize(_ channel: CGFloat) -> Double {
            let c = Double(channel)
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b)
    }
}

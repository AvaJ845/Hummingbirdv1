import SwiftUI

/// Watch-local palette — mirrors the dark-mode variants of the iOS `Theme`,
/// since watchOS surfaces are effectively always dark-background. Kept
/// separate from `Hummingbird/Support/Theme.swift` because that file imports
/// UIKit (for adaptive light/dark `UIColor`), which isn't available on watchOS.
enum WatchTheme {
    static let accent = Color(red: 0.30, green: 0.78, blue: 0.55)
    static let up = Color(red: 0.33, green: 0.86, blue: 0.56)
    static let down = Color(red: 1.00, green: 0.46, blue: 0.48)

    static func changeColor(_ change: Double?) -> Color {
        guard let change else { return .secondary }
        return change >= 0 ? up : down
    }
}

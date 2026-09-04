import SwiftUI

/// Shared navigation timing so pushes/pops feel intentional rather than instant.
enum NavigationMotion {
    /// Horizontal page push / pop.
    static let page = Animation.spring(response: 0.46, dampingFraction: 0.88)

    @MainActor
    static func push(_ path: inout NavigationPath, _ route: AppRoute) {
        withAnimation(page) {
            path.append(route)
        }
    }

    @MainActor
    static func pop(_ dismiss: DismissAction) {
        withAnimation(page) {
            dismiss()
        }
    }
}

/// Destinations pushed onto the root `NavigationStack`.
enum AppRoute: Hashable {
    case models
    case indicators
    /// Optional unlock reason shown on the paywall (fair, contextual ask).
    case paywall(reason: String?)
}

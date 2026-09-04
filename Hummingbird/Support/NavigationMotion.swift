import SwiftUI

/// Shared navigation timing so pushes/pops feel intentional rather than instant.
enum NavigationMotion {
    private static let pageSpring = Animation.spring(response: 0.46, dampingFraction: 0.88)

    /// Horizontal page push / pop. `nil` under the UI-test screenshot harness
    /// (`TestSupport.animationsDisabled`) so a capture can never land on a
    /// transition mid-flight — same effect as Reduce Motion, DEBUG-only.
    static var page: Animation? {
        #if DEBUG
        if TestSupport.animationsDisabled { return nil }
        #endif
        return pageSpring
    }

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

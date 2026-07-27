import Foundation

/// Shared storage between the app and its widget/intents extensions.
/// Falls back to standard defaults if the App Group isn't provisioned so the
/// in-app experience always works.
enum AppGroup {
    static let identifier = "group.com.hummingbird.app"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}

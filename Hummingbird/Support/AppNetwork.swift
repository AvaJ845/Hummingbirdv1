import Foundation

enum AppNetwork {
    /// Single source of truth for the app version: read from the bundle at
    /// runtime so the User-Agent never drifts from `CFBundleShortVersionString`.
    static let appVersion = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0"
    static let userAgent = "Hummingbird/\(appVersion) (iOS; educational)"
}

import Foundation

/// Decides *when* to ask for an App Store rating — at a "happy moment"
/// (a completed projection), never at launch or after an error. Fires at most
/// once per app version, after `threshold` successful projections.
///
/// Pure and deterministic (UserDefaults + version injected) so it's testable.
enum ReviewPrompt {
    static let threshold = 3
    private static let countKey = "hummingbird.review.successCount"
    private static let versionKey = "hummingbird.review.lastPromptedVersion"

    /// Record a successful projection. Returns true exactly once per version,
    /// once at least `threshold` successes have accumulated — the moment to ask.
    static func registerSuccessAndShouldRequest(
        defaults: UserDefaults = .standard,
        version: String = currentVersion
    ) -> Bool {
        let count = defaults.integer(forKey: countKey) + 1
        defaults.set(count, forKey: countKey)

        guard count >= threshold else { return false }
        guard defaults.string(forKey: versionKey) != version else { return false }

        defaults.set(version, forKey: versionKey)
        return true
    }

    static var currentVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }
}

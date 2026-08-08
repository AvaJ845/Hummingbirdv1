import Foundation

/// Privacy Policy & Terms — required for auto-renewable subscriptions (Guideline 3.1.2).
/// In-app copies ship in the bundle; host the same text at these URLs in App Store Connect.
enum AppLegal {
    /// Hosted URL (GitHub Pages `/docs` on the Hummingbirdv1 repo) — same content as bundled PRIVACY.md.
    static let privacyPolicyURL = URL(string: "https://avaj845.github.io/Hummingbirdv1/privacy.html")!
    /// Hosted URL (GitHub Pages `/docs` on the Hummingbirdv1 repo) — same content as bundled TERMS.md.
    static let termsOfUseURL = URL(string: "https://avaj845.github.io/Hummingbirdv1/terms.html")!

    static let privacyResourceName = "PRIVACY"
    static let termsResourceName = "TERMS"

    static func bundledMarkdown(named name: String) -> String? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "md", subdirectory: "Legal")
                ?? Bundle.main.url(forResource: name, withExtension: "md") else {
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}

/// Fair A+ price for untested educational sketches (must match Products.storekit + ASC).
enum AppPricing {
    /// Fallback display prices (StoreKit provides the localized live price at runtime).
    static let yearlyUSD = "19.99"
    static let monthlyUSD = "2.99"
    static let lifetimeUSD = "49.99"
    /// 7-day free trial on the annual plan.
    static let annualTrial = "7-day free trial"
}

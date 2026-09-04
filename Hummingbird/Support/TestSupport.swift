#if DEBUG
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Launch-argument switches for deterministic UI-test screenshots and the
/// opt-in developer menu.
///
/// This whole file is wrapped in `#if DEBUG`, so nothing here — not the
/// property storage, not the argument strings — is compiled into a Release
/// build. `RELEASE_AUDIT.md` verifies that with a `strings` sweep of the
/// Release binary.
enum TestSupport {
    private static let arguments = ProcessInfo.processInfo.arguments

    /// Opt-in gate for the in-app "Unlock Pro" developer toggles (Settings +
    /// Paywall). A plain Debug build shows nothing; pass `-DEBUG_MENU` to
    /// reveal them. Keeps QA affordances out of ordinary Debug/TestFlight use.
    static let isDebugMenuEnabled = arguments.contains("-DEBUG_MENU")

    /// When true, `MarketDataService` serves deterministic `SampleData` and
    /// never touches the network — so screenshots render identical prices
    /// every run, offline. The sample-data banner still shows (honest).
    static let forceSampleData = arguments.contains("-UITEST_FORCE_SAMPLE")

    /// True when any UI-test launch argument is present — used to suppress
    /// non-deterministic chrome (review prompts, etc.) during capture.
    static let isUITest = arguments.contains { $0.hasPrefix("-UITEST_") }

    /// True under the UI-test screenshot harness: the app's own navigation /
    /// results-stack animations are treated exactly like Reduce Motion (nil
    /// animation), and UIKit's implicit animations are switched off process-wide
    /// (see `disableAnimationsForUITests()`). This is what stops a capture from
    /// catching a push transition mid-flight (the "double-exposure" ghosting at
    /// the top of screens 05/08/11). DEBUG-only, like the rest of this file.
    static let animationsDisabled = isUITest

    /// Apply one-time launch state. Call as early as possible in app start-up,
    /// before any store reads `UserDefaults`.
    static func applyLaunchArgumentsIfNeeded() {
        guard isUITest else { return }
        disableAnimationsForUITests()
        let defaults = UserDefaults.standard

        if arguments.contains("-UITEST_RESET") {
            if let domain = Bundle.main.bundleIdentifier {
                defaults.removePersistentDomain(forName: domain)
            }
            if let group = UserDefaults(suiteName: AppGroup.identifier) {
                group.removePersistentDomain(forName: AppGroup.identifier)
            }
        }
        if arguments.contains("-UITEST_SKIP_ONBOARDING") {
            defaults.set(true, forKey: "hummingbird.hasOnboarded")
        }
        if arguments.contains("-UITEST_PRACTICE_ON") {
            defaults.set(true, forKey: "hb.practice.enabled")
        }
        if arguments.contains("-UITEST_PRO_ON") {
            // Reuses the existing DEBUG QA-unlock key that EntitlementStore
            // reads in its initializer.
            defaults.set(true, forKey: "hummingbird.debug.proUnlocked")
        }
        if arguments.contains("-UITEST_SEED_WATCHLIST") {
            seedWatchlist()
        }
        if arguments.contains("-UITEST_SEED_SCORECARD") {
            seedScorecard()
        }
        AppGroup.defaults.synchronize()
        defaults.synchronize()
    }

    /// Kill every implicit animation for the process so screenshot captures are
    /// deterministic: no UIKit view animations, and an opaque nav bar so no
    /// scroll content smears through it. The SwiftUI side is handled separately
    /// by `animationsDisabled` gating the app's `withAnimation` / `.animation(...)`
    /// call sites (`NavigationMotion`, `ContentView`). Safe to call before the
    /// scene is up — these are global switches / appearance-proxy writes.
    private static func disableAnimationsForUITests() {
        #if canImport(UIKit)
        UIView.setAnimationsEnabled(false)

        // Make the navigation bar opaque for captures. iOS 26's translucent
        // "Liquid Glass" bar otherwise shows a blurred smear of whatever scroll
        // content sits behind it at the top of every pushed/scrolled screen —
        // which read as double-exposure ghosting in screens 05 / 08 / 11.
        let opaque = UINavigationBarAppearance()
        opaque.configureWithOpaqueBackground()
        opaque.backgroundColor = .systemGroupedBackground
        opaque.shadowColor = .clear
        let bar = UINavigationBar.appearance()
        bar.standardAppearance = opaque
        bar.compactAppearance = opaque
        bar.scrollEdgeAppearance = opaque
        bar.compactScrollEdgeAppearance = opaque
        #endif
    }

    /// Every UserDefaults surface a store might resolve to.
    private static var seedTargets: [UserDefaults] {
        var targets: [UserDefaults] = [.standard, AppGroup.defaults]
        if let suite = UserDefaults(suiteName: AppGroup.identifier), !targets.contains(suite) {
            targets.append(suite)
        }
        return targets
    }

    /// A small deterministic set of already-resolved sketches so the Accuracy
    /// report renders with real numbers (median error, per-horizon accuracy,
    /// per-method performance, directional record) instead of its empty state.
    private static func seedScorecard() {
        let cal = Calendar(identifier: .gregorian)
        let now = Date()

        func record(_ symbol: String, _ klass: AssetClass, _ modelId: String, _ modelName: String,
                    daysAgo: Int, spot: Double, errors: [Int: Double], dir: Double) -> SketchRecord {
            let createdAt = cal.date(byAdding: .day, value: -daysAgo, to: now) ?? now
            let projections: [SketchProjection] = errors.sorted { $0.key < $1.key }.map { horizon, ape in
                let mean = spot * (1 + dir * Double(horizon) / 100)
                let actual = mean * (1 + ape)          // resolved close, `ape` off the mean
                let target = cal.date(byAdding: .day, value: horizon, to: createdAt) ?? createdAt
                return SketchProjection(
                    targetDate: target,
                    projectedMean: mean,
                    projectedBandHalfWidth: mean * 0.08,
                    actualClose: actual,
                    resolvedAt: target
                )
            }
            return SketchRecord(
                id: UUID(), symbol: symbol, assetClass: klass,
                modelId: modelId, modelName: modelName,
                createdAt: createdAt, spotAtCreation: spot,
                projections: projections,
                reliabilityAtCreation: 64, regimeAtCreation: .normal
            )
        }

        let records: [SketchRecord] = [
            record("AAPL", .stock, "trend-seasonal", "Trend + weekday", daysAgo: 47, spot: 168,
                   errors: [7: 0.014, 14: -0.022, 30: 0.041], dir: 0.05),
            record("AAPL", .stock, "holt", "Holt", daysAgo: 41, spot: 172,
                   errors: [7: -0.009, 14: 0.018, 30: -0.033], dir: -0.03),
            record("MSFT", .stock, "trend-seasonal", "Trend + weekday", daysAgo: 38, spot: 410,
                   errors: [7: 0.006, 14: 0.011, 30: 0.027], dir: 0.04),
            record("bitcoin", .crypto, "drift", "Drift", daysAgo: 35, spot: 61000,
                   errors: [7: 0.03, 14: -0.048, 30: 0.062], dir: 0.08),
            record("bitcoin", .crypto, "trend-seasonal", "Trend + weekday", daysAgo: 33, spot: 59500,
                   errors: [7: -0.017, 14: 0.026, 30: -0.039], dir: -0.05),
            record("ethereum", .crypto, "linear", "Straight trend", daysAgo: 30, spot: 3350,
                   errors: [7: 0.021, 14: 0.034, 30: -0.05], dir: 0.06)
        ]
        guard let data = try? JSONEncoder().encode(records) else { return }
        for target in seedTargets { target.set(data, forKey: "hummingbird.scorecard.records") }
    }

    /// Two deterministic watched assets so the watchlist screenshot isn't empty.
    private static func seedWatchlist() {
        let items = [
            WatchlistItem(symbol: "AAPL", assetClass: .stock, displayName: "Apple"),
            WatchlistItem(symbol: "bitcoin", assetClass: .crypto, displayName: "Bitcoin")
        ]
        guard let data = try? JSONEncoder().encode(items) else { return }
        for target in seedTargets { target.set(data, forKey: "hummingbird.watchlist.items") }
    }
}
#endif

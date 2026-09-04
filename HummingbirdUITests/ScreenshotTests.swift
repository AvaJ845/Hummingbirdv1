import XCTest
import UIKit

/// Drives the app and captures the App Store screenshot set as real device
/// screenshots, written straight to disk.
///
/// iPhone 6.9" set (1320×2868) → `AppStore/raw-screens/`:
/// ```
/// TEST_RUNNER_SCREENSHOT_DIR=/abs/path/AppStore/raw-screens \
/// xcodebuild test -project Hummingbird.xcodeproj -scheme Hummingbird \
///   -sdk iphonesimulator \
///   -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
///   -only-testing:HummingbirdUITests CODE_SIGNING_ALLOWED=NO
/// ```
///
/// 13" iPad set → `AppStore/raw-screens-ipad/` (same `TEST_RUNNER_SCREENSHOT_DIR`;
/// when the run is on an iPad the harness redirects a `.../raw-screens` path to a
/// sibling `.../raw-screens-ipad`, or honours `TEST_RUNNER_SCREENSHOT_SUBDIR`):
/// ```
/// TEST_RUNNER_SCREENSHOT_DIR=/abs/path/AppStore/raw-screens \
/// xcodebuild test -project Hummingbird.xcodeproj -scheme Hummingbird \
///   -sdk iphonesimulator \
///   -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
///   -only-testing:HummingbirdUITests CODE_SIGNING_ALLOWED=NO
/// ```
final class ScreenshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    // MARK: - Infrastructure

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    private var screenshotDir: URL {
        let env = ProcessInfo.processInfo.environment
        var path = env["SCREENSHOT_DIR"]
            ?? env["TEST_RUNNER_SCREENSHOT_DIR"]
            ?? NSTemporaryDirectory().appending("hummingbird-screens")

        // Keep the iPad set alongside — never on top of — the iPhone set.
        if isPad {
            var url = URL(fileURLWithPath: path, isDirectory: true)
            if let sub = env["TEST_RUNNER_SCREENSHOT_SUBDIR"] {
                url = url.appendingPathComponent(sub, isDirectory: true)
            } else if url.lastPathComponent == "raw-screens" {
                url = url.deletingLastPathComponent().appendingPathComponent("raw-screens-ipad", isDirectory: true)
            } else {
                url = url.appendingPathComponent("ipad", isDirectory: true)
            }
            path = url.path
        }

        let url = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func app(_ extraArgs: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITEST_RESET"] + extraArgs
        return app
    }

    /// Full-screen device screenshot → PNG on disk + result-bundle attachment.
    ///
    /// `settleOn`, when given, is a static text known to be on the destination
    /// screen — we block on it existing so timing is deterministic rather than
    /// purely slept. Animations are already disabled in-process by
    /// `TestSupport` under `-UITEST_*`, so the sleep is only a paint-settle
    /// margin.
    private func capture(_ name: String, app: XCUIApplication, settleOn: String? = nil) {
        _ = app.wait(for: .runningForeground, timeout: 5)
        if let settleOn {
            XCTAssertTrue(
                app.staticTexts[settleOn].waitForExistence(timeout: 8),
                "expected '\(settleOn)' on screen before capturing \(name)"
            )
        }
        Thread.sleep(forTimeInterval: 0.9)

        let shot = XCUIScreen.main.screenshot()
        let url = screenshotDir.appendingPathComponent("\(name).png")
        do {
            try shot.pngRepresentation.write(to: url)
            print("SCREENSHOT wrote \(url.path) (\(shot.pngRepresentation.count) bytes)")
        } catch {
            XCTFail("Could not write \(url.path): \(error)")
        }

        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - 01–03 Onboarding

    func test_01to03_onboarding() {
        let app = app([])   // no skip → onboarding shows
        app.launch()

        let cont = app.buttons["onboarding.continue"]
        XCTAssertTrue(cont.waitForExistence(timeout: 10), "onboarding did not appear")

        capture("01_onboarding_sketches", app: app, settleOn: "Sketches, not predictions")

        cont.tap()
        capture("02_onboarding_private", app: app, settleOn: "Private by design")

        cont.tap()
        capture("03_onboarding_honest", app: app, settleOn: "See how wrong it's been")
    }

    // MARK: - 04–06 Home + sketch + reliability

    func test_04to06_homeAndSketch() {
        let app = app(["-UITEST_SKIP_ONBOARDING", "-UITEST_FORCE_SAMPLE"])
        app.launch()

        let field = app.textFields["symbol.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        capture("04_home_empty", app: app)

        // Switch to Stock — the field auto-fills the "AAPL" default.
        if app.buttons["Stock"].exists { app.buttons["Stock"].tap() }
        Thread.sleep(forTimeInterval: 0.3)
        let current = (field.value as? String) ?? ""
        if current != "AAPL" {
            field.tap()
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 2))
            field.typeText("AAPL")
        }
        app.buttons["sketch.run"].tap()

        // Results card renders once loading finishes.
        Thread.sleep(forTimeInterval: 3.0)
        // Scroll past the input card so the plain-English result is the focus.
        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.5)
        capture("05_sketch_result", app: app)

        // Scroll to the reliability meter / best-method card.
        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.4)
        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.4)
        app.swipeUp()
        capture("06_reliability", app: app)
    }

    // MARK: - 07–08 Paywall

    func test_07to08_paywall() {
        let app = app(["-UITEST_SKIP_ONBOARDING", "-UITEST_FORCE_SAMPLE"])
        app.launch()

        let pro = app.buttons["toolbar.pro"]
        XCTAssertTrue(pro.waitForExistence(timeout: 10))
        pro.tap()

        capture("07_paywall_top", app: app, settleOn: "Hummingbird Pro")

        // Scroll to the plan buttons ($19.99/year + 7-day trial, $2.99/month, $49.99 Lifetime).
        for _ in 0..<4 {
            if app.buttons["paywall.buy.yearly"].exists || app.staticTexts["Choose your plan"].exists {
                break
            }
            app.swipeUp()
        }
        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.4)
        capture("08_paywall_plans", app: app)
    }

    // MARK: - 09 + 11 Settings & accuracy report

    func test_09and11_settings() {
        let app = app(["-UITEST_SKIP_ONBOARDING", "-UITEST_FORCE_SAMPLE", "-UITEST_SEED_SCORECARD"])
        app.launch()

        let gear = app.buttons["toolbar.settings"]
        XCTAssertTrue(gear.waitForExistence(timeout: 10))
        gear.tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        capture("09_settings", app: app, settleOn: "Appearance")

        // The Accuracy report row sits a few sections down — scroll it into the
        // rendered range deterministically instead of hoping it's on-screen
        // (it isn't on shorter devices, which is what used to flake this test).
        let report = app.buttons["settings.accuracyReport"]
        var scrolls = 0
        while !report.isHittable && scrolls < 8 {
            app.swipeUp()
            scrolls += 1
        }
        XCTAssertTrue(report.waitForExistence(timeout: 3), "accuracy report row not found")
        report.tap()
        capture("11_accuracy_report", app: app, settleOn: "Across all assets")
    }

    // MARK: - 10 Practice home

    func test_10_practiceHome() {
        let app = app(["-UITEST_SKIP_ONBOARDING", "-UITEST_FORCE_SAMPLE", "-UITEST_PRACTICE_ON"])
        app.launch()

        XCTAssertTrue(app.textFields["symbol.field"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 0.8)
        capture("10_practice_home", app: app)
    }

    // MARK: - 12 Watchlist

    func test_12_watchlist() {
        let app = app(["-UITEST_SKIP_ONBOARDING", "-UITEST_FORCE_SAMPLE", "-UITEST_SEED_WATCHLIST"])
        app.launch()

        let star = app.buttons["toolbar.watchlist"]
        XCTAssertTrue(star.waitForExistence(timeout: 10))
        star.tap()

        XCTAssertTrue(app.navigationBars["Watchlist"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.5)   // let snapshot refresh settle
        capture("12_watchlist", app: app)
    }
}

import XCTest

/// Drives the app on iPhone 17 Pro Max and captures the App Store screenshot
/// set as real device screenshots, written straight to disk.
///
/// Run:
/// ```
/// TEST_RUNNER_SCREENSHOT_DIR=/abs/path/AppStore/raw-screens \
/// xcodebuild test -project Hummingbird.xcodeproj -scheme Hummingbird \
///   -sdk iphonesimulator \
///   -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
///   -only-testing:HummingbirdUITests CODE_SIGNING_ALLOWED=NO
/// ```
final class ScreenshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    // MARK: - Infrastructure

    private var screenshotDir: URL {
        let env = ProcessInfo.processInfo.environment
        let path = env["SCREENSHOT_DIR"]
            ?? env["TEST_RUNNER_SCREENSHOT_DIR"]
            ?? NSTemporaryDirectory().appending("hummingbird-screens")
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
    private func capture(_ name: String, app: XCUIApplication) {
        // Let layout/animation settle.
        _ = app.wait(for: .runningForeground, timeout: 5)
        Thread.sleep(forTimeInterval: 0.6)

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

        XCTAssertTrue(app.staticTexts["Sketches, not predictions"].waitForExistence(timeout: 5))
        capture("01_onboarding_sketches", app: app)

        cont.tap()
        XCTAssertTrue(app.staticTexts["Private by design"].waitForExistence(timeout: 5))
        capture("02_onboarding_private", app: app)

        cont.tap()
        XCTAssertTrue(app.staticTexts["See how wrong it's been"].waitForExistence(timeout: 5))
        capture("03_onboarding_honest", app: app)
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

        XCTAssertTrue(app.staticTexts["Hummingbird Pro"].waitForExistence(timeout: 5))
        capture("07_paywall_top", app: app)

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
        Thread.sleep(forTimeInterval: 0.5)
        capture("09_settings", app: app)

        let report = app.buttons["settings.accuracyReport"]
        if report.waitForExistence(timeout: 3) {
            report.tap()
            Thread.sleep(forTimeInterval: 0.8)
            capture("11_accuracy_report", app: app)
        } else {
            XCTFail("accuracy report row not found")
        }
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

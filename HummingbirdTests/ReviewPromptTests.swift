import XCTest
@testable import Hummingbird

final class ReviewPromptTests: XCTestCase {
    private func store() -> UserDefaults { UserDefaults(suiteName: UUID().uuidString)! }

    func testFiresOnceAtThresholdPerVersion() {
        let d = store()
        // Below threshold (3): no prompt.
        XCTAssertFalse(ReviewPrompt.registerSuccessAndShouldRequest(defaults: d, version: "1.0"))
        XCTAssertFalse(ReviewPrompt.registerSuccessAndShouldRequest(defaults: d, version: "1.0"))
        // Third success → prompt once.
        XCTAssertTrue(ReviewPrompt.registerSuccessAndShouldRequest(defaults: d, version: "1.0"))
        // Further successes on the same version → never again.
        XCTAssertFalse(ReviewPrompt.registerSuccessAndShouldRequest(defaults: d, version: "1.0"))
        XCTAssertFalse(ReviewPrompt.registerSuccessAndShouldRequest(defaults: d, version: "1.0"))
    }

    func testEligibleAgainOnNewVersion() {
        let d = store()
        for _ in 0..<3 { _ = ReviewPrompt.registerSuccessAndShouldRequest(defaults: d, version: "1.0") }
        // A new version becomes eligible on the next success (count already high).
        XCTAssertTrue(ReviewPrompt.registerSuccessAndShouldRequest(defaults: d, version: "1.1"))
        XCTAssertFalse(ReviewPrompt.registerSuccessAndShouldRequest(defaults: d, version: "1.1"))
    }
}

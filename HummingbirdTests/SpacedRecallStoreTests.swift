import XCTest
@testable import Hummingbird

final class SpacedRecallStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "hummingbird.tests.spacedRecall"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func call() -> UserCall {
        UserCall(id: UUID(), symbol: "AAPL", assetClass: .stock, createdAt: Date(),
                 horizonDays: 7, spotAtCall: 100, direction: .higher, confidence: .hunch,
                 actualClose: 110, resolvedAt: Date())
    }

    @MainActor func testFreshStoreHasNothingReviewed() {
        let store = SpacedRecallStore(defaults: defaults)
        XCTAssertFalse(store.isReviewed(call(), intervalIndex: 0))
    }

    @MainActor func testRecordReviewedMarksExactCallAndInterval() {
        let store = SpacedRecallStore(defaults: defaults)
        let c = call()
        store.recordReviewed(c, intervalIndex: 0)
        XCTAssertTrue(store.isReviewed(c, intervalIndex: 0))
        XCTAssertFalse(store.isReviewed(c, intervalIndex: 1), "A different interval on the same call is a separate checkpoint.")
    }

    @MainActor func testDifferentCallsAreIndependent() {
        let store = SpacedRecallStore(defaults: defaults)
        let a = call()
        let b = call()
        store.recordReviewed(a, intervalIndex: 0)
        XCTAssertTrue(store.isReviewed(a, intervalIndex: 0))
        XCTAssertFalse(store.isReviewed(b, intervalIndex: 0))
    }

    @MainActor func testPersistsAcrossInstances() {
        let c = call()
        let first = SpacedRecallStore(defaults: defaults)
        first.recordReviewed(c, intervalIndex: 1)

        let second = SpacedRecallStore(defaults: defaults)
        XCTAssertTrue(second.isReviewed(c, intervalIndex: 1))
    }
}

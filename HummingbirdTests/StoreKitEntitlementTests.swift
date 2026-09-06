import XCTest
import StoreKit
import StoreKitTest
@testable import Hummingbird

// MARK: - Runs unconditionally (no SKTestSession)

/// The `loadProducts()` bounded-backoff retry / error surface, driven by an
/// injected `productLoader` seam — no StoreKit daemon involvement, so these run
/// in every `xcodebuild test`.
@MainActor
final class EntitlementStoreRetryTests: XCTestCase {

    private actor Counter {
        private(set) var value = 0
        func next() -> Int { value += 1; return value }
    }

    func testLoadProductsRetriesThenRecovers() async throws {
        struct Boom: Error {}
        let store = EntitlementStore()
        store.retryDelays = [.milliseconds(1), .milliseconds(1), .milliseconds(1)]

        // Fail the first two attempts, succeed on the third — proves the bounded
        // backoff loop retries rather than giving up on the first failure.
        let counter = Counter()
        store.productLoader = { _ in
            let n = await counter.next()
            if n < 3 { throw Boom() }
            return []   // DEBUG treats an empty catalogue as the by-design stub
        }

        await store.loadProducts()
        let calls = await counter.value
        XCTAssertEqual(calls, 3, "should have retried twice before succeeding")
        XCTAssertNil(store.lastError, "a recovered load clears the error even after earlier attempts failed")
    }

    func testLoadProductsSurfacesErrorWhenAllRetriesFail() async throws {
        struct Boom: LocalizedError { var errorDescription: String? { "no network" } }
        let store = EntitlementStore()
        store.retryDelays = [.milliseconds(5), .milliseconds(5), .milliseconds(5)]
        let counter = Counter()
        store.productLoader = { _ in
            _ = await counter.next()
            throw Boom()
        }

        await store.loadProducts()

        let calls = await counter.value
        XCTAssertEqual(calls, 4, "one initial attempt + three retries")
        XCTAssertTrue(store.products.isEmpty)
        XCTAssertEqual(store.lastError, "no network")
        XCTAssertFalse(store.isLoading, "isLoading is cleared once the sequence ends")
    }

    func testSecondLoadWhileFirstInFlightIsANoOp() async throws {
        // Re-entrancy guard: a concurrent loadProducts() must not start a second
        // retry loop.
        let store = EntitlementStore()
        store.retryDelays = [.milliseconds(200), .milliseconds(200), .milliseconds(200)]
        let counter = Counter()
        store.productLoader = { _ in
            _ = await counter.next()
            throw NSError(domain: "t", code: 1)
        }

        async let first: Void = store.loadProducts()
        try await Task.sleep(for: .milliseconds(20))
        await store.loadProducts()   // should bail immediately on `guard !isLoading`
        await first

        let calls = await counter.value
        XCTAssertEqual(calls, 4, "only the first sequence ran; the concurrent call was a no-op")
    }

    func testRetryDelayScheduleIsBounded() {
        XCTAssertEqual(EntitlementStore.loadRetryDelays.count, 3)
    }
}

// MARK: - Opt-in only (constructs SKTestSession)

/// Real StoreKit 2 purchase / refund / entitlement paths driven by an in-process
/// `SKTestSession`.
///
/// **These are opt-in.** Constructing an `SKTestSession` under a plain CLI
/// `xcodebuild test` on this Xcode 26.6 + iOS 17 simulator throws
/// `SKInternalErrorDomain Code=3` ("Error saving configuration file") and, worse,
/// leaves `storekitd` in a state that crashes the app when the parallel
/// `HummingbirdUITests` shards launch it afterwards. So the whole class
/// `XCTSkipUnless`-es out **before** touching `SKTestSession` unless
/// `RUN_STOREKIT_SESSION_TESTS=1` is set.
///
/// To run them:
/// ```
/// RUN_STOREKIT_SESSION_TESTS=1 xcodebuild test \
///   -scheme Hummingbird -only-testing:HummingbirdTests/StoreKitEntitlementTests …
/// ```
/// or add the env var to the Xcode scheme's Test action and run Cmd-U. They pass
/// from an Xcode GUI test run; the CLI simulator does not support them.
@MainActor
final class StoreKitEntitlementTests: XCTestCase {

    private var session: SKTestSession!

    private static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["RUN_STOREKIT_SESSION_TESTS"] == "1"
    }

    override func setUpWithError() throws {
        try XCTSkipUnless(Self.isEnabled,
                          "Set RUN_STOREKIT_SESSION_TESTS=1 to run the SKTestSession purchase tests (see class doc).")
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Products", withExtension: "storekit"))
        session = try SKTestSession(contentsOf: url)
        session.disableDialogs = true
        session.clearTransactions()
    }

    override func tearDown() {
        session?.clearTransactions()
        session = nil
    }

    private func loadedStore() async throws -> EntitlementStore {
        let store = EntitlementStore()
        await store.loadProducts()
        XCTAssertEqual(store.products.count, 3)
        return store
    }

    // MARK: - Catalogue

    func testLoadProductsReturnsThreeTiersAtExpectedPrices() async throws {
        let store = try await loadedStore()

        let yearly = try XCTUnwrap(store.yearlyProduct)
        let monthly = try XCTUnwrap(store.monthlyProduct)
        let lifetime = try XCTUnwrap(store.lifetimeProduct)

        XCTAssertEqual(yearly.price, Decimal(string: "19.99"))
        XCTAssertEqual(monthly.price, Decimal(string: "2.99"))
        XCTAssertEqual(lifetime.price, Decimal(string: "49.99"))

        XCTAssertEqual("\(yearly.price)", AppPricing.yearlyUSD)
        XCTAssertEqual("\(monthly.price)", AppPricing.monthlyUSD)
        XCTAssertEqual("\(lifetime.price)", AppPricing.lifetimeUSD)

        let intro = try XCTUnwrap(yearly.subscription?.introductoryOffer)
        XCTAssertEqual(intro.paymentMode, .freeTrial)
        XCTAssertEqual(intro.period.unit, .week)

        XCTAssertNil(monthly.subscription?.introductoryOffer)
        XCTAssertNil(lifetime.subscription, "lifetime is a non-consumable, not a subscription")
    }

    // MARK: - Buy / refund / persist

    func testBuyYearlyUnlocksProAndRealPurchase() async throws {
        let store = try await loadedStore()
        let yearly = try XCTUnwrap(store.yearlyProduct)

        let ok = await store.purchase(yearly)
        XCTAssertTrue(ok)
        XCTAssertTrue(store.isPro)
        XCTAssertTrue(store.hasRealPurchase)
        XCTAssertTrue(store.purchasedProductIDs.contains(EntitlementStore.yearlyProductID))
    }

    func testRefundingYearlyRevokesPro() async throws {
        let store = try await loadedStore()
        let yearly = try XCTUnwrap(store.yearlyProduct)

        _ = await store.purchase(yearly)
        XCTAssertTrue(store.isPro)

        let found = await currentTransaction(for: EntitlementStore.yearlyProductID)
        let txn = try XCTUnwrap(found)
        try session.refundTransaction(identifier: UInt(txn.id))
        try session.expireSubscription(productIdentifier: EntitlementStore.yearlyProductID)

        await store.loadProducts()
        XCTAssertFalse(store.hasRealPurchase, "refunded + expired subscription must not grant Pro")
    }

    func testLifetimeSurvivesSubscriptionExpiry() async throws {
        let store = try await loadedStore()
        let lifetime = try XCTUnwrap(store.lifetimeProduct)

        let ok = await store.purchase(lifetime)
        XCTAssertTrue(ok)
        XCTAssertTrue(store.isPro)

        try? session.expireSubscription(productIdentifier: EntitlementStore.yearlyProductID)
        try? session.expireSubscription(productIdentifier: EntitlementStore.monthlyProductID)

        await store.loadProducts()
        XCTAssertTrue(store.hasRealPurchase)
        XCTAssertTrue(store.purchasedProductIDs.contains(EntitlementStore.lifetimeProductID))
    }

    // MARK: - Long-lived listener + restore

    func testExternalTransactionIsPickedUpByLongLivedListener() async throws {
        let store = try await loadedStore()
        XCTAssertFalse(store.hasRealPurchase)

        // Buy WITHOUT EntitlementStore.purchase() — mimics an Ask-to-Buy approval
        // or a purchase completed on another device.
        _ = try await session.buyProduct(identifier: EntitlementStore.monthlyProductID)

        try await waitFor("listener picks up external purchase") { store.hasRealPurchase }
        XCTAssertTrue(store.isPro)
    }

    func testRestoreSurfacesExistingPurchase() async throws {
        _ = try await loadedStore()
        _ = try await session.buyProduct(identifier: EntitlementStore.yearlyProductID)

        let store = EntitlementStore()
        await store.restore()
        XCTAssertTrue(store.hasRealPurchase)
        XCTAssertTrue(store.isPro)
    }

    // MARK: - Helpers

    private func currentTransaction(for productID: String) async -> StoreKit.Transaction? {
        for await result in Transaction.currentEntitlements {
            if case .verified(let txn) = result, txn.productID == productID { return txn }
        }
        return nil
    }

    private func waitFor(
        _ label: String,
        timeout: TimeInterval = 5,
        _ condition: @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTFail("timed out waiting for: \(label)")
    }
}

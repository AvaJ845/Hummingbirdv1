import XCTest
import StoreKit
import StoreKitTest
@testable import Hummingbird

/// Exercises the real StoreKit 2 purchase / refund / entitlement paths with an
/// in-process `SKTestSession` driving `Products.storekit` (bundled into the test
/// target's resources). This is the reliable way to test purchases from
/// `xcodebuild test` — the scheme-attached StoreKit configuration does NOT
/// engage under CLI `xcodebuild` (`storekitd`: "Allows client override: NO"),
/// but `SKTestSession` does.
@MainActor
final class StoreKitEntitlementTests: XCTestCase {

    private var session: SKTestSession!

    /// True once we've confirmed `SKTestSession` actually serves the catalogue in
    /// this environment. If it doesn't (some CLI `xcodebuild` + simulator
    /// combinations refuse the client override), the real-purchase tests
    /// `XCTSkipUnless` out rather than fail the build — the retry/error tests,
    /// which use an injected loader, always run.
    private func loadProductsOrSkip() async throws -> EntitlementStore {
        let store = EntitlementStore()
        await store.loadProducts()
        try XCTSkipUnless(store.products.count == 3,
                          "SKTestSession did not serve Products.storekit in this environment")
        return store
    }

    override func setUp() async throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Products", withExtension: "storekit"))
        session = try SKTestSession(contentsOf: url)
        session.disableDialogs = true
        session.clearTransactions()
    }

    override func tearDown() async throws {
        session?.clearTransactions()
        session = nil
    }

    // MARK: - Catalogue

    func testLoadProductsReturnsThreeTiersAtExpectedPrices() async throws {
        let store = try await loadProductsOrSkip()

        XCTAssertEqual(store.products.count, 3, "yearly + monthly subs and the lifetime non-consumable")

        let yearly = try XCTUnwrap(store.yearlyProduct)
        let monthly = try XCTUnwrap(store.monthlyProduct)
        let lifetime = try XCTUnwrap(store.lifetimeProduct)

        XCTAssertEqual(yearly.price, Decimal(string: "19.99"))
        XCTAssertEqual(monthly.price, Decimal(string: "2.99"))
        XCTAssertEqual(lifetime.price, Decimal(string: "49.99"))

        XCTAssertEqual("\(yearly.price)", AppPricing.yearlyUSD)
        XCTAssertEqual("\(monthly.price)", AppPricing.monthlyUSD)
        XCTAssertEqual("\(lifetime.price)", AppPricing.lifetimeUSD)

        // Yearly carries the 7-day free intro offer.
        let intro = try XCTUnwrap(yearly.subscription?.introductoryOffer)
        XCTAssertEqual(intro.paymentMode, .freeTrial)
        XCTAssertEqual(intro.period.unit, .week)

        XCTAssertNil(monthly.subscription?.introductoryOffer)
        XCTAssertNil(lifetime.subscription, "lifetime is a non-consumable, not a subscription")
    }

    // MARK: - Buy a subscription

    func testBuyYearlyUnlocksProAndRealPurchase() async throws {
        let store = try await loadProductsOrSkip()
        let yearly = try XCTUnwrap(store.yearlyProduct)

        let ok = await store.purchase(yearly)
        XCTAssertTrue(ok)
        XCTAssertTrue(store.isPro)
        XCTAssertTrue(store.hasRealPurchase)
        XCTAssertTrue(store.purchasedProductIDs.contains(EntitlementStore.yearlyProductID))
    }

    // MARK: - Refund / revoke

    func testRefundingYearlyRevokesPro() async throws {
        let store = try await loadProductsOrSkip()
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

    // MARK: - Lifetime non-consumable persists

    func testLifetimeSurvivesSubscriptionExpiry() async throws {
        let store = try await loadProductsOrSkip()
        let lifetime = try XCTUnwrap(store.lifetimeProduct)

        let ok = await store.purchase(lifetime)
        XCTAssertTrue(ok)
        XCTAssertTrue(store.isPro)

        // Expiring subscriptions must not touch a non-consumable entitlement.
        try? session.expireSubscription(productIdentifier: EntitlementStore.yearlyProductID)
        try? session.expireSubscription(productIdentifier: EntitlementStore.monthlyProductID)

        await store.loadProducts()
        XCTAssertTrue(store.hasRealPurchase)
        XCTAssertTrue(store.purchasedProductIDs.contains(EntitlementStore.lifetimeProductID))
    }

    // MARK: - Transaction.updates listener (external / Ask-to-Buy approval)

    func testExternalTransactionIsPickedUpByLongLivedListener() async throws {
        let store = try await loadProductsOrSkip()
        XCTAssertFalse(store.hasRealPurchase)

        // Buy WITHOUT going through EntitlementStore.purchase() — mimics an
        // Ask-to-Buy approval or a purchase completed on another device. The
        // long-lived `Transaction.updates` listener in `init` should catch it.
        _ = try await session.buyProduct(identifier: EntitlementStore.monthlyProductID)

        try await waitFor("listener picks up external purchase") {
            store.hasRealPurchase
        }
        XCTAssertTrue(store.isPro)
    }

    // MARK: - Restore

    func testRestoreSurfacesExistingPurchase() async throws {
        _ = try await loadProductsOrSkip()  // skip if SKTestSession isn't serving the catalogue
        // Seed a purchase, then a fresh store instance should see it after restore.
        _ = try await session.buyProduct(identifier: EntitlementStore.yearlyProductID)

        let store = EntitlementStore()
        await store.restore()
        XCTAssertTrue(store.hasRealPurchase)
        XCTAssertTrue(store.isPro)
    }

    // MARK: - loadProducts retry / error surface

    func testLoadProductsRetriesThenSurfacesErrorAndRecovers() async throws {
        struct Boom: Error {}
        let store = EntitlementStore()
        store.retryDelays = [.milliseconds(1), .milliseconds(1), .milliseconds(1)]

        // Fail the first two attempts, succeed on the third — proves the bounded
        // backoff loop retries rather than giving up on the first failure.
        let counter = Counter()
        store.productLoader = { ids in
            let n = await counter.next()
            if n < 3 { throw Boom() }
            return try await Product.products(for: ids)
        }

        await store.loadProducts()
        let calls = await counter.value
        XCTAssertEqual(calls, 3, "should have retried twice before succeeding")
        XCTAssertNil(store.lastError, "a recovered load clears the error even after earlier attempts failed")
        // (Whether attempt 3's real Product.products actually returns the 3-item
        //  catalogue depends on SKTestSession; the retry/recover behaviour under
        //  test does not.)
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

    func testRetryDelayScheduleIsBounded() {
        XCTAssertEqual(EntitlementStore.loadRetryDelays.count, 3)
    }

    // MARK: - Helpers

    private func currentTransaction(for productID: String) async -> StoreKit.Transaction? {
        for await result in Transaction.currentEntitlements {
            if case .verified(let txn) = result, txn.productID == productID {
                return txn
            }
        }
        return nil
    }

    private actor Counter {
        private(set) var value = 0
        func next() -> Int { value += 1; return value }
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

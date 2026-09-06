import Foundation
import Observation
import StoreKit

/// StoreKit 2 entitlement surface. Products are optional until App Store Connect
/// is configured; Debug builds can unlock Pro locally for QA.
@MainActor
@Observable
final class EntitlementStore {
    nonisolated static let yearlyProductID = "com.avaresearch.hummingbird.pro.yearly"
    nonisolated static let monthlyProductID = "com.avaresearch.hummingbird.pro.monthly"
    /// One-time, non-consumable unlock — no renewal, no expiry. Once purchased it
    /// stays in `Transaction.currentEntitlements` forever, so `hasRealPurchase`
    /// and `isPro` pick it up through the same path as the subscriptions.
    nonisolated static let lifetimeProductID = "com.avaresearch.hummingbird.pro.lifetime"
    nonisolated static var allProductIDs: [String] { [yearlyProductID, monthlyProductID, lifetimeProductID] }

    #if DEBUG
    private static let debugUnlockKey = "hummingbird.debug.proUnlocked"
    #endif

    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var isLoading = false
    private(set) var lastError: String?
    #if DEBUG
    /// Local QA unlock — DEBUG builds only. The property, its storage, and every
    /// path that reads it are compiled out of Release entirely.
    private(set) var debugUnlocked: Bool = false
    #endif

    /// The real, StoreKit-verified purchase status — independent of the
    /// TestFlight override below. This is what the paywall's purchase button
    /// gates on, so the actual buy flow stays fully testable in TestFlight
    /// even though features are already unlocked there.
    var hasRealPurchase: Bool { !purchasedProductIDs.isEmpty }

    /// True only when the running binary was installed via TestFlight — never
    /// true for a real App Store download. TestFlight and the App Store ship
    /// the exact same Release build (there's no separate "beta configuration"
    /// to compile against), so this is the only reliable way to tell them
    /// apart at runtime: Apple stamps a TestFlight install with a sandbox
    /// receipt, a real purchase with a production one.
    nonisolated static var isTestFlight: Bool {
        Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }

    /// Feature-gating status: a real purchase, DEBUG's local QA toggle, or
    /// simply running via TestFlight. External testers get every Pro method
    /// and feature unlocked automatically so they can validate the full set
    /// without completing a purchase first — never true for a real App Store
    /// production install.
    var isPro: Bool {
        #if DEBUG
        debugUnlocked || hasRealPurchase || Self.isTestFlight
        #else
        hasRealPurchase || Self.isTestFlight
        #endif
    }

    var yearlyProduct: Product? {
        products.first { $0.id == Self.yearlyProductID }
    }

    var monthlyProduct: Product? {
        products.first { $0.id == Self.monthlyProductID }
    }

    var lifetimeProduct: Product? {
        products.first { $0.id == Self.lifetimeProductID }
    }

    /// How much cheaper (per month) the yearly plan is vs 12× the monthly plan.
    /// Nil until both live products are loaded.
    var yearlySavingsPercent: Int? {
        guard let monthly = monthlyProduct, let yearly = yearlyProduct else { return nil }
        return Self.savingsPercent(monthly: monthly.price, yearly: yearly.price)
    }

    /// Pure, testable savings calculation.
    nonisolated static func savingsPercent(monthly: Decimal, yearly: Decimal) -> Int? {
        let annualizedMonthly = monthly * 12
        guard annualizedMonthly > 0, yearly < annualizedMonthly else { return nil }
        let fraction = (annualizedMonthly - yearly) / annualizedMonthly
        return Int((fraction as NSDecimalNumber).doubleValue * 100 + 0.5)
    }

    /// Long-lived `Transaction.updates` listener. Stored so it can be cancelled.
    /// `@ObservationIgnored` + `nonisolated(unsafe)` so `deinit` (which is
    /// nonisolated) can cancel it — `Task` is `Sendable`, and it's written once
    /// in `init` and read only in `deinit`, when no other reference exists.
    @ObservationIgnored
    private nonisolated(unsafe) var transactionListener: Task<Void, Never>?

    init() {
        #if DEBUG
        debugUnlocked = UserDefaults.standard.bool(forKey: Self.debugUnlockKey)
        #endif
        // Re-acquire self weakly *each iteration* so the listener never pins the
        // store alive between transactions — the frame of a plain
        // `for await … in Transaction.updates` would hold self strongly forever.
        transactionListener = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if let transaction = try? self.checkVerified(result) {
                    await transaction.finish()
                    await self.refreshPurchases()
                }
            }
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    func canUse(model: ForecastModel) -> Bool {
        !model.requiresPro || isPro
    }

    func maxHorizon(requested: Int) -> Int {
        let upper = isPro ? 90 : FreeTierLimits.maxHorizonDays
        return min(max(7, requested), upper)
    }

    func canSelectMoreIndicators(currentCount: Int) -> Bool {
        isPro || currentCount < FreeTierLimits.maxSelectedIndicators
    }

    /// Backoff schedule between `loadProducts()` attempts — a transient App Store
    /// outage or a cold StoreKit cache usually clears within a few seconds, so we
    /// retry a bounded number of times before surfacing an error. `isLoading`
    /// stays true across the whole sequence so the paywall shows one calm spinner
    /// rather than flashing an error and recovering.
    nonisolated static let loadRetryDelays: [Duration] = [.milliseconds(500), .seconds(2), .seconds(5)]

    /// Overridable in tests to shrink the backoff and stay fast.
    @ObservationIgnored
    var retryDelays: [Duration] = EntitlementStore.loadRetryDelays

    /// Seam for tests: how the product catalogue is fetched. Defaults to the
    /// real StoreKit call; a test can inject a loader that throws to exercise
    /// the bounded-backoff retry.
    @ObservationIgnored
    var productLoader: @Sendable ([String]) async throws -> [Product] = { try await Product.products(for: $0) }

    func loadProducts() async {
        // Already have the catalogue and nothing new to retry — just refresh
        // entitlements. Prevents a second `.task` (e.g. re-presenting the
        // paywall) from throwing the UI back into a loading state.
        if !products.isEmpty {
            await refreshPurchases()
            return
        }
        // Re-entrancy guard: ContentView.task and PaywallView.task both call
        // this, and a flaky connection can retrigger it. Without this, two
        // 4-attempt backoff loops run concurrently, doubling StoreKit calls and
        // wakeups. The in-flight load will set `products` / `lastError` for us.
        guard !isLoading else { return }

        isLoading = true
        lastError = nil
        defer { isLoading = false }

        // One initial attempt plus one per backoff delay.
        let attempts = retryDelays.count + 1
        for attempt in 0..<attempts {
            do {
                let loaded = try await productLoader(Self.allProductIDs)
                #if DEBUG
                // Without an attached StoreKit config / App Store Connect record,
                // `Product.products` legitimately returns []. That's the paywall's
                // by-design stub, not a failure — accept it and stop retrying.
                let emptyIsFailure = false
                #else
                let emptyIsFailure = true
                #endif
                if loaded.isEmpty && emptyIsFailure { throw StoreError.emptyProductList }
                products = loaded
                lastError = nil
                await refreshPurchases()
                return
            } catch {
                lastError = error.localizedDescription
                guard attempt < retryDelays.count else { break }
                try? await Task.sleep(for: retryDelays[attempt])
                guard !Task.isCancelled else { return }
            }
        }
        // All attempts exhausted — `lastError` is set, paywall shows an honest
        // empty state with a Retry button. The plan copy still renders.
    }

    func purchase(_ product: Product) async -> Bool {
        lastError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshPurchases()
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func restore() async {
        lastError = nil
        do {
            try await AppStore.sync()
            await refreshPurchases()
        } catch {
            lastError = error.localizedDescription
        }
    }

    #if DEBUG
    func setDebugUnlocked(_ unlocked: Bool) {
        debugUnlocked = unlocked
        UserDefaults.standard.set(unlocked, forKey: Self.debugUnlockKey)
    }
    #endif

    private func refreshPurchases() async {
        var owned: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                owned.insert(transaction.productID)
            }
        }
        purchasedProductIDs = owned
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

enum StoreError: LocalizedError {
    case failedVerification
    case emptyProductList

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            "Purchase could not be verified."
        case .emptyProductList:
            // Covers both "the store returned nothing" causes without guessing:
            // a transient App Store hiccup, or the products not being approved
            // in App Store Connect yet. Deliberately does NOT tell the user to
            // check a connection that may be fine.
            "The App Store isn't offering the Pro plans right now. Try again in a moment."
        }
    }
}

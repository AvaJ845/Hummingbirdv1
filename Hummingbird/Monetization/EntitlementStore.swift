import Foundation
import Observation
import StoreKit

/// StoreKit 2 entitlement surface. Products are optional until App Store Connect
/// is configured; Debug builds can unlock Pro locally for QA.
@MainActor
@Observable
final class EntitlementStore {
    static let yearlyProductID = "com.avaresearch.hummingbird.pro.yearly"
    static let monthlyProductID = "com.avaresearch.hummingbird.pro.monthly"
    static let lifetimeProductID = "com.avaresearch.hummingbird.pro.lifetime"
    nonisolated static var allProductIDs: [String] { [yearlyProductID, monthlyProductID, lifetimeProductID] }

    #if DEBUG
    private static let debugUnlockKey = "hummingbird.debug.proUnlocked"
    #endif

    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var isLoading = false
    private(set) var lastError: String?
    /// Local QA unlock — DEBUG builds only; never written in Release.
    private(set) var debugUnlocked: Bool = false

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

    /// Pay-once lifetime unlock (non-consumable). `isPro` already covers it —
    /// `Transaction.currentEntitlements` returns a non-consumable forever.
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
    /// `nonisolated(unsafe)` so `deinit` can cancel it — safe because it's written
    /// once in `init` and read only in `deinit`, when no other reference exists.
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

    func loadProducts() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            products = try await Product.products(for: Self.allProductIDs)
            await refreshPurchases()
        } catch {
            lastError = error.localizedDescription
            // Keep UI usable — paywall still explains the plan.
        }
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

    func setDebugUnlocked(_ unlocked: Bool) {
        #if DEBUG
        debugUnlocked = unlocked
        UserDefaults.standard.set(unlocked, forKey: Self.debugUnlockKey)
        #else
        _ = unlocked
        #endif
    }

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

    var errorDescription: String? {
        "Purchase could not be verified."
    }
}

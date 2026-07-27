import Foundation
import Observation
import StoreKit

/// StoreKit 2 entitlement surface. Products are optional until App Store Connect
/// is configured; Debug builds can unlock Pro locally for QA.
@MainActor
@Observable
final class EntitlementStore {
    static let yearlyProductID = "com.hummingbird.app.pro.yearly"

    #if DEBUG
    private static let debugUnlockKey = "hummingbird.debug.proUnlocked"
    #endif

    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var isLoading = false
    private(set) var lastError: String?
    /// Local QA unlock — DEBUG builds only; never written in Release.
    private(set) var debugUnlocked: Bool = false

    var isPro: Bool {
        #if DEBUG
        debugUnlocked || !purchasedProductIDs.isEmpty
        #else
        !purchasedProductIDs.isEmpty
        #endif
    }

    var yearlyProduct: Product? {
        products.first { $0.id == Self.yearlyProductID }
    }

    init() {
        #if DEBUG
        debugUnlocked = UserDefaults.standard.bool(forKey: Self.debugUnlockKey)
        #endif
        Task { [weak self] in
            await self?.listenForTransactions()
        }
    }

    func unlocks(_ feature: ProFeature) -> Bool {
        isPro
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
            products = try await Product.products(for: [Self.yearlyProductID])
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

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if let transaction = try? checkVerified(result) {
                await transaction.finish()
                await refreshPurchases()
            }
        }
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

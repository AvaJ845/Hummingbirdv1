import XCTest
@testable import Hummingbird

final class PricingTests: XCTestCase {
    func testProductIdentifiers() {
        XCTAssertEqual(EntitlementStore.yearlyProductID, "com.avaresearch.hummingbird.pro.yearly")
        XCTAssertEqual(EntitlementStore.monthlyProductID, "com.avaresearch.hummingbird.pro.monthly")
        XCTAssertEqual(EntitlementStore.lifetimeProductID, "com.avaresearch.hummingbird.pro.lifetime")
        // Three tiers: two auto-renewable subscriptions + one non-consumable unlock.
        XCTAssertEqual(EntitlementStore.allProductIDs, [
            "com.avaresearch.hummingbird.pro.yearly",
            "com.avaresearch.hummingbird.pro.monthly",
            "com.avaresearch.hummingbird.pro.lifetime"
        ])
    }

    func testLifetimePriceIsAboutTwoAndAHalfTimesAnnual() {
        let lifetime = Double(AppPricing.lifetimeUSD)!
        let yearly = Double(AppPricing.yearlyUSD)!
        XCTAssertEqual(lifetime, 49.99, accuracy: 0.001)
        // A fair one-time price sits between 2× and 3× the annual plan.
        XCTAssertGreaterThan(lifetime, yearly * 2)
        XCTAssertLessThan(lifetime, yearly * 3)
    }

    func testYearlySavingsVsMonthly() {
        // $2.99/mo → $35.88/yr vs $19.99/yr ≈ 44% cheaper.
        XCTAssertEqual(EntitlementStore.savingsPercent(monthly: 2.99, yearly: 19.99), 44)
    }

    func testSavingsNilWhenYearlyNotCheaper() {
        XCTAssertNil(EntitlementStore.savingsPercent(monthly: 1.00, yearly: 20.00)) // 12 < 20
        XCTAssertNil(EntitlementStore.savingsPercent(monthly: 0, yearly: 19.99))
    }
}

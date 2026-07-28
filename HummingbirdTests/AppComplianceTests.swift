import XCTest
@testable import Hummingbird

final class AppComplianceTests: XCTestCase {
    func testYearlyOnlyPricingForUntestedResults() {
        XCTAssertEqual(AppPricing.yearlyUSD, "19.99")
        let yearly = Double(AppPricing.yearlyUSD)!
        XCTAssertEqual(yearly, 19.99, accuracy: 0.001)
        // Roughly tip-jar monthly equivalent (~$1.67/mo) — fair for untested sketches.
        XCTAssertLessThan(yearly / 12, 2.0)
    }

    func testFreeTierKeepsClassicMethods() {
        XCTAssertFalse(ForecastModel.model(id: ForecastStrategy.drift.rawValue)!.requiresPro)
        XCTAssertFalse(ForecastModel.model(id: ForecastStrategy.holt.rawValue)!.requiresPro)
        XCTAssertFalse(ForecastModel.model(id: ForecastStrategy.trendSeasonal.rawValue)!.requiresPro)
        XCTAssertTrue(ForecastModel.model(id: ForecastStrategy.momentum.rawValue)!.requiresPro)
        XCTAssertEqual(ForecastModel.model(id: ForecastStrategy.momentum.rawValue)!.name, "Momentum")
        XCTAssertEqual(ForecastModel.model(id: ForecastStrategy.momentum.rawValue)!.nickname, "Peregrine")
        XCTAssertFalse(ForecastModel.all.contains { $0.name == "Swift" || $0.nickname == "Swift" })
    }

    func testLegalResourceNamesAreStable() {
        XCTAssertEqual(AppLegal.privacyResourceName, "PRIVACY")
        XCTAssertEqual(AppLegal.termsResourceName, "TERMS")
        XCTAssertNotNil(AppLegal.privacyPolicyURL)
        XCTAssertNotNil(AppLegal.termsOfUseURL)
    }

    func testUserAgentIsUnified() {
        XCTAssertTrue(AppNetwork.userAgent.contains("1.4"))
        XCTAssertTrue(AppNetwork.userAgent.contains("Hummingbird"))
    }

    func testProProductIDIsYearlyOnly() {
        XCTAssertEqual(EntitlementStore.yearlyProductID, "com.avaresearch.hummingbird.pro.yearly")
    }

    func testMethodNamesLeadNotBirdNicknames() {
        for model in ForecastModel.available {
            XCTAssertFalse(model.name.isEmpty)
            // Product UI uses method titles; nicknames are internal-only.
            XCTAssertNotEqual(model.name, model.nickname)
        }
        XCTAssertEqual(ForecastModel.model(id: ForecastStrategy.drift.rawValue)?.name, "Drift")
        XCTAssertEqual(ForecastModel.model(id: ForecastStrategy.holt.rawValue)?.name, "Holt")
        XCTAssertEqual(ForecastModel.model(id: ForecastStrategy.ensemble.rawValue)?.name, "Blend")
    }
}

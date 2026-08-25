import XCTest
@testable import Hummingbird

final class AlertEnginePortfolioTests: XCTestCase {
    private let day1 = Date(timeIntervalSince1970: 1_700_000_000)

    private func position(_ symbol: String, shares: Double = 1) -> PaperPosition {
        PaperPosition(id: UUID(), symbol: symbol, assetClass: .stock, openedAt: day1,
                      entryPrice: 100, shares: shares, direction: .higher)
    }

    func testFiresWhenMoveExceedsThreshold() {
        let alerts = AlertEngine.evaluatePortfolio(
            openPositions: [position("AAPL")],
            previousPrices: ["Stock:aapl": 100],
            newPrices: ["Stock:aapl": 110],
            threshold: 0.05
        )
        XCTAssertEqual(alerts.count, 1)
        XCTAssertTrue(alerts[0].title.contains("AAPL"))
    }

    func testSilentWhenMoveIsBelowThreshold() {
        let alerts = AlertEngine.evaluatePortfolio(
            openPositions: [position("AAPL")],
            previousPrices: ["Stock:aapl": 100],
            newPrices: ["Stock:aapl": 102],
            threshold: 0.05
        )
        XCTAssertTrue(alerts.isEmpty)
    }

    // No previous price (first-ever fetch) can't have "moved" — must not fire.
    func testSilentWithNoPreviousPrice() {
        let alerts = AlertEngine.evaluatePortfolio(
            openPositions: [position("AAPL")],
            previousPrices: [:],
            newPrices: ["Stock:aapl": 110],
            threshold: 0.05
        )
        XCTAssertTrue(alerts.isEmpty)
    }

    // A partial sell leaves two lots of the same symbol — must fire once, not twice.
    func testGroupsMultipleLotsOfSameSymbolIntoOneAlert() {
        let alerts = AlertEngine.evaluatePortfolio(
            openPositions: [position("AAPL", shares: 5), position("AAPL", shares: 5)],
            previousPrices: ["Stock:aapl": 100],
            newPrices: ["Stock:aapl": 110],
            threshold: 0.05
        )
        XCTAssertEqual(alerts.count, 1)
    }

    func testEvaluatesEachDistinctHeldSymbolIndependently() {
        let alerts = AlertEngine.evaluatePortfolio(
            openPositions: [position("AAPL"), position("MSFT")],
            previousPrices: ["Stock:aapl": 100, "Stock:msft": 200],
            newPrices: ["Stock:aapl": 110, "Stock:msft": 201],   // AAPL moved, MSFT didn't
            threshold: 0.05
        )
        XCTAssertEqual(alerts.count, 1)
        XCTAssertTrue(alerts[0].title.contains("AAPL"))
    }

    func testEmptyPortfolioProducesNoAlerts() {
        let alerts = AlertEngine.evaluatePortfolio(
            openPositions: [], previousPrices: ["Stock:aapl": 100],
            newPrices: ["Stock:aapl": 110], threshold: 0.05
        )
        XCTAssertTrue(alerts.isEmpty)
    }
}

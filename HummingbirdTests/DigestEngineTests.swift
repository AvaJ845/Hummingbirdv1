import XCTest
@testable import Hummingbird

final class DigestEngineTests: XCTestCase {

    private func snap(_ title: String, projected: Double) -> WatchlistSnapshot {
        WatchlistSnapshot(
            symbol: title.lowercased(),
            assetClass: .stock,
            title: title,
            price: 100,
            projectedChange: projected,
            bestMethodName: "Drift",
            horizonDays: 14,
            historySpark: [0.2, 0.5, 0.8],
            projectionSpark: [0.8, 0.9],
            updatedAt: Date()
        )
    }

    func testNilWithNoSnapshots() {
        XCTAssertNil(DigestEngine.compose(snapshots: []))
    }

    func testQuietWhenNothingMovesPastThreshold() {
        let digest = DigestEngine.compose(snapshots: [snap("AAPL", projected: 0.005)])
        XCTAssertNotNil(digest)
        XCTAssertTrue(digest!.body.contains("flat"))
    }

    func testCallsOutBiggestMoversInOrderAndExcludesSubThreshold() {
        let digest = DigestEngine.compose(snapshots: [
            snap("AAPL", projected: 0.03),    // +3%
            snap("BTC", projected: -0.08),    // -8% (biggest)
            snap("MSFT", projected: 0.003)    // +0.3% (below threshold)
        ])
        let body = digest!.body
        XCTAssertTrue(body.contains("BTC"))
        XCTAssertTrue(body.contains("AAPL"))
        XCTAssertFalse(body.contains("MSFT"), "sub-threshold excluded")
        // BTC (biggest) should appear before AAPL.
        XCTAssertLessThan(body.range(of: "BTC")!.lowerBound, body.range(of: "AAPL")!.lowerBound)
    }

    func testMorePluralization() {
        let snaps = (0..<5).map { snap("A\($0)", projected: 0.05 + Double($0) * 0.01) }
        XCTAssertTrue(DigestEngine.compose(snapshots: snaps)!.body.contains("and 2 more"))
    }

    func testHonestFramingNoAdviceWords() {
        let body = DigestEngine.compose(snapshots: [snap("AAPL", projected: 0.05)])!.body
        XCTAssertTrue(body.lowercased().contains("not predictions or advice"))
    }
}

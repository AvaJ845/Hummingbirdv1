import XCTest
@testable import Hummingbird

/// Sanity: the scorecard the screenshot harness seeds must round-trip through
/// the same persistence path the store uses.
final class TestSupportSeedTests: XCTestCase {
    func test_seededScorecardRoundTrips() throws {
        let proj = SketchProjection(
            targetDate: Date(), projectedMean: 170,
            projectedBandHalfWidth: 13, actualClose: 174, resolvedAt: Date()
        )
        let rec = SketchRecord(
            id: UUID(), symbol: "AAPL", assetClass: .stock,
            modelId: "trend-seasonal", modelName: "Trend + weekday",
            createdAt: Date().addingTimeInterval(-40 * 86_400), spotAtCreation: 168,
            projections: [proj], reliabilityAtCreation: 64, regimeAtCreation: .normal
        )
        let data = try JSONEncoder().encode([rec])
        let back = try JSONDecoder().decode([SketchRecord].self, from: data)
        XCTAssertEqual(back.count, 1)
        XCTAssertTrue(back[0].isResolved)
        XCTAssertEqual(back[0].representativeError ?? 0, abs(170 - 174) / 174, accuracy: 1e-9)
    }
}

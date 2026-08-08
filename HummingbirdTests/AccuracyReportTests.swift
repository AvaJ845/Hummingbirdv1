import XCTest
@testable import Hummingbird

/// Accuracy Report Card aggregations: per-horizon error, range calibration,
/// directional record, and Codable migration of the new optional fields.
final class AccuracyReportTests: XCTestCase {
    private let created = Date(timeIntervalSince1970: 1_700_000_000)

    private func proj(daysAhead: Int, mean: Double, band: Double? = nil, actual: Double?) -> SketchProjection {
        SketchProjection(
            targetDate: created.addingTimeInterval(Double(daysAhead) * 86_400),
            projectedMean: mean,
            projectedBandHalfWidth: band,
            actualClose: actual,
            resolvedAt: actual == nil ? nil : created
        )
    }

    private func record(spot: Double, _ projections: [SketchProjection]) -> SketchRecord {
        SketchRecord(id: UUID(), symbol: "AAPL", assetClass: .stock, modelId: "drift",
                     modelName: "Drift", createdAt: created, spotAtCreation: spot,
                     projections: projections, reliabilityAtCreation: nil)
    }

    func testHorizonAccuraciesBucketAndMedian() {
        let r = record(spot: 100, [
            proj(daysAhead: 1, mean: 101, actual: 100),  // 1d, APE 1%
            proj(daysAhead: 7, mean: 110, actual: 100),  // 7d, APE 10%
            proj(daysAhead: 31, mean: 90, actual: 100),  // ~30d bucket, APE 10%
        ])
        let h = ScorecardEngine.horizonAccuracies([r])
        XCTAssertEqual(h.map(\.daysAhead), [1, 7, 30])
        XCTAssertEqual(h[0].medianError, 0.01, accuracy: 1e-9)
        XCTAssertEqual(h[1].medianError, 0.10, accuracy: 1e-9)
        XCTAssertEqual(h[2].medianError, 0.10, accuracy: 1e-9)  // 31d snaps to the 30d bucket
    }

    func testRangeCalibrationCountsInBand() {
        // 4 of 5 land inside ±5 → 0.8.
        let r = record(spot: 100, [
            proj(daysAhead: 1, mean: 100, band: 5, actual: 103),
            proj(daysAhead: 2, mean: 100, band: 5, actual: 97),
            proj(daysAhead: 3, mean: 100, band: 5, actual: 105),  // edge, in
            proj(daysAhead: 4, mean: 100, band: 5, actual: 96),
            proj(daysAhead: 5, mean: 100, band: 5, actual: 110),  // out
        ])
        let cal = ScorecardEngine.rangeCalibration([r])
        XCTAssertEqual(cal?.resolvedWithBand, 5)
        XCTAssertEqual(cal?.inRangeRate ?? 0, 0.8, accuracy: 1e-9)
    }

    func testRangeCalibrationNilBelowThresholdAndIgnoresBandless() {
        let r = record(spot: 100, [
            proj(daysAhead: 1, mean: 100, band: nil, actual: 103),  // no band → excluded
            proj(daysAhead: 2, mean: 100, band: 5, actual: 101),
        ])
        XCTAssertNil(ScorecardEngine.rangeCalibration([r]))  // only 1 banded, < 5
    }

    func testDirectionalRecordSkipsNoDirectionCalls() {
        let r = record(spot: 100, [
            proj(daysAhead: 1, mean: 105, actual: 110),  // up / up  → hit
            proj(daysAhead: 2, mean: 105, actual: 95),   // up / down → miss
            proj(daysAhead: 3, mean: 95, actual: 90),    // down/down → hit
            proj(daysAhead: 4, mean: 95, actual: 101),   // down/up  → miss
            proj(daysAhead: 5, mean: 100, actual: 110),  // no direction → skipped
            proj(daysAhead: 6, mean: 108, actual: 120),  // up / up  → hit
        ])
        let d = ScorecardEngine.directionalRecord([r])
        XCTAssertEqual(d?.count, 5)                       // one skipped
        XCTAssertEqual(d?.hitRate ?? 0, 3.0 / 5.0, accuracy: 1e-9)
    }

    func testDecodesRecordMissingNewOptionalFields() throws {
        // Simulate a record persisted before the new fields existed.
        let rec = record(spot: 100, [proj(daysAhead: 1, mean: 101, band: 5, actual: nil)])
        var dict = try JSONSerialization.jsonObject(with: JSONEncoder().encode(rec)) as! [String: Any]
        dict.removeValue(forKey: "reliabilityAtCreation")
        dict["projections"] = (dict["projections"] as! [[String: Any]]).map {
            var p = $0; p.removeValue(forKey: "projectedBandHalfWidth"); return p
        }
        let data = try JSONSerialization.data(withJSONObject: dict)

        let decoded = try JSONDecoder().decode(SketchRecord.self, from: data)
        XCTAssertNil(decoded.reliabilityAtCreation)
        XCTAssertNil(decoded.projections.first?.projectedBandHalfWidth)
        XCTAssertNil(decoded.projections.first?.landedInRange)
    }
}

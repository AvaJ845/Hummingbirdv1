import XCTest
@testable import Hummingbird

final class VolatilityRegimeTests: XCTestCase {

    private func series(_ closes: [Double]) -> PriceSeries {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let pts = closes.enumerated().map { PricePoint(date: base.addingTimeInterval(Double($0.offset) * 86_400), close: $0.element) }
        return PriceSeries(symbol: "TEST", assetClass: .stock, points: pts, isSample: true)
    }

    func testNilWithoutEnoughHistory() {
        XCTAssertNil(RegimeClassifier.classify(series: series([100, 101, 102])))
    }

    func testHighVolatilityWhenRecentlyTurbulent() {
        // 55 calm days, then 10 wild days → recent vol >> baseline vol.
        var closes: [Double] = []
        for i in 0..<55 { closes.append(100 + Double(i % 2) * 0.1) }   // ~flat
        for i in 0..<10 { closes.append(100 + Double(i % 2 == 0 ? 18 : -18)) } // big swings
        let regime = RegimeClassifier.classify(series: series(closes))
        XCTAssertEqual(regime, .high)
        XCTAssertTrue(regime!.isNoteworthy)
    }

    func testNormalWhenSteady() {
        // Uniform small oscillation → recent ≈ baseline.
        let closes = (0..<70).map { 100 + Double($0 % 2) * 0.5 }
        let regime = RegimeClassifier.classify(series: series(closes))
        XCTAssertEqual(regime, .normal)
        XCTAssertFalse(regime!.isNoteworthy)
    }

    func testCalmWhenRecentlyQuietVsVolatilePast() {
        // Volatile first 55, flat last 10 → recent vol << baseline vol.
        var closes: [Double] = []
        for i in 0..<55 { closes.append(100 + Double(i % 2 == 0 ? 12 : -12)) }
        for _ in 0..<10 { closes.append(100) }
        XCTAssertEqual(RegimeClassifier.classify(series: series(closes)), .calm)
    }
}

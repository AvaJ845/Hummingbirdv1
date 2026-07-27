import XCTest
@testable import Hummingbird

final class MacroAdjusterTests: XCTestCase {
    func testNoSelectionYieldsNoAdjustment() {
        let snapshots = EconomicIndicatorKind.allCases.map(SampleMacro.snapshot)
        let macro = MacroAdjuster.adjustment(from: snapshots, selected: [], assetClass: .stock)
        XCTAssertFalse(macro.isActive)
        XCTAssertEqual(macro.horizonBias, 0, accuracy: 1e-12)
    }

    func testRisingRatesProduceNegativeBias() {
        let snapshot = EconomicSnapshot(
            kind: .fedFunds,
            value: 5.0,
            previousValue: 4.0,
            asOf: .now,
            source: "Test",
            isSample: false
        )
        let macro = MacroAdjuster.adjustment(
            from: [snapshot],
            selected: [snapshot.kind.id],
            assetClass: .stock
        )
        XCTAssertTrue(macro.isActive)
        XCTAssertLessThan(macro.horizonBias, 0)
        XCTAssertEqual(macro.contributions.count, 1)
    }

    func testCryptoGetsLargerAbsoluteTiltThanStocks() {
        let snapshot = EconomicSnapshot(
            kind: .treasury10Y,
            value: 5.0,
            previousValue: 4.0,
            asOf: .now,
            source: "Test",
            isSample: false
        )
        let stock = MacroAdjuster.adjustment(
            from: [snapshot],
            selected: [snapshot.kind.id],
            assetClass: .stock,
            model: .default
        )
        let crypto = MacroAdjuster.adjustment(
            from: [snapshot],
            selected: [snapshot.kind.id],
            assetClass: .crypto,
            model: .default
        )
        XCTAssertGreaterThan(abs(crypto.horizonBias), abs(stock.horizonBias))
    }

    func testForecasterAppliesMacroToTarget() {
        let series = SampleData.series(symbol: "AAPL", assetClass: .stock, days: 120)
        let base = Forecaster.forecast(series: series, model: .default, horizon: 30, macro: .none)
        let macro = MacroAdjustment(
            horizonBias: -0.05,
            bandScale: 1.2,
            contributions: [
                MacroContribution(
                    indicatorID: "fedfunds",
                    name: "Fed Funds Proxy",
                    bias: -0.05,
                    rationale: "Test"
                )
            ]
        )
        let tilted = Forecaster.forecast(series: series, model: .default, horizon: 30, macro: macro)

        guard let baseTarget = base.targetPrice, let tiltedTarget = tilted.targetPrice else {
            return XCTFail("Missing targets")
        }
        XCTAssertLessThan(tiltedTarget, baseTarget)
        XCTAssertEqual(tilted.macro.horizonBias, -0.05, accuracy: 1e-12)
        XCTAssertGreaterThan(
            tilted.points.last!.upper - tilted.points.last!.mean,
            base.points.last!.upper - base.points.last!.mean
        )
    }
}

final class EconomicParsingTests: XCTestCase {
    func testParseYahooPercent() throws {
        let json = """
        {
          "chart": {
            "result": [{
              "timestamp": [1700000000, 1700086400, 1700172800],
              "indicators": { "quote": [{ "close": [4.10, 4.20, 4.30] }] }
            }]
          }
        }
        """.data(using: .utf8)!

        let snapshot = try EconomicParsing.parseYahooPercent(json, kind: .fedFunds)
        XCTAssertEqual(snapshot.value, 4.30, accuracy: 0.0001)
        XCTAssertEqual(snapshot.previousValue ?? -1, 4.10, accuracy: 0.0001)
        XCTAssertFalse(snapshot.isSample)
    }
}

@MainActor
final class EconomicDataServiceTests: XCTestCase {
    func testLiveMacroFetchReturnsOnlyLiveDailyRates() async {
        let service = EconomicDataService()
        let snapshots = await service.fetchSnapshots()

        XCTAssertFalse(snapshots.isEmpty, "Rate what-ifs failed: expected live Yahoo ^IRX/^TNX")
        XCTAssertTrue(snapshots.allSatisfy { !$0.isSample })
        XCTAssertEqual(Set(snapshots.map(\.kind.id)).count, snapshots.count)
        XCTAssertTrue(snapshots.allSatisfy { $0.kind.cadence == "Daily" })
        XCTAssertTrue(snapshots.allSatisfy { $0.source == "Yahoo Finance" })

        let fed = snapshots.first { $0.kind == .fedFunds }
        let tenY = snapshots.first { $0.kind == .treasury10Y }
        XCTAssertNotNil(fed, "Missing Yahoo ^IRX fed proxy")
        XCTAssertNotNil(tenY, "Missing Yahoo ^TNX 10Y")
        XCTAssertGreaterThan(fed?.value ?? 0, 0)
        XCTAssertGreaterThan(tenY?.value ?? 0, 0)
        XCTAssertEqual(snapshots.count, EconomicIndicatorKind.allCases.count)
    }
}

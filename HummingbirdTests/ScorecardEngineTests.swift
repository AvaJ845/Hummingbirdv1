import XCTest
@testable import Hummingbird

final class ScorecardEngineTests: XCTestCase {

    private func day(_ offset: Int, from base: Date = Date(timeIntervalSince1970: 1_700_000_000)) -> Date {
        base.addingTimeInterval(Double(offset) * 86_400)
    }

    private func forecast(lastClose: Double, points: [(offset: Int, mean: Double)], now: Date) -> Forecast {
        let history = [PricePoint(date: now, close: lastClose)]
        let pts = points.map { p in
            ForecastPoint(date: day(p.offset, from: now), mean: p.mean, lower: p.mean * 0.95, upper: p.mean * 1.05)
        }
        let model = ForecastModel.model(id: ForecastStrategy.drift.rawValue)!
        return Forecast(model: model, history: history, points: pts)
    }

    func testMakeRecordSamplesHorizonsAndSpot() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let f = forecast(lastClose: 100, points: [(1, 101), (7, 105), (14, 108), (30, 115)], now: now)
        let record = ScorecardEngine.makeRecord(forecast: f, symbol: "AAPL", assetClass: .stock, now: now)

        XCTAssertNotNil(record)
        XCTAssertEqual(record?.spotAtCreation, 100)
        XCTAssertEqual(record?.symbol, "AAPL")
        XCTAssertEqual(record?.modelId, ForecastStrategy.drift.rawValue)
        XCTAssertFalse(record!.projections.isEmpty)
        // Sorted ascending by target date.
        let dates = record!.projections.map(\.targetDate)
        XCTAssertEqual(dates, dates.sorted())
        XCTAssertFalse(record!.isResolved)
    }

    func testMakeRecordNilWhenNoPoints() {
        let now = Date()
        let empty = Forecast(model: ForecastModel.model(id: ForecastStrategy.drift.rawValue)!,
                             history: [PricePoint(date: now, close: 100)], points: [])
        XCTAssertNil(ScorecardEngine.makeRecord(forecast: empty, symbol: "X", assetClass: .stock, now: now))
    }

    func testResolveMatchesNearestCloseWithinTolerance() {
        let target = Date(timeIntervalSince1970: 1_600_000_000)  // firmly in the past
        var record = SketchRecord(id: UUID(), symbol: "AAPL", assetClass: .stock,
                                  modelId: "drift", modelName: "Drift", createdAt: target.addingTimeInterval(-30 * 86_400),
                                  spotAtCreation: 100,
                                  projections: [SketchProjection(targetDate: target, projectedMean: 100)])
        let series = PriceSeries(symbol: "aapl", assetClass: .stock, points: [
            PricePoint(date: target.addingTimeInterval(86_400), close: 110)  // 1 day off → within tolerance
        ], isSample: false)

        record = ScorecardEngine.resolve(record, against: series)
        XCTAssertEqual(record.projections[0].actualClose, 110)
        XCTAssertEqual(record.projections[0].absolutePercentageError!, abs(100 - 110) / 110, accuracy: 1e-9)
        XCTAssertTrue(record.isResolved)
    }

    func testResolveRespectsToleranceSymbolAndFuture() {
        let past = Date(timeIntervalSince1970: 1_600_000_000)
        let base = SketchRecord(id: UUID(), symbol: "AAPL", assetClass: .stock, modelId: "drift",
                                modelName: "Drift", createdAt: past, spotAtCreation: 100,
                                projections: [SketchProjection(targetDate: past, projectedMean: 100)])
        // Too far away in time (5 days) → no match.
        let farSeries = PriceSeries(symbol: "AAPL", assetClass: .stock,
                                    points: [PricePoint(date: past.addingTimeInterval(5 * 86_400), close: 110)], isSample: false)
        XCTAssertFalse(ScorecardEngine.resolve(base, against: farSeries).isResolved)
        // Wrong symbol → no match.
        let wrong = PriceSeries(symbol: "MSFT", assetClass: .stock,
                                points: [PricePoint(date: past, close: 110)], isSample: false)
        XCTAssertFalse(ScorecardEngine.resolve(base, against: wrong).isResolved)
        // Future target must never resolve.
        let future = SketchRecord(id: UUID(), symbol: "AAPL", assetClass: .stock, modelId: "drift",
                                  modelName: "Drift", createdAt: Date(), spotAtCreation: 100,
                                  projections: [SketchProjection(targetDate: Date().addingTimeInterval(10 * 86_400), projectedMean: 100)])
        let futureSeries = PriceSeries(symbol: "AAPL", assetClass: .stock,
                                       points: [PricePoint(date: Date().addingTimeInterval(10 * 86_400), close: 110)], isSample: false)
        XCTAssertFalse(ScorecardEngine.resolve(future, against: futureSeries).isResolved)
    }

    private func resolvedRecord(model: String, ape: Double, regime: VolatilityRegime? = nil) -> SketchRecord {
        SketchRecord(id: UUID(), symbol: "AAPL", assetClass: .stock, modelId: model, modelName: model.capitalized,
                     createdAt: Date(), spotAtCreation: 100,
                     projections: [SketchProjection(targetDate: Date(timeIntervalSince1970: 1),
                                                    projectedMean: 100, actualClose: 100 / (1 - ape), resolvedAt: Date())],
                     regimeAtCreation: regime)
    }

    func testBestModelPicksLowestErrorAndRespectsMinResolved() {
        let records =
            [resolvedRecord(model: "holt", ape: 0.02), resolvedRecord(model: "holt", ape: 0.02), resolvedRecord(model: "holt", ape: 0.025)]
            + [resolvedRecord(model: "drift", ape: 0.08), resolvedRecord(model: "drift", ape: 0.07), resolvedRecord(model: "drift", ape: 0.09)]
            + [resolvedRecord(model: "linear", ape: 0.001)]   // only 1 → excluded

        let perfs = ScorecardEngine.modelPerformances(records)
        XCTAssertEqual(perfs.count, 2, "linear excluded for too few scored")
        XCTAssertEqual(perfs.first?.modelId, "holt")
        XCTAssertLessThan(perfs.first!.medianError, perfs.last!.medianError)
        XCTAssertEqual(ScorecardEngine.bestModel(records)?.modelId, "holt")
    }

    func testBestModelNilWithoutEnoughResolved() {
        let records = [resolvedRecord(model: "holt", ape: 0.02), resolvedRecord(model: "drift", ape: 0.03)]
        XCTAssertNil(ScorecardEngine.bestModel(records), "one scored sketch per model isn't enough")
    }

    func testSummaryAndMedian() {
        XCTAssertNil(ScorecardEngine.median(sorted: []))
        XCTAssertEqual(ScorecardEngine.median(sorted: [0.02, 0.04, 0.06])!, 0.04, accuracy: 1e-9)
        XCTAssertEqual(ScorecardEngine.median(sorted: [0.02, 0.06])!, 0.04, accuracy: 1e-9)

        func resolved(_ ape: Double) -> SketchRecord {
            SketchRecord(id: UUID(), symbol: "A", assetClass: .stock, modelId: "drift", modelName: "Drift",
                         createdAt: Date(), spotAtCreation: 100,
                         projections: [SketchProjection(targetDate: Date(timeIntervalSince1970: 1),
                                                        projectedMean: 100, actualClose: 100 / (1 - ape), resolvedAt: Date())])
        }
        // Two resolved (~5% and ~10%) + one unresolved.
        let unresolved = SketchRecord(id: UUID(), symbol: "A", assetClass: .stock, modelId: "drift",
                                      modelName: "Drift", createdAt: Date(), spotAtCreation: 100,
                                      projections: [SketchProjection(targetDate: Date(), projectedMean: 100)])
        let summary = ScorecardEngine.summary([resolved(0.05), resolved(0.10), unresolved])
        XCTAssertEqual(summary.totalSketches, 3)
        XCTAssertEqual(summary.resolvedSketches, 2)
        XCTAssertNotNil(summary.medianError)
    }

    // MARK: - Regime-segmented performance

    func testRegimePerformancesExcludesRecordsWithoutARegime() {
        let records = [
            resolvedRecord(model: "holt", ape: 0.02, regime: nil),
            resolvedRecord(model: "holt", ape: 0.02, regime: nil),
        ]
        XCTAssertTrue(ScorecardEngine.regimePerformances(records).isEmpty)
    }

    func testRegimePerformancesSegmentsByRegimeIndependently() {
        let calm =
            [resolvedRecord(model: "drift", ape: 0.01, regime: .calm), resolvedRecord(model: "drift", ape: 0.01, regime: .calm)]
            + [resolvedRecord(model: "holt", ape: 0.05, regime: .calm), resolvedRecord(model: "holt", ape: 0.05, regime: .calm)]
        let high =
            [resolvedRecord(model: "holt", ape: 0.02, regime: .high), resolvedRecord(model: "holt", ape: 0.02, regime: .high)]
            + [resolvedRecord(model: "drift", ape: 0.09, regime: .high), resolvedRecord(model: "drift", ape: 0.09, regime: .high)]

        let result = ScorecardEngine.regimePerformances(calm + high)

        XCTAssertEqual(result.map(\.regime), [.calm, .high])   // canonical calm→high order
        XCTAssertEqual(result.first { $0.regime == .calm }?.best.modelId, "drift")
        XCTAssertEqual(result.first { $0.regime == .high }?.best.modelId, "holt", "the same method needn't win in both regimes")
    }

    func testRegimePerformancesRespectsMinResolvedPerBucket() {
        let records = [resolvedRecord(model: "drift", ape: 0.02, regime: .calm)]   // only 1 scored
        XCTAssertTrue(ScorecardEngine.regimePerformances(records).isEmpty)
    }
}

import Foundation

/// Pure, deterministic scorecard math — no state, no I/O. Turns a finished
/// forecast into a small record, resolves past records against real prices,
/// and aggregates an honest track record. Fully unit-tested.
enum ScorecardEngine {
    /// Horizons (days ahead) we sample from a sketch to score later. Kept
    /// short so records are tiny and resolve quickly.
    static let sampleOffsetsDays = [1, 7, 14, 30]

    private static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    /// Build a record from a completed forecast, sampling a few representative
    /// horizons. Returns nil when there's nothing to score.
    static func makeRecord(
        forecast: Forecast,
        symbol: String,
        assetClass: AssetClass,
        reliabilityAtCreation: Int? = nil,
        now: Date = Date()
    ) -> SketchRecord? {
        guard let spot = forecast.lastClose, !forecast.points.isEmpty else { return nil }

        var projections: [SketchProjection] = []
        var usedDates = Set<Date>()

        func addNearest(to target: Date) {
            guard let point = forecast.points.min(by: {
                abs($0.date.timeIntervalSince(target)) < abs($1.date.timeIntervalSince(target))
            }), !usedDates.contains(point.date) else { return }
            usedDates.insert(point.date)
            projections.append(SketchProjection(
                targetDate: point.date, projectedMean: point.mean,
                projectedBandHalfWidth: point.bandHalfWidth))
        }

        for offset in sampleOffsetsDays {
            if let target = calendar.date(byAdding: .day, value: offset, to: now) {
                addNearest(to: target)
            }
        }
        // Always include the far end of the horizon.
        if let last = forecast.points.last, !usedDates.contains(last.date) {
            projections.append(SketchProjection(
                targetDate: last.date, projectedMean: last.mean,
                projectedBandHalfWidth: last.bandHalfWidth))
        }

        guard !projections.isEmpty else { return nil }
        return SketchRecord(
            id: UUID(),
            symbol: symbol,
            assetClass: assetClass,
            modelId: forecast.model.strategy.rawValue,
            modelName: forecast.model.name,
            createdAt: now,
            spotAtCreation: spot,
            projections: projections.sorted { $0.targetDate < $1.targetDate },
            reliabilityAtCreation: reliabilityAtCreation
        )
    }

    /// Resolve any unresolved horizons of `record` against a fresh series for
    /// the same asset: match each target date to the nearest real close within
    /// `toleranceDays`. Returns an updated copy (unchanged if nothing resolved).
    static func resolve(
        _ record: SketchRecord,
        against series: PriceSeries,
        toleranceDays: Int = 2
    ) -> SketchRecord {
        guard record.symbol.caseInsensitiveCompare(series.symbol) == .orderedSame,
              record.assetClass == series.assetClass else { return record }

        var updated = record
        let now = Date()
        for index in updated.projections.indices where !updated.projections[index].isResolved {
            let target = updated.projections[index].targetDate
            guard target <= now else { continue }  // don't resolve the future
            if let close = nearestClose(in: series, to: target, toleranceDays: toleranceDays) {
                updated.projections[index].actualClose = close
                updated.projections[index].resolvedAt = now
            }
        }
        return updated
    }

    private static func nearestClose(in series: PriceSeries, to date: Date, toleranceDays: Int) -> Double? {
        let tolerance = TimeInterval(toleranceDays * 86_400)
        var best: (delta: TimeInterval, close: Double)?
        for point in series.points {
            let delta = abs(point.date.timeIntervalSince(date))
            guard delta <= tolerance else { continue }
            if let current = best, current.delta <= delta { continue }
            best = (delta, point.close)
        }
        return best?.close
    }

    /// Aggregate a set of records into a display summary.
    static func summary(_ records: [SketchRecord]) -> ScorecardSummary {
        let resolved = records.filter(\.isResolved)
        let errors = resolved.compactMap(\.representativeError).sorted()
        return ScorecardSummary(
            totalSketches: records.count,
            resolvedSketches: resolved.count,
            medianError: median(sorted: errors)
        )
    }

    /// Per-model track record for one asset, best (lowest typical error) first.
    /// Only models with at least `minResolved` scored sketches are included, so
    /// a single lucky sketch never crowns a "best" method.
    static func modelPerformances(_ records: [SketchRecord], minResolved: Int = 2) -> [ModelPerformance] {
        let byModel = Dictionary(grouping: records.filter(\.isResolved)) { $0.modelId }
        return byModel.compactMap { modelId, recs -> ModelPerformance? in
            let errors = recs.compactMap(\.representativeError).sorted()
            guard recs.count >= minResolved, let med = median(sorted: errors) else { return nil }
            return ModelPerformance(modelId: modelId,
                                    modelName: recs.first?.modelName ?? modelId,
                                    resolvedCount: recs.count,
                                    medianError: med)
        }
        .sorted { $0.medianError < $1.medianError }
    }

    /// The method that has tracked this asset closest (nil until enough scored
    /// sketches exist).
    static func bestModel(_ records: [SketchRecord], minResolved: Int = 2) -> ModelPerformance? {
        modelPerformances(records, minResolved: minResolved).first
    }

    // MARK: - Accuracy Report Card

    /// Typical error at each sampled horizon (1/7/14/30 days), snapping each
    /// resolved projection to its nearest sample offset. Best-resolved first.
    static func horizonAccuracies(_ records: [SketchRecord]) -> [HorizonAccuracy] {
        var errorsByBucket: [Int: [Double]] = [:]
        for record in records {
            for projection in record.projections {
                guard let ape = projection.absolutePercentageError else { continue }
                let days = projection.targetDate.timeIntervalSince(record.createdAt) / 86_400
                let bucket = sampleOffsetsDays.min { abs(Double($0) - days) < abs(Double($1) - days) } ?? Int(days.rounded())
                errorsByBucket[bucket, default: []].append(ape)
            }
        }
        return errorsByBucket.compactMap { bucket, errors -> HorizonAccuracy? in
            guard let med = median(sorted: errors.sorted()) else { return nil }
            return HorizonAccuracy(daysAhead: bucket, resolvedCount: errors.count, medianError: med)
        }
        .sorted { $0.daysAhead < $1.daysAhead }
    }

    /// How often the real price landed inside the sketch's stated range. Nil
    /// until at least `minResolved` banded horizons have resolved.
    static func rangeCalibration(_ records: [SketchRecord], minResolved: Int = 5) -> RangeCalibration? {
        let flags = records.flatMap { $0.projections.compactMap(\.landedInRange) }
        guard flags.count >= minResolved else { return nil }
        let inRange = flags.filter { $0 }.count
        return RangeCalibration(inRangeRate: Double(inRange) / Double(flags.count),
                                resolvedWithBand: flags.count)
    }

    /// How often past sketches called the up/down direction (vs. spot at
    /// creation) correctly. Skips horizons with no predicted move. Nil until at
    /// least `minResolved` directional calls have resolved.
    static func directionalRecord(_ records: [SketchRecord], minResolved: Int = 5) -> DirectionalRecord? {
        var calls = 0
        var hits = 0
        for record in records {
            for projection in record.projections {
                guard let actual = projection.actualClose else { continue }
                let predictedUp = projection.projectedMean - record.spotAtCreation
                guard predictedUp != 0 else { continue }   // no direction claimed
                calls += 1
                if (predictedUp > 0) == (actual > record.spotAtCreation) { hits += 1 }
            }
        }
        guard calls >= minResolved else { return nil }
        return DirectionalRecord(hitRate: Double(hits) / Double(calls), count: calls)
    }

    /// The full Accuracy Report Card for a set of records.
    static func report(_ records: [SketchRecord]) -> ScorecardReport {
        ScorecardReport(
            summary: summary(records),
            horizons: horizonAccuracies(records),
            models: modelPerformances(records),
            calibration: rangeCalibration(records),
            directional: directionalRecord(records)
        )
    }

    /// Median of an already-sorted array.
    static func median(sorted values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let n = values.count
        if n % 2 == 1 { return values[n / 2] }
        return (values[n / 2 - 1] + values[n / 2]) / 2
    }
}

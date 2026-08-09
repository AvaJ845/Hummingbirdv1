import Foundation

/// Pure, deterministic scoring for the user's own calls — resolve a call against
/// a fresh series, and aggregate an honest record. No state, no I/O.
enum UserCallEngine {
    /// Resolve a single call against a fresh series for the same asset: match its
    /// target date to the nearest real close within `toleranceDays`. Returns an
    /// updated copy (unchanged if it can't resolve yet).
    static func resolve(
        _ call: UserCall,
        against series: PriceSeries,
        toleranceDays: Int = 3,
        now: Date = Date()
    ) -> UserCall {
        guard !call.isResolved,
              call.symbol.caseInsensitiveCompare(series.symbol) == .orderedSame,
              call.assetClass == series.assetClass,
              call.targetDate <= now,
              let close = PriceResolution.nearestClose(in: series, to: call.targetDate, toleranceDays: toleranceDays)
        else { return call }

        var updated = call
        updated.actualClose = close
        updated.resolvedAt = now
        return updated
    }

    /// Aggregate a set of calls into the user's honest record.
    static func report(_ calls: [UserCall]) -> UserCallReport {
        let resolved = calls.filter(\.isResolved)
        let decided = resolved.compactMap(\.wasCorrect)        // excludes flat pushes
        let overall = CallAccuracy(decided: decided.count, correct: decided.filter { $0 }.count)

        let byConfidence: [ConfidenceCalibration] = CallConfidence.allCases.compactMap { level in
            let flags = resolved.filter { $0.confidence == level }.compactMap(\.wasCorrect)
            guard !flags.isEmpty else { return nil }
            return ConfidenceCalibration(
                confidence: level,
                decided: flags.count,
                hitRate: Double(flags.filter { $0 }.count) / Double(flags.count)
            )
        }
        .sorted { $0.confidence.order < $1.confidence.order }

        return UserCallReport(total: calls.count, resolved: resolved.count,
                              overall: overall, byConfidence: byConfidence)
    }

    /// You vs. the methods — your directional hit rate against each method's, on
    /// the same resolved calls that snapshotted method predictions. Nil until at
    /// least `minResolved` such calls exist.
    static func vsMethods(_ calls: [UserCall], minResolved: Int = 5) -> VsMethods? {
        // Resolved, decidable calls that carry a method snapshot.
        let eligible = calls.filter { $0.wasCorrect != nil && $0.methodDirections != nil }
        guard eligible.count >= minResolved else { return nil }

        let userHits = eligible.filter { $0.wasCorrect == true }.count
        let userRate = Double(userHits) / Double(eligible.count)

        var ids = Set<String>()
        for call in eligible { if let dirs = call.methodDirections { ids.formUnion(dirs.keys) } }

        let methods: [MethodTally] = ids.compactMap { id in
            let flags = eligible.compactMap { $0.methodWasCorrect(id) }
            guard !flags.isEmpty else { return nil }
            return MethodTally(
                methodId: id,
                methodName: ForecastModel.model(id: id)?.name ?? id,
                decided: flags.count,
                hitRate: Double(flags.filter { $0 }.count) / Double(flags.count)
            )
        }
        .sorted { $0.hitRate > $1.hitRate }

        return VsMethods(userHitRate: userRate, userDecided: eligible.count, methods: methods)
    }
}

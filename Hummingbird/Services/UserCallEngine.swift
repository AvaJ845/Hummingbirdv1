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
              let close = nearestClose(in: series, to: call.targetDate, toleranceDays: toleranceDays)
        else { return call }

        var updated = call
        updated.actualClose = close
        updated.resolvedAt = now
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
}

import Foundation

/// One projected point of a past sketch, later "resolved" against the real
/// close once that date arrives. Stored on-device only.
struct SketchProjection: Codable, Hashable, Sendable {
    let targetDate: Date
    let projectedMean: Double
    /// The sketch's ~80% range half-width at this horizon (upper − mean),
    /// captured at creation so we can later check whether the real price landed
    /// inside the stated range (calibration). Optional: records made before this
    /// was tracked simply don't count toward calibration.
    var projectedBandHalfWidth: Double?
    var actualClose: Double?
    var resolvedAt: Date?

    var isResolved: Bool { actualClose != nil }

    /// Absolute percentage error vs. the real close (nil until resolved).
    var absolutePercentageError: Double? {
        guard let actual = actualClose, actual != 0 else { return nil }
        return abs(projectedMean - actual) / abs(actual)
    }

    /// Did the real close land inside the sketch's stated range? Nil unless
    /// resolved *and* a band was recorded.
    var landedInRange: Bool? {
        guard let actual = actualClose, let band = projectedBandHalfWidth else { return nil }
        return abs(projectedMean - actual) <= band
    }
}

/// A lightweight record of one sketch the user ran — the honesty ledger.
/// Deliberately small (a handful of sampled horizons, no full path) so the
/// whole history stays tiny and fast.
struct SketchRecord: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let symbol: String
    let assetClass: AssetClass
    let modelId: String
    let modelName: String
    let createdAt: Date
    let spotAtCreation: Double
    var projections: [SketchProjection]
    /// The reliability score (0–100) shown when this sketch was made. Groundwork
    /// for reliability calibration; optional so older records decode cleanly.
    var reliabilityAtCreation: Int?

    var isResolved: Bool { projections.contains { $0.isResolved } }
    var isFullyResolved: Bool { !projections.isEmpty && projections.allSatisfy { $0.isResolved } }

    /// Representative error for this sketch: the mean APE across its resolved
    /// horizons. Nil until at least one horizon resolves.
    var representativeError: Double? {
        let apes = projections.compactMap(\.absolutePercentageError)
        guard !apes.isEmpty else { return nil }
        return apes.reduce(0, +) / Double(apes.count)
    }
}

/// Aggregated, plain-English track record for display.
struct ScorecardSummary: Equatable, Sendable {
    let totalSketches: Int
    let resolvedSketches: Int
    /// Median representative error across resolved sketches (fraction, e.g. 0.032).
    let medianError: Double?

    var hasResolved: Bool { resolvedSketches > 0 }

    static let empty = ScorecardSummary(totalSketches: 0, resolvedSketches: 0, medianError: nil)
}

/// One method's tracked accuracy for a single asset.
struct ModelPerformance: Identifiable, Equatable, Sendable {
    let modelId: String
    let modelName: String
    let resolvedCount: Int
    let medianError: Double   // fraction, e.g. 0.021
    var id: String { modelId }
}

/// Typical error at one sampled horizon (e.g. "7 days ahead → 2.3%").
struct HorizonAccuracy: Identifiable, Equatable, Sendable {
    let daysAhead: Int
    let resolvedCount: Int
    let medianError: Double   // fraction
    var id: Int { daysAhead }
}

/// How often the real price landed inside the sketch's stated ~80% range.
struct RangeCalibration: Equatable, Sendable {
    let inRangeRate: Double    // fraction, e.g. 0.78
    let resolvedWithBand: Int
    /// The range's design coverage (bands are ±1.28σ ≈ 80%).
    static let target = 0.80
}

/// How often past sketches called the up/down direction (vs. spot) correctly.
/// A record of the past — never a promise, never advice.
struct DirectionalRecord: Equatable, Sendable {
    let hitRate: Double        // fraction, e.g. 0.61
    let count: Int
}

/// The full Accuracy Report Card for a set of records.
struct ScorecardReport: Equatable, Sendable {
    let summary: ScorecardSummary
    let horizons: [HorizonAccuracy]
    let models: [ModelPerformance]
    let calibration: RangeCalibration?
    let directional: DirectionalRecord?

    static let empty = ScorecardReport(
        summary: .empty, horizons: [], models: [], calibration: nil, directional: nil
    )
}

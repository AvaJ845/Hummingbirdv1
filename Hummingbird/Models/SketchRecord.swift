import Foundation

/// One projected point of a past sketch, later "resolved" against the real
/// close once that date arrives. Stored on-device only.
struct SketchProjection: Codable, Hashable, Sendable {
    let targetDate: Date
    let projectedMean: Double
    var actualClose: Double?
    var resolvedAt: Date?

    var isResolved: Bool { actualClose != nil }

    /// Absolute percentage error vs. the real close (nil until resolved).
    var absolutePercentageError: Double? {
        guard let actual = actualClose, actual != 0 else { return nil }
        return abs(projectedMean - actual) / abs(actual)
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

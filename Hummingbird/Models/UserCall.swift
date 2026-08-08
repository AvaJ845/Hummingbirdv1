import Foundation

/// Which way the user thinks the price goes, vs. today's price.
enum CallDirection: String, Codable, Sendable, Hashable {
    case higher, lower
    var title: String { self == .higher ? "Higher" : "Lower" }
}

/// How sure the user felt — qualitative on purpose (a stated % would be false
/// precision). Drives the honest "confidence vs. accuracy" calibration.
enum CallConfidence: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case hunch, fairlySure, confident
    var id: String { rawValue }
    var title: String {
        switch self {
        case .hunch: "Hunch"
        case .fairlySure: "Fairly sure"
        case .confident: "Confident"
        }
    }
    /// Sort order, least → most sure.
    var order: Int {
        switch self {
        case .hunch: 0
        case .fairlySure: 1
        case .confident: 2
        }
    }
}

/// One call the user logged *before* seeing the sketch — their own judgment,
/// later resolved against the real price. Stored on-device only.
struct UserCall: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let symbol: String
    let assetClass: AssetClass
    let createdAt: Date
    let horizonDays: Int
    let spotAtCall: Double
    let direction: CallDirection
    let confidence: CallConfidence
    var actualClose: Double?
    var resolvedAt: Date?

    /// Roughly when the call can be judged (horizon days after it was made).
    var targetDate: Date {
        Calendar(identifier: .gregorian).date(byAdding: .day, value: horizonDays, to: createdAt) ?? createdAt
    }

    var isResolved: Bool { actualClose != nil }

    /// Was the direction right vs. the spot at call time? Nil until resolved, or
    /// if the price landed exactly flat (no direction to judge — a push).
    var wasCorrect: Bool? {
        guard let actual = actualClose, actual != spotAtCall else { return nil }
        return (direction == .higher) == (actual > spotAtCall)
    }

    /// Signed % move from spot to the resolved close (nil until resolved).
    var actualChange: Double? {
        guard let actual = actualClose, spotAtCall != 0 else { return nil }
        return (actual - spotAtCall) / spotAtCall
    }
}

// MARK: - Aggregates

/// Correct-vs-total over calls that had a decidable direction (pushes excluded).
struct CallAccuracy: Equatable, Sendable {
    let decided: Int
    let correct: Int
    var hitRate: Double? { decided > 0 ? Double(correct) / Double(decided) : nil }
}

/// Hit rate at one confidence level — the honest "did feeling sure mean right?"
struct ConfidenceCalibration: Identifiable, Equatable, Sendable {
    let confidence: CallConfidence
    let decided: Int
    let hitRate: Double
    var id: String { confidence.rawValue }
}

/// The user's own accountability record.
struct UserCallReport: Equatable, Sendable {
    let total: Int
    let resolved: Int
    let overall: CallAccuracy
    let byConfidence: [ConfidenceCalibration]

    static let empty = UserCallReport(total: 0, resolved: 0,
                                      overall: CallAccuracy(decided: 0, correct: 0),
                                      byConfidence: [])
}

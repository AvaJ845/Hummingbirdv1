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
    /// What each method predicted for this asset over this call's horizon,
    /// snapshotted at call time (method id → Higher/Lower). Lets us score you
    /// head-to-head against the methods on the very same calls. Optional so
    /// older calls decode cleanly.
    var methodDirections: [String: CallDirection]?
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

    /// Whether a given method's snapshotted call was right. Nil if unresolved,
    /// flat (a push), or the method wasn't recorded for this call.
    func methodWasCorrect(_ methodId: String) -> Bool? {
        guard let actual = actualClose, actual != spotAtCall,
              let dir = methodDirections?[methodId] else { return nil }
        return (dir == .higher) == (actual > spotAtCall)
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

/// One method's head-to-head record against the user, over the same calls.
struct MethodTally: Identifiable, Equatable, Sendable {
    let methodId: String
    let methodName: String
    let decided: Int
    let hitRate: Double
    var id: String { methodId }
}

/// You vs. the methods: your directional hit rate against each method's, scored
/// on the very same calls. A record of the past — never advice.
struct VsMethods: Equatable, Sendable {
    let userHitRate: Double
    let userDecided: Int
    let methods: [MethodTally]   // best hit rate first

    /// How many methods you're beating (strictly higher hit rate).
    var methodsBeaten: Int { methods.filter { userHitRate > $0.hitRate }.count }
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

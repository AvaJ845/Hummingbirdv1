import Foundation

/// Detects when the user's own confidence-vs-accuracy record has drifted into
/// a genuinely worth-knowing shape. The underlying numbers already live in
/// `UserCallReport.byConfidence` — this exists because a passive dashboard
/// doesn't change behavior, only actively seeing a surprising pattern does
/// (Tetlock & Gardner, 2015, "Superforecasting" — deliberate calibration
/// feedback, not a static scoreboard, is what improves judgment over time).
/// A record of the past, never advice: this never says what to do next.
enum CalibrationInsight: Equatable, Sendable {
    /// Stated-confident calls have landed meaningfully *less* accurately than
    /// a less-sure bucket — classic overconfidence, and the one pattern worth
    /// interrupting someone's day to point out.
    case overconfident(confidentRate: Double, lowerRate: Double, lowerLabel: String)

    var title: String { "Worth a look" }

    var message: String {
        switch self {
        case let .overconfident(confidentRate, lowerRate, lowerLabel):
            return "Your \u{201C}Confident\u{201D} calls have been right \(Self.pct(confidentRate)) of the time — your \u{201C}\(lowerLabel)\u{201D} calls, \(Self.pct(lowerRate)). Confidence and accuracy aren't the same thing."
        }
    }

    /// A compact signature identifying this insight's current shape, so it
    /// only resurfaces when the underlying numbers actually move.
    var signature: String {
        switch self {
        case let .overconfident(confidentRate, lowerRate, lowerLabel):
            return "overconfident-\(lowerLabel)-\(Int((confidentRate * 100).rounded()))-\(Int((lowerRate * 100).rounded()))"
        }
    }

    private static func pct(_ fraction: Double) -> String { String(format: "%.0f%%", fraction * 100) }
}

enum CalibrationInsightEngine {
    /// Minimum decided calls a confidence bucket needs before its hit rate is
    /// trustworthy enough to act on — small samples wobble.
    static let minDecidedPerBucket = 3
    /// How far below a less-sure bucket "Confident" has to fall before it's a
    /// real signal, not sampling noise.
    static let minGap = 0.15

    /// The insight worth showing right now, if any.
    static func insight(from byConfidence: [ConfidenceCalibration]) -> CalibrationInsight? {
        guard let confident = byConfidence.first(where: { $0.confidence == .confident }),
              confident.decided >= minDecidedPerBucket else { return nil }

        let lowerBuckets = byConfidence.filter { $0.confidence != .confident && $0.decided >= minDecidedPerBucket }
        guard let strongestLower = lowerBuckets.max(by: { $0.hitRate < $1.hitRate }) else { return nil }
        guard strongestLower.hitRate - confident.hitRate >= minGap else { return nil }

        return .overconfident(
            confidentRate: confident.hitRate,
            lowerRate: strongestLower.hitRate,
            lowerLabel: strongestLower.confidence.title
        )
    }
}

/// Persists which insight signature was last shown, on-device only — the
/// same finding isn't repeated every launch, but a genuine shift in the
/// numbers surfaces again.
enum CalibrationInsightThrottle {
    private static let key = "hb.calibrationInsight.lastShownSignature"

    static func lastShownSignature(defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: key)
    }

    static func recordShown(_ signature: String, defaults: UserDefaults = .standard) {
        defaults.set(signature, forKey: key)
    }
}

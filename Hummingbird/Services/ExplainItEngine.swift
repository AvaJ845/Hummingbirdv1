import Foundation

/// Which genuinely non-obvious driver a forecast is worth pausing to reason
/// about — never every run, only when there's real inferential work to do.
/// Self-explanation only deepens understanding when there's something
/// non-trivial to explain (Chi, De Leeuw, Chiu & LaVancher, 1994, "Eliciting
/// Self-Explanations Improves Understanding," Cognitive Science).
enum ExplainItPrompt: Equatable, Sendable {
    /// The methods disagree by at least the threshold — worth asking what
    /// that disagreement actually means.
    case disagreement(spread: Double)
    /// A macro rate what-if is dialed in — worth asking whether the user can
    /// predict its direction.
    case macro(horizonBias: Double)

    var question: String {
        switch self {
        case .disagreement:
            "The methods disagree here. What do you think that means?"
        case .macro:
            "You dialed in a rate what-if. Do you think it pushed this sketch up or down?"
        }
    }

    var options: [String] {
        switch self {
        case .disagreement: ["Trust it more", "Trust it less", "Doesn't matter"]
        case .macro: ["Up", "Down", "Barely any effect"]
        }
    }

    /// Same threshold `RetailExplainer.scenarioNudgePlain` already uses for
    /// "almost unchanged" — one definition of negligible, not two.
    private static let negligibleBias = 0.005

    func isCorrect(_ answer: String) -> Bool {
        switch self {
        case .disagreement:
            answer == "Trust it less"
        case .macro(let bias):
            abs(bias) < Self.negligibleBias
                ? answer == "Barely any effect"
                : (bias > 0 && answer == "Up") || (bias < 0 && answer == "Down")
        }
    }

    var explanation: String {
        switch self {
        case .disagreement:
            return "More disagreement means less certainty, not more confidence. When methods spread out, that's the sketch's own honesty check — not a green light."
        case .macro(let bias):
            let direction = abs(bias) < Self.negligibleBias
                ? "barely any effect"
                : (bias > 0 ? "an upward nudge" : "a downward nudge")
            return "Your rate what-ifs give this sketch \(direction) — optional context, never a reason to act on its own."
        }
    }
}

enum ExplainItEngine {
    static let disagreementThreshold = 0.02
    /// Don't prompt more than this often — a learning aid, not friction.
    static let minimumGapBetweenPrompts: TimeInterval = 6 * 3600

    /// The prompt worth showing right now, if any. Disagreement takes
    /// priority over macro when both apply — it's the more universally
    /// relevant lesson (every sketch can disagree; only some have a macro
    /// nudge dialed in).
    static func prompt(
        disagreementSpread: Double?,
        macroActive: Bool,
        macroHorizonBias: Double,
        lastPromptedAt: Date?,
        now: Date = Date()
    ) -> ExplainItPrompt? {
        if let last = lastPromptedAt, now.timeIntervalSince(last) < minimumGapBetweenPrompts {
            return nil
        }
        if let spread = disagreementSpread, spread >= disagreementThreshold {
            return .disagreement(spread: spread)
        }
        if macroActive {
            return .macro(horizonBias: macroHorizonBias)
        }
        return nil
    }
}

/// Persists when the user was last shown an Explain It prompt — on-device
/// only, a single timestamp, not a growing record.
enum ExplainItThrottle {
    private static let key = "hb.explainIt.lastPromptedAt"

    static func lastPromptedAt(defaults: UserDefaults = .standard) -> Date? {
        defaults.object(forKey: key) as? Date
    }

    static func recordPrompted(now: Date = Date(), defaults: UserDefaults = .standard) {
        defaults.set(now, forKey: key)
    }
}

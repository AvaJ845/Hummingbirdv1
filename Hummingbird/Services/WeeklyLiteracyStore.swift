import Foundation
import Observation

/// Tracks the current week's literacy question and which questions have
/// already been shown — on-device only. One question per calendar week,
/// stable across app opens within that week; declining is treated the same
/// as answering (both advance the rotation), matching the app's deference
/// to the user everywhere else this pattern is used.
@MainActor
@Observable
final class WeeklyLiteracyStore {
    private(set) var shownIDs: [String] = []
    private(set) var currentQuestionID: String?
    private(set) var weekAnchor: Date?
    private(set) var answered = false
    /// When the user first engaged with any weekly lesson (answered or
    /// dismissed) — the split point for the "lessons → calibration" insight.
    /// Only ever set once, nil → date; never cleared.
    private(set) var firstEngagedAt: Date?

    private let defaults: UserDefaults
    private enum Keys {
        static let shown = "hummingbird.weeklyLiteracy.shown"
        static let currentID = "hummingbird.weeklyLiteracy.currentID"
        static let weekAnchor = "hummingbird.weeklyLiteracy.weekAnchor"
        static let answered = "hummingbird.weeklyLiteracy.answered"
        static let firstEngaged = "hummingbird.weeklyLiteracy.firstEngagedAt"
    }

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
        shownIDs = defaults.stringArray(forKey: Keys.shown) ?? []
        currentQuestionID = defaults.string(forKey: Keys.currentID)
        weekAnchor = defaults.object(forKey: Keys.weekAnchor) as? Date
        answered = defaults.bool(forKey: Keys.answered)
        firstEngagedAt = defaults.object(forKey: Keys.firstEngaged) as? Date
    }

    /// This week's question — stable across repeated calls within the same
    /// calendar week. Assigns a fresh one (and resets `answered`) the first
    /// time it's asked for in a new week. Nil once the bank is empty.
    func questionForThisWeek(now: Date = Date(), calendar: Calendar = .current) -> LiteracyQuestion? {
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)

        if let anchor = weekAnchor, calendar.isDate(anchor, inSameDayAs: weekStart) {
            // Already assigned for this week. Once it's been answered or
            // dismissed (both set `answered`), stay silent for the rest of the
            // week — it's a once-a-week nudge, not something to re-ask every
            // time Home comes forward.
            guard !answered else { return nil }
            if let id = currentQuestionID,
               let question = LiteracyQuestionBank.all.first(where: { $0.id == id }) {
                return question
            }
        }

        guard let next = LiteracyQuestionEngine.next(shown: shownIDs) else { return nil }
        currentQuestionID = next.id
        weekAnchor = weekStart
        answered = false
        save()
        return next
    }

    /// Mark the current question answered (or dismissed) — advances the
    /// rotation so it isn't offered again until the bank cycles.
    func recordShown(now: Date = Date()) {
        guard let id = currentQuestionID else { return }
        answered = true
        if firstEngagedAt == nil { firstEngagedAt = now }
        if !shownIDs.contains(id) { shownIDs.append(id) }
        save()
    }

    private func save() {
        defaults.set(shownIDs, forKey: Keys.shown)
        defaults.set(currentQuestionID, forKey: Keys.currentID)
        defaults.set(weekAnchor, forKey: Keys.weekAnchor)
        defaults.set(answered, forKey: Keys.answered)
        if let firstEngagedAt { defaults.set(firstEngagedAt, forKey: Keys.firstEngaged) }
    }
}

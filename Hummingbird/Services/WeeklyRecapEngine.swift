import Foundation

/// Composes an optional once-a-week recap of the user's own call activity —
/// participation and honest accuracy, never a nudge to be "more right." Pure
/// and deterministic; built entirely from calls already cached on-device (no
/// network call of its own).
enum WeeklyRecapEngine {
    /// nil when there's nothing to report (no calls made in the trailing week).
    static func compose(
        calls: [UserCall],
        streak: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Digest? {
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else { return nil }
        let thisWeek = calls.filter { $0.createdAt >= weekAgo && $0.createdAt <= now }
        guard !thisWeek.isEmpty else { return nil }

        var parts = ["\(thisWeek.count) call\(thisWeek.count == 1 ? "" : "s") made"]

        let decided = thisWeek.filter(\.isResolved).compactMap(\.wasCorrect)
        if !decided.isEmpty {
            let hits = decided.filter { $0 }.count
            let pct = Int((Double(hits) / Double(decided.count) * 100).rounded())
            parts.append("\(hits) of \(decided.count) resolved calls right (\(pct)%)")
        }

        if streak >= 2 {
            parts.append("a \(streak)-day streak going")
        }

        let body = parts.joined(separator: ", ") + ". A record of the past — never advice."
        return Digest(title: "Your week in calls", body: body)
    }
}

/// Reads the weekly-recap preference and (re)schedules with fresh content.
/// Deliberately has no BGTask of its own — it's called from the same
/// `BackgroundRefresh` wake-up that already reschedules the morning digest, so
/// adding this feature costs zero extra background wakeups.
enum WeeklyRecap {
    static let enabledKey = "hb.weeklyRecap.enabled"

    static func rescheduleIfEnabled(calls: [UserCall], streak: Int) async {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: enabledKey) else { return }
        guard await NotificationService.isAuthorized() else { return }

        guard let digest = WeeklyRecapEngine.compose(calls: calls, streak: streak) else {
            NotificationService.cancelWeeklyRecap()
            return
        }
        await NotificationService.scheduleWeeklyRecap(digest)
    }
}

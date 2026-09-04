import Foundation

/// Composes an optional once-a-week recap of the user's own call activity —
/// participation and honest accuracy, never a nudge to be "more right." Pure
/// and deterministic; built entirely from calls already cached on-device (no
/// network call of its own).
enum WeeklyRecapEngine {
    /// nil when there's nothing to report (no calls made in the trailing week).
    /// `hasJournalActivity` just adds a one-line pointer to the separate Sketch
    /// Journal (watchlist rollup) when there's something there too — reusing
    /// this same notification rather than scheduling a second one.
    static func compose(
        calls: [UserCall],
        streak: Int,
        hasJournalActivity: Bool = false,
        portfolioComparison: BuyAndHoldComparison? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Digest? {
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else { return nil }
        let thisWeek = calls.filter { $0.createdAt >= weekAgo && $0.createdAt <= now }
        // The recap is anchored to call activity, same as before — a portfolio
        // line only ever enriches an existing recap, never creates a new trigger
        // (deliberately: this app doesn't add fresh notification conditions).
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

        // Only mention the practice portfolio when there's an honest, non-flat
        // number to report — silence beats a "0.0%, no change" non-update.
        if let c = portfolioComparison, abs(c.edge) > 0.0005 {
            parts.append(c.isBeatingHold
                ? "your practice portfolio ahead of buy-and-hold by \(c.edge.asSignedPercent())"
                : "your practice portfolio \((-c.edge).asPercent()) behind buy-and-hold")
        }

        var body = parts.joined(separator: ", ") + ". A record of the past — never advice."
        if hasJournalActivity {
            body += " Your watchlist journal is ready too."
        }
        // A question about the user's own data opens more often than a flat
        // statement — the body underneath still states the real numbers
        // plainly, so this is a hook, never a withheld fact (Loewenstein,
        // 1994, "The Psychology of Curiosity," Psychological Bulletin).
        return Digest(title: "How did your week go?", body: body)
    }
}

/// Reads the weekly-recap preference and (re)schedules with fresh content.
/// Deliberately has no BGTask of its own — it's called from the same
/// `BackgroundRefresh` wake-up that already reschedules the morning digest, so
/// adding this feature costs zero extra background wakeups.
enum WeeklyRecap {
    static let enabledKey = "hb.weeklyRecap.enabled"

    static func rescheduleIfEnabled(calls: [UserCall], streak: Int, hasJournalActivity: Bool = false,
                                    portfolioComparison: BuyAndHoldComparison? = nil) async {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: enabledKey) else { return }
        guard await NotificationService.isAuthorized() else { return }

        guard let digest = WeeklyRecapEngine.compose(calls: calls, streak: streak, hasJournalActivity: hasJournalActivity,
                                                      portfolioComparison: portfolioComparison) else {
            NotificationService.cancelWeeklyRecap()
            return
        }
        await NotificationService.scheduleWeeklyRecap(digest)
    }
}

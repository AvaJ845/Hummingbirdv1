import Foundation
import BackgroundTasks

/// Schedules and performs periodic off-screen refreshes of the watchlist so the
/// widget stays fresh and movement alerts fire even when the app is closed.
enum BackgroundRefresh {
    /// Must match `BGTaskSchedulerPermittedIdentifiers` in Info.plist.
    static let taskIdentifier = "com.avaresearch.hummingbird.refresh"

    /// Ask the system to wake us in ~30 minutes (the OS decides the real timing).
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Run one background refresh cycle: reschedule, refresh the watchlist (which
    /// fires movement alerts + reloads widgets), then keep the morning read and
    /// weekly recap fresh so neither ever goes stale between app opens. The
    /// weekly recap piggybacks on this same wake-up rather than registering its
    /// own BGTask — one background wakeup, multiple jobs.
    @MainActor
    static func perform() async {
        schedule() // always queue the next cycle first

        let store = WatchlistStore()
        if !store.items.isEmpty, !Task.isCancelled {
            await WatchlistRefresh.refreshAll(store: store)
        }

        if !Task.isCancelled {
            await MorningDigest.rescheduleIfEnabled()
        }

        // Fill in any user calls whose horizon has passed, and clear their
        // reminders — so the record stays trustworthy without opening the app.
        let callStore = UserCallStore()
        if !Task.isCancelled {
            for id in await callStore.resolveDue(using: MarketDataService()) {
                NotificationService.cancelCallResolution(callID: id)
            }
        }

        if !Task.isCancelled {
            await WeeklyRecap.rescheduleIfEnabled(
                calls: callStore.calls,
                streak: callStore.currentStreak,
                hasJournalActivity: !SharedStorage.snapshots().isEmpty
            )
        }
    }
}

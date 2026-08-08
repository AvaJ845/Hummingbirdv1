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
    /// fires movement alerts + reloads widgets), then keep the morning read fresh
    /// so it never goes stale between app opens.
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
    }
}

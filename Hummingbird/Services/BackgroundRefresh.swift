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

    /// Run one background refresh cycle: reschedule, then update every asset.
    @MainActor
    static func perform() async {
        schedule() // always queue the next cycle first
        let store = WatchlistStore()
        guard !store.items.isEmpty else { return }
        await WatchlistRefresh.refreshAll(store: store)
    }
}

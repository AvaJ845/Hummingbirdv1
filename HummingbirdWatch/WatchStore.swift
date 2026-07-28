import Foundation
import Observation
import WatchConnectivity

/// Receives watchlist snapshots from the iPhone and keeps the last set for
/// glanceable display, persisting so they survive relaunch.
@MainActor
@Observable
final class WatchStore: NSObject, WCSessionDelegate {
    private(set) var snapshots: [WatchlistSnapshot] = []

    private let defaults = UserDefaults.standard
    private let key = "hummingbird.watch.snapshots"

    override init() {
        super.init()
        load()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    private func apply(_ context: [String: Any]) {
        guard let data = context["snapshots"] as? Data,
              let decoded = try? JSONDecoder().decode([WatchlistSnapshot].self, from: data) else { return }
        let sorted = decoded.sorted { $0.updatedAt > $1.updatedAt }
        snapshots = sorted
        defaults.set(data, forKey: key)
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([WatchlistSnapshot].self, from: data) else { return }
        snapshots = decoded.sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        let context = session.receivedApplicationContext
        Task { @MainActor in self.apply(context) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.apply(applicationContext) }
    }
}

import Foundation
import WatchConnectivity

/// Pushes watchlist snapshots to the Apple Watch app via the lightweight
/// application-context channel (latest state only).
final class WatchSync: NSObject, WCSessionDelegate {
    static let shared = WatchSync()

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func push(_ snapshots: [WatchlistSnapshot]) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        try? session.updateApplicationContext(["snapshots": data])
    }

    // MARK: - WCSessionDelegate (required)

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }
}

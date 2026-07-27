import Foundation

/// Read-only access to the watchlist snapshots the app writes to the App Group.
/// Used by the widget (and could back Siri) without pulling in the full store.
enum SharedStorage {
    static let snapshotsKey = "hummingbird.watchlist.snapshots"

    static func snapshots(defaults: UserDefaults = AppGroup.defaults) -> [WatchlistSnapshot] {
        guard let data = defaults.data(forKey: snapshotsKey),
              let list = try? JSONDecoder().decode([WatchlistSnapshot].self, from: data) else { return [] }
        return list.sorted { $0.updatedAt > $1.updatedAt }
    }
}

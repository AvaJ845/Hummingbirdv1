import Foundation

/// Read-only access to the watchlist snapshots the app writes to the App Group.
/// Used by the widget (and could back Siri) without pulling in the full store.
enum SharedStorage {
    static let snapshotsKey = "hummingbird.watchlist.snapshots"
    static let itemsKey = "hummingbird.watchlist.items"

    static func snapshots(defaults: UserDefaults = AppGroup.defaults) -> [WatchlistSnapshot] {
        guard let data = defaults.data(forKey: snapshotsKey),
              let list = try? JSONDecoder().decode([WatchlistSnapshot].self, from: data) else { return [] }
        return list.sorted { $0.updatedAt > $1.updatedAt }
    }

    /// The saved watchlist items (in the user's order) — for the widget's asset picker.
    static func items(defaults: UserDefaults = AppGroup.defaults) -> [WatchlistItem] {
        guard let data = defaults.data(forKey: itemsKey),
              let list = try? JSONDecoder().decode([WatchlistItem].self, from: data) else { return [] }
        return list
    }
}

import Foundation

/// Shared App Group storage the main app writes to and the widget/watch
/// extensions read from — the watchlist side is read-only here (the app
/// writes it via `WatchlistStore`); the track-record side is read *and*
/// written here since it has no dedicated store of its own.
enum SharedStorage {
    static let snapshotsKey = "hummingbird.watchlist.snapshots"
    static let itemsKey = "hummingbird.watchlist.items"
    static let trackRecordKey = "hummingbird.trackRecord.snapshot"

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

    /// Persist the latest track-record snapshot (streak + accuracy) for the
    /// widget and watch complication to read.
    static func saveTrackRecord(_ snapshot: TrackRecordSnapshot, defaults: UserDefaults = AppGroup.defaults) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: trackRecordKey)
    }

    static func trackRecord(defaults: UserDefaults = AppGroup.defaults) -> TrackRecordSnapshot? {
        guard let data = defaults.data(forKey: trackRecordKey) else { return nil }
        return try? JSONDecoder().decode(TrackRecordSnapshot.self, from: data)
    }
}

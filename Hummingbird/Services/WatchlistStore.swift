import Foundation
import Observation

/// Persists the user's watchlist and the per-asset snapshots the widget reads.
/// Backed by the App Group so extensions see the same data.
@MainActor
@Observable
final class WatchlistStore {
    private(set) var items: [WatchlistItem] = []

    private var alertPrefs: [String: AlertPreference] = [:]

    private let defaults: UserDefaults
    private let itemsKey = "hummingbird.watchlist.items"
    private let snapshotsKey = "hummingbird.watchlist.snapshots"
    private let alertsKey = "hummingbird.watchlist.alerts"

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
        load()
    }

    // MARK: - Alerts

    func alertPreference(for item: WatchlistItem) -> AlertPreference {
        alertPrefs[item.id] ?? AlertPreference()
    }

    func isAlerting(_ item: WatchlistItem) -> Bool {
        alertPreference(for: item).enabled
    }

    func setAlert(enabled: Bool, threshold: Double? = nil, for item: WatchlistItem) {
        var pref = alertPreference(for: item)
        pref.enabled = enabled
        if let threshold { pref.thresholdPercent = threshold }
        alertPrefs[item.id] = pref
        persistAlerts()
    }

    // MARK: - Watchlist

    func contains(symbol: String, assetClass: AssetClass) -> Bool {
        let id = WatchlistItem(symbol: symbol, assetClass: assetClass).id
        return items.contains { $0.id == id }
    }

    @discardableResult
    func toggle(symbol: String, assetClass: AssetClass, displayName: String? = nil) -> Bool {
        if contains(symbol: symbol, assetClass: assetClass) {
            remove(symbol: symbol, assetClass: assetClass)
            return false
        }
        add(symbol: symbol, assetClass: assetClass, displayName: displayName)
        return true
    }

    func add(symbol: String, assetClass: AssetClass, displayName: String? = nil) {
        let trimmed = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let item = WatchlistItem(symbol: trimmed, assetClass: assetClass, displayName: displayName)
        guard !items.contains(where: { $0.id == item.id }) else { return }
        items.append(item)
        persist()
    }

    func remove(symbol: String, assetClass: AssetClass) {
        let id = WatchlistItem(symbol: symbol, assetClass: assetClass).id
        items.removeAll { $0.id == id }
        removeSnapshot(id: id)
        persist()
    }

    func remove(atOffsets offsets: IndexSet) {
        for index in offsets { removeSnapshot(id: items[index].id) }
        items.remove(atOffsets: offsets)
        persist()
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    // MARK: - Snapshots (for the widget / Siri)

    func snapshot(for item: WatchlistItem) -> WatchlistSnapshot? {
        allSnapshots()[item.id]
    }

    func saveSnapshot(_ snapshot: WatchlistSnapshot) {
        var all = allSnapshots()
        all[snapshot.id] = snapshot
        if let data = try? JSONEncoder().encode(Array(all.values)) {
            defaults.set(data, forKey: snapshotsKey)
        }
    }

    // MARK: - Persistence

    private func persist() {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: itemsKey)
        }
    }

    private func persistAlerts() {
        if let data = try? JSONEncoder().encode(alertPrefs) {
            defaults.set(data, forKey: alertsKey)
        }
    }

    private func load() {
        if let data = defaults.data(forKey: itemsKey),
           let decoded = try? JSONDecoder().decode([WatchlistItem].self, from: data) {
            items = decoded
        }
        if let data = defaults.data(forKey: alertsKey),
           let decoded = try? JSONDecoder().decode([String: AlertPreference].self, from: data) {
            alertPrefs = decoded
        }
    }

    private func allSnapshots() -> [String: WatchlistSnapshot] {
        guard let data = defaults.data(forKey: snapshotsKey),
              let list = try? JSONDecoder().decode([WatchlistSnapshot].self, from: data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
    }

    private func removeSnapshot(id: String) {
        var all = allSnapshots()
        all[id] = nil
        if let data = try? JSONEncoder().encode(Array(all.values)) {
            defaults.set(data, forKey: snapshotsKey)
        }
    }
}

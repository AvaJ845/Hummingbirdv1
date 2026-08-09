import Foundation

/// Shared on-device persistence for the app's record stores (sketch scorecard,
/// user calls). Both keep a Codable array in UserDefaults and prune by retention
/// + a hard cap, so that logic lives here once.
enum RecordDefaultsStore {
    static func load<T: Decodable>(_ type: [T].Type, from defaults: UserDefaults, key: String) -> [T] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([T].self, from: data) else { return [] }
        return decoded
    }

    static func save<T: Encodable>(_ records: [T], to defaults: UserDefaults, key: String) {
        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: key)
        }
    }

    /// Drop records older than `retentionDays` (nil = keep all), then cap at
    /// `maxCount`, keeping the most recent by `date`.
    static func pruned<T>(_ records: [T], retentionDays: Int?, maxCount: Int, date: (T) -> Date) -> [T] {
        var result = records
        if let days = retentionDays {
            let cutoff = Date(timeIntervalSinceNow: -Double(days) * 86_400)
            result.removeAll { date($0) < cutoff }
        }
        if result.count > maxCount {
            result = Array(result.sorted { date($0) > date($1) }.prefix(maxCount))
        }
        return result
    }
}

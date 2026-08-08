import Foundation
import Observation

/// Stores the user's own calls **on the device only** (App Group). Nothing is
/// ever sent off-device; the user can wipe it or set it to auto-expire.
@MainActor
@Observable
final class UserCallStore {
    private(set) var calls: [UserCall] = []

    /// Guards `didSet` side effects until `init` has finished loading.
    private var isReady = false

    /// Auto-clear calls older than this many days. `nil` = keep everything.
    var retentionDays: Int? {
        didSet {
            guard isReady else { return }
            defaults.set(retentionDays ?? 0, forKey: Keys.retention)
            prune()
            save()
        }
    }

    static let maxCalls = 500

    private let defaults: UserDefaults
    private enum Keys {
        static let calls = "hummingbird.calls"
        static let retention = "hummingbird.calls.retentionDays"
    }

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
        let stored = defaults.integer(forKey: Keys.retention)
        self.retentionDays = stored > 0 ? stored : nil
        load()
        prune()
        isReady = true
    }

    // MARK: - Recording & resolving

    /// Log a call the user made before revealing the sketch.
    @discardableResult
    func record(symbol: String, assetClass: AssetClass, direction: CallDirection,
                confidence: CallConfidence, horizonDays: Int, spot: Double,
                now: Date = Date()) -> UserCall {
        let call = UserCall(
            id: UUID(), symbol: symbol, assetClass: assetClass, createdAt: now,
            horizonDays: horizonDays, spotAtCall: spot, direction: direction,
            confidence: confidence, actualClose: nil, resolvedAt: nil
        )
        calls.append(call)
        prune()
        save()
        return call
    }

    /// Resolve any pending calls for this asset against a fresh series.
    func resolve(using series: PriceSeries) {
        var changed = false
        calls = calls.map { call in
            let updated = UserCallEngine.resolve(call, against: series)
            if updated != call { changed = true }
            return updated
        }
        if changed { save() }
    }

    // MARK: - Reads

    var report: UserCallReport { UserCallEngine.report(calls) }

    /// Pending (unresolved) calls, soonest to resolve first.
    var pending: [UserCall] {
        calls.filter { !$0.isResolved }.sorted { $0.targetDate < $1.targetDate }
    }

    func clearAll() {
        calls = []
        defaults.removeObject(forKey: Keys.calls)
    }

    // MARK: - Persistence

    private func load() {
        guard let data = defaults.data(forKey: Keys.calls),
              let decoded = try? JSONDecoder().decode([UserCall].self, from: data) else { return }
        calls = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(calls) {
            defaults.set(data, forKey: Keys.calls)
        }
    }

    private func prune() {
        if let days = retentionDays {
            let cutoff = Date(timeIntervalSinceNow: -Double(days) * 86_400)
            calls.removeAll { $0.createdAt < cutoff }
        }
        if calls.count > Self.maxCalls {
            calls = Array(calls.sorted { $0.createdAt > $1.createdAt }.prefix(Self.maxCalls))
        }
    }
}

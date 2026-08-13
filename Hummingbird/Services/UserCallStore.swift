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
                methodDirections: [String: CallDirection]? = nil,
                now: Date = Date()) -> UserCall {
        let call = UserCall(
            id: UUID(), symbol: symbol, assetClass: assetClass, createdAt: now,
            horizonDays: horizonDays, spotAtCall: spot, direction: direction,
            confidence: confidence, methodDirections: methodDirections,
            actualClose: nil, resolvedAt: nil
        )
        calls.append(call)
        prune()
        save()
        return call
    }

    /// Resolve any pending calls for this asset against a fresh series. Returns
    /// the IDs that newly resolved (so callers can clear their reminders).
    @discardableResult
    func resolve(using series: PriceSeries) -> [UUID] {
        var resolvedIDs: [UUID] = []
        calls = calls.map { call in
            let updated = UserCallEngine.resolve(call, against: series)
            if updated != call { resolvedIDs.append(updated.id) }
            return updated
        }
        if !resolvedIDs.isEmpty { save() }
        return resolvedIDs
    }

    /// Distinct assets that have an unresolved call whose horizon has passed.
    func dueAssets(now: Date = Date()) -> [WatchlistItem] {
        var seen = Set<String>()
        var result: [WatchlistItem] = []
        for call in calls where !call.isResolved && call.targetDate <= now {
            let key = "\(call.assetClass.rawValue):\(call.symbol.lowercased())"
            if seen.insert(key).inserted {
                result.append(WatchlistItem(symbol: call.symbol, assetClass: call.assetClass))
            }
        }
        return result
    }

    /// Fetch fresh prices for each due asset and resolve its calls. Capped at
    /// `maxAssets` fetches per pass so a big backlog can't fire dozens of network
    /// calls at once — the rest resolve on the next pass. Returns the IDs that
    /// newly resolved.
    @discardableResult
    func resolveDue(using service: any MarketDataProviding, now: Date = Date(),
                    maxAssets: Int = 12) async -> [UUID] {
        var resolved: [UUID] = []
        for item in dueAssets(now: now).prefix(maxAssets) {
            if let series = try? await service.history(symbol: item.symbol, assetClass: item.assetClass) {
                resolved.append(contentsOf: resolve(using: series))
            }
        }
        return resolved
    }

    // MARK: - Reads

    var report: UserCallReport { UserCallEngine.report(calls) }

    /// Consecutive days you've made a call — participation, never correctness.
    var currentStreak: Int { StreakEngine.currentStreak(calls) }

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
        calls = RecordDefaultsStore.load([UserCall].self, from: defaults, key: Keys.calls)
    }

    private func save() {
        RecordDefaultsStore.save(calls, to: defaults, key: Keys.calls)
    }

    private func prune() {
        calls = RecordDefaultsStore.pruned(calls, retentionDays: retentionDays,
                                           maxCount: Self.maxCalls, date: \.createdAt)
    }
}

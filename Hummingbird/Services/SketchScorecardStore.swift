import Foundation
import Observation

/// Stores the sketch track record **on the device only** (App Group, so a
/// future widget could read it). Nothing here is ever sent off-device, and the
/// user can wipe it or set it to auto-expire in Settings.
@MainActor
@Observable
final class SketchScorecardStore {
    private(set) var records: [SketchRecord] = []

    /// Guards `didSet` side effects until `init` has finished loading — with
    /// `@Observable`, property `didSet` observers fire during `init`, which
    /// would otherwise persist-and-prune over the data we're about to load.
    private var isReady = false

    /// Auto-clear sketches older than this many days. `nil` = keep everything.
    var retentionDays: Int? {
        didSet {
            guard isReady else { return }
            defaults.set(retentionDays ?? 0, forKey: Keys.retention)
            prune()
            save()
        }
    }

    static let maxRecords = 300
    private let dedupeWindow: TimeInterval = 12 * 3600

    private let defaults: UserDefaults
    private enum Keys {
        static let records = "hummingbird.scorecard.records"
        static let retention = "hummingbird.scorecard.retentionDays"
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

    /// Record a freshly completed sketch (deduped to ~one per asset+model per
    /// 12 h so auto-refresh doesn't spam the ledger).
    func record(forecast: Forecast, symbol: String, assetClass: AssetClass) {
        guard let new = ScorecardEngine.makeRecord(forecast: forecast, symbol: symbol, assetClass: assetClass)
        else { return }

        let duplicate = records.contains { existing in
            existing.modelId == new.modelId
            && existing.assetClass == assetClass
            && existing.symbol.caseInsensitiveCompare(symbol) == .orderedSame
            && abs(existing.createdAt.timeIntervalSince(new.createdAt)) < dedupeWindow
        }
        guard !duplicate else { return }

        records.append(new)
        prune()
        save()
    }

    /// Resolve any past sketches for this asset against a fresh series.
    func resolve(using series: PriceSeries) {
        var changed = false
        records = records.map { record in
            guard !record.isFullyResolved,
                  record.assetClass == series.assetClass,
                  record.symbol.caseInsensitiveCompare(series.symbol) == .orderedSame
            else { return record }
            let updated = ScorecardEngine.resolve(record, against: series)
            if updated != record { changed = true }
            return updated
        }
        if changed { save() }
    }

    // MARK: - Reads

    var overall: ScorecardSummary { ScorecardEngine.summary(records) }

    func summary(for symbol: String, assetClass: AssetClass) -> ScorecardSummary {
        ScorecardEngine.summary(records(for: symbol, assetClass: assetClass))
    }

    /// The method that has tracked this asset closest (nil until enough scored
    /// sketches exist across at least two methods to be meaningful).
    func bestModel(for symbol: String, assetClass: AssetClass) -> ModelPerformance? {
        ScorecardEngine.bestModel(records(for: symbol, assetClass: assetClass))
    }

    /// Per-method track record for this asset, best first.
    func modelPerformances(for symbol: String, assetClass: AssetClass) -> [ModelPerformance] {
        ScorecardEngine.modelPerformances(records(for: symbol, assetClass: assetClass))
    }

    func records(for symbol: String, assetClass: AssetClass) -> [SketchRecord] {
        records.filter {
            $0.assetClass == assetClass && $0.symbol.caseInsensitiveCompare(symbol) == .orderedSame
        }
    }

    /// One row per watched asset, most-recent first.
    var assets: [ScorecardAsset] {
        let groups = Dictionary(grouping: records) { AssetKey(symbol: $0.symbol.lowercased(), assetClass: $0.assetClass) }
        return groups.map { key, recs in
            ScorecardAsset(
                symbol: recs.first?.symbol ?? key.symbol,
                assetClass: key.assetClass,
                summary: ScorecardEngine.summary(recs),
                lastSketchedAt: recs.map(\.createdAt).max() ?? .distantPast
            )
        }
        .sorted { $0.lastSketchedAt > $1.lastSketchedAt }
    }

    /// Concrete, personalised "what Pro would do for you" highlights, drawn
    /// from the user's own track record — best-tracking method per asset. Empty
    /// until enough scored sketches exist. Powers the value-recap paywall.
    var proValueHighlights: [ProValueHighlight] {
        assets.compactMap { asset in
            guard let best = bestModel(for: asset.symbol, assetClass: asset.assetClass) else { return nil }
            return ProValueHighlight(symbol: asset.symbol, modelName: best.modelName, medianError: best.medianError)
        }
        .sorted { $0.medianError < $1.medianError }
    }

    // MARK: - Clearing

    func clearAll() {
        records = []
        defaults.removeObject(forKey: Keys.records)
    }

    // MARK: - Persistence

    private func load() {
        guard let data = defaults.data(forKey: Keys.records),
              let decoded = try? JSONDecoder().decode([SketchRecord].self, from: data) else { return }
        records = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: Keys.records)
        }
    }

    private func prune() {
        if let days = retentionDays {
            let cutoff = Date().addingTimeInterval(-Double(days) * 86_400)
            records.removeAll { $0.createdAt < cutoff }
        }
        if records.count > Self.maxRecords {
            records = Array(records.sorted { $0.createdAt > $1.createdAt }.prefix(Self.maxRecords))
        }
    }
}

struct ScorecardAsset: Identifiable {
    let symbol: String
    let assetClass: AssetClass
    let summary: ScorecardSummary
    let lastSketchedAt: Date
    var id: String { "\(assetClass.rawValue):\(symbol.lowercased())" }
}

private struct AssetKey: Hashable {
    let symbol: String
    let assetClass: AssetClass
}

/// A concrete, personalised Pro value point for the value-recap paywall.
struct ProValueHighlight: Identifiable, Equatable {
    let symbol: String
    let modelName: String
    let medianError: Double
    var id: String { symbol.lowercased() }
}

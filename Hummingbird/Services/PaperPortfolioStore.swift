import Foundation
import Observation

/// The user's on-device paper-trading portfolio — practice with a fixed
/// $10,000, scored honestly against buy-and-hold. Nothing leaves the device;
/// prices are end-of-day only, never real-time. Mirrors `UserCallStore`'s shape.
@MainActor
@Observable
final class PaperPortfolioStore {
    private(set) var portfolio: PaperPortfolio

    /// Latest end-of-day closes per asset key, refreshed by `revalueDue`. Held
    /// in memory and re-fetched on open; a cold start briefly values holdings at
    /// cost (no fake P/L) until the first refresh lands.
    private(set) var latestPrices: [String: Double] = [:]

    /// Full end-of-day series per asset key, kept alongside `latestPrices` so the
    /// You-vs-hold chart can reconstruct both value lines over time. In memory
    /// only, re-fetched on open.
    private(set) var histories: [String: PriceSeries] = [:]

    /// Hard safety cap so the record can't grow unbounded. Buys are rejected
    /// beyond it rather than silently dropping lots, which would corrupt the
    /// day-one benchmark.
    static let maxPositions = 500

    private var lastRevalue: Date?
    private let revalueThrottle: TimeInterval = 10 * 60

    private var isReady = false
    private let defaults: UserDefaults
    private enum Keys { static let portfolio = "hummingbird.paperPortfolio" }

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Keys.portfolio),
           let decoded = try? JSONDecoder().decode(PaperPortfolio.self, from: data) {
            portfolio = decoded
        } else {
            portfolio = PaperPortfolio()
        }
        isReady = true
    }

    // MARK: - Trading

    /// Invest `cashAmount` of the portfolio's cash into `symbol` at `price`,
    /// stating a direction (and optionally why). Returns the new lot, or nil if
    /// there isn't enough cash, the inputs are invalid, or the cap is reached.
    @discardableResult
    func buy(symbol: String, assetClass: AssetClass, cashAmount: Double, price: Double,
             direction: CallDirection, reason: CallReason? = nil, now: Date = Date()) -> PaperPosition? {
        let trimmed = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, price > 0, cashAmount > 0,
              cashAmount <= portfolio.cash + 1e-6,
              portfolio.positions.count < Self.maxPositions
        else { return nil }

        let position = PaperPosition(
            id: UUID(), symbol: trimmed, assetClass: assetClass, openedAt: now,
            entryPrice: price, shares: cashAmount / price, direction: direction,
            reason: reason, closedAt: nil, exitPrice: nil
        )
        portfolio.positions.append(position)
        portfolio.cash -= cashAmount
        save()
        return position
    }

    /// Close an open lot at `price`; proceeds return to cash. No-op if the lot
    /// isn't found or is already closed.
    @discardableResult
    func sell(positionID: UUID, price: Double, now: Date = Date()) -> Bool {
        guard price > 0,
              let idx = portfolio.positions.firstIndex(where: { $0.id == positionID }),
              portfolio.positions[idx].isOpen
        else { return false }
        portfolio.positions[idx].closedAt = now
        portfolio.positions[idx].exitPrice = price
        portfolio.cash += portfolio.positions[idx].shares * price
        save()
        return true
    }

    // MARK: - Valuation

    /// Distinct assets we need fresh closes for: every **open** lot (drives your
    /// current value) plus every **day-one** lot even if later sold (drives the
    /// buy-and-hold benchmark, which holds the day-one basket untouched). Missing
    /// the sold day-one picks would value them at entry cost and quietly compute
    /// the headline comparison wrong.
    func heldAssets(calendar: Calendar = .current) -> [WatchlistItem] {
        var needed = portfolio.openPositions
        if let firstDay = portfolio.positions.map(\.openedAt).min() {
            needed += portfolio.positions.filter { calendar.isDate($0.openedAt, inSameDayAs: firstDay) }
        }
        var seen = Set<String>()
        var result: [WatchlistItem] = []
        for pos in needed where seen.insert(pos.assetKey).inserted {
            result.append(WatchlistItem(symbol: pos.symbol, assetClass: pos.assetClass))
        }
        return result
    }

    /// Refresh end-of-day closes for held assets, capped per pass and throttled
    /// so foregrounding can't spray network calls. Mirrors `UserCallStore.resolveDue`.
    func revalueDue(using service: any MarketDataProviding, now: Date = Date(),
                    maxAssets: Int = 12, force: Bool = false) async {
        let held = heldAssets()
        guard !held.isEmpty else { return }
        if !force, let last = lastRevalue, now.timeIntervalSince(last) < revalueThrottle { return }
        lastRevalue = now

        var prices = latestPrices
        var series = histories
        for item in held.prefix(maxAssets) {
            if let fetched = try? await service.history(symbol: item.symbol, assetClass: item.assetClass),
               !fetched.isSample, let close = fetched.last?.close {
                let key = "\(item.assetClass.rawValue):\(item.symbol.lowercased())"
                prices[key] = close
                series[key] = fetched
            }
        }
        latestPrices = prices
        histories = series
    }

    // MARK: - Reads

    var report: PaperReport { PaperPortfolioEngine.report(portfolio, prices: latestPrices) }
    var hasStarted: Bool { !portfolio.positions.isEmpty }

    /// Start over with a fresh $10,000 — a deliberate, user-initiated reset.
    func resetPortfolio(now: Date = Date()) {
        portfolio = PaperPortfolio(createdAt: now)
        latestPrices = [:]
        histories = [:]
        lastRevalue = nil
        save()
    }

    // MARK: - Persistence

    private func save() {
        guard isReady else { return }
        if let data = try? JSONEncoder().encode(portfolio) {
            defaults.set(data, forKey: Keys.portfolio)
        }
    }
}

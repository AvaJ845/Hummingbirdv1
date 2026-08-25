import Foundation

/// One paper-trading lot — a buy the user made in the on-device practice
/// portfolio. Every buy states a direction (and optionally a reason), so a
/// position is also a *call*: a view logged before the outcome is known, never
/// a blind tap. Long-only in slice 1; `direction` records conviction, not a
/// short. Stored on-device only.
struct PaperPosition: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let symbol: String
    let assetClass: AssetClass
    let openedAt: Date
    let entryPrice: Double
    let shares: Double
    let direction: CallDirection
    var reason: CallReason?
    var closedAt: Date?
    var exitPrice: Double?
    /// What each method called for this asset at buy time (method id →
    /// Higher/Lower), snapshotted the same way a call's `methodDirections`
    /// is — lets the portfolio be scored head-to-head against the app's own
    /// methods, on the very same positions. Optional so older positions
    /// decode cleanly.
    var methodDirections: [String: CallDirection]? = nil

    /// Cash put in at entry.
    var cost: Double { entryPrice * shares }

    var isOpen: Bool { closedAt == nil }

    /// Normalized asset key, matching the store's per-asset grouping and the
    /// price dictionary the engine values against.
    var assetKey: String { "\(assetClass.rawValue):\(symbol.lowercased())" }

    /// Market value of this lot at a given price.
    func value(at price: Double) -> Double { shares * price }

    /// Was the stated lean right — did the price move the way you leaned between
    /// buy and sell? Nil while open, or on a flat exit (a push). Measures your
    /// directional *read*, separate from whether the sell was well-timed.
    var leanWasRight: Bool? {
        guard let exit = exitPrice, exit != entryPrice else { return nil }
        return (direction == .higher) == (exit > entryPrice)
    }

    /// Whether a given method's snapshotted call for this position was right —
    /// same entry→exit comparison as `leanWasRight`, just scored against the
    /// method's stated direction instead of your own. Nil if unresolved, flat
    /// (a push), or the method wasn't recorded for this position.
    func methodWasCorrect(_ methodId: String) -> Bool? {
        guard let exit = exitPrice, exit != entryPrice,
              let dir = methodDirections?[methodId] else { return nil }
        return (dir == .higher) == (exit > entryPrice)
    }

    /// Realized percent gain/loss on a closed lot (nil while open).
    var realizedReturn: Double? {
        guard let exit = exitPrice, entryPrice != 0 else { return nil }
        return (exit - entryPrice) / entryPrice
    }
}

/// The user's on-device practice portfolio. One per device in slice 1.
/// Starting cash is a fixed $10,000 — deliberately modest so it maps to real
/// stakes, never an inflating casino chip stack.
struct PaperPortfolio: Codable, Identifiable, Sendable {
    let id: UUID
    let createdAt: Date
    let startingCash: Double
    /// Uninvested cash. Buys subtract cost; sells add proceeds.
    var cash: Double
    /// Every lot ever opened, including closed ones — the closed lots are what
    /// let us reconstruct the day-one buy-and-hold benchmark.
    var positions: [PaperPosition]

    static let defaultStartingCash: Double = 10_000

    init(id: UUID = UUID(), createdAt: Date = Date(),
         startingCash: Double = PaperPortfolio.defaultStartingCash) {
        self.id = id
        self.createdAt = createdAt
        self.startingCash = startingCash
        self.cash = startingCash
        self.positions = []
    }

    var openPositions: [PaperPosition] { positions.filter(\.isOpen) }
}

// MARK: - Aggregates

/// You vs. buy-and-hold: your active portfolio's return against the return of
/// your day-one picks held untouched. `edge` > 0 means your trading *after*
/// day one added value; `edge` ≈ 0 means you're effectively holding — a
/// legitimate strategy, never a failure. A record of the past, never advice.
struct BuyAndHoldComparison: Equatable, Sendable {
    let yourValue: Double
    let holdValue: Double
    let startingCash: Double
    /// Trades beyond the initial day-one buys (later buys + all sells) — the
    /// honest turnover count. Buy-and-hold's is always zero.
    let tradeCount: Int

    var yourReturn: Double { startingCash != 0 ? (yourValue - startingCash) / startingCash : 0 }
    var holdReturn: Double { startingCash != 0 ? (holdValue - startingCash) / startingCash : 0 }
    /// How much your trading beat (or lagged) simply holding your first picks.
    var edge: Double { yourReturn - holdReturn }
    var isBeatingHold: Bool { yourValue > holdValue }
}

/// One dated sample of the portfolio's value beside the day-one buy-and-hold
/// benchmark — the two lines of the You-vs-hold chart.
struct PortfolioValuePoint: Identifiable, Equatable, Sendable {
    var id: Date { date }
    let date: Date
    let you: Double
    let hold: Double
    /// Your starting cash put into the market (S&P) on day one and held — an
    /// asset-class-neutral "would an index fund have beaten me?" line. Nil when
    /// no market history is available.
    var market: Double? = nil
}

/// How spread out the open portfolio is across distinct assets — information,
/// never advice ("you should diversify" is a judgment this app doesn't make).
/// Groups by symbol, not by lot, so a partially-sold position still counts as
/// one asset. Nil when there's nothing open to measure.
struct ConcentrationInsight: Equatable, Sendable {
    let topSymbol: String
    /// Share of total open value held in the single largest asset, 0...1.
    let topFraction: Double
    /// Distinct assets currently held (not lot count).
    let assetCount: Int
}

/// The practice portfolio's honest record. Reason calibration deliberately
/// lives on *calls* (a single decision, honestly scored) and not here: a lot's
/// profit depends on both entry thesis and exit timing, so tagging it to the
/// entry reason alone would be a muddy, half-true attribution.
struct PaperReport: Equatable, Sendable {
    let value: Double            // your current total (cash + open positions)
    let startingCash: Double
    let openPositionCount: Int
    let comparison: BuyAndHoldComparison
    /// How often your directional lean was right, over closed (decidable) lots —
    /// your read, scored separately from your P/L.
    let leanAccuracy: CallAccuracy
    /// Nil when there are no open positions.
    let concentration: ConcentrationInsight?
}

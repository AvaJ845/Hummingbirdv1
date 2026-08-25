import Foundation

/// Pure, deterministic scoring for the on-device paper portfolio. Values the
/// portfolio and its day-one buy-and-hold benchmark from end-of-day closes —
/// no real-time data, no I/O, no state. The win-condition it measures is "did
/// your trading beat just holding your first picks," never "did the number go
/// up."
enum PaperPortfolioEngine {

    /// History key for the market benchmark line (S&P via SPY).
    static let marketKey = "Stock:spy"

    /// Latest close for a position's asset, falling back to its own entry price
    /// when a fresh price isn't available — so an unpriced holding shows no fake
    /// P/L rather than dropping out of the totals.
    private static func price(for position: PaperPosition, in prices: [String: Double]) -> Double {
        prices[position.assetKey] ?? position.entryPrice
    }

    /// Your current total value: uninvested cash plus open lots at today's close.
    /// (Closed lots' proceeds already live in `cash`.)
    static func currentValue(_ portfolio: PaperPortfolio, prices: [String: Double]) -> Double {
        portfolio.cash + portfolio.openPositions.reduce(0) { $0 + $1.value(at: price(for: $1, in: prices)) }
    }

    /// The day-one buy-and-hold benchmark: whatever the user bought on their
    /// first active day, held untouched to today, plus the cash left uninvested
    /// after those first buys. Bounded by starting cash and well-defined even
    /// when later trades recycle capital, and it needs no data beyond the closes
    /// we already fetch for held symbols.
    static func buyAndHoldValue(_ portfolio: PaperPortfolio, prices: [String: Double],
                                calendar: Calendar = .current) -> Double {
        guard let firstDay = portfolio.positions.map(\.openedAt).min() else {
            return portfolio.startingCash   // nothing bought yet → all cash
        }
        let dayOne = portfolio.positions.filter { calendar.isDate($0.openedAt, inSameDayAs: firstDay) }
        let dayOneCost = dayOne.reduce(0) { $0 + $1.cost }
        let residualCash = portfolio.startingCash - dayOneCost
        let heldValue = dayOne.reduce(0) { $0 + $1.value(at: price(for: $1, in: prices)) }
        return residualCash + heldValue
    }

    static func comparison(_ portfolio: PaperPortfolio, prices: [String: Double],
                           calendar: Calendar = .current) -> BuyAndHoldComparison {
        let firstDay = portfolio.positions.map(\.openedAt).min()
        let laterBuys = portfolio.positions.filter { pos in
            guard let firstDay else { return false }
            return !calendar.isDate(pos.openedAt, inSameDayAs: firstDay)
        }.count
        let sells = portfolio.positions.filter { !$0.isOpen }.count
        return BuyAndHoldComparison(
            yourValue: currentValue(portfolio, prices: prices),
            holdValue: buyAndHoldValue(portfolio, prices: prices, calendar: calendar),
            startingCash: portfolio.startingCash,
            tradeCount: laterBuys + sells
        )
    }

    /// The two value lines over time — your portfolio vs. holding your day-one
    /// basket untouched — reconstructed from the trade history against each held
    /// asset's daily closes. Sampled at the closes we already fetch; end-of-day
    /// only, no I/O. Empty until histories are available or nothing's been bought.
    static func valueSeries(_ portfolio: PaperPortfolio, histories: [String: PriceSeries],
                            now: Date = Date(), calendar: Calendar = .current) -> [PortfolioValuePoint] {
        guard let firstOpen = portfolio.positions.map(\.openedAt).min() else { return [] }
        let start = calendar.startOfDay(for: firstOpen)
        let today = calendar.startOfDay(for: now)

        // Day axis: unique close days across the needed histories, within range,
        // always bookended by the first buy and today.
        var days: Set<Date> = [start, today]
        for series in histories.values {
            for point in series.points {
                let day = calendar.startOfDay(for: point.date)
                if day >= start && day <= today { days.insert(day) }
            }
        }
        let axis = days.sorted()

        let dayOne = portfolio.positions.filter { calendar.isDate($0.openedAt, inSameDayAs: firstOpen) }
        let residualCash = portfolio.startingCash - dayOne.reduce(0) { $0 + $1.cost }

        // Market benchmark: startingCash into the S&P on day one, held.
        let marketSeries = histories[marketKey]
        let marketBase = marketSeries.flatMap { PriceResolution.nearestClose(in: $0, to: start, toleranceDays: 5) }

        func price(_ pos: PaperPosition, on day: Date) -> Double {
            guard let series = histories[pos.assetKey] else { return pos.entryPrice }
            return PriceResolution.nearestClose(in: series, to: day, toleranceDays: 5) ?? pos.entryPrice
        }
        func onOrBefore(_ date: Date?, _ day: Date) -> Bool {
            guard let date else { return false }
            return calendar.startOfDay(for: date) <= day
        }

        return axis.map { day in
            var cash = portfolio.startingCash
            var openValue = 0.0
            for pos in portfolio.positions {
                let bought = onOrBefore(pos.openedAt, day)
                let sold = onOrBefore(pos.closedAt, day)
                if bought { cash -= pos.cost }
                if sold { cash += pos.shares * (pos.exitPrice ?? pos.entryPrice) }
                if bought && !sold { openValue += pos.shares * price(pos, on: day) }
            }
            let hold = residualCash + dayOne.reduce(0.0) { $0 + $1.shares * price($1, on: day) }

            var market: Double?
            if let marketSeries, let base = marketBase, base != 0,
               let close = PriceResolution.nearestClose(in: marketSeries, to: day, toleranceDays: 5) {
                market = portfolio.startingCash * (close / base)
            }
            return PortfolioValuePoint(date: day, you: cash + openValue, hold: hold, market: market)
        }
    }

    /// How concentrated the *open* book is in its single largest asset, grouped
    /// by symbol (not lot) so a partial sell doesn't inflate the count. Nil with
    /// no open positions or zero open value (avoids a divide-by-zero fraction).
    static func concentration(_ portfolio: PaperPortfolio, prices: [String: Double]) -> ConcentrationInsight? {
        let open = portfolio.openPositions
        guard !open.isEmpty else { return nil }
        var valueBySymbol: [String: Double] = [:]
        for pos in open {
            valueBySymbol[pos.symbol.uppercased(), default: 0] += pos.value(at: price(for: pos, in: prices))
        }
        let total = valueBySymbol.values.reduce(0, +)
        guard total > 0, let top = valueBySymbol.max(by: { $0.value < $1.value }) else { return nil }
        return ConcentrationInsight(topSymbol: top.key, topFraction: top.value / total, assetCount: valueBySymbol.count)
    }

    /// The volatility regime for one holding, classified from its own fetched
    /// history — the same classifier used elsewhere in the app for sketches, so
    /// "elevated"/"high" means the same thing here as it does there. Nil until
    /// that asset's history has loaded or there isn't enough of it yet.
    static func regime(for position: PaperPosition, histories: [String: PriceSeries]) -> VolatilityRegime? {
        guard let series = histories[position.assetKey] else { return nil }
        return RegimeClassifier.classify(series: series)
    }

    /// "What if you'd spread the same day-one dollars over several buys instead
    /// of all at once?" — dollar-cost averaging, simulated honestly against the
    /// SAME closes already fetched for the You-vs-hold chart. Splits each
    /// day-one position's cost into equal chunks bought at evenly spaced dates
    /// (capped at `maxIntervals` so a long-running portfolio stays cheap), each
    /// chunk priced at that date's nearest close, then values the resulting
    /// shares at today's close. Needs no data beyond what's already fetched.
    /// Nil when there's nothing to compare (no buys yet, or only a single
    /// possible interval — DCA and lump sum are then the same thing).
    static func dollarCostAverageValue(
        _ portfolio: PaperPortfolio, histories: [String: PriceSeries],
        intervalDays: Int = 7, maxIntervals: Int = 12,
        now: Date = Date(), calendar: Calendar = .current
    ) -> Double? {
        guard let firstOpen = portfolio.positions.map(\.openedAt).min() else { return nil }
        let start = calendar.startOfDay(for: firstOpen)
        let today = calendar.startOfDay(for: now)
        let dayOne = portfolio.positions.filter { calendar.isDate($0.openedAt, inSameDayAs: firstOpen) }
        guard !dayOne.isEmpty else { return nil }

        var dates: [Date] = [start]
        var cursor = start
        while dates.count < maxIntervals {
            guard let next = calendar.date(byAdding: .day, value: intervalDays, to: cursor), next <= today else { break }
            dates.append(next)
            cursor = next
        }
        guard dates.count >= 2 else { return nil }   // one possible buy date == lump sum; nothing to compare

        // Falls back to entry price on a missing close — same convention as
        // valueSeries/buyAndHoldValue's local price helpers, so a data gap
        // never silently zeroes out a position here while the benchmark it's
        // compared against stays populated.
        func price(_ pos: PaperPosition, on day: Date) -> Double {
            guard let series = histories[pos.assetKey] else { return pos.entryPrice }
            return PriceResolution.nearestClose(in: series, to: day, toleranceDays: 5) ?? pos.entryPrice
        }

        let residualCash = portfolio.startingCash - dayOne.reduce(0) { $0 + $1.cost }
        var investedValue = 0.0
        for pos in dayOne {
            let perBuy = pos.cost / Double(dates.count)
            var shares = 0.0
            for date in dates {
                let close = price(pos, on: date)
                guard close > 0 else { continue }
                shares += perBuy / close
            }
            investedValue += shares * price(pos, on: today)
        }
        return residualCash + investedValue
    }

    /// The portfolio's honest record: your value, and how it compares to holding
    /// your day-one basket untouched.
    static func report(_ portfolio: PaperPortfolio, prices: [String: Double],
                       calendar: Calendar = .current) -> PaperReport {
        let leanFlags = portfolio.positions.compactMap(\.leanWasRight)   // closed + decidable
        let leanAccuracy = CallAccuracy(decided: leanFlags.count, correct: leanFlags.filter { $0 }.count)
        return PaperReport(
            value: currentValue(portfolio, prices: prices),
            startingCash: portfolio.startingCash,
            openPositionCount: portfolio.openPositions.count,
            comparison: comparison(portfolio, prices: prices, calendar: calendar),
            leanAccuracy: leanAccuracy,
            concentration: concentration(portfolio, prices: prices)
        )
    }
}

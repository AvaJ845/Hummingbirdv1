import Foundation

/// Pure, deterministic scoring for the on-device paper portfolio. Values the
/// portfolio and its day-one buy-and-hold benchmark from end-of-day closes —
/// no real-time data, no I/O, no state. The win-condition it measures is "did
/// your trading beat just holding your first picks," never "did the number go
/// up."
enum PaperPortfolioEngine {

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
            return PortfolioValuePoint(date: day, you: cash + openValue, hold: hold)
        }
    }

    /// The portfolio's honest record: your value, and how it compares to holding
    /// your day-one basket untouched.
    static func report(_ portfolio: PaperPortfolio, prices: [String: Double],
                       calendar: Calendar = .current) -> PaperReport {
        PaperReport(
            value: currentValue(portfolio, prices: prices),
            startingCash: portfolio.startingCash,
            openPositionCount: portfolio.openPositions.count,
            comparison: comparison(portfolio, prices: prices, calendar: calendar)
        )
    }
}

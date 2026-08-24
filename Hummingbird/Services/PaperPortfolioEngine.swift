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

import Foundation

/// One financial-literacy question — pure definitional trivia about how
/// markets and investing work. Deliberately never about any specific
/// asset's future direction, so it carries zero prediction risk: the whole
/// point is education, the cleanest possible North Star fit.
struct LiteracyQuestion: Identifiable, Equatable, Sendable {
    let id: String
    let question: String
    let options: [String]
    let correctIndex: Int
    let explanation: String
}

enum LiteracyQuestionBank {
    static let all: [LiteracyQuestion] = [
        LiteracyQuestion(
            id: "pe-ratio",
            question: "A stock's P/E ratio compares its price to its...",
            options: ["Earnings", "Employees", "Expenses"],
            correctIndex: 0,
            explanation: "Price-to-earnings ratio: the share price divided by earnings per share — a rough gauge of how much investors are paying for each dollar of profit."
        ),
        LiteracyQuestion(
            id: "market-cap",
            question: "A company's market cap is calculated as...",
            options: ["Revenue minus expenses", "Share price × shares outstanding", "Total employee salaries"],
            correctIndex: 1,
            explanation: "Market capitalization is the total value of all outstanding shares — share price multiplied by the number of shares."
        ),
        LiteracyQuestion(
            id: "diversification",
            question: "Diversification mainly helps by...",
            options: ["Guaranteeing higher returns", "Reducing risk from any single holding", "Avoiding all fees"],
            correctIndex: 1,
            explanation: "Spreading money across different assets means one holding's bad day matters less to the whole — it manages risk, not a promise of better returns."
        ),
        LiteracyQuestion(
            id: "volatility",
            question: "Volatility describes...",
            options: ["How much a price swings over time", "How many shares trade per day", "A company's debt level"],
            correctIndex: 0,
            explanation: "Volatility measures the size and frequency of price swings, up or down — not direction, just how much it moves."
        ),
        LiteracyQuestion(
            id: "dividend-yield",
            question: "Dividend yield is...",
            options: ["A company's total profit", "Annual dividend as a % of share price", "The tax rate on dividends"],
            correctIndex: 1,
            explanation: "Yield expresses the dividend relative to the current share price, so it moves as the price does even if the payout doesn't change."
        ),
        LiteracyQuestion(
            id: "expense-ratio",
            question: "A fund's expense ratio is...",
            options: ["A one-time purchase fee", "Its annual cost as a % of your investment", "A penalty for selling early"],
            correctIndex: 1,
            explanation: "The expense ratio is charged every year as a percentage of assets, quietly reducing returns whether the fund goes up or down."
        ),
        LiteracyQuestion(
            id: "dollar-cost-averaging",
            question: "Dollar-cost averaging means...",
            options: ["Timing purchases around dips", "Investing a fixed amount at regular intervals", "Only buying round-numbered share counts"],
            correctIndex: 1,
            explanation: "A fixed amount, on a fixed schedule, regardless of price — it trades trying to time the market for consistency."
        ),
        LiteracyQuestion(
            id: "inflation",
            question: "Inflation refers to...",
            options: ["Rising stock prices", "The general rise in prices, eroding purchasing power", "A company issuing more shares"],
            correctIndex: 1,
            explanation: "Inflation is a broad, economy-wide rise in prices — a dollar buys a little less over time."
        ),
        LiteracyQuestion(
            id: "compound-interest",
            question: "Compound interest means you earn returns on...",
            options: ["Only your original deposit", "Your deposit plus previously earned returns", "Only the interest, not the principal"],
            correctIndex: 1,
            explanation: "Each period's returns get added to the base, so future returns are calculated on a growing amount — growth builds on itself."
        ),
        LiteracyQuestion(
            id: "bull-bear",
            question: "A \u{201C}bear market\u{201D} generally refers to...",
            options: ["Rising prices", "A sustained drop, commonly 20%+ from a recent high", "A single bad trading day"],
            correctIndex: 1,
            explanation: "\u{201C}Bear\u{201D} describes a sustained decline, not one rough day — \u{201C}bull\u{201D} is the opposite, a sustained rise."
        ),
        LiteracyQuestion(
            id: "liquidity",
            question: "An asset with high liquidity is one that...",
            options: ["Pays a high dividend", "Can be bought or sold quickly without moving its price much", "Has never lost value"],
            correctIndex: 1,
            explanation: "Liquidity is about ease of trading — a liquid asset has enough buyers and sellers that a trade doesn't move the price much."
        ),
        LiteracyQuestion(
            id: "index-fund",
            question: "An index fund is designed to...",
            options: ["Beat the market every year", "Track a market index rather than beat it", "Only hold one company"],
            correctIndex: 1,
            explanation: "Index funds aim to mirror an index's holdings and performance, not to outguess it — broad, low-cost exposure rather than stock-picking."
        ),
        LiteracyQuestion(
            id: "yield-curve",
            question: "The yield curve plots...",
            options: ["Stock prices over a year", "Bond interest rates against their time to maturity", "A company's quarterly earnings"],
            correctIndex: 1,
            explanation: "It shows how interest rates differ across bonds with different maturities — its shape is widely watched as an economic signal."
        ),
        LiteracyQuestion(
            id: "blue-chip",
            question: "A \u{201C}blue chip\u{201D} stock typically refers to...",
            options: ["A brand-new startup", "A large, well-established, financially sound company", "Any stock under $10"],
            correctIndex: 1,
            explanation: "The term describes size and stability — large, established companies with a long track record, not a price range or age."
        ),
        LiteracyQuestion(
            id: "market-vs-limit-order",
            question: "A limit order, unlike a market order, lets you...",
            options: ["Guarantee immediate execution", "Set the specific price you're willing to trade at", "Avoid all trading fees"],
            correctIndex: 1,
            explanation: "A market order executes right away at whatever the current price is; a limit order only executes at your specified price or better — which can mean it doesn't execute at all."
        ),
        LiteracyQuestion(
            id: "asset-allocation",
            question: "Asset allocation refers to...",
            options: ["Picking individual stocks", "How money is split across categories like stocks, bonds, and cash", "A broker's commission structure"],
            correctIndex: 1,
            explanation: "It's the mix across broad categories — a bigger driver of a portfolio's overall risk and return pattern than any single pick within it."
        ),
    ]
}

/// Cycles the literacy bank without immediate repeats — the same spaced-
/// repetition logic already used for Spaced Recall, applied to general
/// literacy instead of the user's own calls (Roediger & Karpicke, 2006,
/// "Test-Enhanced Learning"; Cepeda, Pashler, Vul, Wixted & Rohrer, 2006,
/// on distributed practice). Pure: given which question IDs have already
/// been shown (in the order they were shown), returns the next one — the
/// first not-yet-shown question in bank order, or the bank's first question
/// again once every question has been shown at least once.
enum LiteracyQuestionEngine {
    static func next(shown: [String], bank: [LiteracyQuestion] = LiteracyQuestionBank.all) -> LiteracyQuestion? {
        guard !bank.isEmpty else { return nil }
        return bank.first { !shown.contains($0.id) } ?? bank.first
    }
}

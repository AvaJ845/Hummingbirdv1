import Foundation

/// Maps CoinGecko-style ids / short tickers to Yahoo `{TICKER}-USD` chart symbols
/// for key-less crypto failover when CoinGecko rate-limits.
enum CryptoSymbolMap {
    private static let known: [String: String] = [
        "bitcoin": "BTC-USD",
        "btc": "BTC-USD",
        "ethereum": "ETH-USD",
        "eth": "ETH-USD",
        "solana": "SOL-USD",
        "sol": "SOL-USD",
        "ripple": "XRP-USD",
        "xrp": "XRP-USD",
        "cardano": "ADA-USD",
        "ada": "ADA-USD",
        "dogecoin": "DOGE-USD",
        "doge": "DOGE-USD",
        "polkadot": "DOT-USD",
        "dot": "DOT-USD",
        "litecoin": "LTC-USD",
        "ltc": "LTC-USD",
        "chainlink": "LINK-USD",
        "link": "LINK-USD",
        "avalanche-2": "AVAX-USD",
        "avax": "AVAX-USD",
        "binancecoin": "BNB-USD",
        "bnb": "BNB-USD",
        "matic-network": "MATIC-USD",
        "polygon": "MATIC-USD",
        "matic": "MATIC-USD",
        "uniswap": "UNI-USD",
        "uni": "UNI-USD",
        "shiba-inu": "SHIB-USD",
        "shib": "SHIB-USD"
    ]

    /// Yahoo chart ticker for a crypto id/symbol, if we can resolve one.
    static func yahooTicker(for raw: String) -> String? {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return nil }
        if let mapped = known[key] { return mapped }
        // Short ticker typed directly (e.g. "BTC").
        if key.count >= 2, key.count <= 5, key.unicodeScalars.allSatisfy(CharacterSet.letters.contains) {
            return "\(key.uppercased())-USD"
        }
        return nil
    }
}

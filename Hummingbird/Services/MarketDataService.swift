import Foundation

enum MarketDataError: LocalizedError {
    case emptySymbol
    case notFound(String)

    var errorDescription: String? {
        switch self {
        case .emptySymbol: return "Enter a symbol to forecast."
        case .notFound(let s): return "Couldn't find data for \"\(s)\"."
        }
    }
}

/// Fetches historical daily prices. Uses free, key-less public endpoints:
/// crypto via CoinGecko, stocks via Stooq. Falls back to a deterministic
/// synthetic series when the network is unavailable so the app always works.
struct MarketDataService {

    func history(symbol rawSymbol: String, assetClass: AssetClass, days: Int = 180) async throws -> PriceSeries {
        let symbol = rawSymbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !symbol.isEmpty else { throw MarketDataError.emptySymbol }

        do {
            switch assetClass {
            case .crypto:
                return try await fetchCrypto(id: symbol.lowercased(), days: days)
            case .stock:
                return try await fetchStock(ticker: symbol.uppercased(), days: days)
            }
        } catch let error as MarketDataError {
            throw error
        } catch {
            // Network / decoding failure — degrade gracefully to sample data.
            return SampleData.series(symbol: symbol, assetClass: assetClass, days: days)
        }
    }

    // MARK: - Crypto (CoinGecko)

    private func fetchCrypto(id: String, days: Int) async throws -> PriceSeries {
        var comps = URLComponents(string: "https://api.coingecko.com/api/v3/coins/\(id)/market_chart")!
        comps.queryItems = [
            URLQueryItem(name: "vs_currency", value: "usd"),
            URLQueryItem(name: "days", value: String(days)),
            URLQueryItem(name: "interval", value: "daily")
        ]
        let (data, response) = try await URLSession.shared.data(from: comps.url!)
        if let http = response as? HTTPURLResponse, http.statusCode == 404 {
            throw MarketDataError.notFound(id)
        }
        struct ChartResponse: Decodable { let prices: [[Double]] }
        let decoded = try JSONDecoder().decode(ChartResponse.self, from: data)
        let points: [PricePoint] = decoded.prices.compactMap { pair in
            guard pair.count == 2 else { return nil }
            return PricePoint(date: Date(timeIntervalSince1970: pair[0] / 1000), close: pair[1])
        }
        guard !points.isEmpty else { throw MarketDataError.notFound(id) }
        return PriceSeries(symbol: id, assetClass: .crypto, points: points, isSample: false)
    }

    // MARK: - Stocks (Stooq CSV)

    private func fetchStock(ticker: String, days: Int) async throws -> PriceSeries {
        let url = URL(string: "https://stooq.com/q/d/l/?s=\(ticker.lowercased()).us&i=d")!
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let csv = String(data: data, encoding: .utf8) else { throw MarketDataError.notFound(ticker) }

        let lines = csv.split(separator: "\n").map(String.init)
        guard lines.count > 1, lines[0].lowercased().contains("date") else {
            throw MarketDataError.notFound(ticker)
        }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        var points: [PricePoint] = []
        for line in lines.dropFirst() {
            let cols = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            // Date,Open,High,Low,Close,Volume
            guard cols.count >= 5, let date = formatter.date(from: cols[0]), let close = Double(cols[4]) else { continue }
            points.append(PricePoint(date: date, close: close))
        }
        guard !points.isEmpty else { throw MarketDataError.notFound(ticker) }
        let trimmed = Array(points.suffix(days))
        return PriceSeries(symbol: ticker, assetClass: .stock, points: trimmed, isSample: false)
    }
}

// MARK: - Sample data

enum SampleData {
    /// Deterministic pseudo-random walk seeded by the symbol, so the same
    /// symbol always yields the same series (useful offline / in previews).
    static func series(symbol: String, assetClass: AssetClass, days: Int) -> PriceSeries {
        var seed = UInt64(abs(symbol.hashValue) & 0x7fffffff) &+ 1
        func next() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 33) / Double(UInt64(1) << 31)
        }

        let base = assetClass == .crypto ? 30_000.0 : 150.0
        var price = base * (0.7 + next() * 0.6)
        let drift = (next() - 0.45) * 0.004
        let vol = assetClass == .crypto ? 0.035 : 0.015

        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        var points: [PricePoint] = []
        for i in 0..<days {
            let shock = (next() - 0.5) * 2 * vol
            price = max(0.01, price * (1 + drift + shock))
            if let date = calendar.date(byAdding: .day, value: i, to: start) {
                points.append(PricePoint(date: date, close: price))
            }
        }
        return PriceSeries(symbol: symbol, assetClass: assetClass, points: points, isSample: true)
    }
}

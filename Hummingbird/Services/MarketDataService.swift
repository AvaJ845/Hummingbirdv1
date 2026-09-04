import Foundation

/// Fetches historical daily prices from key-less public endpoints:
/// - Crypto: CoinGecko primary, Yahoo `{TICKER}-USD` failover
/// - Stocks: Yahoo Finance chart API
/// Falls back to deterministic sample data when the network is unavailable.
actor MarketDataService: MarketDataProviding {
    private let session: URLSession
    private let sampleProvider: @Sendable (String, AssetClass, Int) -> PriceSeries

    init(
        session: URLSession = .shared,
        sampleProvider: @escaping @Sendable (String, AssetClass, Int) -> PriceSeries = { SampleData.series(symbol: $0, assetClass: $1, days: $2) }
    ) {
        self.session = session
        self.sampleProvider = sampleProvider
    }

    /// Tickers and coin ids are letters, digits, `-` and `.` only (e.g. `BRK-B`,
    /// `ethereum-classic`). Anything else can't be a real symbol.
    private static let allowedSymbolCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.-"
    )

    /// Security: the symbol is interpolated into the request path, so restrict it
    /// to a strict allowlist. Blocks path manipulation (`/`, `..`, query/fragment
    /// injection) from reaching the network layer.
    static func isValidSymbol(_ symbol: String) -> Bool {
        guard (1...32).contains(symbol.count) else { return false }
        // Defense-in-depth: even within the allowlist, "." is permitted (BRK.B),
        // so reject any ".." run that could collapse a path segment on the API
        // host. Real tickers/ids never contain it.
        guard !symbol.contains("..") else { return false }
        return symbol.unicodeScalars.allSatisfy { allowedSymbolCharacters.contains($0) }
    }

    /// Coalesce redundant fetches through the shared cache (short TTL + in-flight
    /// dedupe) so the several paths that want the same symbol at once don't each
    /// hit the network. Kept below the auto-refresh cadence so refreshes stay live.
    static let cacheTTL: TimeInterval = 20

    func history(symbol rawSymbol: String, assetClass: AssetClass, days: Int = 180) async throws -> PriceSeries {
        let symbol = rawSymbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !symbol.isEmpty else { throw MarketDataError.emptySymbol }
        guard Self.isValidSymbol(symbol) else { throw MarketDataError.notFound(symbol) }

        let key = "\(assetClass.rawValue)|\(symbol.lowercased())|\(days)"
        return try await PriceCache.shared.series(key: key, ttl: Self.cacheTTL) {
            try await self.fetchFresh(symbol: symbol, assetClass: assetClass, days: days)
        }
    }

    private func fetchFresh(symbol: String, assetClass: AssetClass, days: Int) async throws -> PriceSeries {
        #if DEBUG
        if TestSupport.forceSampleData {
            return sampleProvider(symbol, assetClass, days)
        }
        #endif
        do {
            let series: PriceSeries
            switch assetClass {
            case .crypto:
                series = try await fetchCrypto(id: symbol.lowercased(), days: days)
            case .stock:
                series = try await fetchYahooStock(ticker: symbol.uppercased(), days: days)
            }
            // Scrub isolated bad ticks from real feeds before modeling.
            return PriceSanitizer.clean(series)
        } catch let error as MarketDataError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return sampleProvider(symbol, assetClass, days)
        }
    }

    // MARK: - Crypto

    private func fetchCrypto(id: String, days: Int) async throws -> PriceSeries {
        do {
            return try await fetchCoinGecko(id: id, days: days)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as MarketDataError where error == .notFound(id) {
            // Unknown id — try Yahoo ticker mapping before giving up.
            if let yahoo = CryptoSymbolMap.yahooTicker(for: id) {
                do {
                    return try await fetchYahooCrypto(coinID: id, yahooTicker: yahoo, days: days)
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    throw MarketDataError.notFound(id)
                }
            }
            throw error
        } catch {
            // Rate limit / transport — Yahoo failover, then sample via outer catch.
            if let yahoo = CryptoSymbolMap.yahooTicker(for: id) {
                return try await fetchYahooCrypto(coinID: id, yahooTicker: yahoo, days: days)
            }
            throw error
        }
    }

    private func fetchCoinGecko(id: String, days: Int) async throws -> PriceSeries {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.coingecko.com"
        components.path = "/api/v3/coins/\(id)/market_chart"
        components.queryItems = [
            URLQueryItem(name: "vs_currency", value: "usd"),
            URLQueryItem(name: "days", value: String(days)),
            URLQueryItem(name: "interval", value: "daily")
        ]

        guard let url = components.url else { throw MarketDataError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue(AppNetwork.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 404 { throw MarketDataError.notFound(id) }
            if http.statusCode == 429 { throw URLError(.resourceUnavailable) }
            if !(200...299).contains(http.statusCode) {
                throw URLError(.badServerResponse)
            }
        }

        struct ChartResponse: Decodable {
            let prices: [[Double]]
        }

        let decoded: ChartResponse
        do {
            decoded = try JSONDecoder().decode(ChartResponse.self, from: data)
        } catch {
            throw MarketDataError.decodingFailed
        }

        let points: [PricePoint] = decoded.prices.compactMap { pair in
            guard pair.count == 2 else { return nil }
            return PricePoint(
                date: Date(timeIntervalSince1970: pair[0] / 1000),
                close: pair[1]
            )
        }

        guard !points.isEmpty else { throw MarketDataError.notFound(id) }
        return PriceSeries(symbol: id, assetClass: .crypto, points: points, isSample: false)
    }

    private func fetchYahooCrypto(coinID: String, yahooTicker: String, days: Int) async throws -> PriceSeries {
        let series = try await fetchYahooStock(ticker: yahooTicker, days: days)
        return PriceSeries(
            symbol: coinID,
            assetClass: .crypto,
            points: series.points,
            isSample: false
        )
    }

    // MARK: - Stocks (Yahoo)

    private func fetchYahooStock(ticker: String, days: Int) async throws -> PriceSeries {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "query1.finance.yahoo.com"
        components.path = "/v8/finance/chart/\(ticker)"
        components.queryItems = [
            URLQueryItem(name: "interval", value: "1d"),
            URLQueryItem(name: "range", value: days <= 90 ? "3mo" : "6mo"),
            URLQueryItem(name: "includeAdjustedClose", value: "true")
        ]

        guard let url = components.url else { throw MarketDataError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue(AppNetwork.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 404 { throw MarketDataError.notFound(ticker) }
            if !(200...299).contains(http.statusCode) {
                throw URLError(.badServerResponse)
            }
        }

        return try StockPriceParsing.parseYahooChart(data, ticker: ticker, days: days)
    }
}

import Foundation

/// Pure parsers for stock history payloads — kept free of networking so they can be unit tested.
enum StockPriceParsing {
    /// Yahoo Finance chart JSON (`query1.finance.yahoo.com/v8/finance/chart/...`).
    static func parseYahooChart(_ data: Data, ticker: String, days: Int) throws -> PriceSeries {
        let decoded: YahooChartResponse
        do {
            decoded = try JSONDecoder().decode(YahooChartResponse.self, from: data)
        } catch {
            throw MarketDataError.decodingFailed
        }

        guard let result = decoded.chart.result?.first,
              let timestamps = result.timestamp,
              let closes = result.indicators.quote.first?.close else {
            throw MarketDataError.notFound(ticker)
        }

        var points: [PricePoint] = []
        points.reserveCapacity(min(timestamps.count, closes.count))

        for (timestamp, close) in zip(timestamps, closes) {
            guard let close, close > 0 else { continue }
            points.append(
                PricePoint(
                    date: Date(timeIntervalSince1970: TimeInterval(timestamp)),
                    close: close
                )
            )
        }

        guard !points.isEmpty else { throw MarketDataError.notFound(ticker) }
        return PriceSeries(
            symbol: ticker,
            assetClass: .stock,
            points: Array(points.suffix(days)),
            isSample: false
        )
    }
}

// MARK: - Yahoo decoding

private struct YahooChartResponse: Decodable {
    let chart: Chart

    struct Chart: Decodable {
        let result: [Result]?
    }

    struct Result: Decodable {
        let timestamp: [Int]?
        let indicators: Indicators
    }

    struct Indicators: Decodable {
        let quote: [Quote]
    }

    struct Quote: Decodable {
        let close: [Double?]
    }
}

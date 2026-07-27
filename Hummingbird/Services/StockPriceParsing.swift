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

        // Prefer split/dividend-adjusted close so corporate actions don't inject
        // artificial jumps into the trend/drift math. Fall back to raw close.
        let adjusted = result.indicators.adjclose?.first?.adjclose

        var points: [PricePoint] = []
        let usableCount = min(timestamps.count, closes.count)
        points.reserveCapacity(usableCount)

        for index in 0..<usableCount {
            let adjustedClose = (adjusted != nil && index < adjusted!.count) ? adjusted![index] : nil
            guard let price = firstValidPrice(adjustedClose, closes[index]) else { continue }
            points.append(
                PricePoint(
                    date: Date(timeIntervalSince1970: TimeInterval(timestamps[index])),
                    close: price
                )
            )
        }

        guard !points.isEmpty else { throw MarketDataError.notFound(ticker) }
        // Yahoo returns ascending time; sort defensively so `suffix` is the most recent.
        let ordered = points.sorted { $0.date < $1.date }
        return PriceSeries(
            symbol: ticker,
            assetClass: .stock,
            points: Array(ordered.suffix(days)),
            isSample: false
        )
    }

    /// First positive, finite candidate (adjusted close preferred over raw close).
    private static func firstValidPrice(_ candidates: Double?...) -> Double? {
        for value in candidates {
            if let value, value.isFinite, value > 0 { return value }
        }
        return nil
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
        let adjclose: [AdjClose]?
    }

    struct Quote: Decodable {
        let close: [Double?]
    }

    struct AdjClose: Decodable {
        let adjclose: [Double?]
    }
}

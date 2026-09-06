import Foundation

/// Pure parsers for macro payloads — networking stays in `EconomicDataService`.
enum EconomicParsing {
    static func parseYahooPercent(_ data: Data, kind: EconomicIndicatorKind) throws -> EconomicSnapshot {
        let decoded = try JSONDecoder().decode(YahooChart.self, from: data)
        guard let result = decoded.chart.result?.first,
              let timestamps = result.timestamp,
              let closes = result.indicators.quote.first?.close else {
            throw MarketDataError.decodingFailed
        }

        var pairs: [(Date, Double)] = []
        for (timestamp, close) in zip(timestamps, closes) {
            // ^IRX / ^TNX are quoted as a plain percent (e.g. 4.25). Anything at
            // or above 100 isn't a real short/long Treasury yield — treat it as
            // a corrupt tick, not a data point.
            guard let close, close.isFinite, close > 0, close < 100 else { continue }
            pairs.append((Date(timeIntervalSince1970: TimeInterval(timestamp)), close))
        }
        guard let last = pairs.last else { throw MarketDataError.decodingFailed }

        let previous: Double?
        if pairs.count > 21 {
            previous = pairs[pairs.count - 22].1
        } else if pairs.count > 1 {
            previous = pairs[0].1
        } else {
            previous = nil
        }

        return EconomicSnapshot(
            kind: kind,
            value: last.1,
            previousValue: previous,
            asOf: last.0,
            source: "Yahoo Finance",
            isSample: false
        )
    }
}

private struct YahooChart: Decodable {
    let chart: Chart
    struct Chart: Decodable { let result: [Result]? }
    struct Result: Decodable {
        let timestamp: [Int]?
        let indicators: Indicators
    }
    struct Indicators: Decodable { let quote: [Quote] }
    struct Quote: Decodable { let close: [Double?] }
}

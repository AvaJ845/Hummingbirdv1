import Foundation

/// Deterministic synthetic series for offline use and SwiftUI previews.
enum SampleData {
    /// Pseudo-random walk seeded by a stable hash of the symbol so the same
    /// symbol always yields the same series across launches.
    static func series(symbol: String, assetClass: AssetClass, days: Int) -> PriceSeries {
        var seed = stableSeed(for: symbol) &+ 1

        func next() -> Double {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(seed >> 33) / Double(UInt64(1) << 31)
        }

        let base = assetClass == .crypto ? 30_000.0 : 150.0
        var price = base * (0.7 + next() * 0.6)
        let drift = (next() - 0.45) * 0.004
        let vol = assetClass == .crypto ? 0.035 : 0.015

        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(byAdding: .day, value: -days, to: .now) ?? .now
        var points: [PricePoint] = []
        points.reserveCapacity(days)

        for dayOffset in 0..<days {
            let shock = (next() - 0.5) * 2 * vol
            price = max(0.01, price * (1 + drift + shock))
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: start) {
                points.append(PricePoint(date: date, close: price))
            }
        }

        return PriceSeries(symbol: symbol, assetClass: assetClass, points: points, isSample: true)
    }

    /// FNV-1a 64-bit — stable across process launches (unlike `hashValue`).
    static func stableSeed(for string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in string.lowercased().utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100_0000_01b3
        }
        return hash
    }
}

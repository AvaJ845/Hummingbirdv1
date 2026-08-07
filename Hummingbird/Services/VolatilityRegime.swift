import Foundation
import SwiftUI

/// How turbulent an asset is *right now* relative to its own recent norm —
/// context that helps a user read a sketch with appropriate caution. Pairs
/// with the gap-handling in the forecaster: when things are wild, widen your
/// mental error bars.
enum VolatilityRegime: String, Sendable {
    case calm, normal, elevated, high

    /// Only elevated/high are worth interrupting the user for.
    var isNoteworthy: Bool { self == .elevated || self == .high }

    var title: String {
        switch self {
        case .calm: "Calm stretch"
        case .normal: "Normal volatility"
        case .elevated: "Elevated volatility"
        case .high: "High volatility"
        }
    }

    var message: String {
        switch self {
        case .calm, .normal:
            return "Recent moves are within this asset's usual range."
        case .elevated:
            return "This asset is moving more than usual lately — read this sketch with wider error."
        case .high:
            return "This asset is unusually turbulent right now. Sketches are far less reliable in conditions like this."
        }
    }

    var symbol: String {
        switch self {
        case .calm, .normal: "waveform.path"
        case .elevated: "waveform.path.ecg"
        case .high: "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .calm, .normal: Theme.accent
        case .elevated: Theme.warning
        case .high: Theme.down
        }
    }
}

enum RegimeClassifier {
    /// Classify by the ratio of short-window return volatility to a longer
    /// baseline. >1 means "more volatile than its own norm." Distribution-free
    /// and self-referential, so it works across assets of any price scale.
    static func classify(
        series: PriceSeries,
        shortWindow: Int = 10,
        longWindow: Int = 60
    ) -> VolatilityRegime? {
        let closes = series.points.map(\.close)
        guard closes.count >= 20 else { return nil }

        var returns: [Double] = []
        returns.reserveCapacity(closes.count - 1)
        for i in 1..<closes.count where closes[i - 1] != 0 {
            returns.append((closes[i] - closes[i - 1]) / closes[i - 1])
        }
        guard returns.count >= 12 else { return nil }

        let recent = Array(returns.suffix(shortWindow))
        let baseline = Array(returns.suffix(longWindow))
        let recentVol = std(recent)
        let baselineVol = std(baseline)
        guard baselineVol > 0 else { return .calm }

        switch recentVol / baselineVol {
        case ..<0.7: return .calm
        case ..<1.3: return .normal
        case ..<2.0: return .elevated
        default: return .high
        }
    }

    private static func std(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count - 1)
        return variance > 0 ? sqrt(variance) : 0
    }
}

import Foundation

/// The derived, at-a-glance context around the current sketch — volatility
/// regime, calibrated reliability, and the best-tracking method for this asset.
/// Bundled into one value type so the view renders context instead of
/// manufacturing and juggling four separate pieces of loose state.
struct SketchContext: Equatable {
    var regime: VolatilityRegime?
    var reliability: ReliabilityScore?
    var bestModel: ModelPerformance?
    var modelBreakdown: [ModelPerformance] = []
}

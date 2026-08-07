import ActivityKit
import Foundation

/// Shared contract for the "tracking a sketch" Live Activity. Lives in both the
/// app (which starts/updates/ends the activity) and the widget extension (which
/// renders it). Honest by design: it shows the live price and the sketch's
/// projected change — an educational read, never a signal.
struct SketchActivityAttributes: ActivityAttributes {
    /// The parts that change over the activity's life.
    public struct ContentState: Codable, Hashable {
        /// Latest public price.
        var price: Double
        /// The sketch's projected change over the horizon, as a fraction.
        var projectedChange: Double
        var updatedAt: Date
    }

    /// The fixed parts, set when the activity starts.
    var symbol: String
    var title: String
    var horizonDays: Int
}

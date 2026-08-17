import SwiftUI

/// A horizontal gauge showing a calibration rate against its target — makes
/// "how close to on-target" scannable at a glance without reading percentages.
/// Decoration only: color still pairs with an adjacent number everywhere this
/// is used, never the sole carrier of meaning.
///
/// Colors are explicit parameters (not `.primary`/`.secondary`) so this works
/// unmodified inside a fixed-dark-look share card as well as an adaptive list.
struct CalibrationGauge: View {
    let rate: Double
    let target: Double
    let barColor: Color
    var trackColor: Color = Color.secondary.opacity(0.15)
    var markerColor: Color = Color.primary.opacity(0.4)

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(trackColor)
                Capsule().fill(barColor)
                    .frame(width: max(0, geo.size.width * min(1, max(0, rate))))
                Rectangle()
                    .fill(markerColor)
                    .frame(width: 2)
                    .offset(x: max(0, min(geo.size.width - 2, geo.size.width * target - 1)))
            }
        }
        .accessibilityHidden(true)
    }
}

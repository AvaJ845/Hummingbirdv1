import SwiftUI

/// A self-contained, brandable card rendered to an image for sharing the
/// Accuracy Report — same fixed dark look and caveat-always-travels precedent
/// as `ProjectionShareCard`/`ScorecardShareCard`. The app's own honesty
/// pledge, made shareable.
struct AccuracyShareCard: View {
    let report: ScorecardReport

    private var accentColor: Color {
        guard let cal = report.calibration else { return .white }
        return cal.inRangeRate >= 0.70
            ? Color(red: 0.35, green: 0.85, blue: 0.55)
            : Color(red: 1.00, green: 0.74, blue: 0.24)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image("BrandMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Hummingbird").font(.headline.weight(.bold)).foregroundStyle(.white)
                    Text("accuracy report").font(.caption2).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                if let cal = report.calibration {
                    Text("\(Int((cal.inRangeRate * 100).rounded()))% in range")
                        .font(.caption.weight(.bold)).monospacedDigit()
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.white.opacity(0.12), in: Capsule())
                        .foregroundStyle(.white)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(errorText(report.summary.medianError))
                    .font(.system(size: 44, weight: .bold, design: .rounded)).monospacedDigit()
                    .foregroundStyle(accentColor)
                Text("typical miss across \(report.summary.resolvedSketches) resolved sketches")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.65))
            }

            if let cal = report.calibration {
                CalibrationGauge(
                    rate: cal.inRangeRate, target: RangeCalibration.target, barColor: accentColor,
                    trackColor: .white.opacity(0.15), markerColor: .white.opacity(0.6)
                )
                .frame(height: 10)
            }

            Divider().overlay(.white.opacity(0.15))

            Text("A record of the past — not a prediction, never financial advice")
                .font(.caption2).foregroundStyle(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(width: 340)
        .background(
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.15, blue: 0.12), Color(red: 0.03, green: 0.08, blue: 0.07)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func errorText(_ error: Double?) -> String {
        guard let error else { return "—" }
        return String(format: "%.1f%%", error * 100)
    }
}

import SwiftUI

/// A self-contained, brandable card rendered to an image for sharing the
/// user's own call record — same fixed dark look and caveat-always-travels
/// precedent as `ProjectionShareCard`. Participation and honest accuracy only:
/// the streak line reads "days called," never "days right," and there is
/// deliberately no comparison against other users anywhere on this card.
struct ScorecardShareCard: View {
    let report: UserCallReport
    /// Consecutive days with a call made. 0 hides the badge entirely.
    let streak: Int

    private var accentColor: Color {
        guard let hit = report.overall.hitRate else { return .white }
        return hit >= 0.5 ? Color(red: 0.35, green: 0.85, blue: 0.55)
                          : Color(red: 0.98, green: 0.45, blue: 0.45)
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
                    Text("your call record").font(.caption2).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                if streak >= 2 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                        Text("\(streak)d")
                    }
                    .font(.caption.weight(.bold)).monospacedDigit()
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.white.opacity(0.12), in: Capsule())
                    .foregroundStyle(.white)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(report.overall.hitRate.map(pct) ?? "—")
                    .font(.system(size: 44, weight: .bold, design: .rounded)).monospacedDigit()
                    .foregroundStyle(accentColor)
                Text("right on \(report.overall.correct) of \(report.overall.decided) calls")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.65))
            }

            if !report.byConfidence.isEmpty {
                HStack(spacing: 0) {
                    ForEach(report.byConfidence) { row in
                        label(row.confidence.title, pct(row.hitRate))
                        if row.id != report.byConfidence.last?.id { Spacer() }
                    }
                }
            }

            if streak >= 2 {
                Text("\(streak)-day streak of calls made — showing up, not always right.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.75))
            }

            Divider().overlay(.white.opacity(0.15))

            Text("A record of your own calls, on-device · not financial advice")
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

    private func label(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.white.opacity(0.5))
            Text(value).font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    private func pct(_ fraction: Double) -> String { String(format: "%.0f%%", fraction * 100) }
}

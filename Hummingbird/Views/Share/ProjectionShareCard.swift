import SwiftUI

/// A self-contained, brandable card rendered to an image for sharing.
/// Fixed dark look so `ImageRenderer` output is consistent in light or dark, and
/// the "educational, not advice" caveat always travels with the image.
struct ProjectionShareCard: View {
    let symbol: String
    let price: Double
    let projectedChange: Double
    let methodName: String
    let horizonDays: Int
    /// Normalized 0...1 history + projection for the card sparkline.
    let historySpark: [Double]
    let projectionSpark: [Double]

    private var changeColor: Color {
        projectedChange >= 0 ? Color(red: 0.35, green: 0.85, blue: 0.55)
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
                    Text("on-device sketch").font(.caption2).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Text("\(horizonDays)d")
                    .font(.caption.weight(.bold)).monospacedDigit()
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.white.opacity(0.12), in: Capsule())
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(symbol.uppercased())
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(projectedChange.asSignedPercent())
                    .font(.system(size: 44, weight: .bold, design: .rounded)).monospacedDigit()
                    .foregroundStyle(changeColor)
                Text("projected over \(horizonDays) days")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.65))
            }

            CardSparkline(history: historySpark, projection: projectionSpark, accent: changeColor)
                .frame(height: 70)

            HStack {
                label("Now", price.asCurrency())
                Spacer()
                label("Best method", methodName, alignment: .trailing)
            }

            Divider().overlay(.white.opacity(0.15))

            Text("Educational projection from public prices · not financial advice")
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

    private func label(_ title: String, _ value: String, alignment: HorizontalAlignment = .leading) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(title.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.white.opacity(0.5))
            Text(value).font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
    }
}

/// Card-specific sparkline with explicit light-on-dark colors.
private struct CardSparkline: View {
    let history: [Double]
    let projection: [Double]
    let accent: Color

    var body: some View {
        Canvas { context, size in
            let total = max(1, history.count + projection.count - 1)
            func point(_ i: Int, _ v: Double) -> CGPoint {
                CGPoint(x: size.width * CGFloat(i) / CGFloat(total), y: size.height * (1 - CGFloat(v)))
            }
            var hist = Path()
            for (i, v) in history.enumerated() {
                let p = point(i, v)
                if i == 0 { hist.move(to: p) } else { hist.addLine(to: p) }
            }
            context.stroke(hist, with: .color(.white.opacity(0.55)),
                           style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            var proj = Path()
            let start = history.count - 1
            if let last = history.last, start >= 0 { proj.move(to: point(start, last)) }
            for (j, v) in projection.enumerated() { proj.addLine(to: point(history.count + j, v)) }
            context.stroke(proj, with: .color(accent),
                           style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [4, 3]))
        }
    }
}

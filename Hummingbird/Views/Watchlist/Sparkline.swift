import SwiftUI

/// Compact glanceable line: recent history (solid) continuing into the best
/// method's projection (dashed). Inputs are normalized to 0...1.
struct Sparkline: View {
    let history: [Double]
    let projection: [Double]

    var body: some View {
        Canvas { context, size in
            let total = max(1, history.count + projection.count - 1)

            func point(_ index: Int, _ value: Double) -> CGPoint {
                CGPoint(x: size.width * CGFloat(index) / CGFloat(total),
                        y: size.height * (1 - CGFloat(value)))
            }

            var historyPath = Path()
            for (i, value) in history.enumerated() {
                let p = point(i, value)
                if i == 0 { historyPath.move(to: p) } else { historyPath.addLine(to: p) }
            }
            context.stroke(historyPath, with: .color(.secondary),
                           style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))

            var projectionPath = Path()
            let start = history.count - 1
            if let lastValue = history.last, start >= 0 {
                projectionPath.move(to: point(start, lastValue))
            }
            for (j, value) in projection.enumerated() {
                projectionPath.addLine(to: point(history.count + j, value))
            }
            context.stroke(projectionPath, with: .color(Theme.accent),
                           style: StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [3, 2]))
        }
        .accessibilityHidden(true)
    }
}

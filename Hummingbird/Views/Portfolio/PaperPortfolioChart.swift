import SwiftUI
import Charts

/// Two honest lines over time: your portfolio value (solid) vs. holding your
/// day-one basket untouched (dashed). The gap between them is the value your
/// trading added or destroyed. End-of-day only — a record of the past, never
/// advice.
struct PaperPortfolioChart: View {
    let points: [PortfolioValuePoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Chart {
                ForEach(points) { point in
                    LineMark(x: .value("Date", point.date), y: .value("Value", point.hold),
                             series: .value("Series", "Buy-and-hold"))
                        .foregroundStyle(Color.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
                        .interpolationMethod(.catmullRom)
                }
                ForEach(points) { point in
                    LineMark(x: .value("Date", point.date), y: .value("Value", point.you),
                             series: .value("Series", "You"))
                        .foregroundStyle(Theme.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.catmullRom)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.12))
                    AxisValueLabel {
                        if let dollars = value.as(Double.self) {
                            Text(dollars.asCurrency(maximumFractionDigits: 0)).font(.caption2)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.12))
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day()).font(.caption2)
                }
            }
            .frame(height: 190)
            .accessibilityLabel(accessibilityText)

            legend
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: Theme.accent, faded: false, label: "You")
            legendItem(color: .secondary, faded: true, label: "Buy-and-hold")
        }
        .font(.caption2)
        .accessibilityHidden(true)
    }

    private func legendItem(color: Color, faded: Bool, label: String) -> some View {
        HStack(spacing: 6) {
            Capsule().fill(color).frame(width: 16, height: 3).opacity(faded ? 0.55 : 1)
            Text(label).foregroundStyle(.secondary)
        }
    }

    private var accessibilityText: String {
        guard let first = points.first, let last = points.last else { return "You versus buy-and-hold chart." }
        return "Your value went from \(first.you.asCurrency()) to \(last.you.asCurrency()). "
            + "Holding your first picks: \(first.hold.asCurrency()) to \(last.hold.asCurrency())."
    }
}

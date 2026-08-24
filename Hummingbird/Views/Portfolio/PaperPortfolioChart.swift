import SwiftUI
import Charts

/// Two honest lines over time: your portfolio value (solid) vs. holding your
/// day-one basket untouched (dashed). The gap between them is the value your
/// trading added or destroyed. Scrub to read either line on any date. EOD only
/// — a record of the past, never advice.
struct PaperPortfolioChart: View {
    let points: [PortfolioValuePoint]
    @State private var selectedDate: Date?

    /// Nearest sample to the scrub position.
    private var selected: PortfolioValuePoint? {
        guard let selectedDate else { return nil }
        return points.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }
    /// What the readout row shows: the scrubbed point, else the latest.
    private var readout: PortfolioValuePoint? { selected ?? points.last }

    /// The market line is all-or-nothing (SPY history present or not).
    private var showMarket: Bool { points.contains { $0.market != nil } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let readout { readoutRow(readout) }

            Chart {
                if showMarket {
                    ForEach(points) { point in
                        LineMark(x: .value("Date", point.date), y: .value("Value", point.market ?? point.hold),
                                 series: .value("Series", "Market"))
                            .foregroundStyle(Theme.accentAlt.opacity(0.9))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [2, 3]))
                            .interpolationMethod(.catmullRom)
                    }
                }
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
                if let selected {
                    RuleMark(x: .value("Date", selected.date))
                        .foregroundStyle(Color.secondary.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                    PointMark(x: .value("Date", selected.date), y: .value("Value", selected.hold))
                        .foregroundStyle(Color.secondary).symbolSize(70)
                    PointMark(x: .value("Date", selected.date), y: .value("Value", selected.you))
                        .foregroundStyle(Theme.accent).symbolSize(90)
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
            // Native selection: SwiftUI arbitrates the scrub gesture against the
            // enclosing scroll view, so vertical scrolling still works.
            .chartXSelection(value: $selectedDate)
            .frame(height: 190)
            .sensoryFeedback(.selection, trigger: selected?.date)
            .accessibilityLabel(accessibilityText)

            legend
        }
    }

    private func readoutRow(_ point: PortfolioValuePoint) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            valueColumn("You", point.you, Theme.accent)
            valueColumn("Buy-and-hold", point.hold, .secondary)
            if let market = point.market {
                valueColumn("Market", market, Theme.accentAlt)
            }
            Spacer()
            Text(point.date, format: .dateTime.month(.abbreviated).day())
                .font(.caption2).foregroundStyle(.tertiary).monospacedDigit()
        }
        .accessibilityHidden(true)
    }

    private func valueColumn(_ title: String, _ value: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value.asCurrency(maximumFractionDigits: 0))
                .font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(color)
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: Theme.accent, faded: false, label: "You")
            legendItem(color: .secondary, faded: true, label: "Buy-and-hold")
            if showMarket { legendItem(color: Theme.accentAlt, faded: true, label: "Market") }
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

import SwiftUI
import Charts

/// Interactive price-sketch chart: drag anywhere to scrub, and a live readout
/// shows the date, the likely value, and the (uncalibrated) range at that point.
/// Touch is a free polish upgrade — no new data, no network.
struct ForecastChart: View {
    let forecast: Forecast

    @State private var selectedDate: Date?

    private struct PlotPoint {
        let date: Date
        let value: Double
        let lower: Double?
        let upper: Double?
        let isForecast: Bool
    }

    // Built once in init — not rebuilt on every render or scrub frame.
    private let historyTail: [PricePoint]
    private let plotPoints: [PlotPoint]
    private let plotDates: [Date]

    init(forecast: Forecast) {
        self.forecast = forecast
        let count = max(forecast.points.count * 2, 30)
        let tail = Array(forecast.history.suffix(count))
        let points = tail.map { PlotPoint(date: $0.date, value: $0.close, lower: nil, upper: nil, isForecast: false) }
            + forecast.points.map { PlotPoint(date: $0.date, value: $0.mean, lower: $0.lower, upper: $0.upper, isForecast: true) }
        self.historyTail = tail
        self.plotPoints = points
        self.plotDates = points.map(\.date)
    }

    private var selected: PlotPoint? {
        guard let selectedDate,
              let index = ChartScrub.nearestIndex(to: selectedDate, in: plotDates) else { return nil }
        return plotPoints[index]
    }

    private var yDomain: ClosedRange<Double> {
        let history = historyTail.map(\.close)
        let lows = forecast.points.map(\.lower)
        let highs = forecast.points.map(\.upper)
        let all = history + lows + highs
        guard let min = all.min(), let max = all.max(), min < max else { return 0...1 }
        let pad = (max - min) * 0.08
        return (min - pad)...(max + pad)
    }

    private var accessibilitySummary: String {
        let current = forecast.lastClose?.asCurrency() ?? "unknown"
        let target = forecast.targetPrice?.asCurrency() ?? "unknown"
        let change = forecast.expectedChange?.asSignedPercent() ?? "unknown"
        return "Price sketch. Current \(current), projected \(target), change \(change), with an uncalibrated guess range — not a real probability."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            readout
            chart
        }
    }

    // MARK: readout

    private var readout: some View {
        HStack(spacing: 8) {
            if let selected {
                Text(selected.date.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if selected.isForecast, let lower = selected.lower, let upper = selected.upper {
                    Text("Likely \(selected.value.asCurrency())")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                    Text("· range \(lower.asCurrency(maximumFractionDigits: 0))–\(upper.asCurrency(maximumFractionDigits: 0))")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(selected.value.asCurrency())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                Spacer(minLength: 0)
                Button { selectedDate = nil } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .accessibilityLabel("Clear selection")
            } else {
                Image(systemName: "hand.draw").font(.caption2).foregroundStyle(.tertiary)
                Text("Drag across the chart to inspect any day")
                    .font(.caption).foregroundStyle(.tertiary)
                Spacer(minLength: 0)
            }
        }
        .frame(minHeight: 20)
        .animation(.easeInOut(duration: 0.15), value: selected?.date)
        .accessibilityHidden(true)
    }

    // MARK: chart

    private var chart: some View {
        Chart {
            ForEach(Array(forecast.points.enumerated()), id: \.offset) { _, point in
                AreaMark(
                    x: .value("Date", point.date),
                    yStart: .value("Lower", point.lower),
                    yEnd: .value("Upper", point.upper)
                )
                .foregroundStyle(Theme.accent.opacity(0.14))
                .interpolationMethod(.catmullRom)
            }

            ForEach(historyTail) { point in
                LineMark(x: .value("Date", point.date), y: .value("Price", point.close),
                         series: .value("Series", "History"))
                    .foregroundStyle(Color.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 2))
            }

            ForEach(forecast.points) { point in
                LineMark(x: .value("Date", point.date), y: .value("Price", point.mean),
                         series: .value("Series", "Forecast"))
                    .foregroundStyle(Theme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, dash: [5, 3]))
                    .interpolationMethod(.catmullRom)
            }

            if let last = forecast.history.last {
                PointMark(x: .value("Date", last.date), y: .value("Price", last.close))
                    .foregroundStyle(Color.primary)
                    .symbolSize(60)
            }

            if let selected {
                RuleMark(x: .value("Date", selected.date))
                    .foregroundStyle(Color.secondary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                PointMark(x: .value("Date", selected.date), y: .value("Price", selected.value))
                    .foregroundStyle(selected.isForecast ? Theme.accent : Color.primary)
                    .symbolSize(110)
            }
        }
        .chartYScale(domain: yDomain)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.12))
                AxisValueLabel {
                    if let price = value.as(Double.self) {
                        Text(price.asCurrency(maximumFractionDigits: 0)).font(.caption2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.12))
                AxisValueLabel(format: .dateTime.month(.abbreviated).day()).font(.caption2)
            }
        }
        // Native selection: SwiftUI arbitrates the scrub gesture against the
        // enclosing ScrollView, so vertical scrolling still works.
        .chartXSelection(value: $selectedDate)
        .frame(height: 260)
        .sensoryFeedback(.selection, trigger: selected?.date)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityAddTraits(.isImage)
    }
}

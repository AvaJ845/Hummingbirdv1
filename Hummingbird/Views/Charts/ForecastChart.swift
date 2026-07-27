import SwiftUI
import Charts

struct ForecastChart: View {
    let forecast: Forecast

    private var historyTail: [PricePoint] {
        let count = max(forecast.points.count * 2, 30)
        return Array(forecast.history.suffix(count))
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
        Chart {
            ForEach(forecast.points) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    yStart: .value("Lower", point.lower),
                    yEnd: .value("Upper", point.upper)
                )
                .foregroundStyle(Theme.accent.opacity(0.14))
                .interpolationMethod(.catmullRom)
            }

            ForEach(historyTail) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Price", point.close),
                    series: .value("Series", "History")
                )
                .foregroundStyle(Color.secondary)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }

            ForEach(forecast.points) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Price", point.mean),
                    series: .value("Series", "Forecast")
                )
                .foregroundStyle(Theme.accent)
                .lineStyle(StrokeStyle(lineWidth: 2.5, dash: [5, 3]))
                .interpolationMethod(.catmullRom)
            }

            if let last = forecast.history.last {
                PointMark(
                    x: .value("Date", last.date),
                    y: .value("Price", last.close)
                )
                .foregroundStyle(Color.primary)
                .symbolSize(60)
            }
        }
        .chartYScale(domain: yDomain)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.12))
                AxisValueLabel {
                    if let price = value.as(Double.self) {
                        Text(price.asCurrency(maximumFractionDigits: 0))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.12))
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .font(.caption2)
            }
        }
        .frame(height: 260)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityAddTraits(.isImage)
    }
}

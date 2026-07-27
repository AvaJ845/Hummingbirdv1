import SwiftUI
import Charts

struct ForecastChart: View {
    let forecast: Forecast

    private var historyTail: [PricePoint] {
        // Show a comparable amount of history to the forecast horizon for context.
        let count = max(forecast.points.count * 2, 30)
        return Array(forecast.history.suffix(count))
    }

    private var yDomain: ClosedRange<Double> {
        let hs = historyTail.map(\.close)
        let lows = forecast.points.map(\.lower)
        let highs = forecast.points.map(\.upper)
        let all = hs + lows + highs
        guard let min = all.min(), let max = all.max(), min < max else { return 0...1 }
        let pad = (max - min) * 0.08
        return (min - pad)...(max + pad)
    }

    var body: some View {
        Chart {
            // Confidence band
            ForEach(forecast.points) { p in
                AreaMark(
                    x: .value("Date", p.date),
                    yStart: .value("Lower", p.lower),
                    yEnd: .value("Upper", p.upper)
                )
                .foregroundStyle(Theme.accent.opacity(0.14))
                .interpolationMethod(.catmullRom)
            }

            // History line
            ForEach(historyTail) { p in
                LineMark(
                    x: .value("Date", p.date),
                    y: .value("Price", p.close),
                    series: .value("Series", "History")
                )
                .foregroundStyle(Color.secondary)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }

            // Forecast mean line
            ForEach(forecast.points) { p in
                LineMark(
                    x: .value("Date", p.date),
                    y: .value("Price", p.mean),
                    series: .value("Series", "Forecast")
                )
                .foregroundStyle(Theme.accent)
                .lineStyle(StrokeStyle(lineWidth: 2.5, dash: [5, 3]))
                .interpolationMethod(.catmullRom)
            }

            // Marker at the last known close
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
                    if let v = value.as(Double.self) {
                        Text(v.asCurrency(maximumFractionDigits: 0))
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
    }
}

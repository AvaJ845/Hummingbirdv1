import WidgetKit
import SwiftUI

struct PortfolioEntry: TimelineEntry {
    let date: Date
    let snapshot: PortfolioSnapshot?
}

struct PortfolioProvider: TimelineProvider {
    func placeholder(in context: Context) -> PortfolioEntry {
        PortfolioEntry(date: .now, snapshot: SharedStorage.portfolioSnapshot())
    }

    func getSnapshot(in context: Context, completion: @escaping (PortfolioEntry) -> Void) {
        completion(PortfolioEntry(date: .now, snapshot: SharedStorage.portfolioSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PortfolioEntry>) -> Void) {
        let entry = PortfolioEntry(date: .now, snapshot: SharedStorage.portfolioSnapshot())
        // The app also reloads this widget explicitly on open and in the
        // background refresh cycle — this hourly fallback just covers the gap
        // if neither has run in a while.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

/// The practice portfolio's one honest number — beating or behind buy-and-hold
/// — glanceable with zero taps. Never a green celebration of the balance going
/// up; the win-condition shown here is always "vs. holding," matching the
/// in-app framing exactly. A record of the past, never advice.
struct PortfolioWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: PortfolioWidgetKind.identifier, provider: PortfolioProvider()) { entry in
            PortfolioWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Practice Portfolio")
        .description("Your practice portfolio vs. buy-and-hold. A record of the past, never advice.")
        .supportedFamilies([
            .systemSmall,
            .accessoryRectangular, .accessoryInline, .accessoryCircular
        ])
    }
}

struct PortfolioWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PortfolioEntry

    var body: some View {
        switch family {
        case .accessoryInline: inlineView
        case .accessoryCircular: circularView
        case .accessoryRectangular: rectangularView
        default: homeScreenView
        }
    }

    // MARK: Lock Screen (accessory) families

    @ViewBuilder private var inlineView: some View {
        if let s = entry.snapshot, let edge = s.edge, abs(edge) > 0.0005 {
            Text("Portfolio \(edge.asSignedPercent()) vs. hold")
        } else {
            Text("Hummingbird")
        }
    }

    @ViewBuilder private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let s = entry.snapshot, let edge = s.edge {
                VStack(spacing: 0) {
                    Image(systemName: "chart.pie.fill").font(.system(size: 13))
                    Text(edge.asSignedPercent()).font(.system(size: 13, weight: .bold)).minimumScaleFactor(0.7)
                }
            } else {
                Image(systemName: "chart.pie")
            }
        }
        .widgetAccentable()
    }

    @ViewBuilder private var rectangularView: some View {
        if let s = entry.snapshot {
            VStack(alignment: .leading, spacing: 1) {
                Label(s.value.asCurrency(), systemImage: "chart.pie.fill")
                    .font(.headline)
                    .lineLimit(1)
                Text(vsHoldLine(s))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .widgetAccentable()
        } else {
            Text("Start a practice portfolio in Hummingbird")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: Home Screen (system) families

    @ViewBuilder private var homeScreenView: some View {
        if let s = entry.snapshot {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "chart.pie.fill").foregroundStyle(Theme.accentAlt)
                    Text("Practice portfolio").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Spacer()
                }
                Text(s.value.asCurrency())
                    .font(.system(size: 28, weight: .bold)).monospacedDigit()
                Spacer(minLength: 2)
                Text(vsHoldLine(s))
                    .font(.caption2).foregroundStyle(.secondary)
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "chart.pie")
                    .font(.title2)
                    .foregroundStyle(Theme.accentAlt)
                Text("Start a practice portfolio in Hummingbird")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func vsHoldLine(_ s: PortfolioSnapshot) -> String {
        guard let edge = s.edge, abs(edge) > 0.0005 else { return "Holding your first picks." }
        return edge > 0 ? "Ahead of buy-and-hold by \(edge.asSignedPercent())"
                        : "Behind buy-and-hold by \((-edge).asPercent())"
    }
}

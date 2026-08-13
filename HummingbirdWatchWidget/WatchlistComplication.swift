import WidgetKit
import SwiftUI

struct WatchComplicationEntry: TimelineEntry {
    let date: Date
    let snapshot: WatchlistSnapshot?
}

struct WatchComplicationProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WatchComplicationEntry {
        WatchComplicationEntry(date: .now, snapshot: SharedStorage.snapshots().first)
    }

    func snapshot(for configuration: SelectAssetIntent, in context: Context) async -> WatchComplicationEntry {
        WatchComplicationEntry(date: .now, snapshot: resolve(configuration))
    }

    func timeline(for configuration: SelectAssetIntent, in context: Context) async -> Timeline<WatchComplicationEntry> {
        let entry = WatchComplicationEntry(date: .now, snapshot: resolve(configuration))
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        return Timeline(entries: [entry], policy: .after(next))
    }

    /// The chosen asset's snapshot, or the most recently updated one if unset.
    private func resolve(_ configuration: SelectAssetIntent) -> WatchlistSnapshot? {
        let snapshots = SharedStorage.snapshots()
        if let id = configuration.asset?.id,
           let match = snapshots.first(where: { $0.id == id }) {
            return match
        }
        return snapshots.first
    }

    /// No proactive suggestions — the user picks the asset explicitly via the
    /// configuration intent.
    func recommendations() -> [AppIntentRecommendation<SelectAssetIntent>] { [] }
}

/// Watch face complication mirroring a watched asset's price and best-method
/// sketch. Same App Group data + AppIntent picker as the iPhone Lock Screen
/// widget — no network of its own, no separate source of truth.
struct WatchlistComplication: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "HummingbirdWatchComplication",
            intent: SelectAssetIntent.self,
            provider: WatchComplicationProvider()
        ) { entry in
            WatchComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Watchlist")
        .description("A watched asset's price and best-method sketch. Educational, not advice.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

struct WatchComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WatchComplicationEntry

    var body: some View {
        switch family {
        case .accessoryInline: inlineView
        case .accessoryCircular: circularView
        case .accessoryCorner: cornerView
        default: rectangularView
        }
    }

    @ViewBuilder private var inlineView: some View {
        if let s = entry.snapshot {
            Text("\(s.title) \(s.projectedChange.asSignedPercent())")
        } else {
            Text("Hummingbird")
        }
    }

    @ViewBuilder private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let s = entry.snapshot {
                VStack(spacing: 0) {
                    Text(s.title.prefix(4)).font(.system(size: 11, weight: .medium)).minimumScaleFactor(0.6)
                    Text(s.projectedChange.asSignedPercent()).font(.system(size: 12, weight: .bold)).minimumScaleFactor(0.6)
                }
            } else {
                Image(systemName: "bird")
            }
        }
        .widgetAccentable()
    }

    @ViewBuilder private var cornerView: some View {
        if let s = entry.snapshot {
            Text(s.projectedChange.asSignedPercent())
                .widgetLabel(s.title)
        } else {
            Text("—").widgetLabel("Hummingbird")
        }
    }

    @ViewBuilder private var rectangularView: some View {
        if let s = entry.snapshot {
            VStack(alignment: .leading, spacing: 1) {
                Text(s.title).font(.headline).lineLimit(1)
                Text(s.projectedChange.asSignedPercent())
                    .font(.caption.weight(.semibold).monospacedDigit())
                Text("Best: \(s.bestMethodName)").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            .widgetAccentable()
        } else {
            Text("Add an asset in Hummingbird")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

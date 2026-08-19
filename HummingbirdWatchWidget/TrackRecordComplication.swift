import WidgetKit
import SwiftUI

struct TrackRecordComplicationEntry: TimelineEntry {
    let date: Date
    let snapshot: TrackRecordSnapshot?
}

struct TrackRecordComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> TrackRecordComplicationEntry {
        TrackRecordComplicationEntry(date: .now, snapshot: SharedStorage.trackRecord())
    }

    func getSnapshot(in context: Context, completion: @escaping (TrackRecordComplicationEntry) -> Void) {
        completion(TrackRecordComplicationEntry(date: .now, snapshot: SharedStorage.trackRecord()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TrackRecordComplicationEntry>) -> Void) {
        let entry = TrackRecordComplicationEntry(date: .now, snapshot: SharedStorage.trackRecord())
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

/// Watch face complication mirroring the iPhone lock-screen streak widget —
/// same App Group snapshot, no network of its own. A record of the past,
/// never advice.
struct TrackRecordComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: TrackRecordWidgetKind.watchIdentifier, provider: TrackRecordComplicationProvider()) { entry in
            TrackRecordComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Your Streak")
        .description("Your own call streak and accuracy. A record of the past, never advice.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

struct TrackRecordComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TrackRecordComplicationEntry

    var body: some View {
        switch family {
        case .accessoryInline: inlineView
        case .accessoryCircular: circularView
        case .accessoryCorner: cornerView
        default: rectangularView
        }
    }

    @ViewBuilder private var inlineView: some View {
        if let s = entry.snapshot, s.streak > 0 {
            Text("\u{1F525} \(s.streak)-day streak")
        } else {
            Text("Hummingbird")
        }
    }

    @ViewBuilder private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let s = entry.snapshot, s.streak > 0 {
                VStack(spacing: 0) {
                    Image(systemName: "flame.fill").font(.system(size: 11))
                    Text("\(s.streak)").font(.system(size: 14, weight: .bold))
                }
            } else {
                Image(systemName: "bird")
            }
        }
        .widgetAccentable()
    }

    @ViewBuilder private var cornerView: some View {
        if let s = entry.snapshot, s.streak > 0 {
            Text("\(s.streak)").widgetLabel("day streak")
        } else {
            Text("—").widgetLabel("Hummingbird")
        }
    }

    @ViewBuilder private var rectangularView: some View {
        if let s = entry.snapshot {
            VStack(alignment: .leading, spacing: 1) {
                Label(s.streak > 0 ? "\(s.streak)-day streak" : "No active streak", systemImage: "flame.fill")
                    .font(.headline)
                    .lineLimit(1)
                if let hitRate = s.hitRate {
                    Text("\(pct(hitRate)) right · \(s.decided) call\(s.decided == 1 ? "" : "s")")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .widgetAccentable()
        } else {
            Text("Call it first in Hummingbird")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func pct(_ fraction: Double) -> String { String(format: "%.0f%%", fraction * 100) }
}

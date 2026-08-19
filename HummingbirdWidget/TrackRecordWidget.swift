import WidgetKit
import SwiftUI

struct TrackRecordEntry: TimelineEntry {
    let date: Date
    let snapshot: TrackRecordSnapshot?
}

struct TrackRecordProvider: TimelineProvider {
    func placeholder(in context: Context) -> TrackRecordEntry {
        TrackRecordEntry(date: .now, snapshot: SharedStorage.trackRecord())
    }

    func getSnapshot(in context: Context, completion: @escaping (TrackRecordEntry) -> Void) {
        completion(TrackRecordEntry(date: .now, snapshot: SharedStorage.trackRecord()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TrackRecordEntry>) -> Void) {
        let entry = TrackRecordEntry(date: .now, snapshot: SharedStorage.trackRecord())
        // The app also reloads this widget explicitly whenever the snapshot
        // changes (app open, background refresh) — this hourly fallback just
        // covers the gap if neither has run in a while.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

/// The user's own participation streak and accuracy — the one surface in the
/// app that needs zero taps to see, so it carries the honesty ledger instead
/// of market data. A record of the past, never advice.
struct TrackRecordWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: TrackRecordWidgetKind.identifier, provider: TrackRecordProvider()) { entry in
            TrackRecordWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Your Streak")
        .description("Your own call streak and accuracy. A record of the past, never advice.")
        .supportedFamilies([
            .systemSmall,
            .accessoryRectangular, .accessoryInline, .accessoryCircular
        ])
    }
}

struct TrackRecordWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TrackRecordEntry

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
                    Image(systemName: "flame.fill").font(.system(size: 13))
                    Text("\(s.streak)").font(.system(size: 15, weight: .bold))
                }
            } else {
                Image(systemName: "bird")
            }
        }
        .widgetAccentable()
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
                } else {
                    Text("Call it first to start your record")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .widgetAccentable()
        } else {
            Text("Call it first in Hummingbird")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: Home Screen (system) families

    @ViewBuilder private var homeScreenView: some View {
        if let s = entry.snapshot {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "flame.fill").foregroundStyle(Theme.warning)
                    Text("Your streak").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Spacer()
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(s.streak > 0 ? "\(s.streak)" : "\u{2014}")
                        .font(.system(size: 34, weight: .bold)).monospacedDigit()
                    Text(s.streak == 1 ? "day" : "days")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 2)
                if let hitRate = s.hitRate {
                    Text("\(pct(hitRate)) right · \(s.decided) call\(s.decided == 1 ? "" : "s")")
                        .font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text("A record of the past — never advice.")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "flame")
                    .font(.title2)
                    .foregroundStyle(Theme.warning)
                Text("Call it first in Hummingbird to start your streak")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func pct(_ fraction: Double) -> String { String(format: "%.0f%%", fraction * 100) }
}

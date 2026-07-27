import WidgetKit
import SwiftUI

struct WatchEntry: TimelineEntry {
    let date: Date
    let snapshot: WatchlistSnapshot?
}

struct WatchProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WatchEntry {
        WatchEntry(date: .now, snapshot: SharedStorage.snapshots().first)
    }

    func snapshot(for configuration: SelectAssetIntent, in context: Context) async -> WatchEntry {
        WatchEntry(date: .now, snapshot: resolve(configuration))
    }

    func timeline(for configuration: SelectAssetIntent, in context: Context) async -> Timeline<WatchEntry> {
        let entry = WatchEntry(date: .now, snapshot: resolve(configuration))
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
}

struct WatchlistWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "HummingbirdWatchlist",
            intent: SelectAssetIntent.self,
            provider: WatchProvider()
        ) { entry in
            WatchlistWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Watchlist")
        .description("A watched asset's price and best-method sketch. Educational, not advice.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct WatchlistWidgetView: View {
    let entry: WatchEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(snapshot.title)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: snapshot.assetClass.systemImage)
                        .foregroundStyle(Theme.accent)
                }
                Text(snapshot.price.asCurrency())
                    .font(.title3.weight(.bold).monospacedDigit())
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                Sparkline(history: snapshot.historySpark, projection: snapshot.projectionSpark)
                    .frame(maxHeight: .infinity)

                HStack {
                    Text(snapshot.projectedChange.asSignedPercent())
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.changeColor(snapshot.projectedChange))
                    Spacer()
                    Text("Best: \(snapshot.bestMethodName)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "star")
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
                Text("Add an asset in Hummingbird to see it here")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

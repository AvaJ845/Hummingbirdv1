import SwiftUI
import WidgetKit

/// A glanceable, read-only mirror of the iPhone watchlist. Reads the same App
/// Group snapshots the widget and Siri use — no network of its own, so it's
/// never stale-vs-live and never fetches on the user's behalf from the wrist.
struct WatchContentView: View {
    @State private var items: [WatchlistItem] = []
    @State private var snapshots: [WatchlistSnapshot] = []

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView {
                        Label("No watchlist", systemImage: "star")
                    } description: {
                        Text("Add an asset in Hummingbird on your iPhone.")
                    }
                } else {
                    List(items) { item in
                        row(for: item)
                    }
                }
            }
            .navigationTitle("Hummingbird")
        }
        .onAppear(perform: reload)
    }

    private func snapshot(for item: WatchlistItem) -> WatchlistSnapshot? {
        snapshots.first { $0.id == item.id }
    }

    @ViewBuilder private func row(for item: WatchlistItem) -> some View {
        if let snap = snapshot(for: item) {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(snap.title).font(.headline).lineLimit(1)
                    Spacer()
                    Text(snap.price.asCurrency(maximumFractionDigits: 0))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    WatchSparkline(history: snap.historySpark, projection: snap.projectionSpark)
                        .frame(width: 44, height: 20)
                    Spacer()
                    Text(snap.projectedChange.asSignedPercent())
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(WatchTheme.changeColor(snap.projectedChange))
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(snap.title), \(snap.price.asCurrency()), sketch \(snap.projectedChange.asSignedPercent())")
        } else {
            Text(item.title)
                .foregroundStyle(.secondary)
        }
    }

    private func reload() {
        items = SharedStorage.items()
        snapshots = SharedStorage.snapshots()
    }
}

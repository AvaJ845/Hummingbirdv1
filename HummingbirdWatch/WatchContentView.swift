import SwiftUI

struct WatchContentView: View {
    @Bindable var store: WatchStore

    var body: some View {
        NavigationStack {
            Group {
                if store.snapshots.isEmpty {
                    empty
                } else {
                    List(store.snapshots) { snapshot in
                        NavigationLink {
                            WatchDetailView(snapshot: snapshot)
                        } label: {
                            WatchRowView(snapshot: snapshot)
                        }
                    }
                }
            }
            .navigationTitle("Hummingbird")
        }
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Image(systemName: "star")
                .font(.title2)
                .foregroundStyle(Theme.accent)
            Text("Add assets on your iPhone to see them here.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

struct WatchRowView: View {
    let snapshot: WatchlistSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(snapshot.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(snapshot.projectedChange.asSignedPercent())
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.changeColor(snapshot.projectedChange))
            }
            HStack {
                Text(snapshot.price.asCurrency())
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Sparkline(history: snapshot.historySpark, projection: snapshot.projectionSpark)
                    .frame(width: 46, height: 16)
            }
        }
        .padding(.vertical, 2)
    }
}

struct WatchDetailView: View {
    let snapshot: WatchlistSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(snapshot.price.asCurrency())
                    .font(.title2.weight(.bold).monospacedDigit())
                Text("\(snapshot.projectedChange.asSignedPercent()) · \(snapshot.horizonDays)d")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.changeColor(snapshot.projectedChange))
                Sparkline(history: snapshot.historySpark, projection: snapshot.projectionSpark)
                    .frame(height: 60)
                Text("Best: \(snapshot.bestMethodName)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Educational sketch — not advice.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
        .navigationTitle(snapshot.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

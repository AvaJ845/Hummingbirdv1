import SwiftUI

struct WatchlistView: View {
    @Bindable var store: WatchlistStore
    let onOpen: (WatchlistItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var refreshingIDs: Set<String> = []
    private let service = MarketDataService()

    var body: some View {
        NavigationStack {
            Group {
                if store.items.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Watchlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !store.items.isEmpty {
                    ToolbarItem(placement: .topBarLeading) { EditButton() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await refreshAll() }
            .refreshable { await refreshAll() }
        }
    }

    private var list: some View {
        List {
            Section {
                ForEach(store.items) { item in
                    Button {
                        onOpen(item)
                        dismiss()
                    } label: {
                        WatchlistRowView(
                            item: item,
                            snapshot: store.snapshot(for: item),
                            alertsEnabled: store.isAlerting(item),
                            isRefreshing: refreshingIDs.contains(item.id)
                        )
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .leading) {
                        Button {
                            toggleAlert(item)
                        } label: {
                            Label(store.isAlerting(item) ? "Mute" : "Alerts",
                                  systemImage: store.isAlerting(item) ? "bell.slash.fill" : "bell.fill")
                        }
                        .tint(.orange)
                    }
                }
                .onDelete { store.remove(atOffsets: $0) }
                .onMove { store.move(fromOffsets: $0, toOffset: $1) }
            } footer: {
                Text("Best method = the one with the lowest recent backtest error for that asset. A track record of the past, not a prediction or advice. Swipe right to get a movement alert — never a buy/sell signal.")
            }
        }
    }

    private func toggleAlert(_ item: WatchlistItem) {
        let enabling = !store.isAlerting(item)
        store.setAlert(enabled: enabling, for: item)
        if enabling {
            Task { await NotificationService.requestAuthorization() }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No saved assets", systemImage: "star")
        } description: {
            Text("Tap the star on any projection to add it here for a glanceable, always-fresh sketch.")
        }
    }

    private func refreshAll() async {
        await withTaskGroup(of: Void.self) { group in
            for item in store.items {
                group.addTask { await refresh(item) }
            }
        }
    }

    private func refresh(_ item: WatchlistItem) async {
        refreshingIDs.insert(item.id)
        defer { refreshingIDs.remove(item.id) }

        let previousPrice = store.snapshot(for: item)?.price
        guard let series = try? await service.history(symbol: item.symbol, assetClass: item.assetClass),
              series.isForecastable,
              let snapshot = WatchlistIntelligence.snapshot(for: item, series: series) else { return }

        // Honest movement alert (never a signal) if the asset moved since last check.
        let pref = store.alertPreference(for: item)
        if pref.enabled, let previousPrice,
           let alert = AlertEngine.evaluate(item: item, previousPrice: previousPrice,
                                            newPrice: snapshot.price, threshold: pref.thresholdPercent) {
            await NotificationService.deliver(alert, id: item.id)
        }

        store.saveSnapshot(snapshot)
    }
}

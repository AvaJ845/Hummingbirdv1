import SwiftUI
import WidgetKit

struct WatchlistView: View {
    @Bindable var store: WatchlistStore
    let onOpen: (WatchlistItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var refreshingIDs: Set<String> = []
    @State private var showAdd = false
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
            .readableContentWidth()
            .navigationTitle("Watchlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !store.items.isEmpty { EditButton() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add asset")
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddAssetSheet(store: store)
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
                    .contextMenu { menu(for: item) }
                }
                .onDelete { store.remove(atOffsets: $0) }
                .onMove { store.move(fromOffsets: $0, toOffset: $1) }
            } footer: {
                Text("Best method = the one with the lowest recent backtest error for that asset. A track record of the past, not a prediction or advice. Long-press for movement alerts — never a buy/sell signal.")
            }
        }
    }

    @ViewBuilder private func menu(for item: WatchlistItem) -> some View {
        Menu("Movement alert") {
            Button { enableAlert(item, threshold: 0.03) } label: { Label("3% or more", systemImage: "bell") }
            Button { enableAlert(item, threshold: 0.05) } label: { Label("5% or more", systemImage: "bell") }
            Button { enableAlert(item, threshold: 0.10) } label: { Label("10% or more", systemImage: "bell") }
            if store.isAlerting(item) {
                Button(role: .destructive) {
                    store.setAlert(enabled: false, for: item)
                } label: {
                    Label("Turn off alerts", systemImage: "bell.slash")
                }
            }
        }
        Button(role: .destructive) {
            store.remove(symbol: item.symbol, assetClass: item.assetClass)
        } label: {
            Label("Remove", systemImage: "trash")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No saved assets", systemImage: "star")
        } description: {
            Text("Add an asset — or tap the star on any projection — for a glanceable, always-fresh sketch.")
        } actions: {
            Button {
                showAdd = true
            } label: {
                Label("Add asset", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
        }
    }

    private func toggleAlert(_ item: WatchlistItem) {
        let enabling = !store.isAlerting(item)
        store.setAlert(enabled: enabling, for: item)
        if enabling {
            Task { await NotificationService.requestAuthorization() }
        }
    }

    private func enableAlert(_ item: WatchlistItem, threshold: Double) {
        store.setAlert(enabled: true, threshold: threshold, for: item)
        Task { await NotificationService.requestAuthorization() }
    }

    /// Cap on simultaneous in-flight refreshes. A large watchlist otherwise
    /// bursts one network call per item on every pull-to-refresh and every
    /// background tick — costly on cellular and unfriendly to rate limits.
    private static let maxConcurrentRefreshes = 5

    private func refreshAll() async {
        await withTaskGroup(of: Void.self) { group in
            var iterator = store.items.makeIterator()

            for _ in 0..<Self.maxConcurrentRefreshes {
                guard let item = iterator.next() else { break }
                group.addTask { await refresh(item) }
            }
            while await group.next() != nil {
                if let item = iterator.next() {
                    group.addTask { await refresh(item) }
                }
            }
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func refresh(_ item: WatchlistItem) async {
        refreshingIDs.insert(item.id)
        defer { refreshingIDs.remove(item.id) }
        await WatchlistRefresh.refresh(item, store: store, service: service)
    }
}

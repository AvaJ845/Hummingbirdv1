import SwiftUI

/// Add an asset to the watchlist without first running a projection.
/// Validates by fetching real public history, and pre-warms the snapshot so the
/// new row (and the widget) show data immediately.
struct AddAssetSheet: View {
    @Bindable var store: WatchlistStore
    @Environment(\.dismiss) private var dismiss

    @State private var assetClass: AssetClass = .crypto
    @State private var symbol = ""
    @State private var isValidating = false
    @State private var errorMessage: String?
    @FocusState private var focused: Bool

    private let service = MarketDataService()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Asset type", selection: $assetClass) {
                        ForEach(AssetClass.allCases) { klass in
                            Label(klass.rawValue, systemImage: klass.systemImage).tag(klass)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: assetClass) { _, _ in errorMessage = nil }

                    TextField(assetClass.placeholder, text: $symbol)
                        .textInputAutocapitalization(assetClass == .stock ? .characters : .never)
                        .autocorrectionDisabled()
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit(add)
                } footer: {
                    Text(assetClass.hint)
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                            .font(.subheadline)
                    }
                }

                Section {
                    Button(action: add) {
                        HStack {
                            if isValidating { ProgressView().controlSize(.small) }
                            Text(isValidating ? "Checking public data…" : "Add to watchlist")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(symbol.trimmingCharacters(in: .whitespaces).isEmpty || isValidating)
                } footer: {
                    Text("We confirm there's enough public history to sketch a path before adding.")
                }
            }
            .navigationTitle("Add Asset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium])
    }

    private func add() {
        let trimmed = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isValidating else { return }
        let item = WatchlistItem(symbol: trimmed, assetClass: assetClass)

        guard !store.contains(symbol: item.symbol, assetClass: assetClass) else {
            errorMessage = "\(item.title) is already on your watchlist."
            return
        }

        isValidating = true
        errorMessage = nil
        Task {
            defer { isValidating = false }
            guard let series = try? await service.history(symbol: item.symbol, assetClass: assetClass),
                  series.isForecastable else {
                errorMessage = "Couldn't find enough public history for “\(item.symbol)”."
                return
            }
            store.add(symbol: item.symbol, assetClass: assetClass)
            if let snapshot = WatchlistIntelligence.snapshot(for: item, series: series) {
                store.saveSnapshot(snapshot)
            }
            dismiss()
        }
    }
}

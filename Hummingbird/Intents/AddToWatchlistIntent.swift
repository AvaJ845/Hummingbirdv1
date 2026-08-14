import AppIntents

/// "Hey Siri, add Bitcoin to my watchlist in Hummingbird." Same validation bar
/// as adding from the app itself — confirms there's enough public history
/// before saving, so the watchlist never picks up a symbol it can't sketch.
struct AddToWatchlistIntent: AppIntent {
    static var title: LocalizedStringResource { "Add to Watchlist" }
    static var description: IntentDescription {
        IntentDescription("Adds a stock or crypto to your Hummingbird watchlist, after confirming there's enough public history to sketch.")
    }
    static var openAppWhenRun: Bool { false }

    @Parameter(title: "Symbol") var symbol: String
    @Parameter(title: "Asset type") var asset: AssetKindAppEnum

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$symbol) (\(\.$asset)) to my watchlist")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let assetClass = asset.assetClass
        let store = WatchlistStore()

        guard !store.contains(symbol: symbol, assetClass: assetClass) else {
            return .result(dialog: "\(symbol.uppercased()) is already on your watchlist.")
        }

        let item = WatchlistItem(symbol: symbol, assetClass: assetClass)
        let service = MarketDataService()
        guard let series = try? await service.history(symbol: symbol, assetClass: assetClass),
              series.isForecastable else {
            return .result(dialog: "I couldn't find enough public history for \(symbol).")
        }

        store.add(symbol: item.symbol, assetClass: assetClass)
        if let snapshot = WatchlistIntelligence.snapshot(for: item, series: series) {
            store.saveSnapshot(snapshot)
        }

        return .result(dialog: "Added \(symbol.uppercased()) to your watchlist.")
    }
}

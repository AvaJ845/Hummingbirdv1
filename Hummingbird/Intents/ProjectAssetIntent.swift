import AppIntents

/// Asset type usable as a Siri/Shortcuts parameter.
enum AssetKindAppEnum: String, AppEnum {
    case stock
    case crypto

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Asset type" }
    static var caseDisplayRepresentations: [AssetKindAppEnum: DisplayRepresentation] {
        [.stock: "Stock", .crypto: "Crypto"]
    }

    var assetClass: AssetClass { self == .stock ? .stock : .crypto }
}

/// "Hey Siri, project Bitcoin in Hummingbird." Runs an on-device educational
/// projection and speaks the best recent method's sketch. Never advice.
struct ProjectAssetIntent: AppIntent {
    static var title: LocalizedStringResource { "Project an Asset" }
    static var description: IntentDescription {
        IntentDescription("Runs an on-device educational price projection. Not financial advice.")
    }
    static var openAppWhenRun: Bool { false }

    @Parameter(title: "Symbol") var symbol: String
    @Parameter(title: "Asset type") var asset: AssetKindAppEnum
    @Parameter(title: "Days", default: 30) var days: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Project \(\.$symbol) (\(\.$asset)) for \(\.$days) days")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let horizon = max(7, min(days, 90))
        let service = MarketDataService()
        let series = try await service.history(symbol: symbol, assetClass: asset.assetClass, days: 180)

        guard series.isForecastable,
              let (model, forecast) = WatchlistIntelligence.best(for: series, horizon: horizon),
              let change = forecast.expectedChange else {
            return .result(dialog: "I couldn't find enough public history for \(symbol).")
        }

        let direction = change >= 0 ? "up" : "down"
        let dialog = "\(symbol.uppercased())'s best recent method, \(model.name), sketches it \(direction) \(abs(change).asPercent()) over \(horizon) days. Educational only — not financial advice."
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}

struct HummingbirdShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ProjectAssetIntent(),
            phrases: [
                "Project an asset in \(.applicationName)",
                "Run a projection in \(.applicationName)"
            ],
            shortTitle: "Project asset",
            systemImageName: "chart.line.uptrend.xyaxis"
        )
        AppShortcut(
            intent: AddToWatchlistIntent(),
            phrases: [
                "Add to my watchlist in \(.applicationName)",
                "Watch an asset in \(.applicationName)"
            ],
            shortTitle: "Add to watchlist",
            systemImageName: "star"
        )
        AppShortcut(
            intent: ReadDigestIntent(),
            phrases: [
                "Read my digest in \(.applicationName)",
                "What's my \(.applicationName) digest"
            ],
            shortTitle: "Read digest",
            systemImageName: "text.alignleft"
        )
    }
}

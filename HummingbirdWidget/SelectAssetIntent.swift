import AppIntents

/// A watched asset the user can pick for a widget.
struct WatchlistItemEntity: AppEntity, Identifiable {
    let id: String
    let title: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Asset" }
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }
    static var defaultQuery = WatchlistItemQuery()
}

/// Feeds the widget's asset picker from the saved watchlist.
struct WatchlistItemQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WatchlistItemEntity] {
        allEntities().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [WatchlistItemEntity] {
        allEntities()
    }

    func defaultResult() async -> WatchlistItemEntity? {
        allEntities().first
    }

    private func allEntities() -> [WatchlistItemEntity] {
        SharedStorage.items().map { WatchlistItemEntity(id: $0.id, title: $0.title) }
    }
}

/// Widget configuration: choose which watched asset this widget shows.
struct SelectAssetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Choose Asset" }
    static var description: IntentDescription {
        IntentDescription("Pick which watched asset this widget shows. Leave empty for your most recently updated one.")
    }

    @Parameter(title: "Asset") var asset: WatchlistItemEntity?
}

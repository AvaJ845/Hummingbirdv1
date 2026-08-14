import AppIntents

/// "Hey Siri, read my digest in Hummingbird." Speaks the same on-device
/// summary the optional morning notification carries — movement across the
/// watchlist, never a signal.
struct ReadDigestIntent: AppIntent {
    static var title: LocalizedStringResource { "Read Today's Digest" }
    static var description: IntentDescription {
        IntentDescription("Speaks a summary of your watchlist's current sketches. Educational only — not financial advice.")
    }
    static var openAppWhenRun: Bool { false }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let digest = DigestEngine.compose(snapshots: SharedStorage.snapshots()) else {
            return .result(dialog: "Add an asset to your watchlist in Hummingbird to get a digest.")
        }
        return .result(dialog: IntentDialog(stringLiteral: digest.body))
    }
}

import Foundation

/// Paid capabilities, for display only (the "Pro adds" list on `PaywallView`).
/// Free tier stays useful for literacy; Pro unlocks comparison depth. There is
/// a single price tier, so the actual gate everywhere is `EntitlementStore.isPro`
/// — this enum doesn't (and shouldn't) drive gating itself.
enum ProFeature: String, CaseIterable, Identifiable, Sendable {
    // Self-knowledge leads — the reason to pay is an honest mirror, not foresight.
    case youVsMethods
    case portfolioVsHold
    case regimeReliability
    case honestRecord
    case keepEveryCall
    case weeklyJournal
    // Breadth, quietly last.
    case moreBreadth

    var id: String { rawValue }

    var title: String {
        switch self {
        case .youVsMethods: "You vs. the methods"
        case .portfolioVsHold: "Your portfolio vs. buy-and-hold"
        case .regimeReliability: "Best method by conditions"
        case .honestRecord: "Your record, in depth"
        case .keepEveryCall: "Keep every call — and share it"
        case .weeklyJournal: "Your weekly journal"
        case .moreBreadth: "More methods & longer windows"
        }
    }

    var detail: String {
        switch self {
        case .youVsMethods:
            "See how your own calls compare with the app’s methods — scored on the very same calls."
        case .portfolioVsHold:
            "Watch your practice trades against buy-and-hold and the market over time — did your trading actually add anything?"
        case .regimeReliability:
            "See which method has tracked this asset closest in calm markets versus turbulent ones — the method that wins overall isn't always the one that wins right now."
        case .honestRecord:
            "Your accuracy by confidence and by reasoning — did feeling sure mean being right, and which kind of thinking actually held up."
        case .keepEveryCall:
            "Your full call history, not just the recent handful, plus a shareable summary of your record."
        case .weeklyJournal:
            "A week's rollup of your watchlist's sketch activity — which assets moved most and how closely the app's own methods have tracked lately."
        case .moreBreadth:
            "Momentum, Mean reversion, and Blend beside the free methods, and sketches up to 90 days — more paths to compare, never better foresight."
        }
    }

    var systemImage: String {
        switch self {
        case .youVsMethods: "trophy"
        case .portfolioVsHold: "chart.xyaxis.line"
        case .regimeReliability: "waveform.path.ecg"
        case .honestRecord: "checkmark.seal"
        case .keepEveryCall: "tray.full"
        case .weeklyJournal: "book.closed"
        case .moreBreadth: "arrow.left.arrow.right"
        }
    }
}

enum FreeTierLimits {
    static let maxHorizonDays = 30
    /// Both live daily rate knobs are free (catalogue is only two series).
    static let maxSelectedIndicators = EconomicIndicatorKind.allCases.count
    static let freeModelIDs: Set<String> = [
        ForecastStrategy.drift.rawValue,
        ForecastStrategy.trendSeasonal.rawValue,
        ForecastStrategy.linear.rawValue,
        ForecastStrategy.holt.rawValue
    ]
}

extension ForecastModel {
    var requiresPro: Bool {
        !FreeTierLimits.freeModelIDs.contains(id)
    }
}

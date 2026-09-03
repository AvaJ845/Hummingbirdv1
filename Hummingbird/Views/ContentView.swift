import SwiftUI
import WidgetKit

struct ContentView: View {
    @Environment(\.requestReview) private var requestReview
    @State private var entitlements: EntitlementStore
    @State private var viewModel: ForecastViewModel
    @State private var dictation = DictationController()
    @State private var watchlist = WatchlistStore()
    @State private var showWatchlist = false
    @State private var showSettings = false
    @State private var showOnboarding = false
    @State private var showCallSheet = false
    @State private var showYourCalls = false
    @State private var paper = PaperPortfolioStore()
    @State private var showPaperPortfolio = false
    @State private var spacedRecall = SpacedRecallStore()
    @State private var activeRecallBatch: [(call: UserCall, intervalIndex: Int)] = []
    @State private var literacy = WeeklyLiteracyStore()
    @State private var literacyQuestion: LiteracyQuestion?
    @AppStorage("hummingbird.hasOnboarded") private var hasOnboarded = false
    /// Opt-in "practice" surface: the prediction/portfolio/recall/literacy tools.
    /// Off by default so the home screen stays a calm single-purpose utility —
    /// flipped on from Settings.
    @AppStorage("hb.practice.enabled") private var practiceEnabled = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var symbolFocused: Bool
    @State private var path = NavigationPath()
    @State private var micCenter: CGPoint = .zero
    @State private var lastLiveRefresh: Date = .distantPast
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let store = EntitlementStore()
        let card = SketchScorecardStore()
        let calls = UserCallStore()
        _entitlements = State(initialValue: store)
        _viewModel = State(initialValue: ForecastViewModel(entitlements: store, scorecard: card, userCalls: calls))
    }

    var body: some View {
        ZStack {
            NavigationStack(path: $path) {
                home
                    .navigationDestination(for: AppRoute.self) { route in
                        switch route {
                        case .models:
                            ModelPickerSheet(viewModel: viewModel, entitlements: entitlements)
                        case .indicators:
                            EconomicIndicatorsSheet(viewModel: viewModel)
                        case .paywall(let reason):
                            PaywallView(entitlements: entitlements, reason: reason, scorecard: viewModel.scorecard)
                        }
                    }
            }
            .animation(NavigationMotion.page, value: path.count)
            .allowsHitTesting(!dictation.isActive)

            if dictation.isActive || dictation.bloomProgress > 0.001 {
                DictationOverlay(
                    bloomProgress: dictation.bloomProgress,
                    actionRotation: dictation.actionRotation,
                    phase: dictation.phase,
                    transcript: dictation.displayText,
                    micCenter: micCenter,
                    onConfirm: { Task { await confirmDictation() } },
                    onCancel: {
                        Task { await dictation.cancel() }
                    }
                )
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .overlayPreferenceValue(MicAnchorKey.self) { anchor in
            GeometryReader { geo in
                Color.clear
                    .onAppear { updateMicCenter(anchor: anchor, geo: geo) }
                    .onChange(of: dictation.phase) { _, _ in
                        updateMicCenter(anchor: anchor, geo: geo)
                    }
                    .onChange(of: path.count) { _, _ in
                        updateMicCenter(anchor: anchor, geo: geo)
                    }
            }
        }
        .onChange(of: entitlements.isPro) { _, _ in
            viewModel.enforceEntitlementsAfterPurchaseChange()
        }
        .onChange(of: viewModel.pendingPaywallReason) { _, reason in
            if let reason {
                open(.paywall(reason: reason))
                viewModel.pendingPaywallReason = nil
            }
        }
        .onChange(of: viewModel.forecastGeneration) { _, generation in
            guard generation > 0 else { return }
            saveSnapshotIfWatched()
            // Ask for a rating only at a "happy moment" — a completed projection,
            // never at launch or after an error (forecastGeneration bumps only on
            // a successful run).
            if ReviewPrompt.registerSuccessAndShouldRequest() {
                requestReview()
            }
        }
        .sheet(isPresented: $showWatchlist) {
            WatchlistView(store: watchlist) { item in
                viewModel.load(item)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(entitlements: entitlements, scorecard: viewModel.scorecard, userCalls: viewModel.userCalls)
        }
        .sheet(isPresented: $showCallSheet) {
            CallSheet(symbol: viewModel.symbol) { direction, confidence, reason, horizonDays in
                viewModel.run(loggingCall: (direction, confidence, reason, horizonDays))
            }
        }
        .sheet(isPresented: $showPaperPortfolio) {
            NavigationStack {
                PaperPortfolioView(
                    store: paper,
                    entitlements: entitlements,
                    currentSymbol: viewModel.symbol,
                    currentAssetClass: viewModel.assetClass,
                    onUnlock: {
                        showPaperPortfolio = false
                        viewModel.pendingPaywallReason = "Pro charts your practice trades against buy-and-hold over time."
                    }
                )
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showPaperPortfolio = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showYourCalls) {
            NavigationStack {
                YourCallsView(
                    store: viewModel.userCalls,
                    entitlements: entitlements,
                    lessonsStartedAt: literacy.firstEngagedAt,
                    onUnlock: {
                        showYourCalls = false
                        viewModel.pendingPaywallReason = "Pro keeps your full call record and a shareable summary of how calibrated you've been."
                    }
                )
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showYourCalls = false }
                    }
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { !activeRecallBatch.isEmpty },
            set: { if !$0 { activeRecallBatch = [] } }
        )) {
            if !activeRecallBatch.isEmpty {
                RecallView(items: activeRecallBatch) {
                    for item in activeRecallBatch {
                        spacedRecall.recordReviewed(item.call, intervalIndex: item.intervalIndex)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(watchlist: watchlist) {
                hasOnboarded = true
                showOnboarding = false
            }
        }
        .task {
            await entitlements.loadProducts()
            // Once per launch, regardless of practice mode, so calls made before
            // practice was turned off still resolve and aren't left frozen.
            await refreshLiveData(force: true)
        }
        .onAppear {
            if !hasOnboarded { showOnboarding = true }
            if practiceEnabled {
                literacyQuestion = literacy.questionForThisWeek()
            }
        }
    }

    /// Keep the widget's/watch complication's track-record snapshot fresh on
    /// app open — same raw participation streak `BackgroundRefresh` writes in
    /// the background, so the two paths never disagree with each other.
    private func updateTrackRecordSnapshot() {
        let report = viewModel.userCalls.report
        SharedStorage.saveTrackRecord(TrackRecordSnapshot(
            streak: viewModel.userCalls.currentStreak,
            hitRate: report.overall.hitRate,
            decided: report.overall.decided,
            updatedAt: Date()
        ))
        WidgetCenter.shared.reloadTimelines(ofKind: TrackRecordWidgetKind.identifier)
    }

    /// Keep the portfolio widget's snapshot fresh on app open, right after
    /// `paper.revalueDue` has run so the value reflects the latest close.
    private func updatePortfolioSnapshot() {
        guard paper.hasStarted else { return }
        let comparison = paper.report.comparison
        SharedStorage.savePortfolioSnapshot(PortfolioSnapshot(
            value: paper.report.value,
            edge: comparison.edge,
            tradeCount: comparison.tradeCount,
            updatedAt: Date()
        ))
        WidgetCenter.shared.reloadTimelines(ofKind: PortfolioWidgetKind.identifier)
    }

    /// Single debounced entry point for "catch up on anything that may have gone
    /// stale while we were away" — resolve due calls, revalue the practice
    /// portfolio, refresh the widget snapshots. Every trigger (launch, return to
    /// foreground) routes through here instead of firing its own overlapping
    /// tasks; a call within `Self.liveRefreshInterval` of the last one no-ops.
    /// `force` (used once per launch) bypasses the interval so old unresolved
    /// calls are never left frozen, even when practice mode is off.
    private static let liveRefreshInterval: TimeInterval = 30
    private func refreshLiveData(force: Bool = false) async {
        guard force || Date().timeIntervalSince(lastLiveRefresh) > Self.liveRefreshInterval else { return }
        lastLiveRefresh = Date()
        await viewModel.resolveDueCalls()
        await paper.revalueDue(using: MarketDataService())
        updateTrackRecordSnapshot()
        updatePortfolioSnapshot()
    }

    /// Recompose the on-device notification content (morning read, weekly recap)
    /// so it never goes stale between opens — throttled so a rapid
    /// background/foreground flap can't reschedule repeatedly.
    private func rescheduleNotificationsIfDue() {
        let key = "hb.notifications.lastReschedule"
        let last = UserDefaults.standard.double(forKey: key)
        guard Date().timeIntervalSince1970 - last > 300 else { return }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: key)
        Task { await MorningDigest.rescheduleIfEnabled() }
        Task {
            await WeeklyRecap.rescheduleIfEnabled(
                calls: viewModel.userCalls.calls,
                streak: viewModel.userCalls.currentStreak,
                hasJournalActivity: !SharedStorage.snapshots().isEmpty
            )
        }
    }

    /// Keep the widget/watchlist snapshot fresh whenever a watched asset is projected.
    private func saveSnapshotIfWatched() {
        guard let item = viewModel.currentWatchItem,
              watchlist.contains(symbol: item.symbol, assetClass: item.assetClass),
              let series = viewModel.loadedSeries,
              let snapshot = WatchlistIntelligence.snapshot(for: item, series: series) else { return }
        watchlist.saveSnapshot(snapshot)
    }

    /// Switch to a recommended method (respecting Pro gating) and re-project.
    private func applyRecommendedModel(_ modelId: String) {
        guard let model = ForecastModel.model(id: modelId) else { return }
        if viewModel.selectModel(model) { viewModel.run() }
    }

    private var home: some View {
        ScrollView {
            VStack(spacing: 16) {
                header

                // Practice surface — opt-in only. The default home screen is
                // just: header → input → results → disclaimer.
                if practiceEnabled {
                    if !viewModel.userCalls.calls.isEmpty {
                        YourCallsCard(
                            report: viewModel.userCalls.report,
                            pendingCount: viewModel.userCalls.pending.count,
                            streak: displayStreak
                        ) { showYourCalls = true }
                        .transition(.opacity)
                    }

                    PaperPortfolioCard(
                        report: paper.report,
                        hasStarted: paper.hasStarted
                    ) { showPaperPortfolio = true }

                    if let insight = calibrationInsight {
                        CalibrationInsightCard(
                            insight: insight,
                            onTap: {
                                CalibrationInsightThrottle.recordShown(insight.signature)
                                showYourCalls = true
                            },
                            onDismiss: {
                                CalibrationInsightThrottle.recordShown(insight.signature)
                            }
                        )
                        .transition(.opacity)
                    }

                    if !dueRecallBatch.isEmpty {
                        RecallCard(
                            symbols: dueRecallBatch.map(\.call.symbol),
                            daysAgo: daysSince(dueRecallBatch.first?.call.resolvedAt),
                            onTap: { activeRecallBatch = dueRecallBatch },
                            onDismiss: {
                                for item in dueRecallBatch {
                                    spacedRecall.recordReviewed(item.call, intervalIndex: item.intervalIndex)
                                }
                            }
                        )
                        .transition(.opacity)
                    }

                    if let literacyQuestion {
                        LiteracyQuestionCard(
                            question: literacyQuestion,
                            onAnswered: { literacy.recordShown() },
                            onDismiss: {
                                literacy.recordShown()
                                self.literacyQuestion = nil
                            }
                        )
                        .transition(.opacity)
                    }
                }

                ForecastInputCard(
                    viewModel: viewModel,
                    symbolFocused: $symbolFocused,
                    dictation: dictation,
                    entitlements: entitlements,
                    onSelectModel: { open(.models) },
                    onForecast: {
                        symbolFocused = false
                        viewModel.run()
                    },
                    onCallIt: {
                        symbolFocused = false
                        showCallSheet = true
                    },
                    onStartDictation: {
                        symbolFocused = false
                        Task { await dictation.start() }
                    },
                    onUnlock: {
                        open(.paywall(reason: "Free includes horizons up to \(FreeTierLimits.maxHorizonDays) days. Pro stretches sketches to 90."))
                    },
                    practiceEnabled: practiceEnabled
                )

                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if let dictationError = dictation.errorMessage, !dictation.isActive {
                    ErrorBanner(message: dictationError)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // High-volatility is a genuine interrupt; "elevated" stays a
                // quiet factor inside the reliability meter, not its own card —
                // keeps the results stack from becoming an avalanche.
                if viewModel.hasResult, viewModel.sketchContext.regime == .high {
                    RegimeBanner(regime: .high)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if viewModel.isLoading {
                    ForecastLoadingCard()
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                } else if let forecast = viewModel.forecast, viewModel.hasResult {
                    ForecastResultsView(
                        viewModel: viewModel,
                        forecast: forecast,
                        entitlements: entitlements,
                        watchlist: watchlist,
                        onUnlock: { open(.paywall(reason: "Pro lets you compare every method’s path in one place.")) },
                        onCompareMethods: { open(.models) }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                } else {
                    ForecastEmptyState()
                        .transition(.opacity)
                }

                if viewModel.hasResult, let reliability = viewModel.sketchContext.reliability {
                    ReliabilityMeter(
                        score: reliability,
                        isPro: entitlements.isPro,
                        onUnlock: { open(.paywall(reason: "Pro shows exactly what's driving each sketch's reliability score.")) }
                    )
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                if viewModel.hasResult, let best = viewModel.sketchContext.bestModel, let series = viewModel.loadedSeries {
                    BestModelCard(
                        assetSymbol: series.symbol,
                        best: best,
                        breakdown: viewModel.sketchContext.modelBreakdown,
                        regimeBreakdown: viewModel.sketchContext.regimeBreakdown,
                        isPro: entitlements.isPro,
                        currentModelId: viewModel.model.strategy.rawValue,
                        onUse: { applyRecommendedModel($0) },
                        onUnlock: { open(.paywall(reason: "Pro recommends the method that has tracked this asset closest.")) }
                    )
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                if viewModel.hasResult, viewModel.sketchContext.bestModel == nil, viewModel.scorecard.records.count < 2 {
                    dayOneHint
                        .transition(.opacity)
                }

                if !viewModel.hasResult {
                    ForecastDisclaimer()
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
            .animation(reduceMotion ? nil : NavigationMotion.page, value: viewModel.hasResult)
            .animation(reduceMotion ? nil : NavigationMotion.page, value: viewModel.isLoading)
            .animation(reduceMotion ? nil : NavigationMotion.page, value: viewModel.forecastGeneration)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Hummingbird")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    symbolFocused = false
                    showWatchlist = true
                } label: {
                    Image(systemName: watchlist.items.isEmpty ? "star" : "star.fill")
                }
                .disabled(dictation.isActive)
                .accessibilityLabel("Watchlist")
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !entitlements.isPro {
                    Button {
                        open(.paywall(reason: nil))
                    } label: {
                        Text("Pro")
                            .font(.caption.weight(.bold))
                    }
                    .accessibilityLabel("Hummingbird Pro")
                }

                Button {
                    open(.indicators)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.selectedIndicatorCount > 0
                              ? "building.columns.fill"
                              : "building.columns")
                        if viewModel.selectedIndicatorCount > 0 {
                            Text("\(viewModel.selectedIndicatorCount)")
                                .font(.caption2.weight(.bold))
                                .monospacedDigit()
                        }
                    }
                }
                .disabled(dictation.isActive)
                .accessibilityLabel(
                    viewModel.selectedIndicatorCount > 0
                    ? "Economic indicators, \(viewModel.selectedIndicatorCount) selected"
                    : "Economic indicators"
                )

                Button {
                    symbolFocused = false
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .disabled(dictation.isActive)
                .accessibilityLabel("Settings")
            }
        }
        .task {
            viewModel.refreshIndicators()
        }
        .onChange(of: viewModel.hasResult) { _, hasResult in
            if hasResult, scenePhase == .active {
                viewModel.beginAutoRefresh()
            } else if !hasResult {
                viewModel.endAutoRefresh()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                if viewModel.hasResult { viewModel.beginAutoRefresh() }
                // Recurring catch-up only while practice mode is on; debounced
                // inside refreshLiveData so a foreground flap can't swarm it.
                if practiceEnabled {
                    Task { await refreshLiveData() }
                }
            case .background:
                viewModel.endAutoRefresh()
                rescheduleNotificationsIfDue()
                // Never leave the mic + audio engine running off-screen. Only on
                // .background (not .inactive) so the first-run permission prompt,
                // which briefly deactivates the scene, doesn't cancel listening.
                if dictation.isActive {
                    Task { await dictation.cancel() }
                }
            default:
                viewModel.endAutoRefresh()
            }
        }
        .sensoryFeedback(.success, trigger: viewModel.forecastGeneration)
        .sensoryFeedback(.impact(flexibility: .solid, intensity: 0.8), trigger: dictation.phase == .listening)
    }

    private func open(_ route: AppRoute) {
        guard !dictation.isActive else { return }
        symbolFocused = false
        NavigationMotion.push(&path, route)
    }

    private func confirmDictation() async {
        let spoken = await dictation.confirm()
        guard !spoken.isEmpty else { return }
        viewModel.symbol = viewModel.assetClass == .stock ? spoken.uppercased() : spoken.lowercased()
        viewModel.run()
    }

    private func updateMicCenter(anchor: Anchor<CGRect>?, geo: GeometryProxy) {
        guard let anchor else { return }
        let rect = geo[anchor]
        let next = CGPoint(x: rect.midX, y: rect.midY)
        if next != micCenter {
            micCenter = next
        }
    }

    /// The raw participation streak shown to the user — no perks, no grace days.
    private var displayStreak: Int {
        StreakEngine.currentStreak(viewModel.userCalls.calls)
    }

    /// The one past call, if any, due for a spaced-retrieval memory check
    /// right now — computed fresh each time the home screen appears rather
    /// than pushed via notification, matching the app's deference to the
    /// user (this is a learning aid, not something to nag someone into).
    private var dueRecallBatch: [(call: UserCall, intervalIndex: Int)] {
        SpacedRecallEngine.dueBatch(
            calls: viewModel.userCalls.calls,
            isReviewed: { spacedRecall.isReviewed($0, intervalIndex: $1) }
        )
    }

    /// A genuinely worth-knowing pattern in the user's own confidence-vs-
    /// accuracy record, if the numbers currently show one and this exact
    /// shape of finding hasn't already been shown.
    private var calibrationInsight: CalibrationInsight? {
        guard let insight = CalibrationInsightEngine.insight(from: viewModel.userCalls.report.byConfidence),
              insight.signature != CalibrationInsightThrottle.lastShownSignature()
        else { return nil }
        return insight
    }

    private func daysSince(_ date: Date?) -> Int {
        guard let date else { return 0 }
        return Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
    }

    /// First-run nudge: sets the honest expectation that the accuracy track
    /// record and method recommendations grow with use.
    private var dayOneHint: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            Text("Your track record starts now. As real prices catch up to your sketches, Hummingbird learns which method tracks each asset best — and shows you how reliable each sketch has been.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image("BrandMark")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.top, 4)
                .accessibilityHidden(true)

            Text("Hummingbird")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)

            Text("Public prices in, a simple path out")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ContentView()
}

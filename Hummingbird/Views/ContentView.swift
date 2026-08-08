import SwiftUI
import StoreKit

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
    @AppStorage("hummingbird.hasOnboarded") private var hasOnboarded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var symbolFocused: Bool
    @State private var path = NavigationPath()
    @State private var micCenter: CGPoint = .zero
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
            SettingsView(entitlements: entitlements, scorecard: viewModel.scorecard)
        }
        .sheet(isPresented: $showCallSheet) {
            CallSheet(symbol: viewModel.symbol, horizon: viewModel.horizon) { direction, confidence in
                viewModel.run(loggingCall: (direction, confidence))
            }
        }
        .sheet(isPresented: $showYourCalls) {
            NavigationStack {
                YourCallsView(store: viewModel.userCalls)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showYourCalls = false }
                        }
                    }
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView {
                hasOnboarded = true
                showOnboarding = false
            }
        }
        .task {
            await entitlements.loadProducts()
        }
        .onAppear {
            if !hasOnboarded { showOnboarding = true }
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
                    }
                )

                if !viewModel.userCalls.calls.isEmpty {
                    YourCallsCard(
                        report: viewModel.userCalls.report,
                        pendingCount: viewModel.userCalls.pending.count
                    ) { showYourCalls = true }
                    .transition(.opacity)
                }

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
            if phase == .active, viewModel.hasResult {
                viewModel.beginAutoRefresh()
            } else if phase != .active {
                viewModel.endAutoRefresh()
            }
            if phase == .background {
                // Refresh the morning-digest content so it never goes stale.
                Task { await MorningDigest.rescheduleIfEnabled() }
                // Never leave the mic + audio engine running off-screen. Only on
                // .background (not .inactive) so the first-run permission prompt,
                // which briefly deactivates the scene, doesn't cancel listening.
                if dictation.isActive {
                    Task { await dictation.cancel() }
                }
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

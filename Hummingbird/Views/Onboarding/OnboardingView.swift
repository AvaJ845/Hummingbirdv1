import SwiftUI

struct OnboardingView: View {
    @Bindable var watchlist: WatchlistStore
    var onFinish: () -> Void
    @State private var page = 0

    private struct Page: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let body: String
    }

    private let pages: [Page] = [
        Page(symbol: "hand.point.up.left.fill",
             title: "Call it before you peek",
             body: "Predict Higher or Lower — and how sure you are — before you see the sketch. Hummingbird keeps an honest score of your own calls over time."),
        Page(symbol: "trophy.fill",
             title: "See if you beat the methods",
             body: "Once your calls resolve against real prices, see how you did — and whether you're beating the app's own methods on the same calls. There's also a practice portfolio to test whether your trades beat simply buying and holding."),
        Page(symbol: "scribble.variable",
             title: "Sketches, not predictions",
             body: "It also draws simple paths from public prices and shows how wrong it's been. A record of the past — never advice, never a signal."),
        Page(symbol: "lock.shield.fill",
             title: "Private by design",
             body: "Everything runs on your device. No account, no tracking — just you and the math.")
    ]

    /// Informational pages plus one interactive setup step at the end.
    private var totalPages: Int { pages.count + 1 }
    private var isLastPage: Bool { page == totalPages - 1 }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, item in
                    pageView(item).tag(index)
                }
                setupPage.tag(pages.count)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < totalPages - 1 {
                    withAnimation { page += 1 }
                } else {
                    onFinish()
                }
            } label: {
                Text(page < totalPages - 1 ? "Continue" : "Get started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)

            Button("Skip", action: onFinish)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)
                .opacity(isLastPage ? 0 : 1)
                .disabled(isLastPage)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func pageView(_ item: Page) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: item.symbol)
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(Theme.brandGradient)
                .accessibilityHidden(true)
            VStack(spacing: 12) {
                Text(item.title)
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(item.body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
            Spacer()
        }
        .padding()
        .accessibilityElement(children: .combine)
    }

    // MARK: - Setup page

    private var setupPage: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56, weight: .semibold))
                        .foregroundStyle(Theme.brandGradient)
                        .accessibilityHidden(true)
                    Text("Get set up")
                        .font(.title.weight(.bold))
                    Text("Two optional things that make Hummingbird worth opening again tomorrow.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 24)

                QuickAddSection(watchlist: watchlist)
                DigestOptInSection()

                VStack(spacing: 6) {
                    Label("Try Siri", systemImage: "mic.fill")
                        .font(.subheadline.weight(.semibold))
                    Text("“Hey Siri, project Bitcoin in Hummingbird” — a spoken sketch, right from the Lock Screen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 4)

                Spacer(minLength: 12)
            }
            .padding(.bottom, 8)
        }
    }
}

/// A row of one-tap, validated adds for a few popular assets — so a new user
/// doesn't land on an empty watchlist after onboarding just taught them why
/// one is worth having.
private struct QuickAddSection: View {
    @Bindable var watchlist: WatchlistStore

    private struct Suggestion: Identifiable {
        let id: String
        let symbol: String
        let assetClass: AssetClass
        let title: String
        let systemImage: String
    }

    private enum AddState: Equatable {
        case idle, loading, added, failed
    }

    private let suggestions: [Suggestion] = [
        Suggestion(id: "aapl", symbol: "AAPL", assetClass: .stock, title: "Apple", systemImage: "applelogo"),
        Suggestion(id: "btc", symbol: "bitcoin", assetClass: .crypto, title: "Bitcoin", systemImage: "bitcoinsign.circle"),
        Suggestion(id: "nvda", symbol: "NVDA", assetClass: .stock, title: "Nvidia", systemImage: "cpu"),
        Suggestion(id: "eth", symbol: "ethereum", assetClass: .crypto, title: "Ethereum", systemImage: "diamond")
    ]

    @State private var states: [String: AddState] = [:]
    private let service = MarketDataService()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add one to your watchlist")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(suggestions) { suggestion in
                        chip(for: suggestion)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private func chip(for suggestion: Suggestion) -> some View {
        let state = states[suggestion.id] ?? .idle
        let alreadySaved = watchlist.contains(symbol: suggestion.symbol, assetClass: suggestion.assetClass)

        return Button {
            guard state != .loading, !alreadySaved else { return }
            add(suggestion)
        } label: {
            HStack(spacing: 6) {
                if state == .loading {
                    ProgressView().controlSize(.mini)
                } else {
                    Image(systemName: (alreadySaved || state == .added) ? "checkmark.circle.fill" : suggestion.systemImage)
                }
                Text(suggestion.title)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                (alreadySaved || state == .added) ? Theme.accent.opacity(0.16) : Color(.secondarySystemGroupedBackground),
                in: Capsule()
            )
            .foregroundStyle((alreadySaved || state == .added) ? Theme.accent : .primary)
        }
        .disabled(alreadySaved || state == .loading)
        .accessibilityLabel("\(suggestion.title)\(alreadySaved || state == .added ? ", added" : "")")
    }

    private func add(_ suggestion: Suggestion) {
        states[suggestion.id] = .loading
        Task {
            guard let series = try? await service.history(symbol: suggestion.symbol, assetClass: suggestion.assetClass),
                  series.isForecastable else {
                states[suggestion.id] = .failed
                return
            }
            watchlist.add(symbol: suggestion.symbol, assetClass: suggestion.assetClass, displayName: suggestion.title)
            let item = WatchlistItem(symbol: suggestion.symbol, assetClass: suggestion.assetClass, displayName: suggestion.title)
            if let snapshot = WatchlistIntelligence.snapshot(for: item, series: series) {
                watchlist.saveSnapshot(snapshot)
            }
            states[suggestion.id] = .added
        }
    }
}

/// Digest opt-in, mirroring `SettingsView`'s toggle so the choice made here
/// behaves identically to changing it later in Settings. Asking *when* the
/// user already checks the markets — rather than silently picking 8am — is
/// an implementation-intention cue (Gollwitzer, 1999): tying a new behavior
/// to a trigger that already exists in the user's day, not inventing one.
private struct DigestOptInSection: View {
    @AppStorage("hb.digest.enabled") private var digestEnabled = false
    @AppStorage("hb.digest.hour") private var digestHour = 8
    @AppStorage("hb.digest.minute") private var digestMinute = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: Binding(
                get: { digestEnabled },
                set: { digestEnabled = $0; reschedule() }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Morning read")
                        .font(.subheadline.weight(.semibold))
                    Text("A once-a-day on-device summary of your watchlist. Movement, not signals — never advice.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(Theme.accent)

            if digestEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("When do you usually check the markets?")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    DigestTriggerChips(hour: $digestHour, minute: $digestMinute, onSelect: reschedule)
                }
                .padding(.top, 2)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 24)
        .animation(.snappy(duration: 0.2), value: digestEnabled)
    }

    private func reschedule() {
        Task { @MainActor in
            guard digestEnabled else {
                NotificationService.cancelMorningDigest()
                return
            }
            var authorized = await NotificationService.isAuthorized()
            if !authorized { authorized = await NotificationService.requestAuthorization() }
            guard authorized else {
                digestEnabled = false
                return
            }
            await MorningDigest.rescheduleIfEnabled()
        }
    }
}

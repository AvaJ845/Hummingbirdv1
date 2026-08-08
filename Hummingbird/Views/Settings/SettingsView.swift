import SwiftUI

enum AppIconOption: String, CaseIterable, Identifiable {
    case classic
    case midnight
    case mono

    var id: String { rawValue }

    /// nil = primary (asset-catalog) icon.
    var alternateName: String? {
        switch self {
        case .classic: nil
        case .midnight: "Midnight"
        case .mono: "Mono"
        }
    }

    var title: String {
        switch self {
        case .classic: "Classic"
        case .midnight: "Midnight"
        case .mono: "Mono"
        }
    }

    /// Bundle image used for the little preview swatch.
    var previewImageName: String {
        switch self {
        case .classic: "BrandMark"
        case .midnight: "AltIcon-Midnight"
        case .mono: "AltIcon-Mono"
        }
    }
}

struct SettingsView: View {
    @Bindable var entitlements: EntitlementStore
    @Bindable var scorecard: SketchScorecardStore
    @Environment(\.dismiss) private var dismiss
    @State private var currentAlternate = UIApplication.shared.alternateIconName
    @State private var showClearConfirm = false
    @AppStorage("hb.digest.enabled") private var digestEnabled = false
    @AppStorage("hb.digest.hour") private var digestHour = 8
    @AppStorage("hb.digest.minute") private var digestMinute = 0
    @AppStorage("hb.liveActivity.enabled") private var liveActivityEnabled = false
    @AppStorage("hb.appearance") private var appearance: AppAppearance = .system

    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        PaywallView(entitlements: entitlements, scorecard: scorecard)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.title3)
                                .foregroundStyle(Theme.brandGradient)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Hummingbird Pro")
                                Text(entitlements.isPro ? "Active — manage or restore" : "Compare every method · restore")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if entitlements.isPro {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                    }
                    .accessibilityLabel(entitlements.isPro ? "Hummingbird Pro, active" : "Hummingbird Pro")
                }

                Section {
                    Picker(selection: $appearance) {
                        ForEach(AppAppearance.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    } label: {
                        Label("Appearance", systemImage: "circle.lefthalf.filled")
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("System follows your iPhone's Light/Dark setting. Light or Dark override it just for Hummingbird.")
                }

                Section("App Icon") {
                    ForEach(AppIconOption.allCases) { option in
                        Button {
                            setIcon(option)
                        } label: {
                            HStack(spacing: 14) {
                                preview(for: option)
                                Text(option.title)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if currentAlternate == option.alternateName {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Theme.accent)
                                }
                            }
                        }
                        .accessibilityLabel("\(option.title) app icon\(currentAlternate == option.alternateName ? ", selected" : "")")
                    }
                }

                Section {
                    NavigationLink {
                        ScorecardView(scorecard: scorecard)
                    } label: {
                        Label("Track record", systemImage: "checkmark.seal")
                    }
                    Picker(selection: $scorecard.retentionDays) {
                        Text("Keep all").tag(Int?.none)
                        Text("After 90 days").tag(Int?.some(90))
                        Text("After 30 days").tag(Int?.some(30))
                    } label: {
                        Label("Auto-clear history", systemImage: "clock.arrow.circlepath")
                    }
                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        Label("Clear sketch history now", systemImage: "trash")
                    }
                    .disabled(scorecard.records.isEmpty)
                } header: {
                    Text("Sketch history")
                } footer: {
                    Text("Your track record is stored only on this device. Clear it any time, or have Hummingbird auto-clear older sketches.")
                }

                Section {
                    Toggle("Morning read", isOn: Binding(
                        get: { digestEnabled },
                        set: { digestEnabled = $0; rescheduleDigest() }
                    ))
                    if digestEnabled {
                        DatePicker("Time", selection: digestTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Morning read")
                } footer: {
                    Text("A once-a-day on-device summary of recent movement across your watchlist. Movement, not signals — never advice.")
                }

                Section {
                    Toggle("Track on Lock Screen", isOn: Binding(
                        get: { liveActivityEnabled },
                        set: { liveActivityEnabled = $0; if !$0 { SketchLiveActivityManager.endAll() } }
                    ))
                } header: {
                    Text("Live Activity")
                } footer: {
                    Text("When on, a “Track” button appears on a sketch so you can pin its live price and projected path to the Lock Screen and Dynamic Island. Educational sketch — never advice.")
                }

                #if DEBUG
                Section {
                    Toggle("Unlock Pro (testing)", isOn: Binding(
                        get: { entitlements.debugUnlocked },
                        set: { entitlements.setDebugUnlocked($0) }
                    ))
                } header: {
                    Text("Developer")
                } footer: {
                    Text("Testing only — unlocks all Pro models and features on this dev build. Compiled out of the App Store build.")
                }
                #endif

                Section {
                    LabeledContent("Version", value: version)
                } footer: {
                    Text("Hummingbird runs entirely on your device. Educational projections only — not financial advice.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Clear all sketch history?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Clear history", role: .destructive) { scorecard.clearAll() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your on-device track record. It can't be undone.")
            }
        }
    }

    @ViewBuilder private func preview(for option: AppIconOption) -> some View {
        Group {
            if let ui = UIImage(named: option.previewImageName) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                Image("BrandMark").resizable().scaledToFill()
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.quaternary))
        .accessibilityHidden(true)
    }

    private func setIcon(_ option: AppIconOption) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        UIApplication.shared.setAlternateIconName(option.alternateName) { _ in
            currentAlternate = UIApplication.shared.alternateIconName
        }
    }

    private var digestTime: Binding<Date> {
        Binding(
            get: { Calendar.current.date(from: DateComponents(hour: digestHour, minute: digestMinute)) ?? Date() },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                digestHour = comps.hour ?? 8
                digestMinute = comps.minute ?? 0
                rescheduleDigest()
            }
        )
    }

    /// (Re)schedule or cancel the daily digest, composing content from the
    /// latest local snapshots. Requests permission the first time it's enabled.
    private func rescheduleDigest() {
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

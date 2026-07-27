import SwiftUI

struct ForecastInputCard: View {
    @Bindable var viewModel: ForecastViewModel
    @FocusState.Binding var symbolFocused: Bool
    let dictation: DictationController
    let entitlements: EntitlementStore
    let onSelectModel: () -> Void
    let onForecast: () -> Void
    let onStartDictation: () -> Void
    let onUnlock: () -> Void

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                assetPicker
                symbolField
                horizonSlider
                modelRow
                forecastButton
            }
        }
    }

    private var assetPicker: some View {
        Picker("Asset type", selection: $viewModel.assetClass) {
            ForEach(AssetClass.allCases) { klass in
                Label(klass.rawValue, systemImage: klass.systemImage)
                    .tag(klass)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Asset type")
    }

    private var symbolField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField(viewModel.assetClass.placeholder, text: $viewModel.symbol)
                    .textInputAutocapitalization(viewModel.assetClass == .stock ? .characters : .never)
                    .autocorrectionDisabled()
                    .focused($symbolFocused)
                    .submitLabel(.go)
                    .onSubmit(onForecast)

                Button(action: onStartDictation) {
                    Image(systemName: dictation.isActive ? "mic.fill" : "mic")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(dictation.isActive ? Theme.accent : .secondary)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color(.tertiarySystemFill))
                        )
                        .anchorPreference(key: MicAnchorKey.self, value: .bounds) { $0 }
                        .symbolEffect(.bounce, value: dictation.phase == .listening)
                }
                .buttonStyle(.plain)
                .disabled(dictation.isActive)
                .accessibilityLabel("Dictate symbol")
                .accessibilityHint("Expands dictation from the microphone")
            }
            .padding(.leading, 12)
            .padding(.trailing, 6)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.tertiarySystemGroupedBackground))
            )

            Text(viewModel.assetClass.hint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }

    private var horizonSlider: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Stacks to two lines when the label + value can't fit on one (large text).
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    horizonTitle
                    Spacer()
                    horizonValue
                    horizonProBadge
                }
                VStack(alignment: .leading, spacing: 4) {
                    horizonTitle
                    HStack(spacing: 8) {
                        horizonValue
                        horizonProBadge
                    }
                }
            }

            Slider(
                value: Binding(
                    get: { Double(viewModel.horizon) },
                    set: { viewModel.horizon = Int($0.rounded()) }
                ),
                in: 7...Double(viewModel.maxHorizonAllowed),
                step: 1
            )
            .tint(Theme.accent)
            .accessibilityLabel("Projection horizon")
            .accessibilityValue("\(viewModel.horizon) days")

            if !entitlements.isPro {
                Text("Free up to \(FreeTierLimits.maxHorizonDays) days. Pro stretches to 90 — same honesty, wider window.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder private var horizonTitle: some View {
        Text("Projection horizon")
            .font(.subheadline.weight(.medium))
    }

    @ViewBuilder private var horizonValue: some View {
        Text("\(viewModel.horizon) days")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.accent)
            .contentTransition(.numericText())
            .accessibilityHidden(true)
    }

    @ViewBuilder private var horizonProBadge: some View {
        if !entitlements.isPro {
            Button(action: onUnlock) {
                ProBadge()
            }
            .buttonStyle(.plain)
        }
    }

    private var modelRow: some View {
        Button(action: onSelectModel) {
            HStack {
                Image(systemName: viewModel.model.systemImage)
                    .foregroundStyle(Theme.brandGradient)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(viewModel.model.name)
                            .font(.subheadline.weight(.semibold))
                        if viewModel.model.requiresPro {
                            ProBadge()
                        }
                    }
                    Text(viewModel.model.familyLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.tertiarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Method: \(viewModel.model.name), \(viewModel.model.familyLabel)")
        .accessibilityHint("Opens method picker")
    }

    private var forecastButton: some View {
        Button(action: onForecast) {
            Text(viewModel.isLoading ? "Projecting…" : "Run projection")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.accent)
        .disabled(viewModel.isLoading || dictation.isActive)
        .accessibilityHint("Fetches history and runs the selected statistical model on device")
    }
}

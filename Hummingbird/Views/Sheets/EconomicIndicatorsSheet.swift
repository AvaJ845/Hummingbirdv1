import SwiftUI

struct EconomicIndicatorsSheet: View {
    @Bindable var viewModel: ForecastViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                if viewModel.isLoadingIndicators, viewModel.indicatorSnapshots.isEmpty {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Loading daily rate feeds…")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                } else if viewModel.indicatorSnapshots.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Couldn’t load rate what-ifs")
                            .font(.headline)
                        Text("Yahoo daily yields need a connection. Pull to refresh or tap below.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button {
                            viewModel.refreshIndicators()
                        } label: {
                            Label("Try again", systemImage: "arrow.clockwise")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                        .disabled(viewModel.isLoadingIndicators)
                    }
                    .padding(.vertical, 8)
                } else {
                    ForEach(viewModel.indicatorSnapshots) { snapshot in
                        indicatorRow(snapshot)
                    }
                }
            } header: {
                Text(viewModel.easyMode ? "Optional rate what-ifs" : "Select rate nudges")
            } footer: {
                Text("Live Yahoo daily rates only (^IRX, ^TNX). Optional context for your sketch — not a macro model.")
            }

            if viewModel.activeMacro.isActive {
                Section(viewModel.easyMode ? "What-if preview" : "Scenario nudge preview") {
                    HStack {
                        Text(viewModel.easyMode ? "Mood shift" : "Horizon nudge")
                        Spacer()
                        Text(viewModel.activeMacro.displayBias)
                            .foregroundStyle(Theme.changeColor(viewModel.activeMacro.horizonBias))
                            .fontWeight(.semibold)
                    }
                    if viewModel.easyMode {
                        Text(RetailExplainer.scenarioNudgePlain(viewModel.activeMacro, horizon: viewModel.horizon))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.activeMacro.contributions) { contribution in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(contribution.name)
                                    Spacer()
                                    Text(contribution.bias.asSignedPercent())
                                        .foregroundStyle(Theme.changeColor(contribution.bias))
                                        .font(.subheadline.monospacedDigit())
                                }
                                Text(contribution.rationale)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .readableContentWidth()
        .navigationTitle("Rate what-ifs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    Button("Clear") {
                        withAnimation(NavigationMotion.page) {
                            viewModel.selectedIndicatorIDs = []
                        }
                    }
                    .disabled(viewModel.selectedIndicatorIDs.isEmpty)

                    Button {
                        viewModel.refreshIndicators()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoadingIndicators)
                    .accessibilityLabel("Refresh rates")

                    Button("Done") {
                        NavigationMotion.pop(dismiss)
                    }
                }
            }
        }
        .overlay {
            if viewModel.isLoadingIndicators {
                ProgressView()
                    .padding(12)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
        .task {
            if viewModel.indicatorSnapshots.isEmpty {
                viewModel.refreshIndicators()
            }
        }
    }

    private func indicatorRow(_ snapshot: EconomicSnapshot) -> some View {
        let selected = viewModel.selectedIndicatorIDs.contains(snapshot.kind.id)

        return Button {
            withAnimation(NavigationMotion.page) {
                _ = viewModel.toggleIndicator(snapshot.kind.id)
            }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Theme.accent : .secondary)
                    .frame(width: 30)
                    .symbolEffect(.bounce, value: selected)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(snapshot.kind.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(snapshot.kind.cadence)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.14), in: Capsule())
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 8)
                        Text(snapshot.displayValue)
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(Theme.accent)
                    }
                    Text(snapshot.kind.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Text(snapshot.asOfLabel)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        if let change = snapshot.displayChange {
                            Text(change)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.changeColor(snapshot.change))
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: snapshot, selected: selected))
    }

    private func accessibilityLabel(for snapshot: EconomicSnapshot, selected: Bool) -> String {
        var parts = [
            snapshot.kind.name,
            snapshot.kind.cadence,
            snapshot.displayValue,
            selected ? "Selected" : "Not selected",
            snapshot.asOfLabel
        ]
        if let change = snapshot.displayChange {
            parts.append("Change \(change)")
        }
        return parts.joined(separator: ". ")
    }
}

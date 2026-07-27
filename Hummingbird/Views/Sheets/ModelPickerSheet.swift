import SwiftUI

struct ModelPickerSheet: View {
    @Bindable var viewModel: ForecastViewModel
    let entitlements: EntitlementStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                Text("Simple math on the same public price history — pick one to sketch a path.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }

            Section {
                ForEach(ForecastModel.all) { model in
                    Button {
                        guard model.status.isAvailable else { return }
                        if viewModel.selectModel(model) {
                            NavigationMotion.pop(dismiss)
                        }
                    } label: {
                        row(for: model)
                    }
                    .disabled(!model.status.isAvailable)
                    .accessibilityLabel(accessibilityLabel(for: model))
                }
            } footer: {
                Text("Free: Drift, Trend + weekday, Straight trend, Holt. Pro: compare every method (Momentum, Mean reversion, Blend) plus longer horizons.")
            }

            if !viewModel.modelPreviews.isEmpty {
                Section {
                    ForEach(viewModel.modelPreviews) { preview in
                        Button {
                            if viewModel.selectModel(preview.model) {
                                NavigationMotion.pop(dismiss)
                            }
                        } label: {
                            previewRow(preview)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(viewModel.usingSampleData
                          ? "Do they agree? · sample · \(viewModel.horizon)d"
                          : "Do they agree? · \(viewModel.horizon)d")
                } footer: {
                    Text("Same history, different methods. Tap one to view its path.")
                }
            }
        }
        .navigationTitle("Methods")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    NavigationMotion.pop(dismiss)
                }
            }
        }
    }

    @ViewBuilder
    private func row(for model: ForecastModel) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: model.systemImage)
                .font(.title2)
                .foregroundStyle(Theme.brandGradient)
                .frame(width: 34)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(model.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if model.requiresPro {
                        ProBadge()
                    }
                    if model.id == viewModel.model.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.accent)
                            .accessibilityLabel("Selected")
                    }
                }
                Text(viewModel.easyMode ? model.plainEnglish : model.methodSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                // Two signals max: family + beta (avoid badge salad).
                HStack(spacing: 8) {
                    Text(model.familyLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if model.status == .beta {
                        StatusBadge(status: .beta)
                    }
                    if !viewModel.easyMode {
                        Text("Nudge ×\(String(format: "%.1f", model.macroSensitivity))")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(model.status.isAvailable ? 1 : 0.55)
    }

    private func previewRow(_ preview: ModelForecastPreview) -> some View {
        HStack {
            Image(systemName: preview.model.systemImage)
                .foregroundStyle(Theme.brandGradient)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(preview.model.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if preview.model.requiresPro {
                        ProBadge()
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(preview.targetPrice.asCurrency())
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.primary)
                Text(preview.expectedChange.asSignedPercent())
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.changeColor(preview.expectedChange))
            }
            if preview.model.id == viewModel.model.id {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(preview.model.name), projected \(preview.targetPrice.asCurrency()), \(preview.expectedChange.asSignedPercent())"
        )
    }

    private func accessibilityLabel(for model: ForecastModel) -> String {
        var parts = [model.name, model.plainEnglish, model.familyLabel]
        if model.status == .beta { parts.append("Beta") }
        if model.requiresPro { parts.append("Pro") }
        if model.id == viewModel.model.id { parts.append("Selected") }
        if !model.status.isAvailable { parts.append("Unavailable") }
        if let preview = viewModel.preview(for: model) {
            parts.append("Projected \(preview.targetPrice.asCurrency())")
            parts.append(preview.expectedChange.asSignedPercent())
        }
        return parts.joined(separator: ". ")
    }
}

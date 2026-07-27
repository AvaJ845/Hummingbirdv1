import SwiftUI

struct ModelPickerSheet: View {
    @Binding var selection: ForecastModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(ForecastModel.all) { model in
                        Button {
                            guard model.status.isAvailable else { return }
                            selection = model
                            dismiss()
                        } label: {
                            row(for: model)
                        }
                        .disabled(!model.status.isAvailable)
                    }
                } footer: {
                    Text("Models run entirely on your device. Forecasts are statistical estimates, not financial advice.")
                }
            }
            .navigationTitle("Forecast Models")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    @ViewBuilder
    private func row(for model: ForecastModel) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: model.systemImage)
                .font(.title2)
                .foregroundStyle(Theme.brandGradient)
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(model.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if model.id == selection.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.accent)
                    }
                }
                Text(model.tagline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    ConfidenceBadge(confidence: model.confidence)
                    StatusBadge(status: model.status)
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(model.status.isAvailable ? 1 : 0.55)
    }
}

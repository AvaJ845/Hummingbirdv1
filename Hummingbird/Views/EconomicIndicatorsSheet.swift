import SwiftUI

struct EconomicIndicatorsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(EconomicIndicator.all) { indicator in
                        HStack(spacing: 14) {
                            Image(systemName: indicator.systemImage)
                                .font(.title3)
                                .foregroundStyle(Theme.brandGradient)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(indicator.name).font(.headline)
                                Text(indicator.detail)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Macro context")
                } footer: {
                    Text("These indicators shape the backdrop for asset prices. Hummingbird surfaces them as context alongside each forecast. Source: Federal Reserve Economic Data (FRED).")
                }
            }
            .navigationTitle("Economic Indicators")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

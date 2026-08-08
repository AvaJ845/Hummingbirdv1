import SwiftUI

/// Predict-first: the user commits a direction + confidence *before* the sketch
/// reveals, so the app scores their own judgment. A record of their call — never
/// advice, never a promise.
struct CallSheet: View {
    let symbol: String
    let horizon: Int
    let onCommit: (CallDirection, CallConfidence) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var direction: CallDirection?
    @State private var confidence: CallConfidence = .fairlySure

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 8) {
                        Text("Call it")
                            .font(.largeTitle.weight(.bold))
                        Text("Before you see the sketch — which way do you think \(symbol.uppercased()) goes over the next \(horizon) days?")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 8)

                    HStack(spacing: 12) {
                        directionButton(.higher, "Higher", "arrow.up.right")
                        directionButton(.lower, "Lower", "arrow.down.right")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("How sure are you?").font(.subheadline.weight(.semibold))
                        Picker("How sure are you?", selection: $confidence) {
                            ForEach(CallConfidence.allCases) { level in
                                Text(level.title).tag(level)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Text("A record of your own call, logged before the sketch. Being right before doesn't mean you'll be right again — never advice.")
                        .font(.caption2).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        guard let direction else { return }
                        onCommit(direction, confidence)
                        dismiss()
                    } label: {
                        Text("Lock in call · see the sketch")
                            .font(.headline).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .disabled(direction == nil)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func directionButton(_ dir: CallDirection, _ label: String, _ icon: String) -> some View {
        let selected = direction == dir
        let tint = dir == .higher ? Theme.up : Theme.down
        return Button {
            direction = dir
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.title)
                Text(label).font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(selected ? tint.opacity(0.16) : Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selected ? tint : .clear, lineWidth: 2)
            )
            .foregroundStyle(selected ? tint : .primary)
        }
        .accessibilityLabel("\(label)\(selected ? ", selected" : "")")
    }
}

import SwiftUI

/// Predict-first: the user commits a direction + confidence *before* the sketch
/// reveals, so the app scores their own judgment. A record of their call — never
/// advice, never a promise.
struct CallSheet: View {
    let symbol: String
    let onCommit: (CallDirection, CallConfidence, CallReason?, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var direction: CallDirection?
    @State private var confidence: CallConfidence = .fairlySure
    @State private var reason: CallReason?
    /// A short window keeps the loop tight — independent of the sketch horizon.
    @State private var callHorizon = 7

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 8) {
                        Text("Call it")
                            .font(.largeTitle.weight(.bold))
                        Text("Before you see the sketch — which way do you think \(symbol.uppercased()) goes?")
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
                        Text("By when?").font(.subheadline.weight(.semibold))
                        Picker("By when?", selection: $callHorizon) {
                            Text("3 days").tag(3)
                            Text("1 week").tag(7)
                            Text("2 weeks").tag(14)
                        }
                        .pickerStyle(.segmented)
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

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("What's driving this call?").font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("Optional").font(.caption).foregroundStyle(.tertiary)
                        }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                            ForEach(CallReason.allCases) { level in
                                reasonChip(level)
                            }
                        }
                    }

                    Text("A record of your own call, logged before the sketch. Being right before doesn't mean you'll be right again — never advice.")
                        .font(.footnote).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        guard let direction else { return }
                        onCommit(direction, confidence, reason, callHorizon)
                        dismiss()
                    } label: {
                        Text("Log the call · see the sketch")
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

    private func reasonChip(_ value: CallReason) -> some View {
        let selected = reason == value
        return Button {
            reason = selected ? nil : value
        } label: {
            Text(value.title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10).padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(selected ? Theme.accent.opacity(0.16) : Color(.secondarySystemGroupedBackground),
                            in: Capsule())
                .overlay(Capsule().strokeBorder(selected ? Theme.accent : .clear, lineWidth: 1.5))
                .foregroundStyle(selected ? Theme.accent : .primary)
        }
        .accessibilityLabel("\(value.title)\(selected ? ", selected" : "")")
    }
}

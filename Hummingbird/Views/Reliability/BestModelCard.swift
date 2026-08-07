import SwiftUI

/// Surfaces the method that has actually tracked *this* asset closest, from the
/// on-device Scorecard. The recommendation + one-tap switch + full breakdown are
/// a Pro depth feature; free users see an honest teaser.
struct BestModelCard: View {
    let assetSymbol: String
    let best: ModelPerformance
    let breakdown: [ModelPerformance]
    let isPro: Bool
    let currentModelId: String
    var onUse: (String) -> Void = { _ in }
    var onUnlock: () -> Void = {}

    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if isPro {
                proBody
            } else {
                teaser
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "trophy")
                .foregroundStyle(Theme.accent)
            Text("Best for \(assetSymbol.uppercased())")
                .font(.subheadline.weight(.semibold))
            Spacer()
        }
    }

    private var proBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(best.modelName).font(.body.weight(.semibold))
                    Text("Tracked closest — \(errorText(best.medianError)) typical error over \(best.resolvedCount) scored")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Best for \(assetSymbol): \(best.modelName), tracked closest with \(errorText(best.medianError)) typical error over \(best.resolvedCount) scored sketches")

            if best.modelId != currentModelId {
                Button {
                    onUse(best.modelId)
                } label: {
                    Text("Use \(best.modelName)")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Theme.accent.opacity(0.15), in: Capsule())
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
            } else {
                Label("You're using it", systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(Theme.accent)
            }

            if breakdown.count > 1 {
                DisclosureGroup(isExpanded: $expanded) {
                    VStack(spacing: 6) {
                        ForEach(breakdown) { perf in
                            HStack {
                                Text(perf.modelName).font(.caption)
                                Spacer()
                                Text(errorText(perf.medianError)).font(.caption.weight(.semibold))
                                    .monospacedDigit().foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.top, 6)
                } label: {
                    Text("All methods, ranked").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
            }

            Text("A record of the past, not a promise. Same public data — Pro is convenience, not better foresight.")
                .font(.caption2).foregroundStyle(.tertiary)
        }
    }

    private var teaser: some View {
        Button(action: onUnlock) {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill").font(.caption)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Pro finds the method that's tracked \(assetSymbol.uppercased()) closest")
                        .font(.caption.weight(.medium)).foregroundStyle(.primary)
                    Text("Personalised from your own track record").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func errorText(_ error: Double) -> String {
        String(format: "%.1f%%", error * 100)
    }
}

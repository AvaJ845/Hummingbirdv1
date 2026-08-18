import SwiftUI

/// The best-tracking method for this asset, from the on-device Scorecard. In
/// the Option-A hierarchy this is a collapsible "insight": glanceable header,
/// with the one-tap switch + full breakdown tucked behind a tap. Pro depth;
/// free users see an honest teaser.
struct BestModelCard: View {
    let assetSymbol: String
    let best: ModelPerformance
    let breakdown: [ModelPerformance]
    var regimeBreakdown: [RegimePerformance] = []
    let isPro: Bool
    let currentModelId: String
    var onUse: (String) -> Void = { _ in }
    var onUnlock: () -> Void = {}

    @State private var expanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isPro {
                Button {
                    withAnimation(reduceMotion ? nil : .snappy) { expanded.toggle() }
                } label: {
                    proHeader
                }
                .buttonStyle(.plain)
                if expanded { proDetail }
            } else {
                teaser
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var proHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "trophy").foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text("Best for \(assetSymbol.uppercased())").font(.subheadline.weight(.semibold))
                Text("\(best.modelName) tracked closest").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 6)
            Image(systemName: "chevron.down")
                .font(.caption2).foregroundStyle(.secondary)
                .rotationEffect(.degrees(expanded ? 180 : 0))
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Best for \(assetSymbol): \(best.modelName) tracked closest")
        .accessibilityHint(expanded ? "Hide details" : "Show details and switch method")
    }

    private var proDetail: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(errorText(best.medianError)) typical error over \(best.resolvedCount) scored sketches")
                .font(.caption).foregroundStyle(.secondary)

            if best.modelId != currentModelId {
                Button { onUse(best.modelId) } label: {
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
                .padding(.top, 2)
            }

            if !regimeBreakdown.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("By market conditions")
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(regimeBreakdown) { perf in
                        HStack {
                            Text(perf.regime.shortLabel).font(.caption)
                            Spacer()
                            Text(perf.best.modelName).font(.caption.weight(.semibold))
                            Text(errorText(perf.best.medianError)).font(.caption2)
                                .monospacedDigit().foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(perf.regime.shortLabel) conditions: \(perf.best.modelName) tracked closest, \(errorText(perf.best.medianError)) typical error")
                    }
                }
                .padding(.top, 2)
            }

            Text("A record of the past, not a promise. Same public data — Pro is convenience, not better foresight.")
                .font(.caption2).foregroundStyle(.tertiary)
        }
    }

    private var teaser: some View {
        Button(action: onUnlock) {
            HStack(spacing: 10) {
                Image(systemName: "trophy").foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Pro finds the method that's tracked \(assetSymbol.uppercased()) closest")
                        .font(.caption.weight(.medium)).foregroundStyle(.primary)
                    Text("Personalised from your own track record").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func errorText(_ error: Double) -> String {
        String(format: "%.1f%%", error * 100)
    }
}

import SwiftUI

/// Side-by-side comparison of each method’s sketch for the same history.
struct ModelDisagreementCard: View {
    let previews: [ModelForecastPreview]
    let activeModelID: String
    let isPro: Bool
    var easyMode: Bool = true
    let onSelect: (ForecastModel) -> Void
    let onUnlock: () -> Void

    private var changes: [Double] {
        visiblePreviews.map(\.expectedChange)
    }

    private var spread: Double? {
        guard let min = changes.min(), let max = changes.max(), changes.count > 1 else { return nil }
        return max - min
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(
                        easyMode ? "Do the methods agree?" : "Method comparison",
                        systemImage: "arrow.left.arrow.right"
                    )
                    .font(.headline.weight(.semibold))
                    Spacer()
                    if let spread {
                        Text("Differ by \(spread.asSignedPercent())")
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                Text(
                    easyMode
                    ? RetailExplainer.disagreementPlain(spread)
                    : "Same public history, different simple methods — tap one to view its path."
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                ForEach(visiblePreviews) { preview in
                    Button {
                        onSelect(preview.model)
                    } label: {
                        HStack {
                            Image(systemName: preview.model.systemImage)
                                .foregroundStyle(Theme.brandGradient)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(preview.model.name)
                                        .font(.subheadline.weight(preview.model.id == activeModelID ? .semibold : .regular))
                                        .foregroundStyle(.primary)
                                    if preview.model.requiresPro && !isPro {
                                        ProBadge()
                                    }
                                }
                                if easyMode {
                                    Text(preview.model.familyLabel)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                } else if let recentError = preview.recentError {
                                    Text("Recent error \(recentError.asPercent())")
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                        .accessibilityLabel("Recent backtest error \(recentError.asPercent())")
                                }
                            }
                            Spacer()
                            Text(preview.expectedChange.asSignedPercent())
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(Theme.changeColor(preview.expectedChange))
                            if !easyMode {
                                Text(preview.targetPrice.asCurrency())
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 72, alignment: .trailing)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(preview.model.requiresPro && !isPro)
                }

                if !isPro {
                    Button(action: onUnlock) {
                        Label(
                            easyMode ? "See all methods (Pro)" : "Unlock every method to compare",
                            systemImage: "lock.open"
                        )
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var visiblePreviews: [ModelForecastPreview] {
        if isPro { return previews }
        return previews.filter { !$0.model.requiresPro }
    }
}

struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Theme.accentAlt.opacity(0.18), in: Capsule())
            .foregroundStyle(Theme.accentAlt)
            .accessibilityLabel("Pro feature")
    }
}

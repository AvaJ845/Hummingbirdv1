import SwiftUI

struct ModelInsightCard: View {
    let model: ForecastModel
    let macro: MacroAdjustment
    var easyMode: Bool = true

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: model.systemImage)
                        .foregroundStyle(Theme.brandGradient)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.name)
                            .font(.subheadline.weight(.semibold))
                        Text(model.familyLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if model.status == .beta {
                        StatusBadge(status: .beta)
                    }
                }

                Text(easyMode ? model.plainEnglish : model.methodSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if model.strategy == .ensemble {
                    Text("Blend averages three methods into one smoother path. Still a sketch — try the others too.")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                if !easyMode {
                    HStack(spacing: 16) {
                        labeledValue(
                            title: "Scenario sensitivity",
                            value: "×\(String(format: "%.1f", model.macroSensitivity))"
                        )
                        if macro.isActive {
                            labeledValue(
                                title: "Applied nudge",
                                value: macro.displayBias,
                                color: Theme.changeColor(macro.horizonBias)
                            )
                        } else {
                            labeledValue(title: "Applied nudge", value: "None")
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(model.name). \(model.plainEnglish)")
    }

    private func labeledValue(title: String, value: String, color: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

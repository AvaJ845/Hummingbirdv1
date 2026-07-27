import SwiftUI

struct MacroImpactCard: View {
    let macro: MacroAdjustment
    let horizon: Int
    var easyMode: Bool = true

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(
                        easyMode ? "Economy what-if" : "Scenario nudge",
                        systemImage: "building.columns"
                    )
                    .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(macro.displayBias)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(Theme.changeColor(macro.horizonBias))
                }

                Group {
                    if easyMode {
                        Text(RetailExplainer.scenarioNudgePlain(macro, horizon: horizon))
                    } else {
                        Text("Selected series apply a capped scenario nudge of \(macro.displayBias) over \(horizon) days. Not an econometric beta estimate.")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if !easyMode {
                    ForEach(macro.contributions) { contribution in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(Theme.changeColor(contribution.bias))
                                .frame(width: 8, height: 8)
                                .padding(.top, 5)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(contribution.name)
                                        .font(.subheadline.weight(.medium))
                                    Spacer()
                                    Text(contribution.bias.asSignedPercent())
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(Theme.changeColor(contribution.bias))
                                }
                                Text(contribution.rationale)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Economy what-if \(macro.displayBias) over \(horizon) days")
    }
}

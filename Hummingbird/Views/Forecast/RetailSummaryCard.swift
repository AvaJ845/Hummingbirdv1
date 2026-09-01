import SwiftUI

/// Easy Mode summary: clear projection bottom line without stacking disclaimers.
struct RetailSummaryCard: View {
    let symbol: String
    let forecast: Forecast
    let disagreementSpread: Double?
    let horizon: Int
    let macro: MacroAdjustment

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("In plain English", systemImage: "text.bubble")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(forecast.model.name)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.accent.opacity(0.14), in: Capsule())
                        .foregroundStyle(Theme.accent)
                }

                Text(RetailExplainer.headline(symbol: symbol, forecast: forecast, horizon: horizon))
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                Text(
                    RetailExplainer.bottomLine(
                        symbol: symbol,
                        forecast: forecast,
                        disagreementSpread: disagreementSpread,
                        horizon: horizon
                    )
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 10) {
                    plainRow(title: "Possible range", value: RetailExplainer.bandCaption(for: forecast))
                    plainRow(title: "Compare methods", value: RetailExplainer.disagreementPlain(disagreementSpread))
                    if macro.isActive {
                        plainRow(title: "Rate context", value: RetailExplainer.scenarioNudgePlain(macro, horizon: horizon))
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func plainRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

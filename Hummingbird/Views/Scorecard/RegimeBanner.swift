import SwiftUI

/// A calm, honest heads-up shown above a sketch when the asset is unusually
/// volatile right now. Never alarmist — it widens the user's mental error bars.
struct RegimeBanner: View {
    let regime: VolatilityRegime

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: regime.symbol)
                .font(.title3)
                .foregroundStyle(regime.tint)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(regime.title)
                    .font(.subheadline.weight(.semibold))
                Text(regime.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(regime.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(regime.tint.opacity(0.25))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(regime.title). \(regime.message)")
    }
}

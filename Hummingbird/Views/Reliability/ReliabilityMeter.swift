import SwiftUI

/// Shows how much to trust a sketch, as a calibrated meter + plain-English
/// read. The meter and headline are free; the factor-by-factor breakdown is a
/// Pro depth feature.
struct ReliabilityMeter: View {
    let score: ReliabilityScore
    let isPro: Bool
    var onUnlock: () -> Void = {}

    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            meterBar
            Text(score.headline)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            breakdown
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Reliability \(score.value) out of 100. \(score.tier.title). \(score.headline)")
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: score.tier.symbol)
                .foregroundStyle(score.tier.color)
            Text("Reliability")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text("\(score.value)")
                .font(.title3.weight(.bold)).monospacedDigit()
                .foregroundStyle(score.tier.color)
            Text("/ 100")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var meterBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.tertiarySystemFill)).frame(height: 8)
                Capsule().fill(score.tier.color)
                    .frame(width: max(6, geo.size.width * CGFloat(score.value) / 100), height: 8)
                    .animation(.easeOut(duration: 0.5), value: score.value)
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var breakdown: some View {
        if isPro {
            DisclosureGroup(isExpanded: $expanded) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Baseline").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("50").font(.caption.weight(.semibold)).monospacedDigit().foregroundStyle(.secondary)
                    }
                    ForEach(score.factors) { factor in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(factor.name).font(.caption.weight(.medium))
                                Text(factor.detail).font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if factor.impact != 0 {
                                Text(factor.impact > 0 ? "+\(factor.impact)" : "\(factor.impact)")
                                    .font(.caption.weight(.semibold)).monospacedDigit()
                                    .foregroundStyle(factor.impact >= 0 ? Theme.up : Theme.down)
                            }
                        }
                    }
                    Text("Starts from a neutral 50, then adjusts for each factor.")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
                .padding(.top, 6)
            } label: {
                Text("Why this score")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        } else {
            Button(action: onUnlock) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text("See what's driving this score with Pro")
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption2)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
        }
    }
}

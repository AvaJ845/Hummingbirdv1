import SwiftUI

/// A thin, always-visible reliability strip that sits directly under the sketch
/// (Option A hierarchy). Collapsed it's one glanceable line — "Reliability 78 ·
/// Good · Why". Tap to reveal the meter, the plain-English read, and the
/// factor breakdown (Pro). Keeps the sketch the hero and the chrome minimal.
struct ReliabilityMeter: View {
    let score: ReliabilityScore
    let isPro: Bool
    var onUnlock: () -> Void = {}

    @State private var expanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            strip
            if expanded {
                expandedContent.padding(.top, 12)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var strip: some View {
        Button {
            withAnimation(reduceMotion ? nil : .snappy) { expanded.toggle() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: score.tier.symbol)
                    .foregroundStyle(score.tier.color)
                Text("Reliability \(score.value)")
                    .font(.subheadline.weight(.semibold))
                Text("· \(score.tier.title)")
                    .font(.subheadline)
                    .foregroundStyle(score.tier.color)
                Spacer(minLength: 6)
                Text(expanded ? "Hide" : "Why")
                    .font(.caption).foregroundStyle(.secondary)
                Image(systemName: "chevron.down")
                    .font(.caption2).foregroundStyle(.secondary)
                    .rotationEffect(.degrees(expanded ? 180 : 0))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Reliability \(score.value) out of 100, \(score.tier.title)")
        .accessibilityHint(expanded ? "Hide details" : "Show what's driving this score")
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            meterBar
            Text(score.headline)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            breakdown
        }
    }

    private var meterBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.tertiarySystemFill)).frame(height: 8)
                Capsule().fill(score.tier.color)
                    .frame(width: max(6, geo.size.width * CGFloat(score.value) / 100), height: 8)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.5), value: score.value)
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var breakdown: some View {
        if isPro {
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

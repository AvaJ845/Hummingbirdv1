import SwiftUI

struct ForecastEmptyState: View {
    var body: some View {
        Card {
            VStack(spacing: 10) {
                Image(systemName: "hand.point.up.left")
                    .font(.largeTitle)
                    .foregroundStyle(Theme.brandGradient)
                    .symbolEffect(.pulse, options: .repeating.speed(0.4))
                    .accessibilityHidden(true)
                Text("Pick a symbol, then call it")
                    .font(.headline)
                Text("Predict Higher or Lower before you see the sketch, and keep an honest score of your own calls. Or just show the sketch — up to you.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
        .accessibilityElement(children: .combine)
    }
}

struct ForecastLoadingCard: View {
    var body: some View {
        Card {
            HStack(spacing: 12) {
                ProgressView()
                Text("Fetching data & projecting…")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading projection")
    }
}

struct ForecastDisclaimer: View {
    var body: some View {
        Text("Hummingbird sketches a future path from public price history and simple models. Not financial advice.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .padding(.top, 8)
            .accessibilityLabel("Disclaimer: Not financial advice.")
    }
}

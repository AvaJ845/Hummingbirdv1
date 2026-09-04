import SwiftUI

struct ForecastEmptyState: View {
    var body: some View {
        Card {
            VStack(spacing: 10) {
                Image(systemName: "scribble.variable")
                    .font(.largeTitle)
                    .foregroundStyle(Theme.brandGradient)
                    .symbolEffect(.pulse, options: .repeating.speed(0.4),
                                  isActive: !ProcessInfo.processInfo.isLowPowerModeEnabled)
                    .accessibilityHidden(true)
                Text("Pick a symbol for a sketch")
                    .font(.headline)
                Text("Hummingbird draws a simple statistical sketch of where a stock or coin could drift, and shows how wrong past sketches have been.")
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
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.top, 8)
            .accessibilityLabel("Disclaimer: Not financial advice.")
    }
}

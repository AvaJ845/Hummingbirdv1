import SwiftUI

struct OnboardingView: View {
    var onFinish: () -> Void
    @State private var page = 0

    private struct Page: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let body: String
    }

    private let pages: [Page] = [
        Page(symbol: "hand.point.up.left.fill",
             title: "Call it before you peek",
             body: "Predict Higher or Lower — and how sure you are — before you see the sketch. Hummingbird keeps an honest score of your own calls over time."),
        Page(symbol: "trophy.fill",
             title: "See if you beat the methods",
             body: "Once your calls resolve against real prices, see how you did — and whether you're beating the app's own methods on the same calls."),
        Page(symbol: "scribble.variable",
             title: "Sketches, not predictions",
             body: "It also draws simple paths from public prices and shows how wrong it's been. A record of the past — never advice, never a signal."),
        Page(symbol: "lock.shield.fill",
             title: "Private by design",
             body: "Everything runs on your device. No account, no tracking — just you and the math.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, item in
                    pageView(item).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < pages.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    onFinish()
                }
            } label: {
                Text(page < pages.count - 1 ? "Continue" : "Get started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)

            Button("Skip", action: onFinish)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)
                .opacity(page < pages.count - 1 ? 1 : 0)
                .disabled(page == pages.count - 1)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func pageView(_ item: Page) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: item.symbol)
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(Theme.brandGradient)
                .accessibilityHidden(true)
            VStack(spacing: 12) {
                Text(item.title)
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(item.body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
            Spacer()
        }
        .padding()
        .accessibilityElement(children: .combine)
    }
}

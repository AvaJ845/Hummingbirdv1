import SwiftUI

/// An inline, optional self-explanation check on a genuinely non-obvious
/// driver of this sketch — gated to only the runs where there's real
/// inferential work to do (see `ExplainItEngine`). Answering, right or
/// wrong, is what deepens understanding (Chi, De Leeuw, Chiu & LaVancher,
/// 1994, "Eliciting Self-Explanations Improves Understanding"). Never
/// scored, ranked, or kept as a record — purely a moment to reason before
/// being told.
struct ExplainItCard: View {
    let prompt: ExplainItPrompt

    @State private var selectedAnswer: String?

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Label("Quick check", systemImage: "questionmark.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.brandGradient)

                Text(prompt.question)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)

                if let selectedAnswer {
                    reveal(selectedAnswer)
                } else {
                    options
                }
            }
        }
    }

    private var options: some View {
        VStack(spacing: 8) {
            ForEach(prompt.options, id: \.self) { option in
                Button {
                    withAnimation(.snappy(duration: 0.2)) { selectedAnswer = option }
                } label: {
                    Text(option)
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accentAlt)
            }
        }
    }

    @ViewBuilder private func reveal(_ answer: String) -> some View {
        let correct = prompt.isCorrect(answer)
        VStack(alignment: .leading, spacing: 8) {
            Label(correct ? "That's right" : "Not quite",
                  systemImage: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(correct ? Theme.up : .secondary)

            Text(prompt.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .transition(.opacity)
        .accessibilityElement(children: .combine)
    }
}

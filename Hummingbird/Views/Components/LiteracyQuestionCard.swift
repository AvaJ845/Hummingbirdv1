import SwiftUI

/// A once-a-week, optional financial-literacy multiple-choice question —
/// pure definitional trivia, never a prediction about any asset's
/// direction. Same testing-effect grounding as Spaced Recall, applied to
/// general literacy instead of the user's own calls (Roediger & Karpicke,
/// 2006, "Test-Enhanced Learning"; Cepeda, Pashler, Vul, Wixted & Rohrer,
/// 2006, on distributed practice). Dismissible and never nagged back —
/// declining is treated the same as answering.
struct LiteracyQuestionCard: View {
    let question: LiteracyQuestion
    let onAnswered: () -> Void
    let onDismiss: () -> Void

    @State private var selectedIndex: Int?

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("This week's question", systemImage: "graduationcap")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.brandGradient)
                    Spacer()
                    if selectedIndex == nil {
                        Button(action: onDismiss) {
                            Image(systemName: "xmark")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Dismiss")
                    }
                }

                Text(question.question)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)

                if let selectedIndex {
                    reveal(selectedIndex)
                } else {
                    options
                }
            }
        }
    }

    private var options: some View {
        VStack(spacing: 8) {
            ForEach(question.options.indices, id: \.self) { index in
                Button {
                    withAnimation(.snappy(duration: 0.2)) { selectedIndex = index }
                    onAnswered()
                } label: {
                    Text(question.options[index])
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accentAlt)
            }
        }
    }

    @ViewBuilder private func reveal(_ index: Int) -> some View {
        let correct = index == question.correctIndex
        VStack(alignment: .leading, spacing: 8) {
            Label(correct ? "That's right" : "Not quite",
                  systemImage: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(correct ? Theme.up : .secondary)

            Text(question.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .transition(.opacity)
        .accessibilityElement(children: .combine)
    }
}

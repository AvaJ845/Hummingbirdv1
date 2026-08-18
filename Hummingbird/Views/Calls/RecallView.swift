import SwiftUI

/// A predict-before-reveal memory check on one of the user's own past,
/// already-resolved calls — the retrieval-practice half of Spaced Recall.
/// Testing what you remember, then seeing the real answer, is what makes it
/// stick (Roediger & Karpicke, 2006, "Test-Enhanced Learning"). Purely
/// educational: nothing here is scored, ranked, or kept as a streak — the
/// self-assessment exists only to make the retrieval attempt real, the way
/// a flashcard app asks "did you know it?" before flipping the card.
struct RecallView: View {
    let call: UserCall
    let daysAgo: Int
    var onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selfAssessment: SelfAssessment?

    private enum SelfAssessment { case right, wrong, unsure }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header

                    if let selfAssessment {
                        reveal(selfAssessment)
                    } else {
                        recallPrompt
                    }
                }
                .padding()
                .padding(.top, 8)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onComplete()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "brain")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Theme.brandGradient)
                .accessibilityHidden(true)
            Text("Remember this call?")
                .font(.title2.weight(.bold))
            Text("\(daysAgo) days ago, you called \(call.symbol.uppercased()) \(call.direction.title.lowercased()) — \(call.confidence.title.lowercased()).")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var recallPrompt: some View {
        VStack(spacing: 14) {
            Text("Before we show you — do you remember if you were right?")
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                assessmentButton("I was right", .right)
                assessmentButton("I was wrong", .wrong)
                assessmentButton("Not sure", .unsure)
            }

            Text("Testing your memory like this, before looking, is what actually makes it stick. That's the point here — not a score.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func assessmentButton(_ title: String, _ value: SelfAssessment) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) { selfAssessment = value }
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .tint(Theme.accent)
    }

    @ViewBuilder private func reveal(_ assessment: SelfAssessment) -> some View {
        VStack(spacing: 14) {
            if let correct = call.wasCorrect {
                Label(correct ? "You were right" : "You were off",
                      systemImage: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(correct ? Theme.up : Theme.down)
            } else {
                Label("It landed flat", systemImage: "minus.circle.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            if let change = call.actualChange {
                Text("\(call.symbol.uppercased()) actually moved \(change.asSignedPercent()).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(feedbackText(for: assessment))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)

            Text("A record of the past — never advice.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
        .transition(.opacity)
    }

    private func feedbackText(for assessment: SelfAssessment) -> String {
        guard let correct = call.wasCorrect else {
            return "This one landed flat, so there was nothing to recall right or wrong."
        }
        switch (assessment, correct) {
        case (.right, true), (.wrong, false):
            return "Your memory matched the record — that's the retrieval practice working."
        case (.unsure, _):
            return "\u{201C}Not sure\u{201D} is an honest answer — recall fades, and that's exactly why spacing this out helps."
        default:
            return "Your memory didn't match the record this time — that's normal, and revisiting it now helps it stick better next time."
        }
    }
}

import SwiftUI

/// A predict-before-reveal memory check across one or more of the user's own
/// past, already-resolved calls — the retrieval-practice half of Spaced
/// Recall. Testing what you remember, then seeing the real answer, is what
/// makes it stick (Roediger & Karpicke, 2006, "Test-Enhanced Learning").
/// When there's more than one call due, they're stepped through in one
/// mixed session — interleaving different symbols, rather than reviewing
/// one repeatedly, is what strengthens retention (Rohrer & Taylor, 2007).
/// Purely educational: nothing here is scored, ranked, or kept as a streak —
/// self-assessment exists only to make the retrieval attempt real, the way a
/// flashcard app asks "did you know it?" before flipping the card.
struct RecallView: View {
    let items: [(call: UserCall, intervalIndex: Int)]
    var onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex = 0
    @State private var selfAssessment: SelfAssessment?

    private enum SelfAssessment { case right, wrong, unsure }

    private var current: UserCall { items[currentIndex].call }
    private var isLast: Bool { currentIndex == items.count - 1 }
    private var daysAgo: Int {
        guard let date = current.resolvedAt else { return 0 }
        return Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    if items.count > 1 {
                        Text("\(currentIndex + 1) of \(items.count)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

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
            Text("\(daysAgo) days ago, you called \(current.symbol.uppercased()) \(current.direction.title.lowercased()) — \(current.confidence.title.lowercased()).")
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
            if let correct = current.wasCorrect {
                Label(correct ? "You were right" : "You were off",
                      systemImage: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(correct ? Theme.up : Theme.down)
            } else {
                Label("It landed flat", systemImage: "minus.circle.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            if let change = current.actualChange {
                Text("\(current.symbol.uppercased()) actually moved \(change.asSignedPercent()).")
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

            if !isLast {
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        currentIndex += 1
                        selfAssessment = nil
                    }
                } label: {
                    Text("Next call")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .padding(.top, 8)
            }
        }
        .accessibilityElement(children: .combine)
        .transition(.opacity)
    }

    private func feedbackText(for assessment: SelfAssessment) -> String {
        guard let correct = current.wasCorrect else {
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

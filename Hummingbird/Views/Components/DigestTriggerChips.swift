import SwiftUI

/// Implementation-intention trigger chips for the morning digest — asking
/// *when* the user already checks the markets, rather than silently defaulting
/// to a fixed time. Gollwitzer (1999) and the Gollwitzer & Sheeran (2006)
/// meta-analysis: tying a new behavior to a trigger that already exists in the
/// user's day measurably beats an arbitrary one — a planning cue, not a reward.
struct DigestTriggerChips: View {
    @Binding var hour: Int
    @Binding var minute: Int
    var onSelect: () -> Void = {}

    private struct Trigger: Identifiable {
        let id = UUID()
        let title: String
        let hour: Int
    }

    private let triggers: [Trigger] = [
        Trigger(title: "Waking up", hour: 7),
        Trigger(title: "Morning coffee", hour: 8),
        Trigger(title: "Commute", hour: 9),
    ]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(triggers) { trigger in
                chip(trigger)
            }
        }
    }

    private func chip(_ trigger: Trigger) -> some View {
        let selected = hour == trigger.hour && minute == 0
        return Button {
            hour = trigger.hour
            minute = 0
            onSelect()
        } label: {
            Text(trigger.title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(selected ? Theme.accent.opacity(0.16) : Color(.tertiarySystemGroupedBackground), in: Capsule())
                .foregroundStyle(selected ? Theme.accent : .secondary)
        }
        .accessibilityLabel("\(trigger.title)\(selected ? ", selected" : "")")
    }
}

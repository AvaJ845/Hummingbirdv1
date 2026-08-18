import SwiftUI

/// A dismissible home-screen nudge surfacing a genuine pattern in the user's
/// own confidence-vs-accuracy record — shown only when the numbers actually
/// say something (see `CalibrationInsightEngine`), and only once per shape of
/// that finding. Tapping opens the full record in Your Calls. A record of
/// the past — never advice, never telling the user what to do next.
struct CalibrationInsightCard: View {
    let insight: CalibrationInsight
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "gauge.with.needle")
                .font(.title3).foregroundStyle(Theme.brandGradient).frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(.subheadline.weight(.semibold))
                Text(insight.message)
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(insight.title): \(insight.message)")
        .accessibilityHint("Opens your call record")
    }
}

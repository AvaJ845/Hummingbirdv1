import SwiftUI

/// A dismissible home-screen prompt offering one or more spaced-retrieval
/// memory checks — never forced, matching the app's deference to the user.
/// Declining is treated the same as completing it: these aren't nagged back
/// into view for the same calls and checkpoints. When more than one call is
/// due, they're reviewed together in one mixed session rather than one at a
/// time — interleaving different material strengthens retention more than
/// the same amount of practice done in isolation (Rohrer & Taylor, 2007,
/// "The Shuffling of Mathematics Problems Improves Learning").
struct RecallCard: View {
    let symbols: [String]
    let daysAgo: Int
    let onTap: () -> Void
    let onDismiss: () -> Void

    private var title: String {
        symbols.count == 1 ? "Remember \(symbols[0].uppercased())?" : "Remember these calls?"
    }

    private var subtitle: String {
        symbols.count == 1
            ? "Test your memory of a call from \(daysAgo) days ago"
            : "Test your memory on \(symbols.count) past calls: \(symbols.map { $0.uppercased() }.joined(separator: ", "))"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "brain")
                .font(.title3).foregroundStyle(Theme.accentAlt).frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
            Image(systemName: "chevron.right")
                .font(.caption).foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityHint("Opens a quick memory check")
    }
}

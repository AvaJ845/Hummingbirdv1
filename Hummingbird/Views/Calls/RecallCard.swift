import SwiftUI

/// A dismissible home-screen prompt offering one spaced-retrieval memory
/// check — never forced, matching the app's deference to the user.
/// Declining is treated the same as completing it: this isn't nagged back
/// into view for the same call and checkpoint.
struct RecallCard: View {
    let symbol: String
    let daysAgo: Int
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "brain")
                .font(.title3).foregroundStyle(Theme.accentAlt).frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Remember \(symbol.uppercased())?")
                    .font(.subheadline.weight(.semibold))
                Text("Test your memory of a call from \(daysAgo) days ago")
                    .font(.caption).foregroundStyle(.secondary)
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
        .accessibilityLabel("Remember \(symbol), test your memory of a call from \(daysAgo) days ago")
        .accessibilityHint("Opens a quick memory check")
    }
}

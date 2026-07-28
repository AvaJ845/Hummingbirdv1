import SwiftUI

/// Expandable "Why this sketch?" — the plain-English drivers behind a projection.
struct WhySketchCard: View {
    let drivers: [String]

    var body: some View {
        Card {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(drivers.indices, id: \.self) { index in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 5))
                                .foregroundStyle(Theme.accent)
                                .padding(.top, 6)
                                .accessibilityHidden(true)
                            Text(drivers[index])
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, 8)
                .accessibilityElement(children: .combine)
            } label: {
                Label("Why this sketch?", systemImage: "lightbulb")
                    .font(.subheadline.weight(.semibold))
            }
            .tint(.primary)
        }
    }
}

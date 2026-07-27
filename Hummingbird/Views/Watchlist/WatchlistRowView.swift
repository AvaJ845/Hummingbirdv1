import SwiftUI

struct WatchlistRowView: View {
    let item: WatchlistItem
    let snapshot: WatchlistSnapshot?
    var alertsEnabled: Bool = false
    var isRefreshing: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.assetClass.systemImage)
                .font(.title3)
                .foregroundStyle(Theme.brandGradient)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(item.title)
                        .font(.headline)
                        .lineLimit(1)
                    if alertsEnabled {
                        Image(systemName: "bell.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .accessibilityHidden(true)
                    }
                }
                if let snapshot {
                    Text("Best: \(snapshot.bestMethodName) · \(snapshot.horizonDays)d")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(isRefreshing ? "Updating…" : "Tap to project")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            if let snapshot {
                Sparkline(history: snapshot.historySpark, projection: snapshot.projectionSpark)
                    .frame(width: 56, height: 28)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(snapshot.price.asCurrency())
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(snapshot.projectedChange.asSignedPercent())
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.changeColor(snapshot.projectedChange))
                }
            } else if isRefreshing {
                ProgressView()
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        guard let snapshot else { return "\(item.title), tap to project" }
        return "\(item.title), \(snapshot.price.asCurrency()), best method \(snapshot.bestMethodName) projects \(snapshot.projectedChange.asSignedPercent()) over \(snapshot.horizonDays) days"
    }
}

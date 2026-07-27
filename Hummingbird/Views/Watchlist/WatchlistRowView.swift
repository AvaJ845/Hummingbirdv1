import SwiftUI

struct WatchlistRowView: View {
    let item: WatchlistItem
    let snapshot: WatchlistSnapshot?
    var alertsEnabled: Bool = false
    var isRefreshing: Bool = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityLayout
            } else {
                standardLayout
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Layouts

    private var standardLayout: some View {
        HStack(spacing: 12) {
            icon
            VStack(alignment: .leading, spacing: 3) {
                titleRow
                subtitle
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            if let snapshot {
                Sparkline(history: snapshot.historySpark, projection: snapshot.projectionSpark)
                    .frame(width: 48, height: 28)
                VStack(alignment: .trailing, spacing: 3) {
                    priceText
                    changeText
                }
            } else if isRefreshing {
                ProgressView()
            }
        }
    }

    private var accessibilityLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                icon
                titleRow
            }
            subtitle
            if snapshot != nil {
                HStack(alignment: .firstTextBaseline) {
                    priceText
                    Spacer(minLength: 8)
                    changeText
                }
            } else if isRefreshing {
                ProgressView()
            }
        }
    }

    // MARK: - Pieces

    private var icon: some View {
        Image(systemName: item.assetClass.systemImage)
            .font(.title3)
            .foregroundStyle(Theme.brandGradient)
            .frame(width: 28)
            .accessibilityHidden(true)
    }

    private var titleRow: some View {
        HStack(spacing: 5) {
            Text(item.title)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if alertsEnabled {
                Image(systemName: "bell.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder private var subtitle: some View {
        if let snapshot {
            Text("Best: \(snapshot.bestMethodName)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        } else {
            Text(isRefreshing ? "Updating…" : "Tap to project")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var priceText: some View {
        if let snapshot {
            Text(snapshot.price.asCurrency())
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    @ViewBuilder private var changeText: some View {
        if let snapshot {
            Text(snapshot.projectedChange.asSignedPercent())
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.changeColor(snapshot.projectedChange))
                .lineLimit(1)
        }
    }

    private var accessibilityLabel: String {
        var parts: [String] = [item.title]
        if let snapshot {
            parts.append(snapshot.price.asCurrency())
            parts.append("best method \(snapshot.bestMethodName) projects \(snapshot.projectedChange.asSignedPercent()) over \(snapshot.horizonDays) days")
        } else {
            parts.append("tap to project")
        }
        if alertsEnabled { parts.append("movement alerts on") }
        return parts.joined(separator: ", ")
    }
}

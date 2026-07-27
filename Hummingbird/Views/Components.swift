import SwiftUI

/// A rounded "card" container used throughout the app.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    var subtitle: String?
    var valueColor: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(valueColor)
                .contentTransition(.numericText())
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

struct ConfidenceBadge: View {
    let confidence: ForecastModel.Confidence

    private var color: Color {
        switch confidence {
        case .high: return Theme.up
        case .medium: return .orange
        case .experimental: return .purple
        }
    }

    var body: some View {
        Text(confidence.rawValue)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
    }
}

struct StatusBadge: View {
    let status: ForecastModel.Status

    private var color: Color {
        switch status {
        case .ready: return Theme.accent
        case .beta: return .blue
        case .comingSoon: return .secondary
        }
    }

    var body: some View {
        Text(status.rawValue)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .overlay(Capsule().stroke(color.opacity(0.5), lineWidth: 1))
            .foregroundStyle(color)
    }
}

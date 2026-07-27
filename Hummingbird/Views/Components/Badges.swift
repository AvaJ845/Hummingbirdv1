import SwiftUI

struct ConfidenceBadge: View {
    let confidence: ForecastModel.Confidence
    var easyMode: Bool = true

    private var color: Color {
        switch confidence {
        case .high: Theme.up
        case .medium: .orange
        case .experimental: Color(red: 0.55, green: 0.35, blue: 0.85)
        }
    }

    /// Always retail labels — never show raw “High” confidence theater.
    private var label: String { confidence.retailLabel }

    var body: some View {
        Text(label)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
            .accessibilityLabel("Style \(label)")
    }
}

struct StatusBadge: View {
    let status: ForecastModel.Status

    private var color: Color {
        switch status {
        case .ready: Theme.accent
        case .beta: .blue
        }
    }

    var body: some View {
        Text(status.rawValue)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .overlay(Capsule().stroke(color.opacity(0.5), lineWidth: 1))
            .foregroundStyle(color)
            .accessibilityLabel("Status \(status.rawValue)")
    }
}

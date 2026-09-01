import SwiftUI

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

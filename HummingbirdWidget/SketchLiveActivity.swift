import ActivityKit
import WidgetKit
import SwiftUI

/// The "tracking a sketch" Live Activity — Lock Screen banner + Dynamic Island.
/// Shows the live public price and the sketch's projected change, always framed
/// as educational, never a signal.
struct SketchLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SketchActivityAttributes.self) { context in
            lockScreen(context)
                .padding(14)
                .activityBackgroundTint(Color.black.opacity(0.25))
                .activitySystemActionForegroundColor(Theme.accent)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.symbol.uppercased())
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(changeText(context.state.projectedChange))
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(Theme.changeColor(context.state.projectedChange))
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.price.asCurrency())
                        .font(.title3.weight(.semibold).monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Educational sketch · not advice")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            } compactLeading: {
                Text(context.attributes.symbol.uppercased()).font(.caption2.weight(.semibold))
            } compactTrailing: {
                Text(changeText(context.state.projectedChange))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Theme.changeColor(context.state.projectedChange))
            } minimal: {
                Image(systemName: "chart.line.uptrend.xyaxis").foregroundStyle(Theme.accent)
            }
            .keylineTint(Theme.accent)
        }
    }

    @ViewBuilder
    private func lockScreen(_ context: ActivityViewContext<SketchActivityAttributes>) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.title).font(.headline).lineLimit(1)
                Text("\(context.attributes.horizonDays)-day sketch · not advice")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(context.state.price.asCurrency())
                    .font(.title3.weight(.bold).monospacedDigit())
                Text(changeText(context.state.projectedChange))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.changeColor(context.state.projectedChange))
            }
        }
    }

    private func changeText(_ change: Double) -> String {
        change.asSignedPercent()
    }
}

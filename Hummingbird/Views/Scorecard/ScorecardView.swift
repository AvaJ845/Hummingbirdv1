import SwiftUI

/// The honesty pledge made tangible: a track record of how Hummingbird's past
/// sketches have *actually* tracked once real prices caught up. A record of
/// the past — never a promise about the future.
struct ScorecardView: View {
    @Bindable var scorecard: SketchScorecardStore

    private var overall: ScorecardSummary { scorecard.overall }

    var body: some View {
        List {
            if scorecard.records.isEmpty {
                emptyState
            } else {
                overallSection
                assetsSection
            }
            aboutSection
        }
        .navigationTitle("Track record")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: sections

    private var overallSection: some View {
        Section {
            HStack(spacing: 18) {
                stat(value: errorText(overall.medianError), caption: "Typical error")
                Divider().frame(height: 40)
                stat(value: "\(overall.resolvedSketches)", caption: "Scored sketches")
                Divider().frame(height: 40)
                stat(value: "\(overall.totalSketches)", caption: "Total")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        } header: {
            Text("Across all assets")
        } footer: {
            if !overall.hasResolved {
                Text("Your sketches are still waiting for real prices to catch up. Check back in a few days.")
            }
        }
    }

    private var assetsSection: some View {
        Section("By asset") {
            ForEach(scorecard.assets) { asset in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(asset.symbol.uppercased())
                            .font(.body.weight(.semibold))
                        Text("\(asset.summary.resolvedSketches) scored · \(asset.summary.totalSketches) total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(errorText(asset.summary.medianError))
                            .font(.body.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(errorColor(asset.summary.medianError))
                        Text("typical error")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(asset.symbol), \(asset.summary.resolvedSketches) scored sketches, typical error \(errorText(asset.summary.medianError))")
            }
        }
    }

    private var aboutSection: some View {
        Section {
            Text("“Typical error” is the median gap between a past sketch and the price that actually happened. It's a record of the past — not a prediction, and never financial advice.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        Section {
            VStack(spacing: 10) {
                Image(systemName: "checkmark.seal")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.accent)
                Text("No scored sketches yet")
                    .font(.headline)
                Text("Run a few projections. Once real prices catch up to their dates, you'll see how honest each sketch turned out to be.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    // MARK: helpers

    private func stat(value: String, caption: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.title3.weight(.bold)).monospacedDigit()
            Text(caption).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func errorText(_ error: Double?) -> String {
        guard let error else { return "—" }
        return String(format: "%.1f%%", error * 100)
    }

    private func errorColor(_ error: Double?) -> Color {
        guard let error else { return .secondary }
        switch error {
        case ..<0.03: return Theme.up
        case ..<0.08: return Color(red: 0.95, green: 0.68, blue: 0.20)
        default: return Theme.down
        }
    }
}

import SwiftUI

/// The Accuracy Report Card — the honesty pledge made tangible: how Hummingbird's
/// past sketches *actually* tracked once real prices caught up. A record of the
/// past, never a promise. Free sees the headline; Pro unlocks the full breakdown.
struct ScorecardView: View {
    @Bindable var scorecard: SketchScorecardStore
    @Bindable var entitlements: EntitlementStore

    private var report: ScorecardReport { scorecard.report }

    var body: some View {
        List {
            if scorecard.records.isEmpty {
                emptyState
            } else {
                headlineSection
                if entitlements.isPro {
                    if !report.horizons.isEmpty { horizonSection }
                    if !report.models.isEmpty { methodSection }
                    assetsSection
                    shareSection
                } else {
                    proTeaser
                }
            }
            aboutSection
        }
        .navigationTitle("Accuracy report")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Headline (free)

    private var headlineSection: some View {
        Section {
            if let cal = report.calibration {
                VStack(spacing: 4) {
                    Text("Ranges held \(pct(cal.inRangeRate))")
                        .font(.title2.weight(.bold)).monospacedDigit()
                        .foregroundStyle(calibrationColor(cal.inRangeRate))
                    Text("of the time · aiming for ~80%")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("The real price landed inside the sketch's range \(pct(cal.inRangeRate)) of the time, aiming for about 80 percent")
            }

            HStack(spacing: 18) {
                stat(value: errorText(report.summary.medianError), caption: "Typical error")
                Divider().frame(height: 40)
                stat(value: "\(report.summary.resolvedSketches)", caption: "Scored")
                Divider().frame(height: 40)
                stat(value: "\(report.summary.totalSketches)", caption: "Total")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)

            if let directional = report.directional {
                Text("Called the direction \(pct(directional.hitRate)) of the time — a record of the past, never advice.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Across all assets")
        } footer: {
            if report.calibration == nil {
                if report.summary.hasResolved {
                    Text("Range calibration appears once a few more sketches resolve against real prices.")
                } else {
                    Text("Your sketches are still waiting for real prices to catch up. Check back in a few days.")
                }
            }
        }
    }

    // MARK: - Pro detail

    private var horizonSection: some View {
        Section {
            ForEach(report.horizons) { horizon in
                HStack {
                    Text("\(horizon.daysAhead)-day sketches")
                        .font(.body)
                    Spacer()
                    Text(errorText(horizon.medianError))
                        .font(.body.weight(.semibold)).monospacedDigit()
                        .foregroundStyle(errorColor(horizon.medianError))
                    Text("·  \(horizon.resolvedCount)")
                        .font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(horizon.daysAhead) day sketches, typical error \(errorText(horizon.medianError)), \(horizon.resolvedCount) scored")
            }
        } header: {
            Text("Typical error by horizon")
        } footer: {
            Text("Further-out sketches are naturally less accurate — that's expected, not a flaw.")
        }
    }

    private var methodSection: some View {
        Section("By method") {
            ForEach(report.models) { model in
                HStack {
                    Text(model.modelName).font(.body)
                    Spacer()
                    Text(errorText(model.medianError))
                        .font(.body.weight(.semibold)).monospacedDigit()
                        .foregroundStyle(errorColor(model.medianError))
                    Text("·  \(model.resolvedCount)")
                        .font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(model.modelName), typical error \(errorText(model.medianError)), \(model.resolvedCount) scored")
            }
        }
    }

    private var assetsSection: some View {
        Section("By asset") {
            ForEach(scorecard.assets) { asset in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(asset.symbol.uppercased()).font(.body.weight(.semibold))
                        Text("\(asset.summary.resolvedSketches) scored · \(asset.summary.totalSketches) total")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(errorText(asset.summary.medianError))
                            .font(.body.weight(.semibold)).monospacedDigit()
                            .foregroundStyle(errorColor(asset.summary.medianError))
                        Text("typical error").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(asset.symbol), \(asset.summary.resolvedSketches) scored sketches, typical error \(errorText(asset.summary.medianError))")
            }
        }
    }

    private var shareSection: some View {
        Section {
            ShareLink(item: reportText) {
                Label("Share this report", systemImage: "square.and.arrow.up")
            }
            .tint(Theme.accentAlt)
        }
    }

    // MARK: - Pro teaser (free)

    private var proTeaser: some View {
        Section {
            NavigationLink {
                PaywallView(entitlements: entitlements, scorecard: scorecard)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Unlock the full report", systemImage: "sparkles")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.brandGradient)
                    ForEach([
                        "Typical error by horizon (1 / 7 / 14 / 30 days)",
                        "Which method has tracked each asset best",
                        "Accuracy per asset, and a shareable report",
                    ], id: \.self) { line in
                        Label(line, systemImage: "checkmark")
                            .font(.caption).foregroundStyle(.secondary)
                            .labelStyle(.titleAndIcon)
                    }
                }
                .padding(.vertical, 4)
            }
        } footer: {
            Text("The headline above is always free — Pro just adds the detail behind it.")
        }
    }

    private var aboutSection: some View {
        Section {
            Text("“Typical error” is the median gap between a past sketch and the price that actually happened; “ranges held” is how often the real price landed inside a sketch's stated range. It's a record of the past — not a prediction, and never financial advice.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        Section {
            VStack(spacing: 10) {
                Image(systemName: "checkmark.seal")
                    .font(.system(size: 40)).foregroundStyle(Theme.accent)
                Text("No scored sketches yet").font(.headline)
                Text("Run a few projections. Once real prices catch up to their dates, you'll see how honest each sketch turned out to be.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
        }
    }

    // MARK: - Helpers

    private var reportText: String {
        var lines = ["Hummingbird accuracy report — a record of the past, not advice.",
                     "\(report.summary.totalSketches) sketches · \(report.summary.resolvedSketches) scored",
                     "Typical error: \(errorText(report.summary.medianError))"]
        if let cal = report.calibration {
            lines.append("Ranges held: \(pct(cal.inRangeRate)) of the time (aiming ~80%)")
        }
        if let directional = report.directional {
            lines.append("Called the direction: \(pct(directional.hitRate)) of the time")
        }
        for horizon in report.horizons {
            lines.append("• \(horizon.daysAhead)d: \(errorText(horizon.medianError)) typical error (\(horizon.resolvedCount) scored)")
        }
        return lines.joined(separator: "\n")
    }

    private func stat(value: String, caption: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.title3.weight(.bold)).monospacedDigit()
            Text(caption).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func pct(_ fraction: Double) -> String { String(format: "%.0f%%", fraction * 100) }

    private func errorText(_ error: Double?) -> String {
        guard let error else { return "—" }
        return String(format: "%.1f%%", error * 100)
    }

    private func errorColor(_ error: Double?) -> Color {
        guard let error else { return .secondary }
        switch error {
        case ..<0.03: return Theme.up
        case ..<0.08: return Theme.warning
        default: return Theme.down
        }
    }

    /// Green when the stated range is holding near/above its ~80% design; amber
    /// when it's running too narrow (real prices escaping the band).
    private func calibrationColor(_ rate: Double) -> Color {
        rate >= 0.70 ? Theme.up : Theme.warning
    }
}

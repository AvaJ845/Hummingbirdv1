import SwiftUI

/// The Accuracy Report Card — the honesty pledge made tangible: how Hummingbird's
/// past sketches *actually* tracked once real prices caught up. Written in plain
/// language for everyone. A record of the past, never a promise. Free sees the
/// headline; Pro unlocks the full breakdown.
struct ScorecardView: View {
    @Bindable var scorecard: SketchScorecardStore
    @Bindable var entitlements: EntitlementStore
    @State private var shareImage: Image?

    private var report: ScorecardReport { scorecard.report }

    var body: some View {
        List {
            if scorecard.records.isEmpty {
                emptyState
            } else {
                headlineSection
                // Definitions sit right after the numbers they explain, not
                // buried below every Pro section — a free user shouldn't have
                // to scroll past a paywall to learn what "typical miss" means.
                aboutSection
                if entitlements.isPro {
                    if !report.horizons.isEmpty { horizonSection }
                    if !report.models.isEmpty { methodSection }
                    assetsSection
                    shareSection
                } else {
                    proTeaser
                }
            }
        }
        .readableContentWidth()
        .navigationTitle("Accuracy report")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: shareRenderKey) { shareImage = renderShareImage() }
    }

    private var shareRenderKey: String {
        "\(report.summary.totalSketches)-\(report.summary.resolvedSketches)-\(report.calibration?.inRangeRate ?? -1)"
    }

    @MainActor private func renderShareImage() -> Image? {
        guard !scorecard.records.isEmpty else { return nil }
        let renderer = ImageRenderer(content: AccuracyShareCard(report: report))
        renderer.scale = 3
        guard let uiImage = renderer.uiImage else { return nil }
        return Image(uiImage: uiImage)
    }

    // MARK: - Headline (free)

    private var headlineSection: some View {
        Section {
            if let cal = report.calibration {
                VStack(spacing: 4) {
                    Text("In range \(pct(cal.inRangeRate)) of the time")
                        .font(.title2.weight(.bold)).monospacedDigit()
                        .foregroundStyle(calibrationColor(cal.inRangeRate))
                        .multilineTextAlignment(.center)
                    Text("the real price landed inside our range · we aim for about 8 in 10")
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    CalibrationGauge(rate: cal.inRangeRate, target: RangeCalibration.target,
                                     barColor: calibrationColor(cal.inRangeRate))
                        .frame(height: 8)
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("The real price landed inside our range \(pct(cal.inRangeRate)) of the time. We aim for about 8 in 10.")
            }

            HStack(spacing: 18) {
                stat(value: errorText(report.summary.medianError), caption: "Typical miss",
                     qualifier: errorQualifier(report.summary.medianError),
                     qualifierColor: errorColor(report.summary.medianError))
                Divider().frame(height: 40)
                stat(value: "\(report.summary.resolvedSketches)", caption: "Resolved")
                Divider().frame(height: 40)
                stat(value: "\(report.summary.totalSketches)", caption: "Total")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)

            if let directional = report.directional {
                Text("Pointed the right way \(pct(directional.hitRate)) of the time — a look back, never advice.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Across all assets")
        } footer: {
            if report.calibration == nil {
                if report.summary.hasResolved {
                    Text("Once a few more sketches catch up to real prices, you'll also see how often the real price landed inside our range.")
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
                    Text("\(horizon.daysAhead) day\(horizon.daysAhead == 1 ? "" : "s") ahead")
                        .font(.body)
                    Spacer()
                    Text(errorText(horizon.medianError))
                        .font(.body.weight(.semibold)).monospacedDigit()
                        .foregroundStyle(errorColor(horizon.medianError))
                    Text("·  \(horizon.resolvedCount)")
                        .font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(horizon.daysAhead) days ahead, typical miss \(errorText(horizon.medianError)), \(horizon.resolvedCount) resolved")
            }
        } header: {
            Text("Accuracy by days ahead")
        } footer: {
            Text("Sketches further out are naturally less accurate — that's expected, not a flaw.")
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
                .accessibilityLabel("\(model.modelName), typical miss \(errorText(model.medianError)), \(model.resolvedCount) resolved")
            }
        }
    }

    private var assetsSection: some View {
        Section("By asset") {
            ForEach(scorecard.assets) { asset in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(asset.symbol.uppercased()).font(.body.weight(.semibold))
                        Text("\(asset.summary.resolvedSketches) resolved · \(asset.summary.totalSketches) total")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(errorText(asset.summary.medianError))
                            .font(.body.weight(.semibold)).monospacedDigit()
                            .foregroundStyle(errorColor(asset.summary.medianError))
                        Text("typical miss").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(asset.symbol), \(asset.summary.resolvedSketches) resolved, typical miss \(errorText(asset.summary.medianError))")
            }
        }
    }

    @ViewBuilder private var shareSection: some View {
        if let shareImage {
            Section {
                ShareLink(item: shareImage,
                          preview: SharePreview("Hummingbird accuracy report", image: shareImage)) {
                    Label("Share this report", systemImage: "square.and.arrow.up")
                }
                .tint(Theme.accentAlt)
                .accessibilityHint("Shares this accuracy report as an image with the not-advice note included")
            }
        }
    }

    // MARK: - Pro teaser (free)

    private var proTeaser: some View {
        Section {
            NavigationLink {
                PaywallView(entitlements: entitlements, scorecard: scorecard)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Label(personalizedTeaserTitle, systemImage: "sparkles")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.brandGradient)
                    ForEach([
                        "Accuracy by how many days ahead",
                        "Which method has tracked each asset best",
                        "How each asset has done — and a shareable report",
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

    /// Personalized with the user's own count when there's enough to make it
    /// concrete, rather than a generic pitch — still strictly honest, just
    /// grounded in what's actually already tracked.
    private var personalizedTeaserTitle: String {
        let n = report.summary.totalSketches
        guard n > 0 else { return "See the full report" }
        return "See the full breakdown of your \(n) sketch\(n == 1 ? "" : "es")"
    }

    private var aboutSection: some View {
        Section {
            Text("“Typical miss” is how far a past sketch typically landed from the price that actually happened — not to be confused with a stock “gap.” “In range” is how often the real price fell inside a sketch's range. It's a record of the past — not a prediction, and never financial advice.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        Section {
            VStack(spacing: 10) {
                Image(systemName: "checkmark.seal")
                    .font(.system(size: 40)).foregroundStyle(Theme.accent)
                Text("No sketches resolved yet").font(.headline)
                Text("Run a few projections. Once real prices catch up to their dates, you'll see how honest each sketch turned out to be.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
        }
    }

    // MARK: - Helpers

    private func stat(value: String, caption: String, qualifier: String? = nil, qualifierColor: Color = .secondary) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.title3.weight(.bold)).monospacedDigit()
            Text(caption).font(.caption2).foregroundStyle(.secondary)
            if let qualifier {
                Text(qualifier).font(.caption2.weight(.semibold)).foregroundStyle(qualifierColor)
            }
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

    /// A plain-English read on the number, so a first-time visitor doesn't
    /// need outside context to know whether e.g. "3.2%" is good — it shares
    /// the exact same thresholds as `errorColor`, just spelled out in words.
    private func errorQualifier(_ error: Double?) -> String? {
        guard let error else { return nil }
        switch error {
        case ..<0.03: return "tight"
        case ..<0.08: return "so-so"
        default: return "wide"
        }
    }

    /// Green when the range is holding near/above its ~8-in-10 aim; amber when
    /// it's running too narrow (real prices escaping the range).
    private func calibrationColor(_ rate: Double) -> Color {
        rate >= 0.70 ? Theme.up : Theme.warning
    }
}

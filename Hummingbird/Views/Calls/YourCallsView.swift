import SwiftUI

/// The return hook: the user's own calls, scored honestly over time. Resolves
/// any due calls when opened. A record of the past — never advice.
struct YourCallsView: View {
    @Bindable var store: UserCallStore
    @Bindable var entitlements: EntitlementStore
    var service: any MarketDataProviding = MarketDataService()
    /// When the user first engaged a weekly lesson — drives the honest
    /// lessons→calibration read. Nil = never engaged (insight stays hidden).
    var lessonsStartedAt: Date? = nil
    var onUnlock: () -> Void = {}
    @State private var shareImage: Image?

    private var report: UserCallReport { store.report }

    /// Correlation-only read of whether calls improved after the lessons began.
    /// Nil unless there's a real sample on both sides — so it never shows noise.
    private var lessonsInsight: LessonsCalibrationInsight? {
        LessonsCalibrationEngine.insight(calls: store.calls, lessonsStartedAt: lessonsStartedAt)
    }
    private var freeResolvedLimit: Int { 5 }

    /// The raw participation streak shown to the user — no perks, no grace days.
    private var displayStreak: Int {
        StreakEngine.currentStreak(store.calls)
    }

    var body: some View {
        List {
            if store.calls.isEmpty {
                emptyState
            } else {
                overallSection
                if let insight = lessonsInsight { lessonsSection(insight) }
                vsMethodsSection
                if !report.byConfidence.isEmpty { confidenceSection }
                if !report.byReason.isEmpty { reasoningSection }
                if !store.pending.isEmpty { pendingSection }
                resolvedSection
                if entitlements.isPro {
                    shareSection
                } else if report.resolved > 0 {
                    proTeaser
                }
            }
            aboutSection
        }
        .navigationTitle("Your calls")
        .navigationBarTitleDisplayMode(.inline)
        .task { await resolveDue() }
        .refreshable { await resolveDue() }
        .task(id: shareRenderKey) { shareImage = renderShareImage() }
    }

    private var shareRenderKey: String {
        "\(report.overall.decided)-\(report.overall.correct)-\(displayStreak)"
    }

    @MainActor private func renderShareImage() -> Image? {
        let card = ScorecardShareCard(report: report, streak: displayStreak)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        guard let uiImage = renderer.uiImage else { return nil }
        return Image(uiImage: uiImage)
    }

    private func resolveDue() async {
        guard !store.dueAssets().isEmpty else { return }
        for id in await store.resolveDue(using: service) {
            NotificationService.cancelCallResolution(callID: id)
        }
    }

    // MARK: Sections

    private var overallSection: some View {
        Section {
            HStack(spacing: 18) {
                stat(value: report.overall.hitRate.map(pct) ?? "—", caption: "Right")
                Divider().frame(height: 40)
                stat(value: "\(report.overall.correct)/\(report.overall.decided)", caption: "Correct")
                Divider().frame(height: 40)
                stat(value: "\(store.pending.count)", caption: "Waiting")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        } header: {
            Text("Your record")
        } footer: {
            if report.overall.decided == 0 {
                Text("Your record fills in as your calls reach their dates. Pull to refresh.")
            } else if displayStreak >= 2 {
                Label("\(displayStreak)-day streak — you've called it \(displayStreak) days running.", systemImage: "flame.fill")
                    .foregroundStyle(Theme.warning)
            }
        }
    }

    /// Honest, *shown-not-rewarded* read of whether engaging with the weekly
    /// lessons tracked with better calls. Correlation only — never a claim the
    /// lessons caused it, and gated so it can't surface on a thin sample.
    private func lessonsSection(_ insight: LessonsCalibrationInsight) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("Since the weekly lessons", systemImage: "graduationcap")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.brandGradient)

                HStack(spacing: 8) {
                    Text(pct(insight.beforeRate)).foregroundStyle(.secondary)
                    Image(systemName: "arrow.right").font(.footnote).foregroundStyle(.tertiary)
                    Text(pct(insight.afterRate))
                        .foregroundStyle(insight.improved ? Theme.up : .primary)
                    Text(deltaText(insight))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(deltaColor(insight))
                }
                .font(.title3.weight(.semibold)).monospacedDigit()

                Text("\(insight.beforeDecided) calls before · \(insight.afterDecided) after")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Since the weekly lessons, your calls went from \(pct(insight.beforeRate)) right to \(pct(insight.afterRate)) right, across \(insight.beforeDecided) calls before and \(insight.afterDecided) after.")
        } footer: {
            Text("How your calls compare before and after you started the weekly questions. Correlation, not proof — the lessons might help, or you might just be practicing more. Never advice.")
        }
    }

    /// Signed change in hit rate, in percentage *points* (a difference of two
    /// rates is points, not percent — saying "%" here would be misleading).
    private func deltaText(_ insight: LessonsCalibrationInsight) -> String {
        let points = (insight.delta * 100).rounded()
        if points > 0 { return "+\(Int(points)) pts" }
        if points < 0 { return "−\(Int(abs(points))) pts" }
        return "no change"
    }

    private func deltaColor(_ insight: LessonsCalibrationInsight) -> Color {
        if insight.delta > 0.0005 { return Theme.up }
        if insight.delta < -0.0005 { return Theme.warning }
        return .secondary
    }

    @ViewBuilder private var vsMethodsSection: some View {
        if let vs = UserCallEngine.vsMethods(store.calls) {
            Section {
                if entitlements.isPro {
                    HStack {
                        Text("You").font(.body.weight(.bold))
                        Spacer()
                        Text(pct(vs.userHitRate)).font(.body.weight(.bold)).monospacedDigit()
                            .foregroundStyle(Theme.accent)
                        Text("·  \(vs.userDecided)").font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                    }
                    ForEach(vs.methods) { method in
                        HStack {
                            Text(method.methodName).font(.body).foregroundStyle(.secondary)
                            Spacer()
                            Text(pct(method.hitRate)).font(.body.weight(.medium)).monospacedDigit()
                                .foregroundStyle(.secondary)
                            Image(systemName: vs.userHitRate > method.hitRate ? "checkmark" : "minus")
                                .font(.caption2)
                                .foregroundStyle(vs.userHitRate > method.hitRate ? Theme.up : Color.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(method.methodName): right \(pct(method.hitRate)), you are \(vs.userHitRate > method.hitRate ? "ahead" : "not ahead")")
                    }
                } else {
                    Button(action: onUnlock) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("You vs. the methods", systemImage: "sparkles")
                                .font(.body.weight(.semibold)).foregroundStyle(Theme.brandGradient)
                            Text("See how your own calls compare with the app's methods — scored on the very same calls. Pro.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("You vs. the methods")
            } footer: {
                if entitlements.isPro {
                    Text("You're ahead of \(vs.methodsBeaten) of \(vs.methods.count) methods so far — a record of the past, never advice. Small samples wobble; more calls make the picture clearer.")
                }
            }
        }
    }

    private var confidenceSection: some View {
        Section {
            ForEach(report.byConfidence) { row in
                HStack {
                    Text(row.confidence.title).font(.body)
                    Spacer()
                    Text(pct(row.hitRate)).font(.body.weight(.semibold)).monospacedDigit()
                    Text("·  \(row.decided)").font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(row.confidence.title): right \(pct(row.hitRate)) of the time, \(row.decided) calls")
            }
        } header: {
            Text("Did feeling sure mean being right?")
        } footer: {
            Text("If “Confident” isn't higher than “Hunch,” that's worth knowing — confidence and accuracy aren't the same thing.")
        }
    }

    /// Which kind of reasoning has actually held up — a second axis of
    /// self-knowledge alongside confidence. Free shows what you've been
    /// tagging (no numbers to protect); Pro unlocks whether each kind of
    /// reasoning has actually paid off.
    @ViewBuilder private var reasoningSection: some View {
        Section {
            if entitlements.isPro {
                ForEach(report.byReason) { row in
                    HStack {
                        Text(row.reason.title).font(.body)
                        Spacer()
                        Text(pct(row.hitRate)).font(.body.weight(.semibold)).monospacedDigit()
                        Text("·  \(row.decided)").font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(row.reason.title): right \(pct(row.hitRate)) of the time, \(row.decided) calls")
                }
            } else {
                ForEach(report.byReason) { row in
                    HStack {
                        Text(row.reason.title).font(.body)
                        Spacer()
                        Text("\(row.decided) call\(row.decided == 1 ? "" : "s")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Button(action: onUnlock) {
                    Label("See accuracy by reason with Pro", systemImage: "sparkles")
                        .font(.subheadline).foregroundStyle(Theme.brandGradient)
                }
            }
        } header: {
            Text("What kind of reasoning holds up?")
        } footer: {
            if entitlements.isPro {
                Text("Which kind of thinking has actually paid off — a record of the past, never advice.")
            }
        }
    }

    private var pendingSection: some View {
        Section("Waiting to resolve") {
            ForEach(store.pending) { call in
                HStack {
                    directionChip(call.direction)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(call.symbol.uppercased()).font(.body.weight(.semibold))
                        Text("\(call.confidence.title) · \(call.horizonDays) days").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(waitLabel(for: call)).font(.caption).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var resolvedSection: some View {
        let resolved = store.calls.filter(\.isResolved).sorted { ($0.resolvedAt ?? .distantPast) > ($1.resolvedAt ?? .distantPast) }
        let limit = entitlements.isPro ? 60 : freeResolvedLimit
        let shown = Array(resolved.prefix(limit))
        return Section {
            if resolved.isEmpty {
                Text("None yet — check back when your calls reach their dates.")
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                ForEach(shown) { call in
                    HStack {
                        directionChip(call.direction)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(call.symbol.uppercased()).font(.body.weight(.semibold))
                            Text("You said \(call.direction.title.lowercased()) · \(call.confidence.title)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        outcome(for: call)
                    }
                    .accessibilityElement(children: .combine)
                }
                if !entitlements.isPro, resolved.count > shown.count {
                    Button(action: onUnlock) {
                        Label("See all \(resolved.count) with Pro", systemImage: "sparkles")
                            .font(.subheadline).foregroundStyle(Theme.brandGradient)
                    }
                }
            }
        } header: {
            Text("Resolved")
        }
    }

    @ViewBuilder private var shareSection: some View {
        if let shareImage {
            Section {
                ShareLink(item: shareImage,
                          preview: SharePreview("My Hummingbird call record", image: shareImage)) {
                    Label("Share your record", systemImage: "square.and.arrow.up")
                }
                .tint(Theme.accentAlt)
                .accessibilityHint("Shares your call record as an image with the not-advice note included")
            }
        }
    }

    private var proTeaser: some View {
        Section {
            Button(action: onUnlock) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Keep your full record", systemImage: "sparkles")
                        .font(.body.weight(.semibold)).foregroundStyle(Theme.brandGradient)
                    ForEach([
                        "Every resolved call, not just the last \(freeResolvedLimit)",
                        "A shareable summary of how calibrated you've been",
                    ], id: \.self) { line in
                        Label(line, systemImage: "checkmark")
                            .font(.caption).foregroundStyle(.secondary).labelStyle(.titleAndIcon)
                    }
                }
                .padding(.vertical, 4)
            }
        } footer: {
            Text("Your headline record and confidence breakdown are always free — Pro just keeps the full history.")
        }
    }

    private var aboutSection: some View {
        Section {
            Text("You call it before the sketch, and Hummingbird checks it against the real price at its date. A record of your own calls — being right before doesn't mean you'll be right again, and this is never advice.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        Section {
            VStack(spacing: 10) {
                Image(systemName: "hand.point.up.left")
                    .font(.system(size: 40)).foregroundStyle(Theme.accent)
                Text("No calls yet").font(.headline)
                Text("Tap “Call it first” on an asset to predict before you peek. Your honest record starts there.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
        }
    }

    // MARK: Helpers

    private func stat(value: String, caption: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.title3.weight(.bold)).monospacedDigit()
            Text(caption).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func directionChip(_ direction: CallDirection) -> some View {
        let tint = direction == .higher ? Theme.up : Theme.down
        return Image(systemName: direction == .higher ? "arrow.up.right" : "arrow.down.right")
            .font(.caption.weight(.bold))
            .foregroundStyle(tint)
            .frame(width: 28, height: 28)
            .background(tint.opacity(0.15), in: Circle())
            .accessibilityHidden(true)
    }

    @ViewBuilder private func outcome(for call: UserCall) -> some View {
        if let correct = call.wasCorrect {
            HStack(spacing: 6) {
                if let change = call.actualChange {
                    Text(change.asSignedPercent()).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(correct ? Theme.up : Theme.down)
            }
        } else {
            Text("flat").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func waitLabel(for call: UserCall) -> String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: call.targetDate).day ?? 0
        if days <= 0 { return "checking…" }
        return "in \(days) day\(days == 1 ? "" : "s")"
    }

    private func pct(_ fraction: Double) -> String { String(format: "%.0f%%", fraction * 100) }
}

/// Compact home-screen entry into the loop — leads with the user's record.
struct YourCallsCard: View {
    let report: UserCallReport
    let pendingCount: Int
    /// Consecutive days with a call made — participation, never correctness.
    var streak: Int = 0
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "checklist")
                    .font(.title3).foregroundStyle(Theme.accent).frame(width: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your calls").font(.subheadline.weight(.semibold))
                    if let hit = report.overall.hitRate {
                        Text("\(pct(hit)) right · \(report.overall.correct) of \(report.overall.decided)")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Your record builds as your calls resolve")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if streak >= 2 {
                    streakBadge
                }
                if pendingCount > 0 {
                    Text("\(pendingCount) waiting")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Theme.accent.opacity(0.15), in: Capsule())
                        .foregroundStyle(Theme.accent)
                }
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your calls\(streak >= 2 ? ", \(streak) day streak" : "")\(pendingCount > 0 ? ", \(pendingCount) waiting" : "")")
        .accessibilityHint("Opens your honest call record")
    }

    private var streakBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
            Text("\(streak)")
        }
        .font(.caption2.weight(.semibold))
        .monospacedDigit()
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Theme.warning.opacity(0.15), in: Capsule())
        .foregroundStyle(Theme.warning)
        .accessibilityHidden(true)
    }

    private func pct(_ fraction: Double) -> String { String(format: "%.0f%%", fraction * 100) }
}

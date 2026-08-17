import SwiftUI

/// Weekly rollup across the whole watchlist — which assets moved most and how
/// closely the app's own methods have tracked lately. Distinct from Your Calls
/// (the user's own predictions) and the Accuracy Report (per-asset detail) —
/// this is the "what happened across everything I'm watching" view. A record
/// of the past, never a promise.
struct SketchJournalView: View {
    @Bindable var scorecard: SketchScorecardStore
    @Bindable var entitlements: EntitlementStore

    private var journal: SketchJournal? {
        SketchJournalEngine.compose(snapshots: SharedStorage.snapshots(), records: scorecard.records)
    }

    var body: some View {
        List {
            if entitlements.isPro {
                if let journal {
                    headlineSection(journal)
                    if !journal.movers.isEmpty { moversSection(journal) }
                } else {
                    emptyState
                }
            } else {
                proTeaser
            }
            aboutSection
        }
        .navigationTitle("Your journal")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Pro content

    private func headlineSection(_ journal: SketchJournal) -> some View {
        Section {
            HStack(spacing: 18) {
                stat(value: "\(journal.sketchesRun)", caption: "Sketches run")
                Divider().frame(height: 40)
                stat(value: errorText(journal.medianAccuracy), caption: "Typical miss")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        } header: {
            Text("This week")
        } footer: {
            Text("A rollup of your watchlist's sketch activity — a record of the past, never a promise.")
        }
    }

    private func moversSection(_ journal: SketchJournal) -> some View {
        Section("Biggest moves this week") {
            ForEach(journal.movers) { mover in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mover.title).font(.body.weight(.semibold))
                        Text("Best: \(mover.bestMethodName)").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(mover.projectedChange.asSignedPercent())
                        .font(.body.weight(.semibold)).monospacedDigit()
                        .foregroundStyle(Theme.changeColor(mover.projectedChange))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(mover.title), projected \(mover.projectedChange.asSignedPercent()), best method \(mover.bestMethodName)")
            }
        }
    }

    private var emptyState: some View {
        Section {
            VStack(spacing: 10) {
                Image(systemName: "book.closed")
                    .font(.system(size: 40)).foregroundStyle(Theme.accent)
                Text("Nothing to journal yet").font(.headline)
                Text("Once you've watched an asset or run a sketch this week, your journal fills in here.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
        }
    }

    // MARK: - Pro teaser (free)

    private var proTeaser: some View {
        Section {
            NavigationLink {
                PaywallView(entitlements: entitlements, scorecard: scorecard)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Label("See your weekly journal", systemImage: "book.closed")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.brandGradient)
                    ForEach([
                        "Which watched assets moved most this week",
                        "How closely the app's own methods have tracked lately",
                    ], id: \.self) { line in
                        Label(line, systemImage: "checkmark")
                            .font(.caption).foregroundStyle(.secondary)
                            .labelStyle(.titleAndIcon)
                    }
                }
                .padding(.vertical, 4)
            }
        } footer: {
            Text("Part of Hummingbird Pro — self-knowledge, not better foresight.")
        }
    }

    private var aboutSection: some View {
        Section {
            Text("Your journal is a weekly rollup of your watchlist's sketch activity — which assets moved most and how closely the app's own methods have tracked lately. A record of the past, not a prediction, and never financial advice.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

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
}

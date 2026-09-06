import StoreKit
import SwiftUI
import UIKit

struct PaywallView: View {
    @Bindable var entitlements: EntitlementStore
    /// Exact gate that opened the paywall — fair, contextual, retail-simple.
    var reason: String? = nil
    /// Optional: powers a personalised "what Pro would do for you" recap from
    /// the user's own on-device track record.
    var scorecard: SketchScorecardStore? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var manageError: String?
    @State private var legalPath: LegalRoute?

    private enum LegalRoute: String, Identifiable, Hashable {
        case privacy
        case terms
        var id: String { rawValue }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Hummingbird Pro")
                        .font(.title2.weight(.bold))
                    Text("The honest one — it scores your own calls and shows how wrong it's been. Pro goes deeper on your record, never better foresight, never advice.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let reason, !reason.isEmpty {
                        Text(reason)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                            .padding(.top, 2)
                            .accessibilityLabel("Why this screen: \(reason)")
                    }
                }
                .padding(.vertical, 4)
            }

            if !entitlements.isPro, let highlights = scorecard?.proValueHighlights, !highlights.isEmpty {
                Section {
                    ForEach(highlights.prefix(3)) { highlight in
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Auto-pick the best method for \(highlight.symbol.uppercased())")
                                Text("\(highlight.modelName) has tracked it closest — usually off \(percent(highlight.medianError))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "trophy").foregroundStyle(Theme.brandGradient)
                        }
                    }
                } header: {
                    Text("What Pro would do for you")
                } footer: {
                    Text("Personalised from your own on-device track record — a record of the past, not a promise.")
                }
            }

            Section("Always free") {
                Label("Drift, Trend, Straight trend & Holt", systemImage: "function")
                Label("Easy Mode bottom line", systemImage: "text.alignleft")
                Label("Horizons up to 30 days", systemImage: "calendar")
                Label("Daily rate what-ifs", systemImage: "building.columns")
                Label("Same public feeds as Pro", systemImage: "network")
            }

            Section("Pro adds") {
                ForEach(ProFeature.allCases) { feature in
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(feature.title)
                            Text(feature.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: feature.systemImage)
                            .foregroundStyle(Theme.brandGradient)
                    }
                }
            }

            Section {
                if entitlements.isLoading && entitlements.products.isEmpty {
                    HStack {
                        ProgressView()
                        Text("Loading App Store products…")
                            .foregroundStyle(.secondary)
                    }
                }

                if let yearly = entitlements.yearlyProduct {
                    let savings = entitlements.yearlySavingsPercent.map { " · save \($0)%" } ?? ""
                    purchaseButton(
                        yearly,
                        badge: "\(AppPricing.annualTrial), then \(yearly.displayPrice)/year\(savings)",
                        identifier: "paywall.buy.yearly",
                        highlighted: true
                    )
                }

                if let monthly = entitlements.monthlyProduct {
                    purchaseButton(
                        monthly,
                        badge: "\(monthly.displayPrice)/month · cancel anytime",
                        identifier: "paywall.buy.monthly"
                    )
                }

                if let lifetime = entitlements.lifetimeProduct {
                    purchaseButton(
                        lifetime,
                        badge: "Pay once · yours forever",
                        identifier: "paywall.buy.lifetime"
                    )
                }

                if entitlements.products.isEmpty && !entitlements.isLoading {
                    VStack(alignment: .leading, spacing: 8) {
                        // An honest failure state — distinct from the by-design
                        // DEBUG stub (which has no `lastError`). Retry re-runs the
                        // bounded-backoff load; the price list below stays as
                        // informational context but isn't purchasable right now.
                        if let error = entitlements.lastError {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Couldn't reach the App Store")
                                        .font(.subheadline.weight(.semibold))
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "wifi.exclamationmark")
                                    .foregroundStyle(.orange)
                            }
                            Button {
                                Task { await entitlements.loadProducts() }
                            } label: {
                                Label("Retry", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("paywall.retry")
                            Text("Plans below are for reference — purchasing will be available once the App Store reconnects.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                        }
                        fairPriceRow(
                            label: "Pro Yearly",
                            price: "$\(AppPricing.yearlyUSD)/year",
                            note: "7-day free trial · best value"
                        )
                        fairPriceRow(
                            label: "Pro Monthly",
                            price: "$\(AppPricing.monthlyUSD)/month",
                            note: "Lower commitment · cancel anytime"
                        )
                        fairPriceRow(
                            label: "Pro Lifetime",
                            price: "$\(AppPricing.lifetimeUSD)",
                            note: "Pay once · yours forever"
                        )
                        #if DEBUG
                        if !TestSupport.isUITest {
                            Text("Live purchase appears once the products are created in App Store Connect and Products.storekit is attached. Until then, use Debug unlock for QA.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        #endif
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Choose your plan")
            } footer: {
                Text(subscriptionFooter)
            }

            // Guideline 3.1.2: an auto-renewable subscription needs functional
            // Privacy Policy + Terms of Use (EULA) links right by the purchase.
            // "Terms of Use" opens the bundled custom EULA, which itself
            // incorporates Apple's standard Licensed Application EULA by
            // reference — so a separate Apple-EULA link would be redundant.
            Section("Legal") {
                Button("Privacy Policy") { legalPath = .privacy }
                Button("Terms of Use (EULA)") { legalPath = .terms }
            }

            Section {
                Button("Restore purchases") {
                    Task { await entitlements.restore() }
                }
                Button("Manage subscription") {
                    Task { await manageSubscriptions() }
                }
                if entitlements.isPro {
                    Label("Pro active", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(Theme.accent)
                }
                if let error = entitlements.lastError ?? manageError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            #if DEBUG
            if TestSupport.isDebugMenuEnabled {
                Section("Debug") {
                    Toggle(
                        "Unlock Pro (local QA)",
                        isOn: Binding(
                            get: { entitlements.debugUnlocked },
                            set: { entitlements.setDebugUnlocked($0) }
                        )
                    )
                }
            }
            #endif
        }
        .readableContentWidth()
        .navigationTitle("Pro")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    NavigationMotion.pop(dismiss)
                }
            }
        }
        .task {
            await entitlements.loadProducts()
        }
        .navigationDestination(item: $legalPath) { route in
            switch route {
            case .privacy:
                LegalDocumentView(title: "Privacy Policy", resourceName: AppLegal.privacyResourceName)
            case .terms:
                LegalDocumentView(title: "Terms of Use", resourceName: AppLegal.termsResourceName)
            }
        }
    }

    private var subscriptionFooter: String {
        """
        Hummingbird Pro is available as an auto-renewable subscription — \
        Yearly ($\(AppPricing.yearlyUSD)/year, with a 7-day free trial) or Monthly ($\(AppPricing.monthlyUSD)/month) — \
        or as a one-time Lifetime purchase ($\(AppPricing.lifetimeUSD), non-renewing). \
        Payment is charged to your Apple ID at purchase confirmation; a free trial converts to a paid year unless cancelled \
        at least 24 hours before it ends. Subscriptions renew unless cancelled at least 24 hours before the period ends. \
        Manage or cancel a subscription in Settings → Apple ID → Subscriptions. \
        Pro unlocks on-device comparison tools only — never financial advice, never better foresight, never premium data. \
        Free and Pro share the same key-less public APIs.
        """
    }

    private func purchaseButton(_ product: Product, badge: String, identifier: String, highlighted: Bool = false) -> some View {
        Button {
            Task {
                let ok = await entitlements.purchase(product)
                if ok { NavigationMotion.pop(dismiss) }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(product.displayName)
                            .font(.headline)
                        if highlighted {
                            Text("BEST VALUE")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Theme.accent.opacity(0.18), in: Capsule())
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    Text(badge)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Theme.accent)
            }
        }
        // Gated on the real purchase status, not `isPro` — in TestFlight,
        // `isPro` is auto-true so testers can validate every Pro feature
        // without buying first, but the buy buttons must stay tappable so
        // the actual purchase flow itself is still testable end to end.
        .disabled(entitlements.hasRealPurchase)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel("\(product.displayName)\(highlighted ? ", best value" : ""), \(badge)")
        .accessibilityHint(product.subscription != nil ? "Auto-renewable subscription" : "One-time purchase")
    }

    private func fairPriceRow(label: String, price: String, note: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(price)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Theme.accent)
        }
    }

    private func percent(_ fraction: Double) -> String {
        String(format: "%.1f%%", fraction * 100)
    }

    private func manageSubscriptions() async {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else { return }
        do {
            try await AppStore.showManageSubscriptions(in: scene)
        } catch {
            manageError = error.localizedDescription
        }
    }
}

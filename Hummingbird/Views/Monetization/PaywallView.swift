import StoreKit
import SwiftUI
import UIKit

struct PaywallView: View {
    @Bindable var entitlements: EntitlementStore
    /// Exact gate that opened the paywall — fair, contextual, retail-simple.
    var reason: String? = nil
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
                    Text("Optional upgrade to compare every method in one place. Same free public data — not a better prediction.")
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
                        highlighted: true
                    )
                }

                if let monthly = entitlements.monthlyProduct {
                    purchaseButton(
                        monthly,
                        badge: "\(monthly.displayPrice)/month · cancel anytime"
                    )
                }

                if entitlements.products.isEmpty && !entitlements.isLoading {
                    VStack(alignment: .leading, spacing: 8) {
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
                        Text("Live purchase appears once the products are created in App Store Connect and Products.storekit is attached. Until then, use Debug unlock for QA.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Choose your plan")
            } footer: {
                Text(subscriptionFooter)
            }

            Section("Legal") {
                Button("Privacy Policy") { legalPath = .privacy }
                Button("Terms of Use") { legalPath = .terms }
                Link("Apple Standard EULA", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
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
            Section("Debug") {
                Toggle(
                    "Unlock Pro (local QA)",
                    isOn: Binding(
                        get: { entitlements.debugUnlocked },
                        set: { entitlements.setDebugUnlocked($0) }
                    )
                )
            }
            #endif
        }
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
        Hummingbird Pro is an auto-renewable subscription: \
        Yearly ($\(AppPricing.yearlyUSD)/year, with a 7-day free trial) or Monthly ($\(AppPricing.monthlyUSD)/month). \
        Payment is charged to your Apple ID at purchase confirmation; a free trial converts to a paid year unless cancelled \
        at least 24 hours before it ends. Subscriptions renew unless cancelled at least 24 hours before the period ends. \
        Manage or cancel in Settings → Apple ID → Subscriptions. \
        Pro unlocks on-device comparison tools only — never financial advice, never better foresight, never premium data. \
        Free and Pro share the same key-less public APIs.
        """
    }

    private func purchaseButton(_ product: Product, badge: String, highlighted: Bool = false) -> some View {
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
        .disabled(entitlements.isPro)
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

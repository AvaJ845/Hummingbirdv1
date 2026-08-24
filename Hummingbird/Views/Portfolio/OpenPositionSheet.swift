import SwiftUI

/// Predict-first buying: you state a direction — your lean — before committing
/// the cash, so a position is a view logged, never a blind tap. That lean is
/// shown back on the holding. The price is the latest end-of-day close, fetched
/// live; there is no real-time data and no way to buy at a made-up number.
struct OpenPositionSheet: View {
    let cash: Double
    var prefillSymbol: String?
    var prefillAssetClass: AssetClass = .stock
    let service: any MarketDataProviding
    /// symbol, assetClass, cashAmount, price, direction
    let onBuy: (String, AssetClass, Double, Double, CallDirection) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var symbol: String = ""
    @State private var assetClass: AssetClass = .stock
    @State private var price: Double?
    @State private var isFetching = false
    @State private var priceError: String?
    @State private var amount: Double = 0
    @State private var direction: CallDirection?

    var body: some View {
        NavigationStack {
            Form {
                symbolSection
                if let price {
                    amountSection(price: price)
                    convictionSection
                }
                disclaimerSection
            }
            .navigationTitle("Buy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Buy") { commit() }.disabled(!canBuy)
                }
            }
            .onAppear {
                if symbol.isEmpty, let prefillSymbol { symbol = prefillSymbol }
                assetClass = prefillAssetClass
                if amount == 0 { amount = min(1_000, cash) }
            }
            .task { if price == nil, !symbol.isEmpty { await fetchPrice() } }
        }
        .presentationDetents([.large])
    }

    // MARK: - Symbol + price

    private var symbolSection: some View {
        Section {
            Picker("Type", selection: $assetClass) {
                ForEach(AssetClass.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: assetClass) { _, _ in invalidatePrice() }

            HStack {
                TextField("Symbol (e.g. AAPL, bitcoin)", text: $symbol)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .onSubmit { Task { await fetchPrice() } }
                    .onChange(of: symbol) { _, _ in invalidatePrice() }
                if isFetching {
                    ProgressView()
                } else {
                    Button("Check price") { Task { await fetchPrice() } }
                        .font(.caption.weight(.semibold))
                        .disabled(symbol.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            if let price {
                Text("Latest close · \(price.asCurrency())")
                    .font(.caption).foregroundStyle(Theme.accent)
            } else if let priceError {
                Text(priceError).font(.caption).foregroundStyle(Theme.warning)
            }
        } header: {
            Text("What to buy")
        } footer: {
            Text("Bought at the most recent end-of-day close — never real-time.")
        }
    }

    // MARK: - Amount

    private func amountSection(price: Double) -> some View {
        Section {
            HStack {
                Text("Amount").font(.subheadline)
                Spacer()
                Text(amount.asCurrency()).font(.body.weight(.semibold)).monospacedDigit()
            }
            Slider(value: $amount, in: 0...max(cash, 1), step: 1)
                .tint(Theme.accent)
            HStack(spacing: 8) {
                quickAmount("25%", cash * 0.25)
                quickAmount("50%", cash * 0.50)
                quickAmount("Max", cash)
            }
            Text("≈ \((amount / price).formatted(.number.precision(.fractionLength(0...4)))) shares · \(cash.asCurrency()) available")
                .font(.caption).foregroundStyle(.secondary).monospacedDigit()
        } header: {
            Text("How much")
        }
    }

    private func quickAmount(_ label: String, _ value: Double) -> some View {
        Button(label) { amount = min(value, cash) }
            .font(.caption.weight(.semibold))
            .buttonStyle(.bordered)
            .tint(Theme.accentAlt)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("\(label), \(min(value, cash).asCurrency())")
    }

    // MARK: - Conviction (every buy is a call)

    private var convictionSection: some View {
        Section {
            HStack(spacing: 12) {
                directionButton(.higher, "Higher", "arrow.up.right")
                directionButton(.lower, "Lower", "arrow.down.right")
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        } header: {
            Text("Your lean")
        } footer: {
            Text("Which way from here? A position is a view, not a blind tap — your lean is shown on the holding so you can watch how it plays out.")
        }
    }

    // MARK: - Disclaimer

    private var disclaimerSection: some View {
        Section {
            Text("Practice only — virtual money, on your device. A record of the past, never advice.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - Logic

    private var canBuy: Bool {
        price != nil && direction != nil && amount >= 1 && amount <= cash + 1e-6 && !isFetching
    }

    private func commit() {
        guard let price, let direction else { return }
        let sym = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sym.isEmpty, amount >= 1 else { return }
        onBuy(sym, assetClass, amount, price, direction)
        dismiss()
    }

    private func invalidatePrice() {
        price = nil
        priceError = nil
    }

    private func fetchPrice() async {
        let sym = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sym.isEmpty else { return }
        isFetching = true
        priceError = nil
        price = nil
        defer { isFetching = false }
        do {
            let series = try await service.history(symbol: sym, assetClass: assetClass)
            if series.isSample {
                priceError = "Live price unavailable right now — try again in a bit."
            } else if let close = series.last?.close {
                price = close
                if amount > cash { amount = cash }
            } else {
                priceError = "No price found for \(sym.uppercased())."
            }
        } catch {
            priceError = "Couldn't fetch a price for \(sym.uppercased())."
        }
    }

    // MARK: - Controls

    private func directionButton(_ dir: CallDirection, _ label: String, _ icon: String) -> some View {
        let selected = direction == dir
        let tint = dir == .higher ? Theme.up : Theme.down
        return Button {
            direction = dir
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.title3)
                Text(label).font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(selected ? tint.opacity(0.16) : Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(selected ? tint : .clear, lineWidth: 2))
            .foregroundStyle(selected ? tint : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label)\(selected ? ", selected" : "")")
    }
}

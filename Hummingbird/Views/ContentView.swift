import SwiftUI

struct ContentView: View {
    @StateObject private var vm = ForecastViewModel()
    @FocusState private var symbolFocused: Bool
    @State private var showModelPicker = false
    @State private var showIndicators = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    inputCard
                    if let error = vm.errorMessage {
                        errorBanner(error)
                    }
                    if vm.isLoading {
                        loadingCard
                    } else if let forecast = vm.forecast, vm.hasResult {
                        resultsSection(forecast)
                    } else {
                        emptyState
                    }
                    disclaimer
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Hummingbird")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showIndicators = true } label: {
                        Image(systemName: "building.columns")
                    }
                    .accessibilityLabel("Economic indicators")
                }
            }
            .sheet(isPresented: $showModelPicker) {
                ModelPickerSheet(selection: $vm.model)
                    .onDisappear { vm.recomputeForecast() }
            }
            .sheet(isPresented: $showIndicators) {
                EconomicIndicatorsSheet()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "bird.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Theme.brandGradient)
                .padding(.top, 4)
            Text("Digital Asset & Stock Forecasting")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("On-device predictions with economic context")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Input

    private var inputCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Asset type", selection: $vm.assetClass) {
                    ForEach(AssetClass.allCases) { klass in
                        Label(klass.rawValue, systemImage: klass.systemImage).tag(klass)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: vm.assetClass) { _, newValue in
                    vm.symbol = newValue.placeholder
                }

                VStack(alignment: .leading, spacing: 6) {
                    TextField(vm.assetClass.placeholder, text: $vm.symbol)
                        .textInputAutocapitalization(vm.assetClass == .stock ? .characters : .never)
                        .autocorrectionDisabled()
                        .focused($symbolFocused)
                        .submitLabel(.go)
                        .onSubmit { Task { await vm.run() } }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.tertiarySystemGroupedBackground)))
                    Text(vm.assetClass.hint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Forecast horizon")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text("\(vm.horizon) days")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    }
                    Slider(value: Binding(
                        get: { Double(vm.horizon) },
                        set: { vm.horizon = Int($0) }
                    ), in: 7...90, step: 1)
                    .onChange(of: vm.horizon) { _, _ in vm.recomputeForecast() }
                }

                Button {
                    showModelPicker = true
                } label: {
                    HStack {
                        Image(systemName: vm.model.systemImage)
                            .foregroundStyle(Theme.brandGradient)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(vm.model.name).font(.subheadline.weight(.semibold))
                            Text("Model").font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        ConfidenceBadge(confidence: vm.model.confidence)
                        Image(systemName: "chevron.right")
                            .font(.caption).foregroundStyle(.tertiary)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.tertiarySystemGroupedBackground)))
                }
                .buttonStyle(.plain)

                Button {
                    symbolFocused = false
                    Task { await vm.run() }
                } label: {
                    Text("Forecast")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(vm.isLoading)
            }
        }
    }

    // MARK: - Results

    private func resultsSection(_ forecast: Forecast) -> some View {
        VStack(spacing: 16) {
            if vm.usingSampleData {
                sampleBanner
            }
            metrics(forecast)
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(vm.symbol.uppercased())
                            .font(.headline)
                        Spacer()
                        Text("\(forecast.model.name) · \(vm.horizon)d")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForecastChart(forecast: forecast)
                    legend
                }
            }
            forecastDetail(forecast)
        }
    }

    private func metrics(_ forecast: Forecast) -> some View {
        let change = forecast.expectedChange
        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                MetricTile(
                    title: "Current",
                    value: (forecast.lastClose ?? 0).asCurrency(),
                    subtitle: "Last close"
                )
                MetricTile(
                    title: "Target",
                    value: (forecast.targetPrice ?? 0).asCurrency(),
                    subtitle: forecast.targetDate.map { $0.formatted(.dateTime.month().day()) },
                    valueColor: Theme.changeColor(change)
                )
            }
            HStack(spacing: 10) {
                MetricTile(
                    title: "Expected change",
                    value: change?.asSignedPercent() ?? "—",
                    subtitle: "Over \(vm.horizon) days",
                    valueColor: Theme.changeColor(change)
                )
                MetricTile(
                    title: "Confidence",
                    value: forecast.model.confidence.rawValue,
                    subtitle: forecast.model.name
                )
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: .secondary, label: "History", dashed: false)
            legendItem(color: Theme.accent, label: "Forecast", dashed: true)
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.accent.opacity(0.18))
                    .frame(width: 16, height: 10)
                Text("80% range").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func legendItem(color: Color, label: String, dashed: Bool) -> some View {
        HStack(spacing: 5) {
            Rectangle()
                .fill(color)
                .frame(width: 16, height: 2)
                .opacity(dashed ? 0.9 : 1)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func forecastDetail(_ forecast: Forecast) -> some View {
        Card {
            DisclosureGroup {
                VStack(spacing: 0) {
                    ForEach(Array(stride(from: 0, to: forecast.points.count, by: max(1, forecast.points.count / 10))), id: \.self) { i in
                        let p = forecast.points[i]
                        HStack {
                            Text(p.date.formatted(.dateTime.month().day()))
                                .font(.subheadline)
                            Spacer()
                            Text(p.mean.asCurrency())
                                .font(.subheadline.weight(.medium))
                            Text("±\((p.upper - p.mean).asCurrency(maximumFractionDigits: 0))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 70, alignment: .trailing)
                        }
                        .padding(.vertical, 8)
                        if i < forecast.points.count - 1 { Divider() }
                    }
                }
                .padding(.top, 8)
            } label: {
                Label("Forecast detail", systemImage: "list.bullet.rectangle")
                    .font(.subheadline.weight(.semibold))
            }
            .tint(.primary)
        }
    }

    // MARK: - Auxiliary states

    private var loadingCard: some View {
        Card {
            HStack(spacing: 12) {
                ProgressView()
                Text("Fetching data & modeling…")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }

    private var emptyState: some View {
        Card {
            VStack(spacing: 10) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.largeTitle)
                    .foregroundStyle(Theme.brandGradient)
                Text("Pick an asset and tap Forecast")
                    .font(.headline)
                Text("Hummingbird pulls recent price history and projects it forward on-device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.orange.opacity(0.12)))
    }

    private var sampleBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.slash").foregroundStyle(.secondary)
            Text("Showing sample data — live prices weren't reachable.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground)))
    }

    private var disclaimer: some View {
        Text("Forecasts are statistical estimates for educational use only and are not financial advice. Markets are unpredictable; never invest based solely on a model.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .padding(.top, 8)
    }
}

#Preview {
    ContentView()
}

import Foundation
import SwiftUI

@MainActor
final class ForecastViewModel: ObservableObject {
    // Inputs
    @Published var assetClass: AssetClass = .crypto
    @Published var symbol: String = "bitcoin"
    @Published var horizon: Int = 30
    @Published var model: ForecastModel = .default

    // Outputs
    @Published private(set) var series: PriceSeries?
    @Published private(set) var forecast: Forecast?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var usingSampleData = false

    private let service = MarketDataService()

    var hasResult: Bool { forecast != nil && !(forecast?.points.isEmpty ?? true) }

    func run() async {
        let trimmed = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = MarketDataError.emptySymbol.errorDescription
            return
        }
        guard model.status.isAvailable else {
            errorMessage = "\(model.name) isn't available yet. Pick a ready model."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fetched = try await service.history(symbol: trimmed, assetClass: assetClass)
            self.series = fetched
            self.usingSampleData = fetched.isSample
            self.forecast = Forecaster.forecast(series: fetched, model: model, horizon: horizon)
        } catch {
            self.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            self.series = nil
            self.forecast = nil
        }
    }

    /// Recompute the forecast from the already-fetched series (fast; no network).
    func recomputeForecast() {
        guard let series else { return }
        forecast = Forecaster.forecast(series: series, model: model, horizon: horizon)
    }
}

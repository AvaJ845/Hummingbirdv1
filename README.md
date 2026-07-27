# Hummingbird

A native iOS app for **on-device stock & crypto price forecasting with economic context** —
a SwiftUI reimagining of the original [HummingBirdv2](https://github.com/AvaJ845/HummingBirdv2)
Streamlit tool.

Where the original ran Python + Prophet on a server, Hummingbird runs everything **on the phone**:
no backend, no API keys, no account.

## Features

- **Assets** — forecast stocks (ticker) or crypto (coin id).
- **On-device forecasting** — statistical models written in Swift, no server round-trip:
  - **Skylark** — linear trend + weekly seasonality (default, high confidence)
  - **Meadowlark** — pure least-squares trend
  - **Swift** — EMA momentum
  - **Kingfisher** — mean reversion (beta)
  - **Phoenix** — blended ensemble (coming soon)
- **Adjustable horizon** — 7–90 days, recomputed instantly.
- **Charts** — history, dashed forecast line, and an 80% confidence band (Swift Charts).
- **Metrics** — current price, target, expected change, model confidence.
- **Economic indicators** — FRED-style macro context panel.
- **Graceful offline** — falls back to deterministic sample data when prices can't be fetched,
  with a clear banner.

Forecasts are statistical estimates for educational use only — **not financial advice.**

## Data sources

- Crypto: [CoinGecko](https://www.coingecko.com/) `market_chart` (key-less)
- Stocks: [Stooq](https://stooq.com/) daily CSV (key-less)

## Architecture

```
Hummingbird/
├── HummingbirdApp.swift            App entry
├── Models/Models.swift             Asset, PriceSeries, Forecast, ForecastModel, EconomicIndicator
├── Services/
│   ├── MarketDataService.swift     Async price fetching + sample fallback
│   └── Forecaster.swift            On-device statistical forecasting
├── ViewModels/ForecastViewModel.swift
├── Views/
│   ├── ContentView.swift           Main screen
│   ├── ForecastChart.swift         Swift Charts visualization
│   ├── ModelPickerSheet.swift
│   ├── EconomicIndicatorsSheet.swift
│   └── Components.swift            Reusable cards, tiles, badges
└── Support/Theme.swift             Colors, gradient, formatters
```

## Build & run

Requires Xcode 16+ (built with Xcode 26). The project is generated with
[XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
xcodegen generate
open Hummingbird.xcodeproj
```

Then run on any iOS 17+ simulator or device.

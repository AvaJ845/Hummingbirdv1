# Hummingbird

A native SwiftUI iOS app for **on-device statistical stock & crypto price "sketches" with economic context** — a reimagining of the original [HummingBirdv2](https://github.com/AvaJ845/HummingBirdv2) Streamlit tool.

Where the original ran Python + Prophet on a server, Hummingbird runs everything **on the phone**: no backend, no API keys, no account.

> Projections are statistical sketches for **education only** — not financial advice, price targets, or predictions. This framing is deliberate and appears on every surface.

## Features

- **On-device methods** (simple math over public history — not calibrated forecasts):
  - **Drift · Trend + weekday · Straight trend · Holt** — free
  - **Momentum · Mean reversion · Blend** — Pro
- **Honest track record** — walk-forward backtest per method; a "Best recent" marker shows which has tracked an asset closest lately.
- **Plain-English** — Easy/Details modes, a retail summary, and a "Why this sketch?" breakdown of the drivers.
- **Live** — adaptive auto-refresh (crypto vs. market-hours-aware stocks), price-flash, and background refresh (`BGTaskScheduler`) so the widget and alerts stay fresh.
- **Watchlist & Home** — save assets, glanceable best-method sparklines, quick-add.
- **Presence** — configurable **WidgetKit** widget, **Siri/App Intents** ("Project an asset in Hummingbird"), and honest **movement alerts** (local notifications — movement, never signals).
- **Share** — export a projection as a branded image card with the not-advice caveat baked in.
- **Polish** — honesty-first onboarding, alternate app icons (Classic/Midnight/Mono), full accessibility pass (Dynamic Type to AX5 + VoiceOver).
- **Hummingbird Pro** — StoreKit 2; **$19.99/year** (7-day free trial), **$2.99/month**, or a one-time **$49.99 Lifetime** unlock; unlocks comparison depth (more methods, 90-day horizons), not better data.
- **Private by design** — privacy manifest, no accounts, no tracking; graceful offline sample data with clear banners.

## Data sources

All key-less; adjusted-close preferred and bad ticks scrubbed (Hampel filter) before modeling.

| Asset / Macro | Source | Auth |
| --- | --- | --- |
| Crypto | [CoinGecko](https://www.coingecko.com/) primary; Yahoo `{TICKER}-USD` failover | Key-less |
| Stocks | [Yahoo Finance](https://finance.yahoo.com/) chart API (adjusted close) | Key-less |
| Rate what-ifs | Yahoo `^IRX`, `^TNX` (daily) | Key-less |

## Project layout

- `Hummingbird/` — app (Models, Services, ViewModels, Views, Support)
- `HummingbirdWidget/` — WidgetKit extension (App Intent-configurable)
- `HummingbirdTests/` — unit tests (~310; exact count shifts with ongoing changes)
- `AppStore/` — iPhone screenshots at 6.5″/6.7″/6.9″ + 13″ iPad, 1024 icon, and listing metadata (`METADATA.md`)
- `docs/` — GitHub Pages legal site (`privacy.html`, `terms.html`)

Bundle id `com.avaresearch.hummingbird` · App Group `group.com.avaresearch.hummingbird` · iOS 17+.

## Build & run

Generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen) (the `.xcodeproj` is gitignored):

```bash
xcodegen generate
open Hummingbird.xcodeproj
```

Simulator build/test without a signing team:

```bash
xcodebuild test -project Hummingbird.xcodeproj -scheme Hummingbird \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO
```

For device/release, set your team and let automatic signing register the App Group + profiles.

## Release

Store assets and the submission checklist live in [`AppStore/METADATA.md`](AppStore/METADATA.md). Legal pages are served from `docs/` via GitHub Pages.

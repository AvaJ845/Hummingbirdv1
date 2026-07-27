# Hummingbird

A native iOS app for **on-device statistical stock & crypto projections with economic context** —
a SwiftUI reimagining of the original [HummingBirdv2](https://github.com/AvaJ845/HummingBirdv2)
Streamlit tool.

Where the original ran Python + Prophet on a server, Hummingbird runs everything **on the phone**:
no backend, no API keys, no account.

Projections are statistical sketches for education only — **not financial advice, price targets, or predictions.**

## Features

- **Easy mode (default)** — plain English bottom line, possible range, and whether methods agree.
- **Agree-first results** — after Run, the first surface asks if simple methods agree.
- **Assets** — stocks (ticker) or crypto (coin id); optional mic dictation fills the field like typing.
- **On-device methods** (simple math on public history — not PhD-vetted forecasts):
  - **Drift** / **Trend + weekday** / **Straight trend** / **Holt** — free
  - **Momentum** / **Mean reversion** / **Blend** — Pro ($19.99/year)
- **Rate what-ifs** — live Yahoo daily yields only (`^IRX`, `^TNX`). Failures omitted (no fake samples).
- **Honest UI** — uncalibrated guess range, Steady/Typical/Experimental style labels, sample banners for offline prices.
- **Hummingbird Pro** — StoreKit 2 freemium (**$19.99/year** only). Same free APIs as Free. See [Docs/MONETIZATION.md](Docs/MONETIZATION.md).
- **Graceful offline** — deterministic sample data with clear banners.
- **Private by design** — privacy manifest; no tracking; no accounts.

## Data sources

All key-less. No paid API vendors in any plan.

| Asset / Macro | Source | Auth |
| --- | --- | --- |
| Crypto | [CoinGecko](https://www.coingecko.com/) primary; Yahoo `{TICKER}-USD` failover | Key-less |
| Stocks | [Yahoo Finance](https://finance.yahoo.com/) chart API | Key-less |
| Fed proxy / 10Y | Yahoo `^IRX`, `^TNX` (daily) | Key-less |

## Monetization (summary)

Fair & simple: free forever stays useful; Pro sells comparison depth, not prophecy. **No plan unlocks paid APIs** — same key-less public feeds for everyone (zero data-vendor overhead).

| Tier | Includes |
| --- | --- |
| Free | Drift, Trend + weekday, Straight trend, Holt, Easy Mode, ≤30d, daily rate what-ifs |
| Pro ($19.99/yr) | More methods to compare, ≤90d, full disagreement lab |

| Plan | Price | Role |
| --- | --- | --- |
| Yearly | $19.99 | Only Pro plan |

Details: [Docs/MONETIZATION.md](Docs/MONETIZATION.md) · App Store kit: [Docs/APP_STORE.md](Docs/APP_STORE.md) · Legal: [Docs/PRIVACY.md](Docs/PRIVACY.md), [Docs/TERMS.md](Docs/TERMS.md). Local StoreKit: `Products.storekit` (attached to Run scheme).

## Build & run

```bash
xcodegen generate
open Hummingbird.xcodeproj
```

Attach `Products.storekit` to the Run scheme for local purchases. iOS 17+.

```bash
xcodebuild -scheme Hummingbird -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

## Docs

- [Docs/ARCHITECTURE.md](Docs/ARCHITECTURE.md)
- [Docs/MONETIZATION.md](Docs/MONETIZATION.md)
- [Docs/APP_STORE.md](Docs/APP_STORE.md)
- [Docs/PRIVACY.md](Docs/PRIVACY.md)
- [Docs/TERMS.md](Docs/TERMS.md)

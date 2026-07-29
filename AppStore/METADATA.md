# App Store — Hummingbird

## Identity — Discovery (keyword-first, per the ASO playbook)
- **App Store Name (≤30):** `Stocks & Crypto - Hummingbird`  *(29 chars — primary keyword FIRST, brand second)*
  - **Decision:** plural `Stocks` — it's the higher-intent exact match users actually type, and Apple stems it to `stock` anyway, so nothing is lost. (Singular `Stock & Crypto - Hummingbird` was the alternative.)
  - Note: this is the **App Store listing name only.** The Home Screen name stays `Hummingbird` (CFBundleDisplayName) — same pattern as "Habit Tracker - Habit Kit" appearing as "Habit Kit" on device.
- **Subtitle (≤30):** `Charts, watchlist & projection`  *(30 chars — all new words, none repeated from the Name)*
  - Alts: `Price chart, watchlist, trend` *(29)* · `Tracker, charts & projections` *(29)*
- **Bundle ID:** com.avaresearch.hummingbird
- **Primary category:** Finance  ·  **Secondary:** Education
- **Age rating:** 4+ (no objectionable content)
- **Price:** Free. Optional **Hummingbird Pro** auto-renewable subscription — **$2.99/month** or **$19.99/year** (7-day free trial on the annual; annual saves ~44%). Group `Hummingbird Pro`.

## Promotional text (≤170)
Sketch where a stock or crypto *could* drift from public prices — with plain-English reasoning and honest backtests. Educational only. Never buy/sell advice.

## Keywords (≤100) — the hidden backend array
`bitcoin,ethereum,ticker,portfolio,market,finance,trend,widget,alert,tracker,price,etf,forecast`  *(94 chars)*

Rules applied (per the playbook): comma-separated, **no spaces**, **no word repeated** from the Name or Subtitle, **singulars only** (no `stocks`/`charts` here — they're covered above), and **no competitor names**. Because Apple indexes Name + Subtitle + Keywords as one string, these unique terms combine into phrases like `stock tracker`, `crypto chart`, `bitcoin price`, `crypto watchlist`, `stock market`, `etf tracker`, `crypto widget` — far more coverage than repeating words.

> **Decision on `forecast`:** kept **in the hidden array only** (never in the visible Name/Subtitle). It's high-intent and genuinely describes what the app does, and hidden keywords aren't a public claim — low App-Review risk when the entire UI/listing frames everything as *educational projections, not advice*. `prediction` and `signals` stay out entirely (too close to an advice claim). Dropped `coin`/`invest` to make room — they're well covered by `bitcoin`/`portfolio`/`finance` via stemming.

## Description
Hummingbird draws simple, honest "sketches" of where a stock or cryptocurrency **could** drift over the coming days — built entirely from public prices, right on your device. It is a learning tool, not a crystal ball: it never tells you to buy or sell.

**Honest by design**
• Several classic methods (trend, drift, Holt, momentum, mean-reversion) sketch a path — and you see when they disagree.
• "Best recent" shows which method has actually tracked an asset closest lately — a track record of the past, not a promise.
• Plain-English summaries explain what's driving each sketch.

**Yours, and private**
• Everything runs on your device. No account. No tracking.
• Save a watchlist with glanceable price + best-method sketches, a Home Screen widget, and Siri.
• Get an optional "it moved" alert — movement, never a signal.

**Hummingbird Pro (optional)**
Compare every method in one place and stretch sketches to 90 days. Same free public data — Pro is convenience, not better foresight.

Hummingbird is for learning and exploration only and is **not financial, investment, or trading advice.** Markets are unpredictable; never make money decisions based solely on this app.

## What's New (1.0)
First release: on-device price sketches for stocks & crypto, method comparison with honest backtests, watchlist, widget, Siri, and shareable sketch cards — educational, never advice.

## URLs
- **Support / Marketing:** https://avaj845.github.io/Hummingbirdv1/
- **Privacy Policy:** https://avaj845.github.io/Hummingbirdv1/privacy.html
- **Terms of Use (EULA):** https://avaj845.github.io/Hummingbirdv1/terms.html (or Apple standard EULA)

## Screenshots (6.9" — 1320×2868, in this folder)
1. `01_plain_english.png` — "Plain-English, not hype."
2. `02_best_method.png` — "Which method tracks best?"
3. `03_watchlist.png` — "Glanceable. Always fresh."
4. `04_any_asset.png` — "Sketch any stock or crypto."
5. `05_honest.png` — "Honest by design. Never advice."

App icon: `AppIcon-1024.png` (1024×1024, no alpha).

## App Privacy (nutrition label)
- **Data collected:** None. No account, no analytics/tracking SDKs.
- Network requests fetch only public market/economic data for the symbols you enter.
- Subscriptions handled by Apple (StoreKit); Hummingbird only learns whether Pro is active.

## Review notes (paste into App Review)
Hummingbird is an **educational** tool. It produces statistical "sketches" from public historical prices and clearly labels them as not predictions and **not financial advice** throughout (onboarding, results, share card, alerts, paywall). It contains no buy/sell signals, no brokerage, and no real-money trading. The subscription unlocks on-device comparison convenience only — identical public data to the free tier.

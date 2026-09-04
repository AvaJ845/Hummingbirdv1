# App Store — Hummingbird

## Identity
- **App Store Name (≤30):** `Hummingbird`  *(11 chars — clean brand name)*
  - **Decision:** the listing name is just the brand. Apple indexes App Store Name + Subtitle + the backend keyword field as one search string, so the search terms live in the Subtitle and the hidden keyword array — the name stays editorially clean and matches `CFBundleDisplayName`, which is already `Hummingbird`.
  - Note: the **Home Screen name is also `Hummingbird`** (CFBundleDisplayName) — listing name and device name match.
- **Subtitle (≤30):** `Honest on-device price sketches`  *(31 chars — leads with the honesty-first promise and carries the search terms `on-device` / `price` / `sketches`. NOTE: this is 1 char over Apple's 30-char subtitle limit — trim to `On-device price sketches` (24) or `Honest on-device price sketch` (29) when pasting into App Store Connect.)*
- **Bundle ID:** com.avaresearch.hummingbird
- **Primary category:** Finance  ·  **Secondary:** Education
- **Age rating:** 4+ (no objectionable content)
- **Price:** Free. Optional **Hummingbird Pro** auto-renewable subscription — **$2.99/month** or **$19.99/year** (7-day free trial on the annual; annual saves ~44%). Group `Hummingbird Pro`.

## Promotional text (≤170)
The rare forecast app that shows you how wrong it's been. Honest, on-device price sketches with a live accuracy track record. Educational only — never advice.  *(≈150 chars; leads with the radical-honesty differentiator per the Evangelism Fellow's note)*

## Keywords (≤100) — the hidden backend array
`bitcoin,ethereum,ticker,portfolio,market,finance,trend,widget,alert,tracker,etf,forecast,crypto`  *(95 chars)*

Rules applied: comma-separated, **no spaces**, **no word repeated** from the Name or Subtitle, **singulars only**, and **no competitor names**. `price` was removed because it now lives in the Subtitle (`Honest on-device price sketches`) and Apple indexes Name + Subtitle + Keywords as one set — repeating a word buys nothing. `crypto` was added with the freed space: it's a distinct high-volume term not covered by stemming `bitcoin`/`ethereum`. The unique terms combine into phrases like `crypto tracker`, `bitcoin price`, `crypto watchlist`, `stock market`, `etf tracker`, `crypto widget`, `price forecast`.

> **Decision on `forecast`:** kept **in the hidden array only** (never in the visible Name/Subtitle). It's high-intent and genuinely describes what the app does, and hidden keywords aren't a public claim — low App-Review risk when the entire UI/listing frames everything as *educational projections, not advice*. `prediction` and `signals` stay out entirely (too close to an advice claim). `coin`/`invest` stay out — well covered by `bitcoin`/`portfolio`/`finance` via stemming.

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
First public release: on-device price sketches for stocks & crypto, method comparison with honest backtests, watchlist, widget, Siri, and shareable sketch cards — educational, never advice.

## URLs
- **Support / Marketing:** https://avaj845.github.io/Hummingbirdv1/
- **Privacy Policy:** https://avaj845.github.io/Hummingbirdv1/privacy.html
- **Terms of Use (EULA):** https://avaj845.github.io/Hummingbirdv1/terms.html (or Apple standard EULA)

## Screenshots (6.9" — 1320×2868, in this folder)
Order leads with the differentiator (radical honesty / the accuracy record),
then plain-English, then depth:
1. `01_honest.png` — "See how wrong it's been." (the honest accuracy record — the hook)
2. `02_plain_english.png` — "Plain-English, not hype."
3. `03_best_method.png` — "Which method tracks best?"
4. `04_watchlist.png` — "Glanceable. Always fresh."
5. `05_any_asset.png` — "Sketch any stock or crypto."

> **Re-shoot required before submission.** All five current images predate the
> round-1/2 changes: they show the old brand mark and app icon, the old
> "Run projection" / "Call it first" home screen, and the pre-reorder
> onboarding. `01_honest.png` is currently the onboarding "Sketches, not
> predictions" page captioned for honesty — the stronger hero is a real capture
> of the **Accuracy report** (Settings → Accuracy report) showing the median
> error / calibration record, captioned "See how wrong it's been."

App icon: `AppIcon-1024.png` (1024×1024, no alpha) — regenerate with
`sh AppStore/icon/render.sh`.

## App Privacy (nutrition label)
- **Data collected:** None. No account, no analytics/tracking SDKs.
- Network requests fetch only public market/economic data for the symbols you enter.
- Subscriptions handled by Apple (StoreKit); Hummingbird only learns whether Pro is active.

## Review notes (paste into App Review)
Hummingbird is an **educational** tool. It produces statistical "sketches" from public historical prices and clearly labels them as not predictions and **not financial advice** throughout (onboarding, results, share card, alerts, paywall). It contains no buy/sell signals, no brokerage, and no real-money trading. The subscription unlocks on-device comparison convenience only — identical public data to the free tier.

# App Store metadata — Hummingbird

**`AppStore/METADATA.md` is the canonical source for all App Store copy.** This file is a
convenience mirror of the paste-ready blocks; if anything here disagrees with
`AppStore/METADATA.md`, that file wins. Verify character counts before pasting.

---

## App Store Name (≤30)
```
Stocks & Crypto - Hummingbird
```
29 chars. Keyword-forward — highest-intent category terms first, brand last. This is the
**listing name only**; the Home Screen name stays `Hummingbird` (`CFBundleDisplayName`).

## Subtitle (≤30)
```
Honest on-device price sketch
```
29 chars. Singular `sketch` so it fits Apple's 30-char limit — Apple stems it to `sketches`.

## Promotional Text (≤170, editable anytime without review)
```
The rare forecast app that shows you how wrong it's been. Honest, on-device price sketches with a live accuracy track record. Educational only — never advice.
```

## Keywords (≤100, comma-separated, no spaces)
```
bitcoin,ethereum,xrp,ticker,portfolio,market,finance,trend,widget,alert,tracker,price,etf,forecast
```
98 chars (live value). No repeat of the Name (`stocks`/`crypto`). `price` also appears in the Subtitle — redundant slot, swap later.

## Description
```
Hummingbird draws simple, honest "sketches" of where a stock or cryptocurrency could drift over the coming days — built entirely from public prices, right on your device. It is a learning tool, not a crystal ball: it never tells you to buy or sell.

Honest by design
• Several classic methods (trend, drift, Holt, momentum, mean-reversion) sketch a path — and you see when they disagree.
• "Best recent" shows which method has actually tracked an asset closest lately — a track record of the past, not a promise.
• Plain-English summaries explain what's driving each sketch.

Yours, and private
• Everything runs on your device. No account. No tracking.
• Save a watchlist with glanceable price + best-method sketches, a Home Screen widget, and Siri.
• Get an optional "it moved" alert — movement, never a signal.

Hummingbird Pro (optional)
Compare every method in one place and stretch sketches to 90 days. Same free public data — Pro is convenience, not better foresight.

Hummingbird is for learning and exploration only and is not financial, investment, or trading advice. Markets are unpredictable; never make money decisions based solely on this app.
```

## What's New (1.0)
```
First public release: on-device price sketches for stocks & crypto, method comparison with honest backtests, watchlist, widget, Siri, and shareable sketch cards — educational, never advice.
```

## Screenshots — honesty-led order (6.9" · 1320×2868)
1. `01_honest.png` — "See how wrong it's been." (the honest accuracy record — the hook)
2. `02_plain_english.png` — "Plain-English, not hype."
3. `03_best_method.png` — "Which method tracks best?"
4. `04_watchlist.png` — "Glanceable. Always fresh."
5. `05_any_asset.png` — "Sketch any stock or crypto."

All five need re-shooting against the current UI/icon before submission — see `AppStore/METADATA.md`.

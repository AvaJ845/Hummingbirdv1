# App Store Connect — Practice Portfolio release

Paste-ready copy for the release that adds the on-device **practice portfolio**
(scored vs. buy-and-hold and the market). Keeps the house rule: honest,
keyword-aware, and review-safe ("never advice / a record of the past / on-device"
is also what keeps a finance app out of App Review trouble). Verify character
counts before pasting.

---

## What's New in This Version (≤4000, editable per release)
```
NEW — Practice portfolio
Start with $10,000 in virtual cash and find out if your trades actually beat simply buying and holding — and the market (S&P). Every buy states your lean before you commit; every trade is scored honestly afterward. End-of-day prices, on your device, never advice.

• You vs. buy-and-hold vs. the market — see whether your trading added anything over doing nothing.
• Your directional reads, scored — how often the price moved the way you leaned, apart from your timing.
• A You-vs-buy-and-hold chart over time (Pro), plus a shareable record.

Also in this release: since you started the weekly lessons, see whether your calls got more accurate; the weekly question now goes quiet once you've answered it; and small refinements throughout.

Educational tool — projections from public prices, not predictions or financial advice.
```
(~730 chars)

---

## Promotional Text (≤170, editable anytime without review)
```
New: a practice portfolio. Start with $10,000 and see if your trades actually beat buy-and-hold — and the market. Honest, on-device, never advice.
```
(147)

---

## Screenshots — upload order

There is now **one canonical screenshot set**: `AppStore/` (6.9″ 1320×2868). The
old bright-green `marketing/appstore-screenshots/hero-*` set was removed — it
pushed the "beat buy-and-hold?" hook, which reads as an engagement game and not
the calm honest utility this app is. The canonical order leads with the accuracy
record instead:

1. `01_honest.png` — "See how wrong it's been." (the accuracy record — the hook)
2. `02_plain_english.png` — the plain-English read
3. `03_best_method.png` — the "best recent" backtest receipts
4. `04_watchlist.png` — glanceable value
5. `05_any_asset.png` — the simple input

The practice portfolio is a secondary, opt-in surface (round-2 change) and is
**not** a screenshot hero. Keep "never advice" visible in every caption band.

> All five images need re-shooting against the current UI/icon before submission —
> see `AppStore/METADATA.md`.

---

## Subtitle (≤30) — optional touch-up
- **Keep (recommended):** `Call it. Keep an honest score.` — 30 (unchanged; still the identity)
- Alternate leaning on the new feature: `Practice. Call it. Keep score.` — 30

## Keyword field (≤100, comma-separated, no spaces, don't repeat Name/Subtitle words)
Swap in the portfolio terms (drops the lower-value `tracker`, `calibration`, `trend`):
```
stock,crypto,bitcoin,ethereum,forecast,portfolio,paper,practice,watchlist,private,invest,market
```
(95) — test `buy`, `hold`, `prediction`, `solana` against this over time.

---

## Description — block to insert
Add under the existing "SEE IF YOU BEAT THE METHODS" section:
```
PRACTICE PORTFOLIO — BEAT BUY-AND-HOLD?
Start with $10,000 in virtual cash. State your lean before each buy, then see the one number that matters: did your trading beat simply holding your first picks — and the market? End-of-day prices, on-device, never advice. The win is "did you beat doing nothing," never "did the number go up."
```

---

## Notes
- No new IAP products required — the chart is gated by the existing Pro entitlement
  (see `app-store-connect-iap.md`).
- Privacy nutrition label unchanged: still **no data collected** (portfolio is
  on-device only).
- Review notes: reiterate the practice portfolio uses **virtual money and
  end-of-day prices**, is a record/education tool, and gives no advice or signals.

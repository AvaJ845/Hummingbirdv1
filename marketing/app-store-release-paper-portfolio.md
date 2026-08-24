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

Use the three captioned heroes in `marketing/`… (exported at 6.9″ 1320×2868 and
6.5″ 1242×2688). Lead with the boldest, most legible hooks — a new, unknown app
has ~2 seconds to catch a scroller, so slots 1–2 must land on their own.

1. **hero-1-beat-buy-and-hold** — "Do you actually beat buy-and-hold?" (the relatable, scroll-stopping hook + the new feature)
2. **hero-3-call-it** — "Call it before you peek." (the app's signature accountability loop)
3. **hero-2-scored-honestly** — "Every trade, scored honestly." (the receipts)
4. Accuracy report — "shows its work, misses and all."
5. A sketch + reliability meter — the honest forecast.

Keep "never advice" visible somewhere in the caption band. A/B worth testing:
swap slots 1↔2 (portfolio hook vs. app identity) and measure tap-through.

*(Both size buckets required by App Store Connect are provided; the 6.9″ set is
primary.)*

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

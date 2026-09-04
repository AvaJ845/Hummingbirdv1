# App Store Connect — Practice Portfolio release

Paste-ready copy for the release that adds the on-device **practice portfolio**
(scored vs. buy-and-hold and the market). Keeps the house rule: honest,
keyword-aware, and review-safe ("never advice / a record of the past / on-device"
is also what keeps a finance app out of App Review trouble). Verify character
counts before pasting.

---

## What's New in This Version (≤4000, editable per release)
```
NEW — Practice portfolio (optional)
Turn on Practice tools to run a virtual $10,000 portfolio with end-of-day prices. It answers one honest question: did your trading do anything that simply buying and holding your first picks wouldn't have — and the market (S&P)? On your device, virtual money only, never advice.

• You vs. buy-and-hold vs. the market — see whether your trading added anything over doing nothing.
• A You-vs-buy-and-hold chart over time (Pro), plus a shareable record.

Also in this release: small refinements throughout, and the weekly practice question now goes quiet once you've answered it.

Educational tool — projections from public prices, not predictions or financial advice.
```
(~730 chars)

---

## Promotional Text (≤170, editable anytime without review)
```
New: an optional practice portfolio — virtual $10,000 to see if your trades beat just buy-and-hold. On-device, never advice.
```
(124)

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

## Subtitle (≤30) — no change
Keep the canonical subtitle from `AppStore/METADATA.md` (`Honest on-device price
sketches`). The practice portfolio is an opt-in secondary surface and does not
earn a place in the Name or Subtitle.

## Keyword field (≤100) — no change for this release
Keep the canonical keyword array from `AppStore/METADATA.md`. `portfolio` and
`market` are already in it; `paper`/`practice` aren't worth displacing a
higher-value term for an opt-in feature. Revisit only if practice-mode adoption
proves high.

---

## Description — optional block to insert
Add as a short paragraph near the end of the description, clearly framed as an
opt-in extra (only surfaces once the user turns on Practice tools):
```
PRACTICE PORTFOLIO (OPTIONAL)
Turn on Practice tools to run a virtual $10,000 portfolio with end-of-day prices. It answers one honest question — did your trading do anything simply holding your first picks wouldn't have, and the market? On-device, virtual money only, never advice.
```

---

## Notes
- No new IAP products required — the chart is gated by the existing Pro entitlement
  (see `app-store-connect-iap.md`).
- Privacy nutrition label unchanged: still **no data collected** (portfolio is
  on-device only).
- Review notes: reiterate the practice portfolio uses **virtual money and
  end-of-day prices**, is a record/education tool, and gives no advice or signals.

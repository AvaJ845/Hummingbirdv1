# Hummingbird — ASO Playbook (applied)

The Habit Kit / Focus Kit developer drives ~$50K/mo with **98% organic App Store
search and $0 ads.** His method is a three-part engine feeding a flywheel:
**Discovery → Conversion → Momentum.** Below is that method applied to Hummingbird,
adapted for one difference: he sells habit trackers; we ship a *finance-adjacent,
deliberately non-advice* app — so we guard high-volume keywords against App-Review
risk and protect the "not advice" brand.

---

## ① Discovery (keywords) — *get found*  ✅ done
Full strings live in **`METADATA.md`**. Summary:

- **App Store Name** (heaviest field): `Hummingbird` — clean brand name. Search terms live in the Subtitle + keyword array, which Apple indexes alongside the Name anyway. Home Screen name is also `Hummingbird`.
- **Subtitle**: `Honest on-device price sketch` — honesty-first promise; carries `on-device` / `price` / `sketch`. (29 chars; singular `sketch` to fit the 30-char field, Apple stems it to `sketches`.)
- **Keyword array** (95/100): `bitcoin,ethereum,ticker,portfolio,market,finance,trend,widget,alert,tracker,etf,forecast,crypto` — no repeats, singulars, no competitors.

Because Apple indexes Name + Subtitle + Keywords as **one string**, the unique
terms combine into phrases we rank for: `crypto tracker`, `bitcoin price`,
`crypto watchlist`, `stock market`, `etf tracker`, `crypto widget`, `price forecast`.

**Guardrail:** `forecast` lives in the hidden array only; `prediction`/`signals`
stay out entirely (advice-claim risk).

**Maintenance:** track keyword rank monthly (AppFigures / Astro). Rotate the
lowest-ranking hidden keyword each update; re-validate ideas with an LLM.

---

## ② Conversion (screenshots) — *get downloaded*
You have **3–5 seconds**. The deck's proven rule: **authentic, functional UI beats
polished abstraction**; lead with your best *real* feature; never a welcome/lifestyle screen.

**Recommended order** (assets in this folder) — lead with the differentiator:
1. **`01_honest.png`** — "See how wrong it's been." The accuracy record IS the hook.
2. **`02_plain_english.png`** — the honest multi-method read in plain English.
3. **`03_best_method.png`** — the "best recent" backtest receipts (unique to Hummingbird).
4. **`04_watchlist.png`** — glanceable value + widget/live angle.
5. **`05_any_asset.png`** — the simple input (what they'll do).

Each already carries a bold caption + the not-advice line — good; the caption is
read faster than the screen.

> ⚠️ All five images are **stale** (pre round-1/2 UI + old icon/mark) and must be
> re-shot. `01_honest.png` should be a real capture of the **Accuracy report**
> screen, not the onboarding page it currently shows.

**Action items**
- [ ] **A/B test via Product Page Optimization** once live (App Store Connect → up to 3 treatments). First test to run: **#1 = the price-sketch chart with the confidence band** vs the current comparison card. The chart is the more *visually* striking hero; the deck says *don't assume — test.*
- [ ] Add a short **App Preview video** (15–30s) of one projection run — video autoplays and lifts conversion.
- [ ] Keep screenshots **truthful to the live UI** (Apple rejects mismatched marketing).

---

## ③ Momentum (reviews) — *dominate rankings*  ✅ prompt shipped
Apple/Google fold conversion + ratings back into ranking, so reviews compound.

- **Happy-moment prompt — implemented.** `ReviewPrompt` + `requestReview` fire only
  after the **3rd successful projection**, once per version, **never** at launch or
  after an error (`ContentView` triggers on `forecastGeneration`, which bumps only on
  a successful run). See `Hummingbird/Services/ReviewPrompt.swift`.
- **The Reply Loop** (process): respond to *every* review. Thank the good; fix the bad —
  a fixed issue often turns 1★ → 5★.
- **The Signature Hack** (process): support-email footer — *"If Hummingbird's been
  useful, a quick App Store review really helps a solo developer."*
- **The Roadmap Signal** (process): if ~20 reviews ask for the same thing (e.g. the Watch
  app, more asset classes), build it — and reply that you shipped it.

---

## The flywheel & the timeline
`keywords → impressions → authentic screenshots → happy moments → 5★ reviews →
algorithm rank-boost → win harder keywords → repeat.`

ASO is a **multi-year compounding asset, not a launch sprint.** Realistic curve:
invisible at launch → cracks Top 10 in smaller markets by ~month 6 → occasional US
Top 10 by year 1 → consistent Top 5 by year 3. **Commit to the marathon; the
algorithm rewards consistency.**

---

## One-look checklist
| Part | Item | Status |
|---|---|---|
| Discovery | Clean brand App Name | ✅ |
| Discovery | Searchable Subtitle (no repeats) | ✅ |
| Discovery | 100-char keyword array (deduped) | ✅ (95) |
| Conversion | Authentic, feature-first screenshots | ✅ set ready |
| Conversion | A/B test (Product Page Optimization) | ▢ after launch |
| Conversion | App Preview video | ▢ optional |
| Momentum | Happy-moment review prompt | ✅ shipped |
| Momentum | Reply loop / signature / roadmap | ▢ ongoing process |

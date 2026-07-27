# App Store — A+ submission kit

Use this for App Store Connect metadata, review notes, and screenshots so listing copy matches the app’s honesty.

## App information

| Field | Value |
| --- | --- |
| Name | Hummingbird |
| Subtitle (30) | Price sketches, not advice |
| Category | Finance (primary) / Education (secondary) |
| Content rights | Yes — you own or have rights to use |
| Age rating | 4+ (no unrestricted web, no mature content) |
| Development Team | `3L683975L8` (set in `project.yml`) |
| Version | 1.4.2 (build 7) |

## Description

```
Hummingbird sketches where a stock or crypto’s public price history might point next — on your iPhone, with simple models, in plain English.

• Easy Mode for newcomers — clear bottom line, possible range, compare methods
• Classic methods free: Drift, Trend + weekday, Straight trend, and Holt
• Optional daily rate what-ifs from Yahoo (^IRX / ^TNX)
• Pro ($19.99/year) adds more methods to compare and longer horizons — same free public data
• Same free public data for everyone — Pro is not “better data” or better foresight

Not financial advice. Not a signal service. Projections are educational sketches from history.
```

## Keywords (100 chars max)

```
stocks,crypto,projection,forecast,education,chart,investing,learn,drift,holt
```

## What’s New (1.4.2)

```
Agree comparison leads results. Method names only (no bird zoo). Pro is $19.99/year. Still not financial advice.
```

## Screenshot script (6.7" / 6.5")

Keep text short. Never show “Buy,” “Target,” “Will go up,” or bird nicknames. Cadence: **Daily only**.

1. **Home** — BrandMark hero + “Public prices in, a simple path out”
2. **Agree first** — “Do the methods agree?” as the post-Run surface
3. **Easy Mode** — plain English bottom line + possible range
4. **Methods** — Drift / Holt called out as classic (method names only)
5. **Rate what-ifs** — Daily · Yahoo only (^IRX / ^TNX)
6. **Pro paywall** — Always free + **$19.99/year** + Privacy/Terms

## Review notes (paste into ASC)

```
Hummingbird is an educational utility. It fetches public market history from key-less APIs and runs simple on-device models to sketch a path. It is not financial advice and does not claim accuracy.

Demo: enter AAPL (Stock) or bitcoin (Crypto) → Run projection. The first result surface asks whether simple methods agree. Easy Mode explains the path in plain English.

IAP: Hummingbird Pro is a single yearly auto-renewable subscription ($19.99/year) that unlocks more on-device comparison methods and up to 90-day horizons. Free and Pro use the same public data. Restore and Manage Subscription are on the Pro screen. Privacy Policy and Terms of Use are linked on the paywall (in-app + hosted URLs).

Dictation (optional): microphone + speech recognition only to fill a symbol field.
```

## App Privacy (nutrition label)

- **Data Not Collected** (no account, no analytics SDK, no tracking)
- Tracking: No
- Note: network calls to public data providers for symbols the user requests; purchases via Apple

## Attachments checklist (P0 — human)

- [ ] Product created in ASC: yearly **$19.99** (`com.hummingbird.app.pro.yearly`)
- [ ] Subscription group Hummingbird Pro
- [x] `DEVELOPMENT_TEAM` = `3L683975L8` in `project.yml`
- [ ] Privacy Policy URL hosted — `https://avaj845.github.io/Hummingbird/privacy.html`
- [ ] Terms of Use URL hosted — `https://avaj845.github.io/Hummingbird/terms.html`
- [ ] Enable GitHub Pages from `/docs` (static pages included) after push
- [x] `Products.storekit` on Run scheme (see project.yml)
- [ ] Screenshots: BrandMark → agree → Easy Mode → methods → rates → $19.99 paywall
- [ ] Support URL + marketing URL set
- [ ] Export compliance: uses exempt encryption only (HTTPS)

## Legal hosting

Bundle already includes `Hummingbird/Resources/Legal/PRIVACY.md` and `TERMS.md`.  
Static GitHub Pages sources live in `/docs` (`privacy.html`, `terms.html`, `index.html`).

Before submit:

1. Push repo to GitHub (`avaj845/Hummingbird` or your fork)
2. Settings → Pages → Deploy from branch `/docs`
3. Confirm URLs match `AppLegal.privacyPolicyURL` / `AppLegal.termsOfUseURL`
4. Paste the same URLs into App Store Connect → App Information

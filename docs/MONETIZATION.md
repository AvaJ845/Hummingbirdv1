# Hummingbird monetization

## Fellow standard: A+ fair and simple

1. **Free forever stays useful** — a newcomer can learn without paying.
2. **Pro sells comparison, not prophecy** — more methods to compare, never “better accuracy.”
3. **One fair price for untested results** — **$19.99 / year** only.
4. **Contextual ask** — the paywall says exactly what the user tried to unlock.
5. **No hostage UI** — core projection always works.
6. **No paid APIs in any plan** — same key-less public feeds for Free and Pro.
7. **Subscription compliance** — Restore, Manage Subscription, Privacy Policy, Terms of Use, auto-renew disclosure (Guideline 3.1.2).

## Data cost rule (non-negotiable)

Hummingbird ships with **zero API-key overhead**. Price and rate inputs come only from free, key-less public endpoints (plus on-device sample fallback).

| Plan | Data sources |
| --- | --- |
| Free | Same free public APIs |
| Pro | **Identical** free public APIs |

## Free forever

| Capability | Limit |
| --- | --- |
| Methods | Drift, Trend + weekday, Straight trend, Holt |
| Horizon | 7–30 days |
| Rate what-ifs | Both Yahoo daily series (^IRX, ^TNX) |
| Compare methods | Free methods only |
| Dictation | Included (fills ticker like typing) |
| Price history | Live free APIs + sample fallback (same as Pro) |
| Easy Mode | Included |

## Hummingbird Pro

| Product ID | Type | Price | Role |
| --- | --- | --- | --- |
| `com.hummingbird.app.pro.yearly` | Auto-renewable | **$19.99 / year** | **Only plan** (~$1.67/mo) |

Unlocks (**on-device comparison only** — same free APIs as Free):

- Momentum, Mean reversion, Blend — more methods to compare
- Horizons to 90 days
- Compare every method side by side

**Never sold:** paid APIs, premium quotes, “Pro data,” better foresight, or financial advice.

**Not offered:** monthly tip jar or lifetime unlock (keeps the ladder honest and simple).

## App Store Connect setup

1. Create **one** auto-renewable product: `com.hummingbird.app.pro.yearly` at **$19.99/year**.
2. Attach `Products.storekit` in the Xcode scheme (configured in `project.yml`).
3. Subscription group **Hummingbird Pro**.
4. Privacy Policy URL + Terms of Use URL — host `/docs` via GitHub Pages (`privacy.html` / `terms.html`) or paste identical text.
5. App Privacy: Data Not Collected / no tracking.
6. Review notes: educational sketches only — see `Docs/APP_STORE.md`.

## In-app compliance surface

Paywall includes: Always free / Pro adds, $19.99/year (live or placeholder), Restore, Manage Subscription, Privacy, Terms, Apple EULA, auto-renew footer.

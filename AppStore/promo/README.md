# Subscription promotional image

App Store Connect → **Subscriptions** (or **In-App Purchases**) → a product →
**Promotional Image** asks for a **1024 × 1024** image that "best represents
this subscription." It appears in:

- win-back offer sheets
- offer-code redemption sheets
- the app's product page, **only if** you enable *App Store Promotion* for the
  subscription

## Files (all 1024×1024, RGB, no alpha)

| File | Use |
| --- | --- |
| `SubscriptionPromo-Screenshot.png` | **Recommended.** The real paywall pixels — the "Choose your plan" card (Yearly $19.99 / Monthly $2.99 / Lifetime $49.99) + subscription terms — cropped straight from `raw-screens/08_paywall_plans.png` to a 1024 square. Regenerate: `python3 AppStore/promo/crop_paywall_1024.py`. |
| `SubscriptionPromo-Plans.png` | Same plans + pricing, but re-drawn (not a screenshot crop) — cleaner typography, no terms paragraph. |
| `SubscriptionPromo-Pro.png` | Mint hummingbird + a small "PRO" wordmark on the dark "Midnight" ground — a brand-mark treatment, premium-tier reading, no pricing. |
| `SubscriptionPromo.png` | Mark only, no text. |

Upload the same image for **each** Pro product (Yearly, Monthly, Lifetime) — they
all represent one thing, "Hummingbird Pro."

## Regenerate

```bash
python3 AppStore/promo/render_promo.py
```

Deterministic — reuses the exact hummingbird geometry from
`AppStore/icon/render.py`, so the promo art can never drift from the app icon.
The dark treatment is the same colourway as the `Midnight` alternate app icon
(`#0B0F0D` ground, `#D1ECDF` mark).

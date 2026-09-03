# App Store Connect — IAP setup

Create two products so Pro can actually be purchased. **Product IDs must match
the app exactly** (from `Products.storekit` / `EntitlementStore`):

| Product | Type | ID | Price | Notes |
|---|---|---|---|---|
| Pro Yearly | Auto-renewable subscription | `com.avaresearch.hummingbird.pro.yearly` | $19.99/yr | **7-day free trial** (intro offer) |
| Pro Monthly | Auto-renewable subscription | `com.avaresearch.hummingbird.pro.monthly` | $2.99/mo | — |

## 0. Prerequisite (the #1 blocker — do this first)
App Store Connect → **Business** → **Agreements, Tax, and Banking**:
- The **Paid Apps** agreement must be **Active**.
- Complete **Banking** + **Tax** forms.
**Without an active Paid Apps agreement, no IAP loads or sells — anywhere.**

## 1. Subscription group (create once)
Your app → **Monetization → Subscriptions** → **Create** a Subscription Group:
- **Reference Name:** `Hummingbird Pro`
- Group **Display Name** (shown to users): `Hummingbird Pro`

## 2. Add the two subscriptions to that group
For **each** (Yearly, then Monthly), inside the group → **Create**:

**Yearly**
- Reference Name: `Pro Yearly`
- Product ID: `com.avaresearch.hummingbird.pro.yearly`
- Duration: **1 Year**
- Price: **$19.99** (pick the closest price point)
- **Introductory Offer** → **Free** → **1 Week** (this is the 7-day trial)
- Localization (en-US):
  - Display Name: `Hummingbird Pro (Yearly)`
  - Description: `Yearly Pro — You vs. the methods, your full call record, and calibration depth. 7-day free trial. Educational, never advice.`

**Monthly**
- Reference Name: `Pro Monthly`
- Product ID: `com.avaresearch.hummingbird.pro.monthly`
- Duration: **1 Month**
- Price: **$2.99**
- No introductory offer.
- Localization (en-US):
  - Display Name: `Hummingbird Pro (Monthly)`
  - Description: `Monthly Pro — You vs. the methods, your full call record, and calibration depth. Educational, never advice.`

## 3. Review metadata (each product needs it)
- **Review screenshot:** upload the paywall screenshot (the "Choose your plan" screen showing both options). Any product's screenshot slot can use the same paywall shot.
- **Review notes** (paste into each):
  > Pro unlocks deeper views of the user's OWN on-device record — "You vs. the methods" (their own calls scored against the app's methods), full call history, and confidence calibration. It does NOT provide financial advice, buy/sell signals, price targets, or premium data — Free and Pro use the same key-less public data. To reach the paywall: Settings (gear) → Hummingbird Pro, or the "See the full report" prompt in "Your calls."

**Finance-app tip:** keep every description "educational / a record of the past / never advice." Reviewers scrutinize finance IAPs for implied advice — your honest framing is an asset here.

## 4. Testing vs. shipping
- **TestFlight (now):** once the products exist (state "Ready to Submit" is fine), TestFlight builds purchase them in the **Sandbox** automatically — no App Review needed. Add a **Sandbox Apple ID** (Users and Access → Sandbox Testers) to test buying.
- **App Store (later):** the IAPs must be **submitted with an app version** and approved before real purchases work in production. Attach both to the 1.x submission.

## 5. Sanity check after creating
- IDs are **exactly** the two above (a single typo = "product not found" and the paywall falls back to the static price rows).
- Prices/durations match the table.
- The 7-day trial is on **Yearly only**.
- Once created, a TestFlight build's paywall shows live prices + working purchase buttons (instead of today's fallback rows).

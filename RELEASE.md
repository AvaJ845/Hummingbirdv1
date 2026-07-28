# Hummingbird — Release Checklist

Everything to take Hummingbird from "ready" to "live on the App Store." The app,
tests, assets, and legal pages are done — the rest is account/config work
(~4–6 focused hours + a couple of short waits). Do the steps in order.

**Key facts**
- Bundle ID: `com.avaresearch.hummingbird`
- Subscription (IAP) Product ID: `com.avaresearch.hummingbird.pro.yearly` · $19.99/yr · group `HummingbirdPro`
- Team: `3L683975L8` (must be the **paid** Apple Developer Program, not a free personal team)
- Assets: `AppStore/` (five 1320×2868 screenshots, `AppIcon-1024.png`, `METADATA.md`)
- Legal: `docs/` via GitHub Pages → `https://avaj845.github.io/Hummingbirdv1/{privacy,terms}.html`

---

## 0 · Before anything (runs on Apple/Dun & Bradstreet's clock — start early)
- [ ] **Apple Developer Program — Organization**, $99/yr. Enroll at [developer.apple.com/account](https://developer.apple.com/account).
- [ ] **D-U-N-S number** for the LLC (required for Organization). Look up / request free: [dnb.com](https://www.dnb.com/duns-number/lookup.html). Can take a few days.
- [ ] Apple may do a quick **verification call** to the LLC — watch for it.

## 1 · If the repo is private, restore the legal pages first
GitHub Pages on a private repo needs GitHub Pro. Simplest: **make the repo public again** (or re-enable Pages) so these return HTTP 200 **before** you submit:
- [ ] `https://avaj845.github.io/Hummingbirdv1/privacy.html`
- [ ] `https://avaj845.github.io/Hummingbirdv1/terms.html`

## 2 · App Store Connect — one-time account setup
- [ ] **Agreements, Tax & Banking** → sign the Paid Apps agreement, add LLC bank + tax forms. *(Do this first — a paid subscription can't go live until it's complete.)*

## 3 · Create the app record
[App Store Connect](https://appstoreconnect.apple.com) → **Apps → +**
- [ ] Platform iOS · Name **Hummingbird** · Primary language English · Bundle ID `com.avaresearch.hummingbird` · SKU (any, e.g. `hummingbird-001`)
- [ ] **Subtitle:** `Honest, on-device sketches`
- [ ] **Category:** Finance (primary), Education (secondary) · **Age:** 4+
- [ ] Description / promo text / keywords → paste from `AppStore/METADATA.md`
- [ ] **Privacy Policy URL:** `https://avaj845.github.io/Hummingbirdv1/privacy.html`
- [ ] **App Privacy** ("nutrition label"): **Data Not Collected** (no account, no tracking)
- [ ] Upload the **5 screenshots** from `AppStore/` to the **6.9″** slot + set the 1024 icon

## 4 · Create the subscription
Apps → Hummingbird → **Subscriptions** → new group **Hummingbird Pro**, then a subscription:
- [ ] **Product ID:** `com.avaresearch.hummingbird.pro.yearly` *(must match exactly)*
- [ ] Reference name `Pro Yearly` · Duration **1 Year** · Price **$19.99** (USD tier)
- [ ] Display name `Hummingbird Pro` + description (from `METADATA.md`)
- [ ] Add a review screenshot + set to **Ready to Submit**
- [ ] Set the app's EULA to Apple's Standard, or your Terms URL

## 5 · Build & upload (Release)
The `xattr` pre-codesign phase is already wired, so signing is clean.

**Easiest (recommended for a first submission):**
- [ ] Open the project → in Xcode, select **Any iOS Device (arm64)**, then **Product → Archive** → **Distribute App → App Store Connect → Upload**. Xcode handles signing/export.

**Or via CLI:**
```bash
cd /path/to/Hummingbird
xcodegen generate
xcodebuild -project Hummingbird.xcodeproj -scheme Hummingbird \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath build/Hummingbird.xcarchive -allowProvisioningUpdates archive
# then: Xcode → Window → Organizer → select the archive → Distribute App
```
- [ ] Wait for the build to finish **processing** in App Store Connect (~10–30 min).

## 6 · Submit for review
- [ ] Attach the processed build to the version, attach the subscription to the submission.
- [ ] **App Review notes:** paste the "Review notes" block from `AppStore/METADATA.md`
      (educational tool, not advice, no trading, no accounts).
- [ ] **Submit.** Review typically takes ~24–48h.

---

## Sanity checks (all already true in the repo)
- [x] Release build **omits** the debug QA unlock (verified: 0 occurrences).
- [x] `isPro` in Release = real StoreKit purchases only.
- [x] Legal + not-advice framing on every surface.
- [x] `CODE_SIGNING_ALLOWED=NO` only for local sim builds — device/release uses your team.

## Optional after launch
- [ ] Add a 6.5″ screenshot set (some older listings still ask) — I can generate it.
- [ ] Push the CI workflow (`ci-workflow` branch) with a `workflow`-scoped token.
- [ ] Apple Watch app (needs a watchOS Simulator runtime / real Watch to finish).

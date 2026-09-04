# Hummingbird — Release Checklist

Everything to take Hummingbird from "ready" to "live on the App Store." The app,
tests, assets, and legal pages are done — the rest is account/config work
(~4–6 focused hours + a couple of short waits). Do the steps in order.

**Key facts**
- Bundle ID: `com.avaresearch.hummingbird`
- Pro products: `…pro.yearly` ($19.99/yr, 7-day free trial) · `…pro.monthly` ($2.99/mo) — auto-renewable subs in group `Hummingbird Pro`; plus `…pro.lifetime` ($49.99, non-consumable one-time unlock)
- Signing: your **paid** Apple Developer Program team (not a free personal team). Set it locally in `Config/Signing.xcconfig` — gitignored; copy from `Config/Signing.xcconfig.example`.
- Assets: `AppStore/raw-screens/` (12 real 1320×2868 device captures of the current UI — from the `HummingbirdUITests` screenshot harness; still need marketing frames + captions before upload); `AppIcon-1024.png` + `icon/` render step; `METADATA.md`
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
- [ ] Platform iOS · Name **`Stocks & Crypto - Hummingbird`** (listing name; Home Screen name stays `Hummingbird` via `CFBundleDisplayName`) · Primary language English · Bundle ID `com.avaresearch.hummingbird` · SKU (any, e.g. `hummingbird-001`)
- [ ] **Subtitle:** `Honest on-device price sketch` (29 chars — see `AppStore/METADATA.md`)
- [ ] **Keywords:** `bitcoin,ethereum,xrp,ticker,portfolio,market,finance,trend,widget,alert,tracker,price,etf,forecast` (98 chars)
- [ ] **Category:** Finance (primary), Education (secondary) · **Age:** 4+
- [ ] Description / promo text / keywords → paste from `AppStore/METADATA.md` — **the Description already ends with `Privacy Policy:` and `Terms of Use (EULA):` https:// lines. Keep them.** (This is the 3.1.2 fix — see below.)
- [ ] **Privacy Policy URL** (App Information): `https://avaj845.github.io/Hummingbirdv1/privacy.html`
- [ ] **License Agreement** (App Information) → **Custom** → `https://avaj845.github.io/Hummingbirdv1/terms.html` — **NOT "Standard Apple EULA".** ⚠️ **Skipping this = automatic 3.1.2 rejection** for a subscription app.
- [ ] **Both URLs return HTTP 200** — check in a browser before submitting. If the repo is private, GitHub Pages needs GitHub Pro; make the repo public or enable Pages (§1).
- [ ] **App Privacy** ("nutrition label"): **Data Not Collected** (no account, no tracking)
- [ ] **Screenshots** — raw re-shoot is **done**: `AppStore/raw-screens/*.png` are 12 real captures of the *current* UI (1320×2868, from the `HummingbirdUITests` harness — regenerate with the command in `AppStore/METADATA.md` §Screenshots). What's left is a **design pass**: add marketing frames + captions, pick the 3–5 strongest, order honesty-first (`11_accuracy_report` → `05_sketch_result` → `06_reliability` → `12_watchlist` → `04_home_empty`). Upload to the **6.9″** slot + set the 1024 icon (`sh AppStore/icon/render.sh`). The old `AppStore/0*_*.png` predate the round-1/2 UI and must not ship.

## 4 · Create the Pro products (3 total)

**4a · Subscriptions** — Apps → Hummingbird → **Subscriptions** → group **Hummingbird Pro**:
- [ ] **Yearly:** `com.avaresearch.hummingbird.pro.yearly` · ref `Pro Yearly` · **1 Year** · **$19.99** · add a **7-day free trial** (Introductory Offer → Free → 1 week)
- [ ] **Monthly:** `com.avaresearch.hummingbird.pro.monthly` · ref `Pro Monthly` · **1 Month** · **$2.99**
- [ ] Set both **Ready to Submit** (product IDs must match exactly)
- [ ] Display name `Hummingbird Pro` + description (from `METADATA.md`)

**4b · In-App Purchase (non-consumable)** — Apps → Hummingbird → **In-App Purchases**:
- [ ] **Lifetime:** `com.avaresearch.hummingbird.pro.lifetime` · type **Non-Consumable** · ref `Pro Lifetime` · **$49.99** · display name `Hummingbird Pro — Lifetime`
- [ ] Same feature set as the subscription — it's a one-time unlock, no renewal. Set **Ready to Submit**.

- [ ] Add a review screenshot for the group + the IAP (**use `AppStore/raw-screens/08_paywall_plans.png`** — re-capture first, it predates the Lifetime row) + set all to **Ready to Submit**
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
- [ ] Attach the processed build to the version; attach **all three** Pro products (Yearly, Monthly, Lifetime) to the submission.
- [ ] **App Review notes:** paste the "Review notes" block from `AppStore/METADATA.md`
      (educational tool, not advice, no trading, no accounts).
- [ ] **Submit.** Review typically takes ~24–48h.

### 3.1.2 pre-flight (do NOT submit until every box is checked)
The last app was rejected on 3.1.2 for a missing Terms-of-Use link. All of these must be true:
- [ ] The **App Description** contains the literal lines `Privacy Policy: https://…` and `Terms of Use (EULA): https://…` (they're in `METADATA.md`'s Description — paste it verbatim, don't trim the tail).
- [ ] **App Information → License Agreement = Custom**, set to `https://avaj845.github.io/Hummingbirdv1/terms.html`.
- [ ] **App Information → Privacy Policy URL** set to `https://avaj845.github.io/Hummingbirdv1/privacy.html`.
- [ ] Open both URLs in a private browser window → each returns a real page (HTTP 200), not a 404.
- [ ] The Description also states the subscription price, period, and renewal terms (it does — keep that paragraph).
- [ ] In-app: open the paywall on a device → **Privacy Policy** and **Terms of Use (EULA)** rows both open a readable document.

---

## Sanity checks (all already true in the repo)
- [x] Release build **omits** the debug QA unlock — the `debugUnlocked` property, `setDebugUnlocked`, and both toggle UIs are fully `#if DEBUG`; re-verified with `strings`/`nm` on a Release build (0 occurrences of `debugUnlock` / `proUnlocked` / `TestSupport` / `UITEST_`). Even in a Debug build the toggles need `-DEBUG_MENU`.
- [x] `isPro` in Release = real StoreKit purchases (or a TestFlight sandbox receipt — never a production App Store install).
- [x] Legal + not-advice framing on every surface.
- [x] In-app paywall shows working **Privacy Policy** + **Terms of Use (EULA)** links right by the purchase buttons (`PaywallView` Legal section) — the custom EULA (`TERMS.md` / `terms.html`) incorporates Apple's standard Licensed Application EULA by reference, so no separate Apple-EULA link is needed.
- [x] `METADATA.md` Description ends with plain-text `Privacy Policy:` / `Terms of Use (EULA):` https:// lines for the App Store product page (Guideline 3.1.2).
- [x] `CODE_SIGNING_ALLOWED=NO` only for local sim builds — device/release uses your team.

## Optional after launch
- [ ] Add a 6.5″ screenshot set (some older listings still ask) — I can generate it.
- [ ] Push the CI workflow (`ci-workflow` branch) with a `workflow`-scoped token.
- [ ] **Apple Watch app — one manual step left.** `HummingbirdWatch` (companion app) and
      `HummingbirdWatchWidget` (watch face complication) both exist and build clean
      standalone:
      ```bash
      xcodebuild build -project Hummingbird.xcodeproj -target HummingbirdWatch \
        -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'
      ```
      What's missing is embedding `HummingbirdWatch` as companion content inside the
      `Hummingbird` iOS target, so it ships as one bundle. Two XcodeGen-level attempts
      (`embed: true`, and the same with `platformFilter: ios`) both made the iOS scheme
      try to compile the watchOS-only widget under the iPhone SDK — a hard build
      failure. Fix it once, in Xcode itself: open `Hummingbird.xcodeproj`, select the
      `Hummingbird` target → **General** → **Frameworks, Libraries, and Embedded
      Content**, add `HummingbirdWatch.app`, and let Xcode wire the "Embed Watch
      Content" phase and its `platformFilters` itself (this is exactly the piece
      XcodeGen can't be told to do blind). Re-export `xcodegen dump` afterward isn't
      needed — Xcode's edit lives in the `.xcodeproj`, which is gitignored, so redo
      this step once per fresh `xcodegen generate` unless you move the wiring into
      `project.yml` by hand once you've seen the working pbxproj diff.

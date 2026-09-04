# Hummingbird — Release Checklist

Everything to take Hummingbird from "ready" to "live on the App Store." The app,
tests, assets, and legal pages are done — the rest is account/config work
(~4–6 focused hours + a couple of short waits). Do the steps in order.

**Key facts**
- Bundle ID: `com.avaresearch.hummingbird`
- Pro products: `…pro.yearly` ($19.99/yr, 7-day free trial) · `…pro.monthly` ($2.99/mo) — auto-renewable subs in group `Hummingbird Pro`; plus `…pro.lifetime` ($49.99, non-consumable one-time unlock)
- Signing: your **paid** Apple Developer Program team (not a free personal team). Set it locally in `Config/Signing.xcconfig` — gitignored; copy from `Config/Signing.xcconfig.example`.
- Device support: **Universal (iPhone + iPad)**, portrait-only, `UIRequiresFullScreen` (no Split View) — see `project.yml`
- Assets: 4 real screenshot sets from the `HummingbirdUITests` harness (current UI) — `raw-screens-6.5in/` (1242×2688), `raw-screens-6.7in/` (1284×2778), `raw-screens/` (1320×2868, 6.9″), `raw-screens-ipad/` (2064×2752, 13″); upload whichever iPhone size ASC's dimension check actually accepts + the iPad set; all still need marketing frames + captions; `AppIcon-1024.png` + `icon/` render step; `METADATA.md`
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
- [ ] **Screenshots** — raw re-shoot is **done** across four sets, all real device captures from the `HummingbirdUITests` harness (regenerate with the commands in `AppStore/METADATA.md` §Screenshots): `raw-screens-6.5in/` (1242×2688), `raw-screens-6.7in/` (1284×2778), `raw-screens/` (1320×2868, 6.9″), `raw-screens-ipad/` (2064×2752, 13″). **⚠️ If ASC's upload rejects a set for "wrong dimensions," it will name the exact accepted sizes — match the set above to that error message rather than assuming 6.9″.** (This happened on the first upload attempt: ASC asked for 1242×2688/1284×2778, not 1320×2868.) What's left is a **design pass**: add marketing frames + captions, pick the 3–5 strongest, order honesty-first (`11_accuracy_report` → `05_sketch_result` → `06_reliability` → `12_watchlist` → `04_home_empty`). Upload whichever iPhone size ASC accepts **plus the 13″ iPad set** (required once the app declares iPad support) + set the 1024 icon (`sh AppStore/icon/render.sh`). The old `AppStore/0*_*.png` predate the round-1/2 UI and must not ship.

## 4 · Create the Pro products (3 total)

**4a · Subscriptions** — Apps → Hummingbird → **Subscriptions** → group **Hummingbird Pro**:
- [ ] **Yearly:** `com.avaresearch.hummingbird.pro.yearly` · ref `Pro Yearly` · **1 Year** · **$19.99** · add a **7-day free trial** (Introductory Offer → Free → 1 week)
- [ ] **Monthly:** `com.avaresearch.hummingbird.pro.monthly` · ref `Pro Monthly` · **1 Month** · **$2.99**
- [ ] Set both **Ready to Submit** (product IDs must match exactly)
- [ ] Display name `Hummingbird Pro` + description (from `METADATA.md`)

**4b · In-App Purchase (non-consumable)** — Apps → Hummingbird → **In-App Purchases**:
- [ ] **Lifetime:** `com.avaresearch.hummingbird.pro.lifetime` · type **Non-Consumable** · ref `Pro Lifetime` · **$49.99** · display name `Hummingbird Pro — Lifetime`
- [ ] Same feature set as the subscription — it's a one-time unlock, no renewal. Set **Ready to Submit**.

- [ ] Add a review screenshot for the group + the IAP (**use `AppStore/raw-screens/08_paywall_plans.png`** — shows all three tiers + prices + trial) + set all to **Ready to Submit**
- [ ] EULA: leave it on the **custom** Terms URL set in §3 (App Information → License Agreement). Do **not** switch to Apple's Standard EULA — see the 3.1.2 pre-flight in §6.

## 5 · Build & upload (Release)
The `xattr` pre-codesign phase is already wired, so signing is clean. The
Apple Watch companion app embeds automatically too — see **Apple Watch app
embedding** below; no extra manual step, and plain `xcodegen generate` is all
you need (no wrapper script).

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

## Apple Watch app embedding
`HummingbirdWatch` (companion app) and `HummingbirdWatchWidget` (its
complication) now ship **inside** `Hummingbird.app` on every device/archive
build — `Hummingbird.app/PlugIns/HummingbirdWatch.app/PlugIns/HummingbirdWatchWidget.appex`
— with no manual Xcode step, and it survives a fresh `xcodegen generate` since
the mechanism lives entirely in `project.yml` + a checked-in script (nothing
you have to redo by hand in the `.xcodeproj`, which stays gitignored).

**Why this isn't a plain XcodeGen `dependencies: [{target: HummingbirdWatch,
embed: true}]`:** that *does* generate a working native "Embed Watch Content"
build phase + target dependency, and it builds and embeds correctly under
`xcodebuild build -destination '...'` alone. It breaks, however, the instant
`-sdk iphonesimulator` is passed explicitly on the command line — which is
exactly what this repo's baseline test command does. `-sdk` on the CLI forces
`SDKROOT=iphonesimulator` for **every** target in the build graph, including
nested watchOS-only ones, so `HummingbirdWatchWidget`'s watchOS-only APIs
(e.g. `WidgetFamily.accessoryCorner`) fail to compile under the iOS SDK. This
is an `xcodebuild -sdk` limitation, not a project misconfiguration — there's
no `platformFilter` (XcodeGen's is Mac-Catalyst-only: `iOS`/`macOS`/`all`,
confirmed against XcodeGen 2.44.1's docs) or other `project.yml` knob that
fixes it. This matches the two earlier failed attempts noted in this file's
history.

**The fix:** `HummingbirdWatch` is deliberately **not** an Xcode target
dependency of `Hummingbird` at all, so a plain
`xcodebuild build -scheme Hummingbird -sdk iphonesimulator ...` (the baseline
test command) never touches it — zero impact on the 315 unit + 6 UI test
suite. Instead, `Scripts/embed_watch_content.sh` runs as a Run Script build
phase on the `Hummingbird` target (wired via `postBuildScripts` in
`project.yml`, so it's regenerated automatically by every `xcodegen
generate` — no wrapper needed):
- No-ops immediately for simulator builds (`PLATFORM_NAME != iphoneos`) — the
  Watch companion has no meaning there; Watch Simulator pairing is a
  separate, independent flow.
- For device/archive builds, it runs a **separate nested `xcodebuild`**
  invocation (`-scheme HummingbirdWatch -sdk watchos`, its own
  `-derivedDataPath`) — always the correct watchOS SDK, regardless of what
  SDK the outer build was invoked with — then `ditto`s the built
  `HummingbirdWatch.app` into `Hummingbird.app/PlugIns/` (the Xcode 26
  location for companion watch apps — Xcode ≤25 used `Watch/`; see
  [XcodeGen#1613](https://github.com/yonaskolb/XcodeGen/issues/1613)) and
  re-signs it when signing is enabled.

Verified: `xcodebuild build test -sdk iphonesimulator -destination 'platform=iOS
Simulator,name=iPhone 17 Pro' ...` still passes 315+6 green with zero
warnings; `xcodebuild build -destination 'generic/platform=iOS'
CODE_SIGNING_ALLOWED=NO` succeeds and the built `.app` contains the full
nested bundle; `xcodebuild archive -destination 'generic/platform=iOS'
CODE_SIGNING_ALLOWED=NO` succeeds end-to-end (no signing required since
signing was disabled) with the same nested bundle present in the archive.

Along the way this also surfaced (and fixed) a pre-existing, unrelated bug:
`HummingbirdWatch` and `HummingbirdWatchWidget`'s `project.yml` source lists
included `Hummingbird/Services/SharedStorage.swift` but not
`Hummingbird/Models/PortfolioSnapshot.swift`, which `SharedStorage.swift`
references — meaning neither target actually compiled before now (only
`HummingbirdWidget` had the fix). Both target source lists now include it.

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

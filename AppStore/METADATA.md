# App Store — Hummingbird

## Identity
- **App Store Name (≤30):** `Stocks & Crypto - Hummingbird`  *(29 chars — keyword-forward: the two highest-intent category terms first, brand last)*
  - **Decision:** discovery over editorial-clean. Apple indexes App Store Name + Subtitle + the backend keyword field as one search string, and for a zero-audience launch the Name is the heaviest-weighted field — so `Stocks` and `Crypto` earn their place there. (The clean `Hummingbird` was the alternative.)
  - Note: this is the **App Store listing name only.** The **Home Screen name stays `Hummingbird`** (`CFBundleDisplayName`) — same pattern as "Habit Tracker - Habit Kit" showing as "Habit Kit" on device.
- **Subtitle (≤30):** `Honest on-device price sketch`  *(29 chars — leads with the honesty-first promise and carries the search terms `on-device` / `price` / `sketch`. No word repeats the Name. Singular `sketch` so it fits Apple's 30-char limit; Apple stems it to cover `sketches` too.)*
- **Bundle ID:** com.avaresearch.hummingbird
- **Primary category:** Finance  ·  **Secondary:** Education
- **Age rating:** 4+ (no objectionable content)
- **Price:** Free. Optional **Hummingbird Pro** — **$2.99/month** or **$19.99/year** (7-day free trial on the annual; annual saves ~44%) as an auto-renewable subscription (group `Hummingbird Pro`), **or a one-time $49.99 Lifetime unlock** (non-consumable, no renewal).

## Promotional text (≤170)
The rare forecast app that shows you how wrong it's been. Honest, on-device price sketches with a live accuracy track record. Educational only — never advice.  *(≈150 chars; leads with the radical-honesty differentiator per the Evangelism Fellow's note)*

## Keywords (≤100) — the hidden backend array
`bitcoin,ethereum,xrp,ticker,portfolio,market,finance,trend,widget,alert,tracker,price,etf,forecast`  *(98 chars — live value in App Store Connect)*

Rules applied: comma-separated, **no spaces**, **singulars only**, **no competitor names**. `stocks`/`crypto` are **not** here — they're in the Name, and Apple indexes Name + Subtitle + Keywords as one set, so repeating a word buys nothing. `xrp` is a supported asset (a distinct high-volume ticker not covered by stemming `bitcoin`/`ethereum`). `price` is also in the Subtitle (`Honest on-device price sketch`) so it's technically a redundant slot — could be swapped for `chart` or `coin` later, but harmless. The unique terms combine into phrases like `crypto tracker`, `bitcoin price`, `xrp price`, `crypto watchlist`, `stock market`, `etf tracker`, `crypto widget`, `price forecast`.

> **Decision on `forecast`:** kept **in the hidden array only** (never in the visible Name/Subtitle). It's high-intent and genuinely describes what the app does, and hidden keywords aren't a public claim — low App-Review risk when the entire UI/listing frames everything as *educational projections, not advice*. `prediction` and `signals` stay out entirely (too close to an advice claim). `coin`/`invest` stay out — well covered by `bitcoin`/`portfolio`/`finance` via stemming.

## Description
Hummingbird draws simple, honest "sketches" of where a stock or cryptocurrency **could** drift over the coming days — built entirely from public prices, right on your device. It is a learning tool, not a crystal ball: it never tells you to buy or sell.

**Honest by design**
• Several classic methods (trend, drift, Holt, momentum, mean-reversion) sketch a path — and you see when they disagree.
• "Best recent" shows which method has actually tracked an asset closest lately — a track record of the past, not a promise.
• Plain-English summaries explain what's driving each sketch.

**Yours, and private**
• Everything runs on your device. No account. No tracking.
• Save a watchlist with glanceable price + best-method sketches, a Home Screen widget, and Siri.
• Get an optional "it moved" alert — movement, never a signal.

**Hummingbird Pro (optional)**
Compare every method in one place and stretch sketches to 90 days. Same free public data — Pro is convenience, not better foresight. Hummingbird Pro is offered as an auto-renewable subscription — $19.99/year (7-day free trial) or $2.99/month — or as a one-time Lifetime purchase ($49.99). Payment is charged to your Apple ID at confirmation; a subscription renews unless cancelled at least 24 hours before the period ends, and you can manage or cancel it in your Apple ID settings.

Hummingbird is for learning and exploration only and is **not financial, investment, or trading advice.** Markets are unpredictable; never make money decisions based solely on this app.

Privacy Policy: https://avaj845.github.io/Hummingbirdv1/privacy.html
Terms of Use (EULA): https://avaj845.github.io/Hummingbirdv1/terms.html

## What's New (1.0)
First public release: on-device price sketches for stocks & crypto, method comparison with honest backtests, watchlist, widget, Siri, and shareable sketch cards — educational, never advice.

## URLs
- **Support / Marketing:** https://avaj845.github.io/Hummingbirdv1/
- **Privacy Policy:** https://avaj845.github.io/Hummingbirdv1/privacy.html  *(paste into the App Store Connect "Privacy Policy URL" field)*
- **Terms of Use (EULA):** https://avaj845.github.io/Hummingbirdv1/terms.html  *(use as the CUSTOM EULA — see 3.1.2 below)*

## ⚠️ Guideline 3.1.2 — Terms of Use / EULA (this is what gets subscription apps rejected)
An auto-renewable subscription (or non-consumable IAP alongside subs) requires a **functional Terms of Use link on the App Store product page** AND the EULA set in App Store Connect. Do ALL of:
1. **App Description** — the two links above (`Privacy Policy:` and `Terms of Use (EULA):`) are already in the Description text above its final paragraph. Keep them there, as plain `https://` text — Apple renders them as tappable links on the product page. Do **not** remove them.
2. **App Store Connect → App Information → License Agreement** → choose **Custom** → paste `https://avaj845.github.io/Hummingbirdv1/terms.html`. (Do not leave it on "Standard Apple EULA" — the custom terms carry the subscription/refund/renewal specifics Apple 3.1.2 looks for.)
3. **App Store Connect → Privacy Policy URL** (App Information) → `https://avaj845.github.io/Hummingbirdv1/privacy.html`
4. **Both URLs must return HTTP 200 before submission** — if the repo is private, GitHub Pages needs GitHub Pro; make the repo public or enable Pages.
5. In-app: the paywall already shows working **Privacy Policy** and **Terms of Use** links right by the purchase buttons (`PaywallView` → Legal section) — that covers 3.1.2's in-binary requirement. Don't remove them.

## Screenshots

The app supports **iPhone and iPad**, so App Store Connect requires screenshot
sets for both idioms. All sets are generated by the same `HummingbirdUITests`
screenshot harness (`ScreenshotTests.swift`) against sample data
(`-UITEST_FORCE_SAMPLE`), so they match the *current* UI, brand mark and icon.
Animations are disabled in-process under the harness and the nav bar is forced
opaque, so captures never catch a push transition mid-flight or a blurred
smear of scroll content behind the bar.

> **⚠️ If App Store Connect rejects an upload for wrong dimensions:** ASC's
> exact accepted iPhone sizes have shifted across hardware generations and can
> differ by account/app record. If the error message names
> **1242×2688 or 1284×2778** (portrait — the message also lists their
> landscape transposes), don't fight it — upload from
> **`AppStore/raw-screens-6.5in/`** (1242×2688) or
> **`AppStore/raw-screens-6.7in/`** (1284×2778) instead of the 6.9″ set.
> Either one alone satisfies the iPhone slot; ASC generates the rest. Both are
> pixel-native captures (real device-type simulators at those exact
> resolutions, not resized), regenerate with:
> ```bash
> xcodegen generate
> xcrun simctl create "iPhone 11 Pro Max" com.apple.CoreSimulator.SimDeviceType.iPhone-11-Pro-Max com.apple.CoreSimulator.SimRuntime.iOS-26-5   # 1242×2688, once
> xcrun simctl create "iPhone 12 Pro Max" com.apple.CoreSimulator.SimDeviceType.iPhone-12-Pro-Max com.apple.CoreSimulator.SimRuntime.iOS-26-5   # 1284×2778, once
> TEST_RUNNER_SCREENSHOT_DIR="$PWD/AppStore/raw-screens-6.5in" xcodebuild test -project Hummingbird.xcodeproj -scheme Hummingbird -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 11 Pro Max' -only-testing:HummingbirdUITests CODE_SIGNING_ALLOWED=NO
> TEST_RUNNER_SCREENSHOT_DIR="$PWD/AppStore/raw-screens-6.7in" xcodebuild test -project Hummingbird.xcodeproj -scheme Hummingbird -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 12 Pro Max' -only-testing:HummingbirdUITests CODE_SIGNING_ALLOWED=NO
> ```
> Adjust the runtime id (`iOS-26-5`) to whatever `xcrun simctl list runtimes` shows installed. The 6.9″ set below is still worth keeping current — some ASC flows do ask for it — just don't assume it's the one your account wants.

### 6.5″ iPhone — `AppStore/raw-screens-6.5in/` (1242×2688)
Real iPhone 11 Pro Max device captures — one of the two sizes App Store
Connect's dimension-check message lists. Regenerate with the command above.

### 6.7″ iPhone — `AppStore/raw-screens-6.7in/` (1284×2778)
Real iPhone 12 Pro Max device captures — the other size ASC's message lists.
Regenerate with the command above.

### 6.9″ iPhone — `AppStore/raw-screens/` (1320×2868)
Real iPhone 17 Pro Max device captures. Regenerate with:

```bash
xcodegen generate
TEST_RUNNER_SCREENSHOT_DIR="$PWD/AppStore/raw-screens" \
xcodebuild test -project Hummingbird.xcodeproj -scheme Hummingbird -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:HummingbirdUITests CODE_SIGNING_ALLOWED=NO
```

### 13″ iPad — `AppStore/raw-screens-ipad/` (2064×2752)
Real iPad Pro 13-inch (M5) portrait captures. The harness detects the iPad
idiom and redirects a `.../raw-screens` path to the sibling
`.../raw-screens-ipad`. Regenerate with:

```bash
xcodegen generate
TEST_RUNNER_SCREENSHOT_DIR="$PWD/AppStore/raw-screens" \
xcodebuild test -project Hummingbird.xcodeproj -scheme Hummingbird -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  -only-testing:HummingbirdUITests CODE_SIGNING_ALLOWED=NO
```

On iPad the main content is width-capped to a readable measure and centered
(`.readableContentWidth()`), so it reads as a considered iPad app rather than a
stretched phone screen.

12 frames per set (same shot list across every size — 6.5″/6.7″/6.9″ iPhone at
1242×2688 / 1284×2778 / 1320×2868, iPad at 2064×2752):

| File | Screen |
| --- | --- |
| `01_onboarding_sketches.png` | Onboarding 1 — "Sketches, not predictions" |
| `02_onboarding_private.png` | Onboarding 2 — "Private by design" |
| `03_onboarding_honest.png` | Onboarding 3 — "See how wrong it's been" |
| `04_home_empty.png` | Fresh home, calm default state |
| `05_sketch_result.png` | Plain-English result card after a sketch |
| `06_reliability.png` | Price-sketch chart + reliability meter |
| `07_paywall_top.png` | Pro paywall — value prop + "Always free" / "Pro adds" |
| `08_paywall_plans.png` | Pro paywall — all 3 plans ($19.99/yr + 7-day trial · $2.99/mo · $49.99 Lifetime) — **use as the IAP review screenshot** |
| `09_settings.png` | Settings — appearance, icon picker, Siri, Accuracy report |
| `10_practice_home.png` | Home with Practice tools on |
| `11_accuracy_report.png` | Settings → Accuracy report (seeded track record) |
| `12_watchlist.png` | Watchlist sheet with saved assets |

## Watch screenshots

App Store Connect's watch screenshot upload requires 5 sizes, one per
Apple Watch case-size family. Case size (the mm variant), not the Series
number, determines the native pixel resolution — verified empirically
against each installed simulator device type rather than assumed:

| Slot | Required size | Device type used | File |
| --- | --- | --- | --- |
| Apple Watch Ultra 3 | 422×514 **or** 410×502 (either satisfies) | Apple Watch Ultra 3 (49mm) | `AppStore/raw-screens-watch/ultra3.png` |
| Apple Watch Series 11 | 416×496 | Apple Watch Series 11 (46mm) | `AppStore/raw-screens-watch/series11.png` |
| Apple Watch Series 9 | 396×484 | Apple Watch Series 9 (45mm) | `AppStore/raw-screens-watch/series9.png` |
| Apple Watch Series 6 | 368×448 | Apple Watch Series 6 (44mm) | `AppStore/raw-screens-watch/series6.png` |
| Apple Watch Series 3 | 312×390 | **none installed** — see note below | — |

For each family the *other* case size was also checked and does **not**
match (e.g. Series 11 42mm → 374×446, Series 9 41mm → 352×430, Series 6
40mm → 324×394) — don't guess the case size, confirm with `sips` as below.

**⚠️ Apple Watch Series 3 has no screenshot.** `xcrun simctl create` for
both Series 3 device types (42mm and 38mm) fails with "Incompatible
device" against the watchOS 26.5 runtime — Series 3 never shipped a
watchOS this new, and this app's watchOS deployment target (10.0, see
`project.yml`) wouldn't run on real Series 3 hardware regardless. If ASC
still shows a Series 3 slot at submission time, either accept the gap (the
other 4 sizes cover it in most upload flows) or generate it from an older
Xcode/watchOS-runtime install using the same steps below, swapping the
device type.

All 4 captures show the **populated watchlist** (not the empty state) via
the `-WATCH_UITEST_SEED` launch argument (`HummingbirdWatch/WatchTestSupport.swift`,
`#if DEBUG`-only), which seeds 3 deterministic `WatchlistItem` +
`WatchlistSnapshot` entries (AAPL, bitcoin, MSFT) straight into the App
Group — no phone pairing needed, so a freshly created, unpaired watchOS
simulator still renders a real-looking list.

Regenerate the full set:
```bash
xcodegen generate

RUNTIME=com.apple.CoreSimulator.SimRuntime.watchOS-26-5   # adjust to whatever `xcrun simctl list runtimes` shows installed

# 1) Create one simulator per slot (skip any that already exist)
xcrun simctl create "WatchShot-Ultra3"  com.apple.CoreSimulator.SimDeviceType.Apple-Watch-Ultra-3-49mm   "$RUNTIME"
xcrun simctl create "WatchShot-S11"     com.apple.CoreSimulator.SimDeviceType.Apple-Watch-Series-11-46mm "$RUNTIME"
xcrun simctl create "WatchShot-S9"      com.apple.CoreSimulator.SimDeviceType.Apple-Watch-Series-9-45mm  "$RUNTIME"
xcrun simctl create "WatchShot-S6"      com.apple.CoreSimulator.SimDeviceType.Apple-Watch-Series-6-44mm  "$RUNTIME"

# 2) Boot + sanity-check each one's native pixel size before trusting it
for name in WatchShot-Ultra3 WatchShot-S11 WatchShot-S9 WatchShot-S6; do
  udid=$(xcrun simctl list devices | grep "$name" | grep -oE '[0-9A-F-]{36}')
  xcrun simctl boot "$udid"
  xcrun simctl io "$udid" screenshot /tmp/check-$name.png
  echo "$name:"; sips -g pixelWidth -g pixelHeight /tmp/check-$name.png
done

# 3) Build the watch app once (any of the simulators above works as the destination)
xcodebuild build -project Hummingbird.xcodeproj -scheme HummingbirdWatch -sdk watchsimulator \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' CODE_SIGNING_ALLOWED=NO

APP=$(find ~/Library/Developer/Xcode/DerivedData/Hummingbird-*/Build/Products/Debug-watchsimulator/HummingbirdWatch.app -maxdepth 0)
BUNDLE_ID=com.avaresearch.hummingbird.dev.watchkitapp

# 4) Install + seed + capture on each
declare -A SLOT=( [WatchShot-Ultra3]=ultra3 [WatchShot-S11]=series11 [WatchShot-S9]=series9 [WatchShot-S6]=series6 )
for name in "${!SLOT[@]}"; do
  udid=$(xcrun simctl list devices | grep "$name" | grep -oE '[0-9A-F-]{36}')
  xcrun simctl install "$udid" "$APP"
  xcrun simctl launch "$udid" "$BUNDLE_ID" -WATCH_UITEST_SEED
  sleep 2
  xcrun simctl io "$udid" screenshot "AppStore/raw-screens-watch/${SLOT[$name]}.png"
done

# 5) Verify dimensions
sips -g pixelWidth -g pixelHeight AppStore/raw-screens-watch/*.png
```

### Store upload — still a design task
These raw frames — the iPhone sets (`raw-screens-6.5in/`, `raw-screens-6.7in/`,
`raw-screens/`) and the iPad set (`raw-screens-ipad/`) — are **un-framed
device captures**. All still need the marketing frame + caption design pass
(add the caption/device-bezel treatment, pick the 3–5 strongest, order
honesty-first). Upload whichever iPhone size ASC's UI actually asks for (see
the ⚠️ note above) plus the 13″ iPad set, which is **required** now that the
app declares iPad support. Suggested hero order for the store:
`11_accuracy_report` ("See how wrong it's been") → `05_sketch_result`
("Plain-English, not hype") → `06_reliability` ("Which method tracks best?") →
`12_watchlist` ("Glanceable. Always fresh") → `04_home_empty`
("Sketch any stock or crypto").

> **Re-shoot at the raw level is done** — real captures of the current UI,
> iPhone (`AppStore/raw-screens/`) and iPad (`AppStore/raw-screens-ipad/`).
> What remains is the marketing-frame/caption pass on top of both sets. The
> older `0*_*.png` files in `AppStore/` predate the round-1/2 UI and must not
> ship.

App icon: `AppIcon-1024.png` (1024×1024, no alpha) — regenerate with
`sh AppStore/icon/render.sh`.

## App Privacy (nutrition label)
- **Data collected:** None. No account, no analytics/tracking SDKs.
- Network requests fetch only public market/economic data for the symbols you enter.
- Subscriptions handled by Apple (StoreKit); Hummingbird only learns whether Pro is active.

## Review notes (paste into App Review)
Hummingbird is an **educational** tool. It produces statistical "sketches" from public historical prices and clearly labels them as not predictions and **not financial advice** throughout (onboarding, results, share card, alerts, paywall). It contains no buy/sell signals, no brokerage, and no real-money trading. Pro (a yearly/monthly auto-renewable subscription or a one-time non-consumable "Lifetime" unlock — same features) unlocks on-device comparison convenience only, on identical public data to the free tier.

Terms of Use (EULA) and Privacy Policy: linked at the end of the App Description, set in App Store Connect (License Agreement = custom terms.html), and shown in-app on the paywall (Pro screen → Legal). Subscription price, length, and renewal terms are stated in the App Description and on the paywall.

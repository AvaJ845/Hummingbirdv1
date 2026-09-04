# Hummingbird — Release-Readiness Audit

Date: 2026-09-03 · Branch: `fellows-roast-fixes` · Xcode 26.6 · xcodegen 2.44.1

Scope: a local clone (not the canonical repo). Build/test baseline before this
pass: **313 unit tests pass, 12 distinct compiler warnings.**
After this pass: **313 unit tests pass, 0 compiler warnings.**

Verdict key: **PASS** (was already fine) · **FIXED** (changed in this pass) ·
**FAIL — needs human** (left for a person to decide/do).

---

## 1 · Compiler warnings — full sweep · FIXED

Clean build of the `Hummingbird` scheme (`xcodebuild clean build … -sdk
iphonesimulator`). 12 raw warning lines → 9 distinct → **0 after fixes**.

| # | file:line | Warning | Resolution |
|---|-----------|---------|------------|
| 1 | `Monetization/EntitlementStore.swift:12` | `yearlyProductID` — main-actor static referenced from `nonisolated` `allProductIDs` (Swift 6 error) | **FIXED** — marked the two product-ID constants `nonisolated static let` (plain `String`, trivially `Sendable`). |
| 2 | `Monetization/EntitlementStore.swift:12` | same, `monthlyProductID` | **FIXED** — as above. |
| 3 | `Monetization/EntitlementStore.swift:80` | `nonisolated(unsafe)` "has no effect" on `transactionListener` | **FIXED** — added `@ObservationIgnored` so the `@Observable` macro stops wrapping the stored property; `nonisolated(unsafe)` then applies cleanly. Behaviour unchanged (written once in `init`, read once in `deinit`). |
| 4 | `Support/NavigationMotion.swift:16` | `DismissAction.callAsFunction()` (main-actor) called from a `nonisolated` static func | **FIXED** — marked `NavigationMotion.push` / `.pop` `@MainActor` (both are only ever called from SwiftUI view code, which is already main-actor). |
| 5 | `Views/Dictation/DictationOverlay.swift:132` | `MicAnchorKey.defaultValue` — nonisolated global mutable state (Swift 6 error) | **FIXED** — changed the stored `static var` to a computed `static var defaultValue: Anchor<CGRect>? { nil }` (PreferenceKey only requires a getter). |
| 6–8 | `Views/Settings/SettingsView.swift:282` (×3) | `currentAlternate` / `UIApplication.shared` / `alternateIconName` touched from the `@Sendable` `setAlternateIconName` completion handler | **FIXED** — the completion body now hops to `Task { @MainActor in … }` before touching `@State` / `UIApplication`. |
| 9 | `HummingbirdWidget/SelectAssetIntent.swift:10` | `WatchlistItemEntity.defaultQuery` — nonisolated global mutable state (Swift 6 error) | **FIXED** — changed the stored `static var defaultQuery = …` to a computed `static var defaultQuery: WatchlistItemQuery { WatchlistItemQuery() }`. |

All three "known Swift 6 strict-concurrency" spots (`EntitlementStore`,
`DictationOverlay`, `SelectAssetIntent`) were low-risk one-liners and are fixed,
not deferred. `SWIFT_STRICT_CONCURRENCY: complete` is already set in
`project.yml`; the module now builds warning-free under it.

---

## 2 · Dead code · PASS (with one note)

Method: enumerated every top-level type across the 4 app/extension targets and
grepped for cross-file references; swept `@AppStorage`/`UserDefaults` keys;
searched for the engines removed in earlier de-gamification rounds.

- **Deleted-engine dangle check — PASS.** No references anywhere to
  `StreakReminderEngine`, `EconomicCalendarCallEngine`, `streakFreeze` /
  `StreakFreeze` / freeze tokens. `StreakEngine` (raw participation streak, no
  perks) is still referenced from `ContentView` and tests — kept intentionally.
- **Types defined but unused — PASS.** Zero genuinely-dead top-level types. The
  automated sweep's hits were all either nested helper views used within their
  own file, or `AppShortcutsProvider` / `AppIntent` / `AppEntity` conformers
  that the system discovers without an explicit code reference
  (`HummingbirdShortcuts`, `ProjectAssetIntent`, `WatchlistItemEntity`).
- **`@AppStorage` / `UserDefaults` keys — PASS.** All 34 `hb.*` / `hummingbird.*`
  keys have both a reader and a writer.
- **Commented-out code — PASS.** No commented-out code blocks (only doc
  comments and one explanatory formula comment).
- **Asset catalog — PASS.** `BrandMark`, `AccentColor`, `AppIcon` and the two
  loose alt-icon PNG pairs (`AltIcon-Midnight`, `AltIcon-Mono`) are all
  referenced. No orphan image/color sets.
- **NOTE (not blocking): `SampleMacro`** in `Services/EconomicDataService.swift`
  (under a `// MARK: - Test / offline helpers` banner) is referenced only by
  unit tests, yet compiles into the Release binary (~6 symbols, no user-visible
  surface). Harmless; consider moving it to the test target in a later pass.

---

## 3 · Test / sample / placeholder data leaking into Release · PASS / FIXED

- **`Services/SampleData.swift` — PASS.** Every `SampleData.series(…)` sets
  `isSample: true`. The only runtime entry point is
  `MarketDataService.fetchFresh`'s `catch` (network failure) and the new
  DEBUG-only `-UITEST_FORCE_SAMPLE` hook. `ForecastViewModel.usingSampleData`
  mirrors `series.isSample` on every code path, and `ForecastResultsView`
  unconditionally renders `SampleDataBanner()` ("Showing sample prices — live
  market data wasn't reachable. This is not a live chart.") whenever it's true.
  `ModelPickerSheet` and `OpenPositionSheet` show their own sample notices.
  `EconomicDataService` goes further and *discards* sample macro snapshots
  (`guard … !snapshot.isSample`). **Sample data cannot render without a banner.**
- **`entitlements.debugUnlocked` / `setDebugUnlocked` / "Unlock Pro" toggles —
  FIXED.** Previously the `debugUnlocked` stored property and `setDebugUnlocked`
  were compiled in all configs (the property left a `_debugUnlocked` symbol in
  the Release binary, though it was never read or set outside `#if DEBUG`). Both
  are now fully inside `#if DEBUG`. Verified against a Release build
  (`-configuration Release`, simulator): `strings` / `nm` of the app binary now
  report **0** occurrences of `debugUnlock`, `proUnlocked`, `Unlock Pro`,
  `local QA`, `hummingbird.debug`, `TestSupport`, or `UITEST_`. The two debug
  unlock UIs are additionally gated behind a `-DEBUG_MENU` launch argument (see
  §Part B) so they don't appear even in an ordinary Debug/TestFlight build.
- **TestFlight auto-unlock — PASS (by design, documented).**
  `EntitlementStore.isPro` returns true for a TestFlight install
  (`appStoreReceiptURL` == `sandboxReceipt`) so external testers get every Pro
  feature without buying. This is **never** true for a production App Store
  download, the buy buttons stay live in TestFlight, and it is thoroughly
  commented in `EntitlementStore.swift`. Not a leak.
- **Hardcoded fake tickers / prices / dates — PASS.** The only literal
  symbols outside `#Preview` are the onboarding quick-add suggestions
  (AAPL / bitcoin / NVDA / ethereum) and the Siri phrase examples — all real,
  all fetched live, none presented as data.
- **`#if DEBUG` blocks — PASS.** 8 sites: `EntitlementStore` (QA unlock),
  `PaywallView` ×2 + `SettingsView` ×1 (QA unlock UI + an informational note),
  `NotificationService` ×2 (`print` on a failed/`budget`-capped schedule),
  and the new `TestSupport` / `HummingbirdApp` / `MarketDataService` /
  `ContentView` hooks. None gates functionality the app needs at runtime in
  Release.

---

## 4 · Secrets / keys / signing · PASS

- Grepped `*.swift` / `*.plist` / `*.xcconfig` / `*.entitlements` / `*.json` /
  `*.storekit` for key/token/secret/password/PEM/`AKIA…`/`AIza…`/`client_secret`
  patterns. **Nothing.** ("token" hits are all UI price-flash counters and a
  speech-recognition token.) The README's "no API keys" claim holds — every
  data source (CoinGecko, Yahoo) is key-less.
- `git log -p --all --full-history` — no secret ever committed-then-removed.
  `Config/Signing.xcconfig` has **never** existed in history; only
  `Config/Base.xcconfig` and `Config/Signing.xcconfig.example` are tracked.
- `.gitignore` covers `*.xcodeproj`, `Config/Signing.xcconfig`, `DerivedData/`,
  `build*/`, `.DS_Store`, `.swiftpm`. **FIXED:** added `xcuserdata/` (belt-and-
  braces; it's already inside the ignored `*.xcodeproj`).
- Real signing (Team `3L683975L8`, `Apple Distribution`, manual profiles) is in
  `project.yml` under each target's `Release` config — that's identifiers, not
  secrets, and is expected for a reproducible archive.

---

## 5 · Info.plist / bundle hygiene · PASS / FIXED

App (`Hummingbird/Info.plist`, `GENERATE_INFOPLIST_FILE: NO`):

| Key | State |
|-----|-------|
| `ITSAppUsesNonExemptEncryption` | `false` — **PASS** |
| `CFBundleDisplayName` | `$(APP_DISPLAY_NAME)` → `Hummingbird` (Release), `Hummingbird Dev` (Debug) — **PASS** |
| `NSHumanReadableCopyright` | `2026 AvaResearch LLC` — **PASS** (confirmed in the generated plist) |
| `NSMicrophoneUsageDescription` / `NSSpeechRecognitionUsageDescription` | both mention dictating a ticker/coin id "for an educational projection … not financial advice" — **PASS** |
| `BGTaskSchedulerPermittedIdentifiers` | `com.avaresearch.hummingbird.refresh` — matches `BackgroundRefresh.taskIdentifier` exactly — **PASS** |
| `NSSupportsLiveActivities` | `true` — matches `SketchLiveActivityManager` usage — **PASS** |
| `UIBackgroundModes` | was `[fetch, processing]`; **FIXED → `[fetch]`**. Only a `BGAppRefreshTaskRequest` is ever registered/submitted — there is no `BGProcessingTaskRequest` and no processing identifier, so `processing` was dead and an easy App-Review question. |
| Placeholder keys | none — **PASS** |

- **Widget** `HummingbirdWidget/Info.plist` — `NSExtensionPointIdentifier`
  `com.apple.widgetkit-extension`, version keys driven from the shared build
  settings. **PASS.**
- **Watch** `HummingbirdWatch/Info.plist` — `WKApplication` / `WKCompanionAppBundleIdentifier`
  correct. **FIXED:** `NSHumanReadableCopyright` was the disclaimer string
  "Educational projections — not financial advice."; set to `2026 AvaResearch LLC`
  to match the app. **Watch Widget** plist — **PASS.**
- Reminder (not new): the watch app is **not yet embedded** in the iOS app
  (see `RELEASE.md` §Optional) — it won't ship in the first submission
  regardless.

---

## 6 · Privacy manifest · FIXED

- `Hummingbird/Resources/PrivacyInfo.xcprivacy` — declared
  `NSPrivacyTracking=false`, no collected data types, and
  `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1`.
- **Code actually uses:** `UserDefaults` — directly and via an **App Group**
  (`group.com.avaresearch.hummingbird`, shared with the widget + watch). No
  file-timestamp APIs (`modificationDate` / `creationDate` / `attributesOfItem`),
  no disk-space APIs (`volumeAvailableCapacity*` / `systemFreeSize`), no
  `systemUptime` / boot-time, no `ActiveKeyboards`. Verified by grep.
- **FIXED:**
  1. Added reason **`1C8F.1`** (app-group-shared user defaults) alongside
     `CA92.1` in the app manifest — the app group read/write genuinely needs it.
  2. Added a **`HummingbirdWidget/PrivacyInfo.xcprivacy`** (same two reasons) —
     the widget extension links `SharedStorage` / `AppGroup` and so accesses the
     `UserDefaults` required-reason API in its own bundle. Confirmed it lands at
     `Hummingbird.app/PlugIns/HummingbirdWidget.appex/PrivacyInfo.xcprivacy`.
- The watch targets also touch app-group defaults; a matching manifest should be
  added there **when the watch app is actually wired for submission** — out of
  scope for this pass since it isn't shipping yet. **(FAIL — needs human, watch only, deferred.)**

---

## 7 · Logging / PII · PASS

Only two logging calls in the whole codebase — `print(…)` at
`NotificationService.swift:74` and `:126`, **both inside `#if DEBUG`**, both
logging a scheduling failure / budget cap with no user data. No `NSLog`,
no `os_log`, no `Logger`. No user-entered symbols, call records, or portfolio
values are logged anywhere. Release paths are silent.

---

## 8 · StoreKit config sanity · PASS

`Products.storekit` — group `Hummingbird Pro` (`id: HummingbirdPro`), two
auto-renewable subscriptions plus one non-consumable unlock (added after this
audit's first pass — the "offer Lifetime, keep yearly + monthly" decision):

| Product | ID | Matches `EntitlementStore`? | Price | Type | Intro |
|---------|----|--------------------------|-------|------|-------|
| Yearly | `com.avaresearch.hummingbird.pro.yearly` | ✓ (`yearlyProductID`) | 19.99 | RecurringSubscription P1Y | 1-week free (`paymentMode: free`) |
| Monthly | `com.avaresearch.hummingbird.pro.monthly` | ✓ (`monthlyProductID`) | 2.99 | RecurringSubscription P1M | none |
| Lifetime | `com.avaresearch.hummingbird.pro.lifetime` | ✓ (`lifetimeProductID`) | 49.99 | NonConsumable | n/a |

- The non-consumable needs **no special entitlement code**: once purchased it
  stays in `Transaction.currentEntitlements` permanently, so `refreshPurchases()`
  → `purchasedProductIDs` → `hasRealPurchase` / `isPro` pick it up through the
  same path as the subscriptions. `restore()` (`AppStore.sync()`) covers it.
- In App Store Connect the Lifetime product is created under **In-App Purchases**
  (Non-Consumable), not inside the subscription group — see `RELEASE.md` §4b.
- Product IDs match `EntitlementStore.swift` **exactly**. **PASS.**
- `groupNumber` 1 (yearly) vs 2 (monthly): this is the **rank within the
  subscription group**, i.e. yearly is the higher service level. Both products
  are in the *same* group, so the user can only hold one at a time; the rank
  makes monthly→yearly an immediate upgrade and yearly→monthly a deferred
  downgrade. That is the intended behaviour for a "same features, cheaper if you
  commit" pair — **leave as is.** No build warning, no StoreKit lint issue.
- The top-level `products` / `nonRenewingSubscriptions` arrays are empty — correct,
  everything is a renewing subscription.

---

## Answers to the direct questions

- **Is the code clean for a build?** **Yes.** `xcodebuild clean build` of the
  `Hummingbird` scheme for the simulator produces **0 warnings and 0 errors**
  under `SWIFT_STRICT_CONCURRENCY: complete`. `xcodebuild build test` runs
  **313 unit tests, 0 failures.** A `-configuration Release` build also
  succeeds clean.
- **Is the repo free of dead code, old test data, and API keys?**
  - **Dead code:** effectively yes — no dead types, no dangling references to
    the removed gamification engines, no orphan defaults keys or assets. One
    cosmetic note (`SampleMacro` is test-only but compiled in).
  - **Old / test / placeholder data:** yes — sample data can only ever appear
    behind an explicit "sample prices" banner; the debug Pro-unlock is now
    fully `#if DEBUG` *and* behind a launch arg, and verified absent from the
    Release binary; no fake tickers/prices/dates in shipping code paths.
  - **API keys / secrets:** yes — none in the tree, none in git history, all
    data sources are key-less, only the signing *identifiers* (not secrets)
    are checked in.

## Still needs a human before submission

1. Nothing blocking in the app binary itself.
2. **Watch app**: still not embedded in the iOS target (pre-existing, tracked in
   `RELEASE.md`); when it is wired up it needs its own `PrivacyInfo.xcprivacy`
   for the app-group `UserDefaults` access.
3. App Store Connect account/listing work per `RELEASE.md` (D-U-N-S, agreements,
   subscription records, screenshots — see the harness output below).

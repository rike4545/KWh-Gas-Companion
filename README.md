# My EV Companion

An iPhone and iPad app for people who want to know what driving electric actually
costs them. It logs charging sessions and expenses, reconciles them against
imported data, compares the result against what the same miles would have cost in
gas, and wraps that in a large library of EV-specific tools — Supercharger
pricing, VIN and option-code decoding, delivery tracking, trip planning, tax and
lease calculators, and more.

Everything runs on device. The app has no backend of its own, no account system,
and no server that sees your data.

| | |
|---|---|
| **Bundle ID** | `Me.KWh-Gas-Companion` |
| **Display name** | My EV Companion |
| **Platforms** | iOS 18.0+, iPhone and iPad |
| **Language** | Swift (language mode 5), SwiftUI |
| **Repo name** | `KWh-Gas-Companion` (the original working title, kept for continuity) |

---

## Building

```bash
open "KWh Gas Companion.xcworkspace"
```

Open the **workspace**, not the project — Swift Package dependencies are resolved
there. Select the `KWh Gas Companion` scheme and run.

From the command line:

```bash
xcodebuild -project "KWh Gas Companion.xcodeproj" -scheme "KWh Gas Companion" -configuration Debug -destination 'generic/platform=iOS Simulator' build
```

There is nothing to configure before the first build. No API keys, no `.env`, no
local secrets file. `GoogleService-Info.plist` and the AdMob application
identifier are checked in — both are client-side identifiers rather than secrets.

### Dependencies

Resolved through Swift Package Manager, pinned in
`KWh Gas Companion.xcworkspace/xcshareddata/swiftpm/Package.resolved`:

- **GoogleMobileAds** + **GoogleUserMessagingPlatform** — banner ads and consent
- **FirebaseAnalytics** — pulled in by the ads SDK; no Firestore or Auth
- **SwiftCSV** — charging and trip CSV import
- **SwiftSoup** — HTML scraping for pricing and news sources

---

## Layout

```
KWh Gas Companion/            The app target — a flat directory of 465 Swift files
KWh Gas CompanionTests/       Unit tests (parsers, engines, agent tooling)
KWh Gas CompanionUITests/     Launch and smoke UI tests
MyEVCompanion-Android/        Kotlin sibling app, built separately with Gradle
shared/                       Cross-platform content shared by both apps
scripts/                      Generators that write into both codebases
KWh-Gas-Companion-Info.plist  Usage descriptions, AdMob ID, URL types
```

The app target uses **Xcode file-system synchronized groups** (`objectVersion 77`).
Sources are discovered from disk, so adding, renaming, or deleting a `.swift` file
needs no change to `project.pbxproj`. Drop the file in `KWh Gas Companion/` and
build.

The source directory is intentionally flat rather than nested in folders. Files
are grouped by name prefix instead — `Charging*`, `Trip*`, `Tesla*`, `Expense*`,
`Supercharger*`, `Forecast*`.

---

## Architecture

### Stores

State lives in `ObservableObject` stores created exactly once in
`KWh_Gas_CompanionApp.init()` and injected into the environment. The important
ones:

| Store | Owns |
|---|---|
| `ProfileStore` | Vehicles, the selected vehicle, per-vehicle assumptions |
| `EntriesStore` | Charging and expense entries — the primary ledger |
| `TeslaFiSessionStore` | Imported TeslaFi sessions and trips |
| `BudgetStore` | Budgets and category targets |
| `AppAppearance` / `AppUISettings` | Appearance mode, density, spacing multipliers |
| `ToolUsageStore` | Tool open counts, driving the "recent" and "favorites" rails |
| `StoreCoordinator` | Cross-store derived values and invalidation |

Most feature-local stores subclass `LocalJSONStore<T>`, which persists an array of
`Codable & Identifiable` items to a JSON file in Documents. Larger stores hand-roll
persistence with a coalesced save so that per-keystroke mutations do not rewrite
the file synchronously on every change.

### Theming

`AppThemeSpec` is a `Sendable` protocol of layout and color tokens, carried in the
environment as `AppThemeBox` and read as:

```swift
@Environment(\.appThemeBox) private var themeBox
private var theme: any AppThemeSpec { themeBox.base }
```

Cards use the `.themedCard()` / `.themedCard(prominent:)` modifier rather than
bespoke backgrounds, which keeps corner radius, elevation, border, and dark-mode
behavior consistent and responsive to the user's density settings.

### The tool dashboard

The Tools tab is driven by a single registry. `CalculatorKind` is an enum of
**127 tools**, sorted into ten `CalcDashCategory` groups. Every tool is a case,
and the dashboard renders, searches, and routes to all of them generically.

**Adding a tool touches exactly three files:**

1. `CalculatorKind.swift` — add the case, plus its `title`, `systemImage`, and
   (optionally) `subtitle`.
2. `CalculatorKind+Search.swift` — assign a `_calcDashCategory`, and add search
   keywords to `_calcDashSearchBlob` so the tool is findable by words that do not
   appear in its title.
3. `CalculatorsDashboardView.swift` — map the case to its destination view in the
   `@ViewBuilder` switch.

Optionally add it to `calcDashEverydayKinds` in `CalculatorsDashboardView.swift`
to surface it on the "Everyday tools" rail.

Miss step 2 and the tool exists but is effectively unsearchable. Miss step 3 and
the build fails on a non-exhaustive switch, which is the intended safety net.

---

## Notable subsystems

**Charging data pipeline.** CSV import (`CSVChargingWizardView`, TeslaFi
importers) feeds a normalization and classification chain
(`ChargingClassifier`, `ChargingLocationNormalizer`,
`TeslaFiSessionNormalizationEngine`), then a reconciliation and data-quality layer
(`ChargingReconciliationView`, `DataQualityAnalyzer`, `DuplicateResolverView`,
`CaughtaKWHView`) that finds duplicates, spikes, missing costs, and implausible
rates before any of it reaches a chart.

**Supercharger pricing.** Community data from supercharge.info
(`SuperchargeInfoStore`), official rate records, and a local predictor
(`SuperchargerLivePricePredictor`) that estimates tiered pricing from occupancy
and time of day.

**Sparky.** The in-app assistant (`SparkyEngine`, `AgentOrchestrator`,
`AgentTools`) is **entirely on-device and makes no network calls**. It answers
from your logged data using a local tool-calling loop, not a hosted model.

**Tesla delivery tracking.** `TeslaDeliveryOrder` models a nine-stage delivery
ladder inferred from which fields have appeared on an order. `TeslaOrderJSONImporter`
parses an order payload you supply yourself, searching the JSON tree for known
keys rather than assuming a shape. `TeslaOptionCodeDecoder` turns `mktOptions`
into a readable build sheet. See [Delivery data](#delivery-data) below.

**Delivery Day Checklist.** 122 inspection checks across eight sections with
per-item status, timestamped notes, and photos, exportable as PDF or text
(`DeliveryChecklist*.swift`). Fully offline — a delivery center is exactly where
you cannot count on signal.

**Trips and routing.** `TPTripPlannerEngine` with MapKit-backed routing and
charger search. Note that `TPOpenRouterProvider` is a MapKit implementation; the
name is a holdover from an earlier routing backend and does not indicate an
external service.

**Live Activities and widgets.** `ChargeActivityAttributes` and
`ChargeLiveActivityManager` for in-progress charge sessions. `ChargeWidgets.swift`
exists in the app target but there is currently **no widget extension target**, so
it is not built into a widget — adding one requires a new target in
`project.pbxproj`.

---

## Data and privacy

All user data — entries, vehicles, imported sessions, photos, delivery orders,
checklists — is stored on device in the app's Documents directory and in
`UserDefaults`. There is no sync service and no account.

The app ships with no backend of its own. Outbound traffic falls into four
buckets, and the first three are all reads of public data:

- **Public data sources** — supercharge.info, Tesla pricing and find-us
  endpoints, NHTSA recalls, incentive and rate references, EV news.
  (`SuperchargeInfoClient`, `TeslaSiteSummary`, `RecallsView`, `IncentivesView`,
  `SiteStore`, `CheapestChargerShift`.)
- **MapKit** — routing, search, and charger discovery.
- **The ads SDK** — AdMob, gated behind UMP consent and disabled once ads are
  removed.
- **A self-hosted endpoint you configure yourself** — `DirectConnectionAPIClient`
  takes a base URL and token that *you* enter (Direct Connection setup). Nothing
  is contacted unless you set it up, and it goes to your server, not ours.

`TeslaAuthManager` implements a Tesla **Fleet API** OAuth flow, but ships with a
placeholder client ID and is not wired into a shipping feature.

### Delivery data

The delivery tracker does **not** sign in to Tesla or fetch your order. Tesla's
order endpoints (`owner-api.teslamotors.com/api/1/users/orders` and the
`/tasks` gateway) are first-party only — reaching them requires the official
Tesla app's client ID and TLS fingerprint, and they are not part of the public
Fleet API that `TeslaAuthManager` targets. The app therefore accepts a payload
you obtained yourself and decodes it locally.

### Monetization

Banner ads via AdMob with UMP consent, removable through a single non-consumable
purchase (`com.my_ev_companion.remove_ads`, handled by `AdsEntitlementStore`).
There is no `.storekit` configuration file in the repo, so testing purchases
requires a sandbox account.

---

## Tests

```bash
xcodebuild test -project "KWh Gas Companion.xcodeproj" -scheme "KWh Gas Companion" -destination 'platform=iOS Simulator,name=iPhone 17'
```

Coverage is focused on logic rather than views: CSV parsing, the CaughtaKWH
anomaly engine, dashboard snapshot math, and the Sparky agent's context builder,
orchestrator, and tools.

---

## The Android sibling

`MyEVCompanion-Android/` is a separate Kotlin/Compose app with its own Gradle
build. It is not part of the Xcode build and does not open from the workspace.

The two apps share content through `shared/`. When discount, coupon, affiliate,
or referral links change, edit `shared/discount_links.json` and run:

```bash
python3 scripts/sync_discount_links.py
```

That writes the updated list into both the iOS `DiscountsView.swift` and the
Android `ToolDetailScreen.kt`, so the two never drift. Do not hand-edit the
generated lists.

---

## Conventions

- **iOS 18.0** is the real deployment target. Many file headers say `iOS 17+`;
  that is a stale convention, not a supported floor.
- Views are `@MainActor` and read the theme from the environment rather than
  taking colors as parameters.
- Long-lived screens live in their own file named after the view.
- Reference files as `Foo.swift` in the flat source directory — there are no
  nested groups to path through.
- Prefer `.themedCard()` over custom backgrounds, and `ContentUnavailableView`
  for empty states.

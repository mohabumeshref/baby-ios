# أنا و طفلي — iOS

Arabic-first (RTL) baby development tracker. SwiftUI, iOS 16+.

Companion to the Android app (`baby-tracker-ar-android`) and sibling to the
pregnancy tracker (`pt-ios`). All three share one Firebase project,
`pregnancy-tracker-57bf7`, and one community forum.

---

## The project file is generated

There is no `.xcodeproj` in this repo. It is generated from [`project.yml`](project.yml)
by [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen && xcodegen generate
```

This app is authored on Windows, where Xcode cannot run to validate a
hand-written `project.pbxproj`. A declarative spec removes that failure mode
and keeps project changes reviewable in diffs. CI regenerates before every
build, so `project.yml` is the single source of truth — edit it, not the
generated project.

## Workflows

| Workflow | Trigger | Does |
|---|---|---|
| `ci.yml` | every branch + PR | Compile check. No secrets, no signing, no upload. |
| `testflight.yml` | push to `main` | Archive, sign, upload to TestFlight. |
| `screenshots.yml` | manual, or UI changes on a branch | Boots a simulator, launches in Arabic, uploads screenshots as artifacts. |

Build numbers are set automatically from `github.run_number` via `agvtool`.
`MARKETING_VERSION` stays manual, in `project.yml`.

## Required secrets

Reusable from the `pt-ios` repo:

- `BUILD_CERTIFICATE_BASE64`, `P12_PASSWORD` — team-wide distribution cert
- `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_PRIVATE_KEY`

Must be created new for this app:

- `BUILD_PROVISION_PROFILE_BASE64` — provisioning profiles are bundle-ID specific

## Still to be supplied

These are placeholders in the repo and must be replaced before a real build:

| What | Where | Note |
|---|---|---|
| `GoogleService-Info.plist` | `BabyTracker/` | new iOS app registered in `pregnancy-tracker-57bf7` under `com.wecare.arabicbaby` |
| App icon | `BabyTracker/Assets.xcassets/AppIcon.appiconset` | 1024×1024 placeholder is empty |

Settled:

- **Bundle ID** — `com.wecare.arabicbaby`
- **AdMob App ID** — `ca-app-pub-6789336355455489~9475789471` (`Info.plist`)
- **AdMob units** — banner / interstitial / app-open, in [`BabyTracker/Ads/AdConfig.swift`](BabyTracker/Ads/AdConfig.swift).
  DEBUG builds automatically use Google's test units, so a development run can
  never file a real impression.
- **Cairo fonts** — five weights in `BabyTracker/Resources/`

The app runs without `GoogleService-Info.plist` — Firebase init is skipped and
logged — so the content and UI layers can be built and screenshotted before
the Firebase app exists.

---

## Content

`BabyTracker/Resources/weeks.json` and `skills.json` are generated from the
Android app's `res/raw/months.xml` and `res/raw/skills.xml` by
[`tools/port_content.py`](tools/port_content.py).

- **weeks.json** — 45 entries. Indices 0–43 are four weeks per month across the
  first eleven months; index 44 is the standalone "طفلك في عامه الأول" entry.
  Each carries a baby-growth article and a parent-focused article as typed
  blocks (`heading` / `body` / `bullet`) instead of the original HTML blobs.
- **skills.json** — 12 months × 3 tiers × 2–4 skills (103 chips total).

The porter repairs two malformed spots in the Android source markup that
`Html.fromHtml` silently absorbs (an orphan `</b>` in week 2 and in skills
month 7). Without the repair, month 7 loses an entire tier. `ContentStoreTests`
pins both fixes.

Content is **Arabic only** — the source articles were never translated. The UI
chrome is ar/en; adding `weeks_en.json` to the bundle is enough to serve
English content later, no code change needed.

## Notifications

This app sends **no** push notifications itself. Forum pushes are produced
server-side by the Cloud Functions in the shared Firebase project
(`onAnswerCreated`, `onPostCreated`, `onReplyAdded`), which trigger on
Firestore writes and are app-agnostic. This app only registers for APNs, keeps
its token in `User/{uid}.token`, and handles taps.

> The Android baby app still contains a client-side FCM sender *and* is covered
> by those Cloud Functions, so it likely delivers duplicate pushes. Tracked
> separately — do not replicate the pattern here.

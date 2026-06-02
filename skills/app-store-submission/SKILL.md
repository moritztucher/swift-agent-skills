---
name: app-store-submission
description: Archive, export, sign, upload, and ship an iOS app to TestFlight and the App Store from the command line — xcodebuild archive/exportArchive, ExportOptions.plist, code signing (automatic vs manual), App Store Connect API key auth, xcrun altool upload, export compliance, and a categorized review-rejection checklist. Use when the user mentions App Store submission, archive, xcodebuild exportArchive, ExportOptions.plist, TestFlight, upload to App Store Connect, code signing, provisioning profile, app review rejection, or export compliance. For the privacy manifest (a top rejection cause) use the privacy-manifest skill; for the "What's New" release text use the ios-release-notes skill.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple Xcode distribution docs via Context7 (/websites/developer_apple_xcode)
---

# App Store Submission

Shipping an iOS app from the command line: archive → export → upload → TestFlight → App Store review. The full CLI pipeline, ExportOptions.plist, signing approaches, App Store Connect API key auth, the pre-submission checklist, and a categorized rejection-reason checklist live in `references/guide.md`. This file is the decision and discipline layer — read it first, open the guide for exact flags and commands.

Scope: the **automatable / CLI** parts. Clicking through the App Store Connect web portal (typing metadata, picking a build, "Submit for Review") is noted where it matters but is not what this skill drives.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `SIGNING` — `automatic` (default; Xcode-managed certs/profiles, needs `-allowProvisioningUpdates` + API key on CI) · `manual` (you install the Apple Distribution cert and name each profile in ExportOptions; required for shared CI signing infra / Fastlane match).
2. `UPLOAD` — `xcode-organizer` (one-off manual ship via Xcode/Transporter) · `cli-api-key` (default for CI; `xcrun altool` + App Store Connect API key).
3. `STAGE` — `testflight` (upload + processing + beta testers, no full review for internal) · `app-store` (the version is also submitted to App Review with metadata + screenshots).

## When to use

Building or reviewing any archive/export/upload pipeline, an ExportOptions.plist, a CI signing setup, or diagnosing why a build won't upload or got rejected by App Review. If the question is specifically about the privacy manifest, use `privacy-manifest`. If it's about generating release notes text, use `ios-release-notes`.

## Core rules

- Archive with **`-destination 'generic/platform=iOS'`** and a **Release** configuration. A simulator destination produces a non-distributable archive.
- The export step is driven entirely by **ExportOptions.plist**. For the store, `method` = `app-store-connect`, `uploadSymbols` = `true`.
- On CI, authenticate everywhere with an **App Store Connect API key** (`.p8` + Key ID + Issuer ID) — never an Apple-ID password.
- **Bump the build number (`CFBundleVersion`) before every upload.** App Store Connect rejects a build number it has already seen for that marketing version.
- Validate (`xcrun altool --validate-app`) before uploading — it catches most ship-blockers early.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll reuse the same build number, the version string changed." | App Store Connect rejects any `CFBundleVersion` it has already seen for that `CFBundleShortVersionString`. **Bump the build number on every single upload** (`agvtool next-version -all`), or the upload is refused. |
| "I'll answer the export-compliance prompt in App Store Connect each build." | That manual click blocks every build from testing/submission. Declare **`ITSAppUsesNonExemptEncryption`** in Info.plist (`false` for the common HTTPS-only app) and the per-build prompt disappears. |
| "The privacy manifest is optional, I'll add it later." | A missing/incomplete `PrivacyInfo.xcprivacy` is the **single most common automated rejection** (ITMS-91053 email). Add it before archiving — see the `privacy-manifest` skill. |
| "I'll use my Apple ID + app-specific password on CI." | Apple-ID auth is fragile (2FA, session expiry) and breaks CI. Use an **App Store Connect API key** (`.p8`/Key ID/Issuer ID) for `altool` and `-allowProvisioningUpdates`. |
| "Automatic signing will just work on the CI runner." | Off your dev Mac, `xcodebuild` refuses to create/download profiles unless you pass **`-allowProvisioningUpdates`** (plus the API key) to *both* `archive` and `-exportArchive`. |
| "I'll strip dSYMs / skip uploadSymbols to slim the upload." | Without dSYMs the Crashes organizer shows raw addresses — unsymbolicated, useless. Keep **`uploadSymbols: true`**. |
| "notarytool uploads to the App Store." | No. `notarytool` notarizes Developer-ID *macOS* apps distributed **outside** the store. App Store/TestFlight uploads use **`xcrun altool`** (or Transporter / Xcode Organizer). |

## Verification gate

Before you call a submission done, confirm every line:

- [ ] Archived from **Release** config with `-destination 'generic/platform=iOS'`; archive contains the `.app`.
- [ ] ExportOptions.plist: `method = app-store-connect`, `uploadSymbols = true`, signing style matches the `SIGNING` dial.
- [ ] Build number bumped past anything already on App Store Connect for this version.
- [ ] `ITSAppUsesNonExemptEncryption` declared in Info.plist (no per-build compliance prompt).
- [ ] `PrivacyInfo.xcprivacy` present and complete (`privacy-manifest` skill ran).
- [ ] Every requested permission has its `NS…UsageDescription`; ATT string present if you track.
- [ ] CI uses an App Store Connect API key; automatic signing passes `-allowProvisioningUpdates` to archive and export.
- [ ] `xcrun altool --validate-app` passes before `--upload-app`.
- [ ] After processing: support/marketing/privacy URLs resolve, screenshots present, demo credentials in review notes if there's a login wall.

## Deep reference

`references/guide.md` — the full archive→export→upload CLI pipeline, ExportOptions.plist for automatic and manual signing, code-signing setup (keychain/profiles), App Store Connect API key auth, `xcrun altool` validate/upload, TestFlight processing, the pre-submission checklist, the categorized rejection-reason checklist with fixes, an end-to-end CI script, and a command quick-reference. Load it for any concrete flag or command.

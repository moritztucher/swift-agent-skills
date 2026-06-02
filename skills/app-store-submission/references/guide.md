# App Store Submission — CLI Pipeline & Review Checklist

The automatable path to shipping an iOS app: `xcodebuild` archive → export → upload, code-signing options, App Store Connect API key auth, TestFlight, and a categorized rejection-reason checklist with fixes. Scoped to the CLI/automatable parts — GUI portal steps (filling in metadata fields, clicking "Submit for Review") are noted but not the focus.

Cross-links: see the `privacy-manifest` skill (the most common rejection cause) and the `ios-release-notes` skill (generates the "What's New" block you paste into App Store Connect).

---

## 0. The pipeline at a glance

```
clean → archive → export (sign) → upload → process (TestFlight) → submit → review
└─ xcodebuild ──────────────┘   └─ xcrun altool ─┘   └── App Store Connect ──┘
```

Everything up to and including **upload** is fully scriptable. Everything after upload (build selection, screenshots, "Submit for Review", phased release) happens in App Store Connect — automatable only via the **App Store Connect API** (REST) or tools like Fastlane `deliver`, which wrap it.

---

## 1. Archive

You must archive from a clean state with a Release configuration. `xcodebuild` needs either `-project` or `-workspace` (use `-workspace` if you use CocoaPods/SPM-in-workspace).

```bash
xcodebuild \
  -workspace MyApp.xcworkspace \
  -scheme MyApp \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/MyApp.xcarchive \
  clean archive
```

Key points:

- **`-destination 'generic/platform=iOS'`** — a generic device destination, NOT a specific simulator/device. Archiving for a concrete simulator produces a non-distributable archive.
- **`-archivePath`** — where the `.xcarchive` lands. Give it an explicit path so the export step can find it (otherwise it goes into `~/Library/Developer/Xcode/Archives` by date).
- The scheme's **Archive action** must use the **Release** build configuration and the app target must be in the scheme's archive set.
- Add `-allowProvisioningUpdates` here if you use **automatic** signing on a fresh CI machine (lets `xcodebuild` create/download profiles via the API key — see §3).
- Optional: `-derivedDataPath build/DerivedData` to keep CI output contained; `CODE_SIGN_STYLE`, `DEVELOPMENT_TEAM`, `PROVISIONING_PROFILE_SPECIFIER` can be overridden as build settings on the command line.

Verify the archive exists and is the right kind:

```bash
ls build/MyApp.xcarchive/Products/Applications/   # MyApp.app present
plutil -p build/MyApp.xcarchive/Info.plist | grep -i version
```

---

## 2. Export (turns the archive into a signed `.ipa`)

```bash
xcodebuild -exportArchive \
  -archivePath build/MyApp.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist \
  -allowProvisioningUpdates
```

This writes `build/export/MyApp.ipa` plus a `DistributionSummary.plist` and `Packaging.log`. The behaviour is driven entirely by **ExportOptions.plist**.

### ExportOptions.plist — App Store, automatic signing

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>destination</key>
    <string>upload</string>            <!-- or "export" to just produce the .ipa -->
    <key>teamID</key>
    <string>ABCDE12345</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>uploadSymbols</key>
    <true/>                            <!-- include dSYMs for crash symbolication -->
    <key>manageAppVersionAndBuildNumber</key>
    <false/>                           <!-- set false so Xcode doesn't silently bump for you -->
</dict>
</plist>
```

Notes on the keys:

- **`method`** — historically `app-store`. Modern Xcode (15+) accepts/prefers **`app-store-connect`**. Other values: `release-testing` (ad-hoc), `enterprise`, `debugging` (development). For TestFlight/App Store use `app-store-connect`.
- **`destination`** — `export` produces a local `.ipa`; `upload` exports AND uploads to App Store Connect in one step (needs API-key auth available, see §4). Splitting export + a separate `altool` upload gives you a validatable artifact and clearer failures, so prefer `export` for CI.
- **`signingStyle`** — `automatic` or `manual`.
- **`uploadSymbols`** — keep `true` so App Store Connect symbolicates crash reports.
- **`manageAppVersionAndBuildNumber`** — leave `false` and control the build number yourself (see §7); `true` lets Xcode auto-increment, which can surprise CI.

### ExportOptions.plist — manual signing additions

For `signingStyle = manual`, add the certificate and a per-bundle-ID profile map:

```xml
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>Apple Distribution</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>com.example.MyApp</key>
        <string>MyApp App Store</string>          <!-- profile NAME, not file -->
        <key>com.example.MyApp.NotificationService</key>
        <string>MyApp NSE App Store</string>
    </dict>
```

Every embedded target (app + every extension/appex + watchOS app) needs its own entry. A missing one fails export with "no profile for bundle identifier".

---

## 3. Code signing — automatic vs manual

### Automatic ("Xcode-managed")

- Xcode/`xcodebuild` creates and renews the App ID, certificate, and provisioning profiles for you.
- On CI you MUST pass **`-allowProvisioningUpdates`** to both `archive` and `-exportArchive`, otherwise `xcodebuild` refuses to touch the developer portal and fails with a signing error.
- Authentication for `-allowProvisioningUpdates` on CI uses an **App Store Connect API key** passed via:
  ```bash
  -authenticationKeyPath /path/AuthKey_ABC123.p8 \
  -authenticationKeyID ABC123 \
  -authenticationKeyIssuerID 11111111-2222-3333-4444-555555555555
  ```
- Simplest to maintain; recommended for solo/small teams. The trade-off: less control over which exact certificate/profile is used.

### Manual

- You manage certificates and profiles explicitly (download `.mobileprovision`, install the **Apple Distribution** cert into the keychain).
- Required when: regulated provisioning, shared CI signing infra (e.g. Fastlane **match** storing certs in a git repo), or when you must pin an exact profile.
- The keychain on CI must be unlocked and contain the private key + distribution cert:
  ```bash
  security create-keychain -p "$KC_PW" build.keychain
  security import dist.p12 -k build.keychain -P "$P12_PW" -T /usr/bin/codesign
  security set-key-partition-list -S apple-tool:,apple: -s -k "$KC_PW" build.keychain
  security list-keychains -d user -s build.keychain login.keychain
  ```
- Profiles must be installed where `xcodebuild` looks (`~/Library/MobileDevice/Provisioning Profiles/`), or referenced by name in ExportOptions.

### Inspect what got signed

```bash
codesign -d -vvv --entitlements :- build/export/MyApp.ipa   # or the unzipped .app
# Look for: Authority=Apple Distribution: …, TeamIdentifier=ABCDE12345
```

---

## 4. Authentication — use an App Store Connect API key, not your Apple ID

Apple-ID + app-specific-password auth still works with `altool` but is fragile (2FA, session expiry) and unsuitable for CI. Use an **App Store Connect API key**:

1. App Store Connect → Users and Access → Integrations → App Store Connect API → generate a key with the **App Manager** role (or Admin).
2. You get three things — keep all of them:
   - the **`.p8`** private key file (downloadable **once**), e.g. `AuthKey_ABC123XYZ.p8`
   - the **Key ID** (e.g. `ABC123XYZ`)
   - the **Issuer ID** (a UUID, shown once at the top of the keys list)
3. Place the `.p8` where the tooling finds it. `altool`/`xcodebuild` look in (in order): `./private_keys`, `~/private_keys`, `~/.private_keys`, `~/.appstoreconnect/private_keys`. Or pass `--apiKey`/`--apiIssuer` directly.

```bash
mkdir -p ~/.appstoreconnect/private_keys
cp AuthKey_ABC123XYZ.p8 ~/.appstoreconnect/private_keys/
```

In CI, store the `.p8` contents and IDs as secrets; write the file out at runtime, never commit it.

---

## 5. Upload

> **Current-tool note (2026):** App Store / TestFlight uploads use **`xcrun altool`** (the command-line uploader) or Apple's **Transporter** app, or Xcode Organizer. **`notarytool` is NOT for App Store submission** — it notarizes Developer-ID-distributed *macOS* apps outside the store. Do not reach for `notarytool` here. `altool`'s *notarization* subcommands were deprecated in favour of `notarytool`, but `altool` remains the documented CLI for **App Store uploads and validation**.

### Validate first (catches most rejections before upload)

```bash
xcrun altool --validate-app \
  -f build/export/MyApp.ipa \
  -t ios \
  --apiKey ABC123XYZ \
  --apiIssuer 11111111-2222-3333-4444-555555555555
```

### Upload

```bash
xcrun altool --upload-app \
  -f build/export/MyApp.ipa \
  -t ios \
  --apiKey ABC123XYZ \
  --apiIssuer 11111111-2222-3333-4444-555555555555
```

- `--apiKey` is the **Key ID**, `--apiIssuer` is the **Issuer ID**; `altool` finds the matching `.p8` in the `private_keys` search path.
- `-t ios` (or `tvos`, `macos`) is the platform.
- Apple-ID fallback (avoid on CI): `--username you@apple.com --password "@keychain:AC_PASSWORD"` using an app-specific password.

### Alternatives

- **Xcode Organizer** — Window → Organizer → select archive → Distribute App. Good for a one-off manual ship; not scriptable.
- **Transporter.app** — drag-and-drop the `.ipa`; uses the same API-key auth.
- **Fastlane `pilot`/`deliver`** — wraps `altool` + the App Store Connect API for TestFlight and metadata/screenshots.
- **One-step**: ExportOptions `destination = upload` does export+upload together (less control, fine for simple pipelines).

---

## 6. After upload — TestFlight and submission

Once `altool` reports success, App Store Connect runs **build processing** (minutes to ~an hour). The build appears in TestFlight as "Processing", then "Ready to Test" / "Ready to Submit".

- **Export compliance** — if you have NOT declared `ITSAppUsesNonExemptEncryption` in Info.plist, every build shows a "Missing Compliance" / "Manage" prompt before it can be tested or submitted. Declare it in Info.plist to skip this per-build (see §7).
- **Internal testers** (up to 100, your team) can install immediately, no review.
- **External testers / groups** require a one-time **Beta App Review** of the build.
- **App Store submission** — attach the processed build to a version, fill required metadata (screenshots per device size, description, keywords, support/marketing URLs, privacy nutrition labels, age rating), then **Submit for Review**. Metadata + submission are automatable via the App Store Connect API / Fastlane `deliver`, not via `altool`.

The "What's New" / release-notes text comes from the **`ios-release-notes`** skill — generate it from git tags and paste it into the version's notes field.

---

## 7. Pre-submission checklist (do these before you archive)

### Build number — bump on EVERY upload

App Store Connect rejects a build whose `CFBundleVersion` (build number) for a given `CFBundleShortVersionString` (marketing version) already exists. You can upload `1.4.0 (5)` only once; the next upload must be `1.4.0 (6)`.

```bash
# Read current build number
agvtool what-version -terse

# Bump it (Apple Generic Versioning)
agvtool next-version -all          # increments CFBundleVersion
# or set marketing version
agvtool new-marketing-version 1.4.0
```

CI pattern: set the build number to the CI run number or commit count, e.g.
`agvtool new-version -all "$(git rev-list --count HEAD)"`.

### Export compliance declaration

Add to **Info.plist** to suppress the per-build compliance prompt:

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

- `false` is correct **only** if your app uses no encryption beyond what's exempt (HTTPS/TLS via the OS, standard Apple crypto). This covers most apps.
- If you use custom/non-exempt encryption, set `true` and supply the compliance documentation / `ITSEncryptionExportComplianceCode` in App Store Connect.
- Getting this wrong is a legal declaration, not just a convenience — but for the overwhelmingly common HTTPS-only case, `false` is both correct and saves the manual click on every build.

### Privacy manifest — the #1 ship-blocker

- `PrivacyInfo.xcprivacy` is required for the app and for many third-party SDKs. Missing required-reason API declarations trigger automated rejection email **ITMS-91053** and similar.
- Full coverage (required-reason APIs, tracking domains, SDK signatures, the privacy report) is in the **`privacy-manifest`** skill. Run it before archiving.

### Other pre-flight items

- **dSYMs** — confirm `uploadSymbols` is `true` so crash reports symbolicate. Without dSYMs, the Crashes organizer shows raw addresses.
- **App Transport Security** — no blanket `NSAllowsArbitraryLoads` without justification.
- **Permission usage strings** — every entitlement/permission you request needs an `NS…UsageDescription` in Info.plist (camera, location, photos, tracking, etc.). A missing string is a guaranteed crash-on-prompt and rejection.
- **App Tracking Transparency** — if you track, you need `NSUserTrackingUsageDescription` and must call `ATTrackingManager.requestTrackingAuthorization` before any tracking.
- **Icons & launch screen** — full icon set, no transparency/alpha in the App Store icon.
- **Screenshots** — required sizes for the device classes you support (uploaded in App Store Connect).
- **Working metadata URLs** — support URL, marketing URL, privacy policy URL must all resolve.
- **Demo account** — if any feature is behind login, provide credentials in App Review notes.

---

## 8. Rejection-reason checklist (categorized, with fixes)

Reviewers cite **App Store Review Guidelines** by number. The buckets you actually hit:

### Privacy & data (Guideline 5.1.x) — most common automated/manual rejections

| Symptom | Fix |
|---|---|
| ITMS-91053 / "missing required reason API" email | Add `PrivacyInfo.xcprivacy` with `NSPrivacyAccessedAPITypes` reasons → `privacy-manifest` skill. |
| Privacy nutrition labels don't match behaviour | Make App Store Connect data-collection answers match what the app actually collects. |
| Tracking without ATT | Implement App Tracking Transparency; declare tracking domains in the privacy manifest. |
| Missing privacy policy URL | Add a reachable privacy policy URL in App Store Connect metadata. |

### Crashes & bugs (Guideline 2.1 — Performance)

| Symptom | Fix |
|---|---|
| Crash on launch / during review | Test the **Release** build on a real device; reviewers use real devices on current OS. |
| Crash on a permission prompt | Add the missing `NS…UsageDescription`; never request a permission without its string. |
| Placeholder content / broken features | Ship a complete, functional build — no "coming soon", lorem ipsum, or dead buttons. |
| Demo content / login wall blocks review | Provide working demo credentials + steps in the App Review notes. |

### Broken links & metadata (Guideline 2.3 — Accurate Metadata, 1.5 — support URL)

| Symptom | Fix |
|---|---|
| Support/marketing URL 404s | Verify every metadata URL resolves before submitting. |
| Screenshots don't reflect the app | Use real in-app screenshots at the required device sizes; no marketing mockups misrepresenting the UI. |
| Description mentions other platforms / prices | Remove references to Android, "free for a limited time", competitor names. |

### Business / payments (Guideline 3.x)

| Symptom | Fix |
|---|---|
| Digital goods sold outside IAP | Unlockable digital content/subscriptions must use StoreKit IAP (see `storekit` / `revenuecat` skills). |
| Subscription terms unclear | Show price, period, and a link to terms on the paywall; restore-purchases path required. |

### Design & spam (Guideline 4.x)

| Symptom | Fix |
|---|---|
| 4.2 "Minimum functionality" / repackaged website | Provide native value beyond a wrapped web view. |
| 4.3 "Spam" / duplicate apps | Don't ship near-identical apps from one account; consolidate. |
| 4.0 Design / non-standard UI | Follow the Human Interface Guidelines; standard navigation and controls. |
| 4.8 Sign in with Apple missing | If you offer third-party social login, also offer Sign in with Apple. |

### Legal & safety (Guideline 1.x, 5.x)

| Symptom | Fix |
|---|---|
| User-generated content with no moderation (1.2) | Add reporting, blocking, and a content filter / EULA. |
| Account creation but no deletion (5.1.1(v)) | Provide in-app account deletion if you support account creation. |
| Login required to use the app unnecessarily | Only gate features that genuinely need an account. |

### Sign / upload errors (not "review", but block submission)

| Symptom | Fix |
|---|---|
| "redundant binary upload" / build number exists | Bump `CFBundleVersion` and re-export (see §7). |
| "no profile for bundle identifier" | Add every embedded target to ExportOptions `provisioningProfiles` (manual) or use `-allowProvisioningUpdates` (automatic). |
| "Missing Compliance" blocks the build | Add `ITSAppUsesNonExemptEncryption` to Info.plist. |
| Invalid Swift support / unsupported architectures | Archive with `generic/platform=iOS`, not a simulator destination. |

---

## 9. End-to-end CI script (automatic signing + API key)

```bash
set -euo pipefail

SCHEME="MyApp"
WORKSPACE="MyApp.xcworkspace"
ARCHIVE="build/MyApp.xcarchive"
EXPORT_DIR="build/export"
KEY_ID="ABC123XYZ"
ISSUER_ID="11111111-2222-3333-4444-555555555555"
KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8"

# 1. Bump build number deterministically
agvtool new-version -all "$(git rev-list --count HEAD)"

# 2. Archive
xcodebuild \
  -workspace "$WORKSPACE" -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY_PATH" \
  -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ISSUER_ID" \
  clean archive

# 3. Export signed .ipa
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist ExportOptions.plist \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY_PATH" \
  -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ISSUER_ID"

# 4. Validate then upload
IPA="$EXPORT_DIR/$SCHEME.ipa"
xcrun altool --validate-app -f "$IPA" -t ios --apiKey "$KEY_ID" --apiIssuer "$ISSUER_ID"
xcrun altool --upload-app   -f "$IPA" -t ios --apiKey "$KEY_ID" --apiIssuer "$ISSUER_ID"
```

After this, the build processes in App Store Connect; attach it to a version and Submit for Review there (or via the App Store Connect API / Fastlane).

---

## 10. Quick reference

| Task | Command |
|---|---|
| Archive | `xcodebuild -workspace W -scheme S -configuration Release -destination 'generic/platform=iOS' -archivePath A clean archive` |
| Export | `xcodebuild -exportArchive -archivePath A -exportPath E -exportOptionsPlist P -allowProvisioningUpdates` |
| Validate | `xcrun altool --validate-app -f X.ipa -t ios --apiKey K --apiIssuer I` |
| Upload | `xcrun altool --upload-app -f X.ipa -t ios --apiKey K --apiIssuer I` |
| Read build number | `agvtool what-version -terse` |
| Bump build number | `agvtool next-version -all` / `agvtool new-version -all N` |
| Inspect signature | `codesign -d -vvv --entitlements :- X.app` |
| List archives | `ls ~/Library/Developer/Xcode/Archives` |

**Tooling reality check:** `altool` = App Store upload/validate (current). `notarytool` = macOS Developer-ID notarization (NOT App Store). API key (`.p8` + Key ID + Issuer ID) = the auth to use everywhere on CI. `-allowProvisioningUpdates` = required for automatic signing off your dev Mac.

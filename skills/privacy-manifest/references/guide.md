# Privacy Manifests & Required-Reason APIs — Deep Reference

The complete reference for Apple privacy manifests (`PrivacyInfo.xcprivacy`), required-reason
APIs, third-party SDK obligations, and the App Store privacy report. The `SKILL.md` is the
discipline layer; this is the API/format detail. Load it for any concrete question.

Sources (verified 2026-06-02 via Context7, `/websites/developer_apple`):
- Privacy manifest files — `developer.apple.com/documentation/bundleresources/privacy-manifest-files`
- Describing data use in privacy manifests — same section
- Describing use of required reason API — same section
- TN3181 — adding tracking keys to your privacy manifest
- TN3182 — adding tracking keys (tracking domains)
- TN3183 — adding required reason API entries to your privacy manifest

---

## 1. What a privacy manifest is, and why it ships-blocks

A **privacy manifest** is a property-list file named exactly **`PrivacyInfo.xcprivacy`** that
declares, in machine-readable form:

1. Whether the code uses data for **tracking** (as defined by App Tracking Transparency).
2. The **internet domains** it connects to that engage in tracking.
3. The **data types** it collects and the reason for each.
4. The **required-reason APIs** it calls and an approved reason code for each.

The manifest is the source of truth Apple uses to (a) assemble the **App Privacy "nutrition
label"** report shown on the product page, and (b) **enforce** the required-reason API rules at
submission. As of **2024-05-01**, App Store Connect **rejects** uploads that call a
required-reason API without a declared reason, and **rejects** uploads that depend on a
commonly-used third-party SDK from Apple's list without that SDK shipping its own valid,
signed manifest. This is not a warning — it is a hard upload failure. The most common rejection
email cites **ITMS-91053 ("Missing API declaration")**, with ITMS-91054/91055/91056 variants for
invalid or unrecognized reason values.

Key truths:
- The manifest is **opt-in by being present**, but **mandatory in effect**: if you touch any
  required-reason API (directly or through a static dependency) you must declare it.
- Required-reason API enforcement applies to **iOS, iPadOS, tvOS, watchOS, and visionOS** apps.
- The file is plain text, but Xcode gives it a structured editor when you add a "App Privacy"
  file to a target.

---

## 2. File location & bundle placement

The manifest must live **inside the bundle it describes**:

| Code unit | Manifest location |
|---|---|
| App | `YourApp.app/PrivacyInfo.xcprivacy` (root of the app bundle) |
| Framework | `Framework.framework/PrivacyInfo.xcprivacy` (or versioned `Versions/A/Resources/` on macOS) |
| XCFramework | one `PrivacyInfo.xcprivacy` per platform/arch slice inside each contained framework |
| SPM resource bundle | declared as a resource so it copies into the consuming target's bundle |
| Static library | the **library author** publishes a manifest in their distribution; for a static `.a` the manifest is bundled in the framework/SPM wrapper that delivers it |

Add it in Xcode: **File → New → File → App Privacy** (resource type), then ensure it's in the
target's **Copy Bundle Resources** build phase. A manifest sitting in the repo but not copied
into the bundle does nothing — Apple only reads the copy inside the shipped bundle.

A single app can carry **many** manifests: one for the app plus one inside each embedded
framework/SDK. Apple **aggregates** all of them into one privacy report.

---

## 3. The four top-level keys

`PrivacyInfo.xcprivacy` is a standard XML plist whose root `<dict>` may contain four keys, all
optional individually but collectively required to cover whatever the code actually does:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array/>
</dict>
</plist>
```

| Key | Type | Meaning |
|---|---|---|
| `NSPrivacyTracking` | Boolean | `true` if the code uses data for tracking as defined by ATT |
| `NSPrivacyTrackingDomains` | Array of String | Internet domains that engage in tracking |
| `NSPrivacyCollectedDataTypes` | Array of Dict | The data types collected, each with a reason |
| `NSPrivacyAccessedAPITypes` | Array of Dict | Required-reason APIs accessed, each with reason codes |

---

## 4. Tracking — `NSPrivacyTracking` & `NSPrivacyTrackingDomains`

"Tracking" means linking data collected in your app with data from other companies' apps,
websites, or offline properties for targeted advertising or measurement, **or** sharing it with
a data broker — the exact ATT definition.

```xml
<key>NSPrivacyTracking</key>
<true/>
<key>NSPrivacyTrackingDomains</key>
<array>
    <string>analytics.example.com</string>
    <string>ads.example-partner.com</string>
</array>
```

Rules:
- If `NSPrivacyTracking` is `true`, the app **must** request authorization via
  `ATTrackingManager.requestTrackingAuthorization` and **must** honor `.denied` — no tracking
  network calls when the user declines.
- Every domain that performs tracking **must** be listed in `NSPrivacyTrackingDomains`. When ATT
  is **not** authorized, the system **blocks network connections** to domains on this list — so
  declaring a domain you can't avoid hitting before consent will break that request, which is the
  intended behavior, not a bug.
- If `NSPrivacyTracking` is `true`, `NSPrivacyTrackingDomains` must be **non-empty**. Conversely,
  if you list tracking domains, set `NSPrivacyTracking` to `true`.
- Find your real connected domains with **Instruments → "Points of Interest" / the network
  instrument**, or Xcode's privacy report, then classify which ones do tracking.

Minimal "we do not track" manifest (still worth shipping to assert the negative cleanly):

```xml
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
</dict>
```

---

## 5. Collected data types — `NSPrivacyCollectedDataTypes`

An array of dictionaries; one entry per data type the code collects. Each entry carries the
data type, whether it is linked to identity, whether it is used for tracking, and one or more
purpose strings.

```xml
<key>NSPrivacyCollectedDataTypes</key>
<array>
    <dict>
        <key>NSPrivacyCollectedDataType</key>
        <string>NSPrivacyCollectedDataTypeEmailAddress</string>
        <key>NSPrivacyCollectedDataTypeLinked</key>
        <true/>
        <key>NSPrivacyCollectedDataTypeTracking</key>
        <false/>
        <key>NSPrivacyCollectedDataTypePurposes</key>
        <array>
            <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
        </array>
    </dict>
    <dict>
        <key>NSPrivacyCollectedDataType</key>
        <string>NSPrivacyCollectedDataTypeDeviceID</string>
        <key>NSPrivacyCollectedDataTypeLinked</key>
        <false/>
        <key>NSPrivacyCollectedDataTypeTracking</key>
        <true/>
        <key>NSPrivacyCollectedDataTypePurposes</key>
        <array>
            <string>NSPrivacyCollectedDataTypePurposeThirdPartyAdvertising</string>
            <string>NSPrivacyCollectedDataTypePurposeAnalytics</string>
        </array>
    </dict>
</array>
```

Per-entry keys:

| Key | Type | Meaning |
|---|---|---|
| `NSPrivacyCollectedDataType` | String | The data category (see below) |
| `NSPrivacyCollectedDataTypeLinked` | Boolean | Whether the data is linked to the user's identity |
| `NSPrivacyCollectedDataTypeTracking` | Boolean | Whether the data is used for tracking |
| `NSPrivacyCollectedDataTypePurposes` | Array of String | One or more purpose values |

Representative data-type values (each maps to a row on the App Privacy label):
- Contact info: `…EmailAddress`, `…Name`, `…PhoneNumber`, `…PhysicalAddress`, `…OtherUserContactInfo`
- Identifiers: `…DeviceID`, `…UserID`
- Usage/diagnostics: `…ProductInteraction`, `…AdvertisingData`, `…CrashData`, `…PerformanceData`, `…OtherDiagnosticData`
- Sensitive: `…PreciseLocation`, `…CoarseLocation`, `…Health`, `…Fitness`, `…Photos`, `…Contacts`, `…PaymentInfo`, `…SearchHistory`, `…BrowsingHistory`

Purpose values:
- `…PurposeThirdPartyAdvertising`
- `…PurposeDeveloperAdvertising`
- `…PurposeAnalytics`
- `…PurposeProductPersonalization`
- `…PurposeAppFunctionality`
- `…PurposeOther`

The privacy report aggregates these across the app and all embedded SDKs; the App Privacy
nutrition label on the product page is derived from the union. You still confirm the label in
App Store Connect, but the manifests are the upstream truth.

---

## 6. Required-reason APIs — `NSPrivacyAccessedAPITypes`

Certain APIs can be abused to fingerprint a device, so Apple gates them: you may call them only
for an approved reason, and you must declare that reason in the manifest. Each entry has exactly
two keys — a **category** and an **array of reason codes**.

```xml
<key>NSPrivacyAccessedAPITypes</key>
<array>
    <dict>
        <key>NSPrivacyAccessedAPIType</key>
        <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
        <key>NSPrivacyAccessedAPITypeReasons</key>
        <array>
            <string>CA92.1</string>
        </array>
    </dict>
    <dict>
        <key>NSPrivacyAccessedAPIType</key>
        <string>NSPrivacyAccessedAPICategoryDiskSpace</string>
        <key>NSPrivacyAccessedAPITypeReasons</key>
        <array>
            <string>E174.1</string>
            <string>85F4.1</string>
        </array>
    </dict>
</array>
```

The dictionary contains **exactly two keys**: `NSPrivacyAccessedAPIType` (one category string)
and `NSPrivacyAccessedAPITypeReasons` (a non-empty array of reason-code strings). You may list
**multiple** reasons for one category if your code uses it several ways.

### 6.1 Categories and reason codes

These are the categories enforced and their valid reason codes. Reason codes verified against
Apple TN3183 / the privacy-manifest-files reference.

#### User Defaults — `NSPrivacyAccessedAPICategoryUserDefaults`
APIs: `UserDefaults`, `NSUserDefaults`.

| Code | Reason |
|---|---|
| `CA92.1` | Access info from user defaults to read/write information accessible only to the app itself (not an app group / not shared). |
| `1C8F.1` | Access user defaults to read/write information **within an app group / among apps from the same vendor** (shared container), where the data is accessible only to those apps. |
| `C56D.1` | A third-party SDK uses user defaults solely to access information the same SDK wrote. |
| `AC6B.1` | Access user defaults to read the com.apple.configuration.managed key for MDM-managed app configuration, or to write feedback. |

> Footgun: **almost every app uses `UserDefaults`.** If you ship a manifest, this category is
> almost always required. Forgetting it is a top ITMS-91053 cause.

#### File timestamp — `NSPrivacyAccessedAPICategoryFileTimestamp`
APIs: `creationDate`/`modificationDate`, `.fileModificationDate`, `.contentModificationDateKey`,
`.creationDateKey`, `getattrlist`, `getattrlistbulk`, `fgetattrlist`, `stat`, `fstat`, `lstat`, etc.

| Code | Reason |
|---|---|
| `DDA9.1` | Display file timestamps to the person using the device. |
| `C617.1` | Access timestamps/size/etc. of files **inside the app's own container** to manage them. |
| `3B52.1` | Access timestamps of files/directories the user **specifically granted access to** (e.g. document picker). |
| `0A2A.1` | A third-party SDK wrapping a file-provider/sync product accesses timestamps of files it manages on behalf of the user. |

#### System boot time — `NSPrivacyAccessedAPICategorySystemBootTime`
APIs: `systemUptime`, `mach_absolute_time`.

| Code | Reason |
|---|---|
| `35F9.1` | Measure elapsed time between events that occurred within the app. |
| `8FFB.1` | Calculate absolute timestamps for events inside the app (e.g. CoreMotion / network), where the absolute timestamp itself is not sent off-device for fingerprinting. |

#### Disk space — `NSPrivacyAccessedAPICategoryDiskSpace`
APIs: `volumeAvailableCapacityKey` family, `systemFreeSize`/`systemSize`, `statfs`, `statvfs`,
`fstatfs`, `fstatvfs`.

| Code | Reason |
|---|---|
| `85F4.1` | Display disk space to the person using the device. |
| `E174.1` | Check there is enough disk space before writing files, or to avoid running with insufficient space. |
| `7D9E.1` | A third-party SDK that is a backup/sync product checks disk space on behalf of the user. |
| `B728.1` | Access disk space to include it in optional, user-initiated diagnostic data the user explicitly shares. |

#### Active keyboard — `NSPrivacyAccessedAPICategoryActiveKeyboards`
APIs: `activeInputModes`.

| Code | Reason |
|---|---|
| `3EC4.1` | A custom keyboard app accesses the list of active keyboards to customize its UI. |
| `54BD.1` | Access active keyboards to present the correct layout for localization, given the user's enabled keyboards. |

### 6.2 Reason-code discipline

- A category with **no approved reason** for your use means you **must not call the API** — there
  is no "declare anyway" escape; you change the code.
- Reason codes are **case-sensitive** and must match Apple's list exactly. A typo yields an
  "invalid value" rejection (ITMS-91055/91056 family).
- If you call a required-reason API **only inside a dependency**, the **dependency's** manifest
  must declare it — but if you call it in your own code too, your app manifest must declare it
  independently. They are not transitive substitutes.

---

## 7. Third-party SDK responsibilities & signatures

Apple maintains a list of **commonly-used SDKs** that have outsized fingerprinting reach. If your
app embeds an SDK on that list, two things are required at submission:

1. The SDK must include its **own** `PrivacyInfo.xcprivacy` describing its tracking, data
   collection, and required-reason API usage.
2. When the SDK is distributed as a binary (XCFramework), it must be **code-signed by its author**,
   and Apple validates that **signature**. An unsigned or mismatched-signature copy of a listed
   SDK fails the upload.

Implications for app developers:
- You **cannot** declare a listed SDK's APIs on its behalf in your own app manifest. The SDK
  author owns its manifest. If their version doesn't ship one (or ships an unsigned binary), you
  must **upgrade** to a version that does, or remove the SDK.
- Verify the SDK's signature before trusting it. For an XCFramework you can inspect with
  `codesign -dv --verbose=4 Path/To/SDK.framework` and confirm the **Authority** /
  **TeamIdentifier** match the vendor. Swift Package binaries declare a checksum in
  `Package.swift`; SPM verifies it on resolve.
- Many SDK vendors (analytics, ads, crash reporters, networking) are on the list precisely
  because they hit required-reason APIs and connect to tracking domains — assume any analytics/ads
  SDK needs a manifest until proven otherwise.

Aggregation: when you archive, Xcode merges the app manifest with every embedded framework/SDK
manifest. The merged result is what feeds the privacy report and the App Privacy label, and what
Apple checks at submission.

---

## 8. Generating & reading the privacy report

Xcode can produce a human-readable **Privacy Report** that aggregates all manifests in an archive
— useful before submission and for filling in App Store Connect:

1. **Product → Archive** the app.
2. In the **Organizer**, select the archive.
3. **Right-click the archive → Generate Privacy Report** (also reachable from the Organizer's
   action menu).
4. Xcode emits a **PDF** summarizing, across the app and all bundled SDKs: tracking flag, tracking
   domains, collected data types with purposes, and the required-reason API categories declared.

Use it to (a) sanity-check that each embedded SDK contributed a manifest, (b) confirm your
declared data types match what you tell App Store Connect, and (c) spot a tracking domain or data
type you didn't expect (often introduced by an SDK).

Complementary tooling:
- **Xcode's build-time privacy diagnostics** flag required-reason API calls without a matching
  manifest entry in some configurations.
- **Instruments / network instrument** reveals the real set of connected domains so you can
  populate `NSPrivacyTrackingDomains` accurately.
- Third-party scanners (e.g. grep for the API symbols in your dependency sources) help find
  undeclared required-reason API calls in static dependencies you control.

---

## 9. Submission-rejection scenarios

What actually bounces an upload, and the fix:

| Symptom (email / Connect) | Cause | Fix |
|---|---|---|
| **ITMS-91053: Missing API declaration** | Code calls a required-reason API in a category not declared in any manifest. | Add the category + a valid reason code to the right manifest (app or SDK). |
| ITMS-91054: Invalid API category | Misspelled `NSPrivacyAccessedAPIType` value. | Use the exact category constant. |
| ITMS-91055/91056: Invalid/Unrecognized reason | Reason code typo or not valid for that category. | Use an approved code from Apple's list for that category. |
| Rejection citing a named SDK + privacy manifest | A listed third-party SDK ships no manifest or is unsigned. | Upgrade to a version with a signed manifest, or drop the SDK. |
| App Privacy label mismatch flagged in review | Declared data types in manifest disagree with App Store Connect answers. | Reconcile the manifest with the Connect questionnaire. |
| Tracking network calls succeed before ATT prompt in review | `NSPrivacyTracking` true but ATT not requested / not honored, or tracking domain not listed. | Request ATT, honor denial, list tracking domains so the system can block them pre-consent. |

Notes:
- These checks run on **upload to App Store Connect**, before human review — you find out within
  minutes of `xcrun altool` / Transporter / Xcode upload, not days later.
- A **TestFlight** build is subject to the same upload checks, so you catch manifest problems in
  beta distribution too.
- The required-reason rules apply even if the API call lives deep in a static dependency you
  didn't write — you're responsible for what your binary contains.

---

## 10. Pre-submission checklist

- [ ] `PrivacyInfo.xcprivacy` exists and is in **Copy Bundle Resources** for the app target.
- [ ] Every embedded framework/SDK that needs one carries its **own** manifest (and listed SDKs are **signed**).
- [ ] `NSPrivacyTracking` matches reality; if `true`, ATT is requested and honored, and `NSPrivacyTrackingDomains` is non-empty and complete.
- [ ] `UserDefaults` usage is declared (`CA92.1` or `1C8F.1` as appropriate) — the most-missed entry.
- [ ] Every required-reason API the binary calls (file timestamp, boot time, disk space, active keyboards, …) has its category + a **valid, exact** reason code.
- [ ] Reason codes are spelled exactly and are valid for their category (case-sensitive).
- [ ] `NSPrivacyCollectedDataTypes` matches the App Store Connect App Privacy answers.
- [ ] Generated the **Privacy Report** from the archive and reviewed the aggregated output.
- [ ] Verified upload succeeds (no ITMS-9105x) on a TestFlight build before the real submission.

---

## 11. Quick reference — category constants & top reason codes

| Category constant | Common reason codes |
|---|---|
| `NSPrivacyAccessedAPICategoryUserDefaults` | `CA92.1` (app-only), `1C8F.1` (app group), `C56D.1` (SDK self), `AC6B.1` (MDM) |
| `NSPrivacyAccessedAPICategoryFileTimestamp` | `DDA9.1` (display), `C617.1` (own container), `3B52.1` (user-granted), `0A2A.1` (SDK file-provider) |
| `NSPrivacyAccessedAPICategorySystemBootTime` | `35F9.1` (elapsed in-app), `8FFB.1` (absolute in-app timestamps) |
| `NSPrivacyAccessedAPICategoryDiskSpace` | `85F4.1` (display), `E174.1` (write check), `7D9E.1` (SDK backup), `B728.1` (user diagnostics) |
| `NSPrivacyAccessedAPICategoryActiveKeyboards` | `3EC4.1` (custom keyboard), `54BD.1` (localization) |

Top-level keys: `NSPrivacyTracking` (Bool) · `NSPrivacyTrackingDomains` ([String]) ·
`NSPrivacyCollectedDataTypes` ([Dict]) · `NSPrivacyAccessedAPITypes` ([Dict]).

Per-API dict: `NSPrivacyAccessedAPIType` (String, one category) +
`NSPrivacyAccessedAPITypeReasons` ([String], ≥1 code).

---
name: privacy-manifest
description: Author and validate Apple privacy manifests (PrivacyInfo.xcprivacy) and required-reason API declarations — a ship-blocking App Store requirement. Use when the user mentions privacy manifest, PrivacyInfo.xcprivacy, required reason API, NSPrivacyAccessedAPITypes, tracking domains, App Store privacy rejection, ITMS-91053, NSPrivacyTracking, or collected data types. Covers the app manifest, third-party SDK manifests + signatures, and the privacy report.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple privacy-manifest docs via Context7 (/websites/developer_apple)
---

# Privacy Manifests

Apple privacy manifests (`PrivacyInfo.xcprivacy`) and required-reason APIs — declaring tracking, tracking domains, collected data types, and the gated APIs your binary calls. Enforced at **upload to App Store Connect**: a missing or wrong declaration is a hard rejection, not a warning. The deep reference — exact plist structure, every category, the real reason codes, SDK signature rules, the privacy report — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `SCOPE` — `app-only` (you only declare your own app's manifest) · `app+sdks` (default; you also confirm every embedded framework/SDK on Apple's commonly-used list ships its own valid, signed manifest — you cannot declare on their behalf).
2. `TRACKING` — `none` (`NSPrivacyTracking` false, no tracking domains) · `tracking-declared` (`NSPrivacyTracking` true + non-empty `NSPrivacyTrackingDomains` + ATT requested and honored).
3. `APIS` — `declare-reasons` (every required-reason API the binary calls has its category + an exact, approved reason code; if no approved reason fits, the code changes — there is no "declare anyway").

## When to use

Authoring or reviewing any `PrivacyInfo.xcprivacy`, debugging an ITMS-91053/91054/91055/91056 rejection, deciding which required-reason API reason code applies, vetting whether an embedded SDK needs its own manifest, or preparing the privacy report before submission. Use it any time an iOS/iPadOS/tvOS/watchOS/visionOS app is about to ship.

## Core rules

- The manifest is the named file **`PrivacyInfo.xcprivacy`**, a standard XML plist, placed **inside the bundle it describes** and copied via **Copy Bundle Resources**. A manifest in the repo but not in the bundle does nothing.
- Four top-level keys: `NSPrivacyTracking` (Bool), `NSPrivacyTrackingDomains` ([String]), `NSPrivacyCollectedDataTypes` ([Dict]), `NSPrivacyAccessedAPITypes` ([Dict]).
- Every required-reason API category entry has **exactly two keys** — `NSPrivacyAccessedAPIType` (one category) and `NSPrivacyAccessedAPITypeReasons` (≥1 exact, case-sensitive reason code).
- You own your app's manifest; each listed third-party SDK owns its own (and binary SDKs must be **signed** by the vendor). Manifests are **aggregated** at archive time into one privacy report.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "We'll ship without a manifest and add it if review complains." | Required-reason API and listed-SDK checks run at **upload**, before human review. A missing declaration is a hard **ITMS-91053** upload failure — you never reach review. |
| "We don't use `UserDefaults` enough to declare it." | **Almost every app uses `UserDefaults`**, and it is a required-reason category. It needs `CA92.1` (app-only) or `1C8F.1` (app group). Missing it is the #1 cause of ITMS-91053. |
| "I'll declare the analytics/ads SDK's APIs in our app manifest." | You **cannot** declare a listed SDK's usage on its behalf. The SDK author must ship its **own** signed `PrivacyInfo.xcprivacy`. If their version doesn't, upgrade or remove it. |
| "We don't show an ATT prompt, but I'll set `NSPrivacyTracking` true to be safe." | `NSPrivacyTracking` must **match actual ATT usage**. True without requesting+honoring `requestTrackingAuthorization` (and a non-empty tracking-domains list) is a mismatch that fails review. |
| "I called a required-reason API, I'll just pick any reason code." | Reason codes are **case-sensitive and category-specific**; a wrong/typo code is ITMS-91055/91056. If **no approved reason fits your use**, you must change the code — there is no escape hatch. |
| "The manifest sits in my repo, so it's covered." | It must be **inside the shipped bundle** (Copy Bundle Resources), and each embedded framework needs its own copy. Apple only reads the bundled copy. |

## Verification gate

Before submitting, confirm every line:

- [ ] `PrivacyInfo.xcprivacy` exists and is in the app target's **Copy Bundle Resources**.
- [ ] `UserDefaults` usage declared (`CA92.1` or `1C8F.1`) — the most-missed entry.
- [ ] Every required-reason API the binary calls (file timestamp, system boot time, disk space, active keyboards, …) has its category + an **exact, approved** reason code.
- [ ] `NSPrivacyTracking` matches reality; if true, ATT is requested **and** honored and `NSPrivacyTrackingDomains` is non-empty and complete.
- [ ] Every embedded framework/SDK that needs one carries its **own** manifest; listed binary SDKs are **signed** by their vendor.
- [ ] `NSPrivacyCollectedDataTypes` matches the App Store Connect App Privacy answers.
- [ ] Generated the **Privacy Report** from the archive and reviewed the aggregated output.
- [ ] Confirmed a TestFlight upload succeeds with no ITMS-9105x before the real submission.

## Deep reference

`references/guide.md` — full file format and bundle placement, the four top-level keys, tracking + tracking domains, collected data types + purposes, the required-reason API table with real reason codes (UserDefaults `CA92.1`/`1C8F.1`, file timestamp `C617.1`/`3B52.1`/`0A2A.1`, system boot time `35F9.1`/`8FFB.1`, disk space `E174.1`/`85F4.1`, active keyboards `54BD.1`, …), third-party SDK responsibilities + signature validation, generating the privacy report, and the submission-rejection scenarios. Load it for any concrete declaration question.

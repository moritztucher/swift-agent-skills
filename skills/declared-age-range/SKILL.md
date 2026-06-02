---
name: declared-age-range
description: Build age-appropriate experiences with Apple's DeclaredAgeRange framework (iOS 26+) — request a privacy-preserving age range via AgeRangeService instead of a birthdate, handle shared/declined responses, respect parental controls, and meet child-safety laws like Texas SB 2420. Use when the user mentions Declared Age Range, DeclaredAgeRange, age verification, age range, age-appropriate, age-gating, parental controls, COPPA, or child safety. For parental-consent and communication-limit flows that pair with this, use the `permissionkit` skill.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple Developer docs via Context7 (/websites/developer_apple — https://developer.apple.com/documentation/DeclaredAgeRange)
---

# DeclaredAgeRange

Apple's privacy-preserving age-assurance framework (iOS 26+). The user (or their guardian, inside iCloud Family) declares an age *band* — the app receives a range like 13–15 or 18+, **never an exact birthdate**. The deep API reference — `AgeRangeService`, SwiftUI `requestAgeRange`, UIKit usage, the full `AgeRangeDeclaration`/`ParentalControlOptions` surface, iOS 26.2 eligibility, testing, and the Texas SB 2420 mapping — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `GATES` — how many age thresholds you request. `single` (one `ageGates:` value → two bands, e.g. `16` → <16 / 16+) · `multi` (up to **3** gates → 4 bands; Texas uses `13, 16, 18` → <13 / 13–15 / 16–17 / 18+). Each resulting band must span at least 2 years or the request throws `invalidRequest`.
2. `DECLINE_POLICY` — what happens when the user returns `.declinedSharing` (or the service is `notAvailable`). `protective` (default; fall back to the most restrictive safe experience — required posture for compliance laws) · `degrade` (disable only the age-gated feature, leave the rest open). Never treat declined as "adult".
3. `ENTRY` — surface used. `swiftui` (`@Environment(\.requestAgeRange)`, default for SwiftUI) · `uikit` (`AgeRangeService.shared.requestAgeRange(ageGates:in:)` with a presenting view controller).

## When to use

Building or reviewing any flow that needs to know a user's age band to gate content, satisfy a child-safety regulation (Texas SB 2420, COPPA-adjacent), or shape an age-appropriate experience on iOS 26+. If the flow needs *parental consent* for a significant change, or contact/communication approval, that is PermissionKit — use the `permissionkit` skill; the two are designed to work together (this framework tells you parental controls are active, PermissionKit runs the parent-approval round trip).

## Core rules

- Requires the **Declared Age Range** capability and the `com.apple.developer.declared-age-range` entitlement. iOS/iPadOS 26.0+; some APIs (`isEligibleForAgeFeatures`, the extra `AgeRangeDeclaration` cases) need 26.2+ — gate them with `@available`.
- The response is `AgeRangeResponse`: `.sharing(AgeRange)` or `.declinedSharing`. Always handle **both**, plus the thrown `AgeRangeService.Error` (`invalidRequest`, `notAvailable`).
- An `AgeRange` gives `lowerBound`/`upperBound` as **optionals** — a `nil` `lowerBound` means "below your lowest gate" (e.g. under 13), the most restrictive case. Branch on that first.
- Store the **derived gate decision** (e.g. `isAdult`, `tier`), not the bounds, and only for as long as you need it. Don't persist or transmit the age band as if it were profile data.
- Respect `range.activeParentalControls` (`.communicationLimits`, `.significantAppChangeApprovalRequired`) regardless of the age band.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "It tells me the user is 16." | It returns a **range**, not an exact age. `lowerBound`/`upperBound` are optionals; a `nil` `lowerBound` means below your lowest gate. Branch on the band, never assume a precise age. |
| "They declined, so they're probably an adult — let them in." | `.declinedSharing` and `notAvailable` are **not** consent and not proof of age. Under `DECLINE_POLICY: protective` you fall back to the most restrictive safe experience; treating declined as adult is exactly the failure these laws target. |
| "I'll save their age range to the profile / send it to my backend." | The whole point is privacy-preserving minimization. Keep the **derived decision** (a gate result), not the band; don't log it, don't ship it to analytics, don't persist a birthdate you were never given. |
| "Shipping this means we're COPPA / SB 2420 compliant." | The API is a *signal*, not a legal shield. It relies on a declared age (it cannot detect a false declaration) and is explicitly **not** high-assurance identity verification. Compliance is a legal determination — pair the signal with your own policy and counsel. |
| "I'll request more gates to get a tighter age." | Max **3** gates, and every band must be ≥2 years or you get `invalidRequest`. More gates ≠ more precision; it's a fixed-resolution, privacy-bounded API by design. |
| "Works in the Simulator, ship it." | The Simulator has limited support; `notAvailable` is common there. Real verification needs a physical device with a sandbox Apple Account and the iOS 26.2 developer test scenarios (e.g. "Texas user aged 14 without parental consent"). |

## Verification gate

Before shipping any age-gated flow, confirm every line:

- [ ] **Declared Age Range** capability enabled and `com.apple.developer.declared-age-range` entitlement present.
- [ ] `ageGates:` is ≤3 values and every resulting band spans ≥2 years (no `invalidRequest`).
- [ ] Both `.sharing` and `.declinedSharing` handled; `invalidRequest` and `notAvailable` caught and handled (not crashed).
- [ ] `nil` `lowerBound` (below lowest gate) is treated as the most restrictive case, branched first.
- [ ] Declined / unavailable falls back per `DECLINE_POLICY` — under `protective`, the safe restrictive experience, never "treat as adult".
- [ ] Only the **derived gate decision** is stored/used; no birthdate, no raw band persisted, logged, or sent to a backend/analytics.
- [ ] `activeParentalControls` respected; significant-change / communication flows routed to PermissionKit (`permissionkit` skill).
- [ ] iOS 26.2-only APIs (`isEligibleForAgeFeatures`, extra declaration cases) guarded with `@available`.
- [ ] Tested on a **physical device** with a sandbox account + developer test scenarios, not just the Simulator.

## Deep reference

`references/guide.md` — full DeclaredAgeRange API: setup/entitlement, `AgeRangeService`, SwiftUI `requestAgeRange` and UIKit usage, the complete `AgeRangeResponse`/`AgeRange`/`AgeRangeDeclaration`/`ParentalControlOptions`/`Error` surface, iOS 26.2 eligibility checks, the Texas SB 2420 category mapping, the PermissionKit pairing, testing in sandbox, best practices, and common errors. Load it for any concrete API question.

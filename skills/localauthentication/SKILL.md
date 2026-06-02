---
name: localauthentication
description: Add and review biometric / device-owner authentication on Apple platforms with the LocalAuthentication framework — LAContext, canEvaluatePolicy, evaluatePolicy, Face ID / Touch ID / Optic ID, biometryType, LAError handling, passcode fallback, and Keychain access control. Use when the user mentions Face ID, Touch ID, Optic ID, biometrics, biometric authentication, LAContext, app lock, unlock with biometrics, or Local Authentication. For account-level / federated sign-in (Sign in with Apple, passkeys, credential sheets) use the `authenticationservices` skill instead.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple Developer docs via Context7 (/websites/developer_apple — LocalAuthentication)
---

# LocalAuthentication

Biometric and device-passcode authentication on Apple platforms (Face ID, Touch ID, Optic ID) via `LAContext`. The deep API reference — setup, every policy, the full evaluate flow, error mapping, biometric-change detection, Keychain access control, SwiftUI app-lock, and testing — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `POLICY` — `biometrics-only` (`.deviceOwnerAuthenticationWithBiometrics`; fails outright if biometry is unavailable/not enrolled — use when only Face ID/Touch ID is acceptable) · `with-passcode` (default; `.deviceOwnerAuthentication`; falls back to the device passcode when biometry fails or is unavailable).
2. `SECRET_BINDING` — `gate-only` (the `evaluatePolicy` Bool just unlocks app UI; **no secret is protected** — acceptable only for convenience locks) · `keychain-bound` (the thing being protected is a Keychain item with `SecAccessControl` flags like `.biometryCurrentSet` + `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`; required when a real secret/token must be unreachable without auth).
3. `REPROMPT` — `every-access` (new `LAContext` per evaluation, default) · `reuse-window` (`context.touchIDAuthenticationAllowableReuseDuration` to skip the prompt for N seconds after a recent success — only for low-sensitivity re-entry).

## When to use

Adding or reviewing any biometric/passcode prompt: app lock, transaction confirmation, unlocking stored credentials, or Keychain items guarded by biometry. If the task is account-level identity — Sign in with Apple, passkeys/WebAuthn, the credential picker — that is `authenticationservices`, not this. LocalAuthentication proves "the device owner is present right now"; it does not establish *who* the account holder is.

## Core rules

- **`NSFaceIDUsageDescription` is mandatory** on any target that can hit Face ID. Without it the system kills the prompt — treat it as a build requirement, not an afterthought.
- **`canEvaluatePolicy(_:error:)` before every `evaluatePolicy`**, and it is what populates `biometryType` — read `biometryType` only after a successful `canEvaluatePolicy`, never before (it returns `.none` otherwise).
- **A fresh `LAContext` per authentication.** A context that already succeeded re-succeeds without prompting; reusing one silently defeats the check.
- **Biometrics is a presence check, not a security boundary.** The returned `Bool` protects nothing on its own. If a real secret is involved, store it in the Keychain with `SecAccessControl` and let the system enforce auth on access (`SECRET_BINDING = keychain-bound`).
- iOS 15+ for async `evaluatePolicy`; Optic ID is visionOS. iOS 26 is the default target. Always handle `@unknown default` on `LABiometryType` / `LAError.Code`.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll add `NSFaceIDUsageDescription` later, it's just a string." | Without it the Face ID prompt fails (or the app crashes on the privacy check) on every Face ID device. It is a hard prerequisite — add it before the first evaluate. |
| "I'll read `context.biometryType` to pick the icon, then authenticate." | `biometryType` is `.none` until `canEvaluatePolicy` runs on that same context. Call `canEvaluatePolicy` first, or your UI always shows the generic/lock state. |
| "Auth passed, so the data is safe — I'll gate the view on the Bool." | The Bool only hid UI. Anyone with the binary/jailbreak can flip it. A real secret must live in the Keychain behind `SecAccessControl` (`.biometryCurrentSet`), so the OS — not your `if` — enforces access. |
| "One `LAContext` for the whole session is simpler." | A context that succeeded once auto-succeeds on the next `evaluatePolicy` with no prompt. Create a new context every time you actually want the user re-verified. |
| "I'll just show a generic error and bail on failure." | `userCancel`/`userFallback` are intentional user choices (don't show an error; honor the fallback), and `biometryLockout` means biometry is locked after repeated failures — you must route to passcode. Map each `LAError.Code` to distinct handling. |
| "`.deviceOwnerAuthenticationWithBiometrics` is the strict, secure choice." | It also *fails closed* when biometry is unenrolled/unavailable, locking out legitimate users with no recourse. Most app locks want `.deviceOwnerAuthentication` so the passcode is a valid fallback — pick the policy deliberately. |

## Verification gate

Before shipping a LocalAuthentication flow, confirm every line:

- [ ] `NSFaceIDUsageDescription` present on every target that can reach Face ID, with a clear user-facing reason.
- [ ] `canEvaluatePolicy(_:error:)` called before each `evaluatePolicy`; `biometryType` read only afterward.
- [ ] A new `LAContext` is created for each authentication — no shared/reused context.
- [ ] Policy chosen deliberately: `.deviceOwnerAuthentication` (passcode fallback) vs `.deviceOwnerAuthenticationWithBiometrics` (fails when biometry unavailable), matching the `POLICY` dial.
- [ ] `LAError.Code` mapped per case: `userCancel`/`userFallback` handled silently/with fallback (no error alert), `biometryLockout` routes to passcode, `biometryNotEnrolled`/`passcodeNotSet` guide the user to Settings.
- [ ] Any actual secret is Keychain-bound with `SecAccessControl` (e.g. `.biometryCurrentSet`), not gated only by the evaluate Bool (`SECRET_BINDING`).
- [ ] `@unknown default` handled on `LABiometryType` and `LAError.Code` switches.
- [ ] Tested on a real device (Simulator Face ID differs): success, cancel, lockout (5 fails), and biometry-disabled-in-Settings paths.

## Deep reference

`references/guide.md` — full setup (`NSFaceIDUsageDescription`, import), `LAContext`/`LAPolicy`/`LABiometryType` concepts, async authentication, availability + biometry-type detection, passcode fallback, complete `LAError` mapping, biometric-change detection via `evaluatedPolicyDomainState`, context customization/invalidation, Keychain access-control integration, SwiftUI app-lock, version compatibility, and testing. Load it for any concrete API question.

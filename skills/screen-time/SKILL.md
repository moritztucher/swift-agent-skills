---
name: screen-time
description: Build Screen Time / parental-control / app-limiting features on Apple platforms — authorization, app & category selection, shields and restrictions, usage monitoring, and the background monitor extension. Covers the FamilyControls, ManagedSettings, and DeviceActivity frameworks as one workflow. Use when the user mentions Screen Time, parental controls, app limits, blocking or shielding apps, FamilyControls, FamilyActivityPicker, ManagedSettings, ManagedSettingsStore, DeviceActivity, DeviceActivityMonitor, ApplicationToken, screen time API, focus/bedtime modes, or digital wellbeing.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple Developer docs via Context7 (/websites/developer_apple — FamilyControls, ManagedSettings, DeviceActivity)
---

# Screen Time API

Parental controls, app limiting, and digital-wellbeing features on Apple platforms. One workflow, three frameworks that share a single entitlement (Family Controls) and a single opaque-token model: **FamilyControls** authorizes and selects, **ManagedSettings** restricts/shields, **DeviceActivity** schedules and monitors. The deep API references live in `references/` (four files). This file is the decision and discipline layer: read it first, open the references for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `CAPABILITY` — `monitor-usage` (DeviceActivity schedules + thresholds, observe only) · `shield-restrict` (ManagedSettings shields/restrictions, block immediately) · `both` (default for limiters: monitor until a threshold, then shield from the extension).
2. `SELECTION` — `app-tokens` (`ApplicationToken` — block named apps the user picked) · `category-tokens` (`ActivityCategoryToken` — block whole App Store categories, incl. `.all()` / `.all(except:)`) · `mixed` (apps + categories + `WebDomainToken`). Driven entirely by what the user picks in `FamilyActivityPicker`.
3. `PERSISTENCE` — `app-group` (default and effectively required once an extension exists: encode `FamilyActivitySelection`/token sets with `PropertyListEncoder`, store in `UserDefaults(suiteName:)` shared with the `DeviceActivityMonitor`/shield extensions) · `standard` (only valid for an app with zero extensions — rare).

## When to use

Building or reviewing any Screen Time feature: requesting Family Controls authorization, presenting the app picker, applying shields/restrictions, scheduling usage monitoring, or writing the `DeviceActivityMonitor` extension. Use this whether the app is a personal digital-wellness tool (`.individual`) or a parental-control app (`.child`). For *displaying* usage numbers, see the `DeviceActivityReport` note in `references/overview.md` — that data is only readable inside a report extension.

## Core rules

- iOS 15+ for the core API; named `ManagedSettingsStore`, `.all(except:)` category policy, and several refinements are iOS 16+. iOS 26 is the default target.
- The **Family Controls entitlement requires Apple approval** before App Store submission — it is not a checkbox you self-grant. Plan for the request and its justification early; the build won't ship without it.
- **Tokens are opaque.** You never get app names or bundle IDs from an `ApplicationToken`/`ActivityCategoryToken`/`WebDomainToken`. The only UI that resolves them to icons/labels is Apple's own (`FamilyActivityPicker`, the `Label(token)` view, the shield). Don't design features that need to read what an app *is*.
- **Persist the selection, re-apply shields dynamically** — store the `FamilyActivitySelection` (encoded), not a snapshot of "currently shielded." Apply shields on launch / on schedule / on threshold from the persisted selection.
- **Share app ↔ extension through an App Group**, never `UserDefaults.standard`. The `DeviceActivityMonitor` extension is a separate process and only sees the shared suite. The unnamed `ManagedSettingsStore` is itself shared across the app group, but the *selection data* you decode in the extension is not unless you put it in the shared suite.
- Always ship an exit path: a `clearAllSettings()` on every store you ever named, so a user (or you, in support) can lift restrictions.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll enable the Family Controls capability and ship." | The entitlement needs **Apple's explicit approval** with a written justification of your use case. Unapproved, your archive is rejected at submission. Request it the day you start, not the week you ship. |
| "I'll read the bundle ID off the token to show the app name / dedupe / analytics it." | Tokens are **opaque by design** for privacy — there is no API to extract a name or bundle ID. Render them only with Apple's `Label(token)` / picker / shield. Any feature that needs the underlying identity is impossible. |
| "I'll import my models + SwiftUI in the monitor extension to reuse code." | The `DeviceActivityMonitor` extension runs under a **~6 MB memory ceiling** and is killed if it exceeds it. Import only `DeviceActivity` + `ManagedSettings`, decode only the token set you need (not the whole `FamilyActivitySelection`), no images, no SwiftUI. |
| "I'll save the selection to `UserDefaults.standard` and read it in the extension." | The extension is a **different process** and can't see `.standard`. Use `UserDefaults(suiteName: "group.…")` from the shared App Group on **both** targets, with the App Group capability on each. |
| "Authorization is global — request it once however." | Authorization is **per-member**: `.individual` (device owner approves, for personal wellness apps) vs `.child` (a parent/guardian in the Family Sharing group approves, for parental controls). The mode must match your `AuthorizationMode` entitlement value and your product. Picking wrong means the prompt never resolves the way you expect. |
| "I'll register a schedule/event per app or per hour as needed." | `DeviceActivityCenter` caps you at **~20 active schedules per app**, and events live inside a schedule. Coalesce — one daily schedule with a few threshold events, not dozens of schedules. Track active names and refuse past the limit instead of failing silently. |

## Verification gate

Before shipping a Screen Time feature, confirm every line:

- [ ] Family Controls capability added **and** the entitlement approval requested from Apple (`.individual` vs `.child` matches the product).
- [ ] Authorization requested via `AuthorizationCenter.shared.requestAuthorization(for:)`, with `.notDetermined` / `.denied` / `.approved` all handled (denied routes the user to Settings).
- [ ] Selection comes only from `FamilyActivityPicker`; tokens are never assumed to be readable as names/bundle IDs.
- [ ] Selection persisted with `PropertyListEncoder` into an **App Group** suite shared by the app and every extension.
- [ ] If monitoring: schedules/events stay under the ~20 cap; one coalesced schedule where possible; activity/event names are stable constants.
- [ ] `DeviceActivityMonitor` extension imports only what it needs, decodes a minimal token set, stays within ~6 MB (no SwiftUI/UIKit/images).
- [ ] Every `ManagedSettingsStore` you name has a matching `clearAllSettings()` exit path; default store is cleared at interval start where appropriate.
- [ ] Tested on a real device — monitor-extension callbacks and shields do not fire reliably in the Simulator.

## Deep reference

Four files in `references/`, load the one you need:

- `references/overview.md` — how the three frameworks fit together, the entitlement + App Group setup, the opaque token system, a step-by-step quick start, and the `DeviceActivityReport` note for displaying usage.
- `references/familycontrols.md` — authorization (`AuthorizationCenter`, `.individual`/`.child`, status observation, error handling), `FamilyActivityPicker`, `FamilyActivitySelection`, the token types, and persistence/App-Group sharing of selections.
- `references/managedsettings.md` — `ManagedSettingsStore` (default + named, iOS 16+), shielding apps/categories/web domains, `ShieldConfiguration`/`ShieldActionDelegate` extensions, application & web-content & media restrictions, and clearing settings.
- `references/deviceactivity.md` — `DeviceActivityCenter`, `DeviceActivitySchedule`, `DeviceActivityEvent` thresholds, the `DeviceActivityMonitor` extension callbacks, the ~6 MB memory budget, and the ~20-schedule limit.

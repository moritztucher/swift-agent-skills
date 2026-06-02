---
name: permissionkit
description: Build child-safety communication permission flows with PermissionKit (iOS 26+) — a child asks a parent/guardian to approve communicating with an unknown contact, requests flow through iMessage, and the app reacts to the parent's response. Use when the user mentions PermissionKit, parental approval, guardian permission, communication permission, ask permission, CommunicationLimits, child-safety chat, or Texas App Store Accountability / significant app update consent. For age verification and age gating, use the `declared-age-range` skill alongside this one.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple PermissionKit docs via Context7 (/websites/developer_apple — official /documentation/PermissionKit)
---

# PermissionKit

Apple's iOS 26+ framework for child-safety communication permission flows: a child account asks a parent or guardian to approve talking to an unknown contact, the ask is rendered consistently with the system's other communication experiences, and your app reacts when the guardian responds. The deep API reference — every type, the full ask flow, the Significant App Update path for Texas SB 2420, DeclaredAgeRange integration, error handling, and testing — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

> **Currency note:** Context7's official `/documentation/PermissionKit` confirmed `CommunicationLimits`, `CommunicationHandle`, `CommunicationTopic`, the **`QuestionTopic`** protocol (not `Topic`), `PermissionQuestion` as a **class** (not a struct), `PermissionResponse`, and `PermissionChoice` — and that asks are **only available using iMessage**. The guide was patched for those. Symbols Context7 did **not** surface at check time (`CommunicationLimits.current`, the `updates` element type `CommunicationLimitsUpdate`, `knownHandles(in:)`, `CommunicationLimitsButton`, `CommunicationAction` cases) are flagged in the guide as unverified — confirm spellings against Xcode 26 headers before shipping.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `UI` — `swiftui` (default; `CommunicationLimitsButton` triggers the ask) · `uikit`/`appkit` (call `ask(_:in:)` with a `UIViewController` / `NSWindow`). The ask UI is system-presented either way; you never build the approval sheet.
2. `TOPIC` — `communication` (default; `CommunicationTopic` — child wants to message/call/video an unknown person) · `significant-update` (`SignificantAppUpdateTopic` — re-consent for an age-rating or functionality change, for Texas SB 2420 / App Store Accountability compliance).
3. `AGE_SOURCE` — how you decide a user is a child before invoking PermissionKit: `declared-age-range` (default; pair with the `declared-age-range` skill and gate on `isEligibleForAgeFeatures`) · `app-managed` (your own age system). PermissionKit does not tell you who is a child — you must already know.

## When to use

Building or reviewing any flow where a supervised child account requests communication approval from a parent/guardian, or where an app under child-safety law needs parental re-consent for a significant change. If you only need to know a user's age band (not request permission), that's the `declared-age-range` skill alone. If the app has no child accounts or Family Sharing supervision, PermissionKit returns default/empty responses and is the wrong tool.

## Core rules

- **iMessage only.** Per Apple's docs, the asking experience is delivered exclusively through iMessage. There is no fallback transport — design the UX so a missing-iMessage / not-supervised path degrades gracefully, never errors at the user.
- **PermissionKit is not an age oracle.** It does not identify children. Determine child status first (DeclaredAgeRange `isEligibleForAgeFeatures` or your own system), then invoke PermissionKit only for those users.
- **Entitlement is the guardian's response, not the ask.** `ask(...)` returning without throwing means the request was *presented/sent*, not *approved*. Approval arrives asynchronously via the `updates` sequence. Never unlock communication on `ask` completion.
- **The system owns the approval UI.** You provide handles, names, and avatars (`PersonInformation`) and the intended actions; the system renders and presents the sheet. Do not build your own approve/decline UI.
- **Maximum metadata.** Always pass `nameComponents` and an avatar when you have them — a guardian approving a bare username with no name or photo is the failure mode the framework exists to prevent.
- **Requirements gracefully absent.** When the user isn't in Family Sharing, Communication Limits is off, or contacts aren't synced, the API returns a *default* response instead of throwing. Treat "no known handles / default response" as "feature unavailable," not "denied."

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "`ask(...)` returned without throwing, so the parent approved — unlock the chat." | A clean return means the ask was **presented**, not answered. Approval/denial arrives later through `updates`. Gate communication on the parent's response, never on `ask` completing. |
| "I'll fire the ask and read the result inline; no `updates` listener needed." | The parent may respond minutes or days later, in iMessage, possibly while your app is backgrounded or relaunched. Without a long-lived `updates` listener you drop the approval entirely. |
| "PermissionKit will tell me if the user is a child." | It won't. It assumes you already know. You must establish child status first (DeclaredAgeRange or your own age system) — calling it for adults just returns default responses and wastes the flow. |
| "I'll send the bare username so the parent decides fast." | A guardian can't safely approve "dragonslayer42" with no name or photo. Omitting `nameComponents`/`avatarImage` defeats the framework's whole purpose. Pass full `PersonInformation`. |
| "It threw / returned empty in the simulator, so my integration is broken." | Empty `knownHandles` and default responses are the **documented** behavior when Family Sharing, Communication Limits, or contact sync aren't set up — and the Simulator can't fully exercise this. Test on a real supervised child device; treat absence as unavailable, not failure. |
| "`SignificantAppUpdateTopic` threw 'region does not support this ask' — that's a bug to surface." | That's expected outside regions that legally require consent (e.g. non-Texas). Catch it and proceed without consent there; don't show the user an error. |
| "I copied the API names straight from the guide, they're authoritative." | Several spellings (`.current`, `CommunicationLimitsUpdate`, `knownHandles(in:)`, `CommunicationAction` cases) were **not** confirmed by Context7 and are flagged unverified in the guide. Confirm against Xcode 26 headers before relying on exact names. |

## Verification gate

Before shipping a PermissionKit flow, confirm every line:

- [ ] Child status is established **before** any PermissionKit call (DeclaredAgeRange `isEligibleForAgeFeatures` or app-managed) — adults never hit the ask.
- [ ] Communication unlocks **only** on the guardian's response via `updates`, never on `ask(...)` returning.
- [ ] A long-lived `updates` listener is started early and survives backgrounding/relaunch; it's cancelled on teardown (no leaked task).
- [ ] Every `PersonInformation` carries `nameComponents` and an avatar when available — no bare-handle asks.
- [ ] `TOPIC` actions match real intent (`.message` vs `.message, .call, .video`).
- [ ] Unavailable prerequisites (no Family Sharing, Limits off, contacts unsynced) render a graceful "ask not available" path, not an error or a silent grant.
- [ ] `SignificantAppUpdateTopic` "region not supported" is caught and treated as "proceed without consent," not surfaced as an error.
- [ ] Consent revocation is handled (App Store Server Notifications) and removes access.
- [ ] Tested on a **real** supervised child device with Family Sharing + Communication Limits enabled — not just the Simulator.
- [ ] Unverified API spellings reconciled against Xcode 26 headers.

## Deep reference

`references/guide.md` — full type reference (`CommunicationLimits`, `CommunicationHandle`, `PersonInformation`, `CommunicationTopic`/`CommunicationAction`, `PermissionQuestion`, `CommunicationLimitsButton`, `SignificantAppUpdateTopic`), the five-step communication ask flow (SwiftUI/UIKit/AppKit), the Significant Change API for Texas SB 2420, DeclaredAgeRange integration, error handling, testing (sandbox + Developer settings scenarios), and best practices. Load it for any concrete API question. Pair with the `declared-age-range` skill for the age-verification half of the flow.

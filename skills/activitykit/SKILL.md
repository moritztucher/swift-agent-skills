---
name: activitykit
description: Build and review Live Activities and Dynamic Island experiences with ActivityKit — ActivityAttributes/ContentState, Activity.request/update/end, ActivityContent (staleDate, relevanceScore), local vs push-token updates, push-to-start, and the Dynamic Island regions. Use when the user mentions Live Activity, Dynamic Island, ActivityKit, lock screen activity, live updates, delivery/sports/timer tracking, or push-to-start. The Live Activity UI is a widget extension built with WidgetKit/SwiftUI — for the widget layer itself use the `widgetkit` skill.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple ActivityKit docs via Context7 (/websites/developer_apple_activitykit)
---

# ActivityKit

Live Activities — glanceable, real-time updates on the Lock Screen and in the Dynamic Island. The deep API reference — setup, attributes, the full start/update/end lifecycle, push tokens, the widget-extension UI, and the complete delivery-tracker example — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `UPDATE_CHANNEL` — `local` (default; foreground app calls `activity.update(_:)`, cheap, no server) · `push-token` (server drives updates via APNs; observe `activity.pushTokenUpdates`, requires the push entitlement and a server). Pick `push-token` whenever the activity must move while the app is suspended.
2. `START_MODE` — `in-app` (default; `Activity.request` while the app is foregrounded) · `push-to-start` (server starts the activity remotely via `Activity.pushToStartTokenUpdates`, iOS 17.2+; no app launch needed).
3. `DYNAMIC_ISLAND` — `minimal` (compactLeading/compactTrailing + minimal only) · `full-expanded` (also implement all `DynamicIslandExpandedRegion`s for the long-press/active presentation). Even `minimal` must still supply compact + minimal — they are not optional.

## When to use

Building or reviewing any Live Activity: starting/updating/ending an `Activity`, defining `ActivityAttributes`/`ContentState`, wiring push or push-to-start tokens, or laying out the Lock Screen / Dynamic Island presentations. The presentation itself is a WidgetKit `ActivityConfiguration` inside a widget extension — for general widget/timeline work reach for `widgetkit`.

## Core rules

- iOS 16.1+ for Live Activities and Dynamic Island; 16.2+ for push updates; 17.2+ for push-to-start (`pushToStartToken`). iOS 26 is the default target.
- **`ContentState` is the only mutable surface.** It must be `Codable` + `Hashable` and stay small — the push payload `content-state` is capped at **4KB**. Everything static goes on the attributes, not the state.
- **`ActivityAttributes` must be shared** between the app and the widget extension (shared framework or Swift package) — both targets need the identical type.
- Gate every start on `ActivityAuthorizationInfo().areActivitiesEnabled`, and observe `activityEnablementUpdates` since the user can revoke at any time.
- Drive timers with `Text(date, style: .timer)` — it self-updates without spending update budget. Never schedule updates just to tick a clock.
- Set a `staleDate` so the system can dim/replace outdated content, and end activities promptly when the task completes.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll just stash the order list / history in `ContentState`." | `ContentState` is capped at **4KB** and re-encoded on every update. Keep it to the few fields the UI renders; put static data on the attributes. Oversized state silently fails to update. |
| "`activity.end(...)` makes it disappear immediately." | `end` only changes content + schedules removal. There is no instant programmatic dismissal — the *system* controls it via `dismissalPolicy` (`.default` lingers up to ~4h, `.after(date)`, `.immediate`). Design for the activity outliving your call. |
| "I requested with `pushType: .token`, so `activity.pushToken` has my token." | The token is `nil` at first and rotates. You must iterate `activity.pushTokenUpdates` (and `Activity.pushToStartTokenUpdates` for push-to-start), send each new token to your server, and invalidate the old one. |
| "Push updates just work once I have a token." | Push needs the APNs push entitlement, a server posting to the activity endpoint with `event`/`content-state`/`timestamp`, and a monotonic `timestamp` — the system drops any update older than the last one. Budget is roughly limited; mark `NSSupportsLiveActivitiesFrequentUpdates` only when you truly need high frequency. |
| "I'll start an activity, no need to check anything." | If `areActivitiesEnabled` is false `Activity.request` throws, and the user can disable mid-activity. Check before starting and observe `activityEnablementUpdates`. |
| "The Live Activity is just normal SwiftUI." | It's a WidgetKit extension view: no scrolling, no interactive state beyond `Button`/`Toggle` with App Intents, archived/snapshot rendering, and a fresh process. Build and test it as a widget, and supply every Dynamic Island region (compact + minimal at minimum). |

## Verification gate

Before shipping a Live Activity, confirm every line:

- [ ] `ActivityAttributes` lives in a target shared by both the app and the widget extension; `ContentState` is `Codable` + `Hashable` and well under 4KB.
- [ ] `Info.plist` has `NSSupportsLiveActivities` (and `NSSupportsLiveActivitiesFrequentUpdates` only if frequent updates are actually needed).
- [ ] Every start is gated on `areActivitiesEnabled`, and `activityEnablementUpdates` is observed for mid-flight revocation.
- [ ] If `UPDATE_CHANNEL = push-token`: `pushTokenUpdates` is observed and each token is sent to the server; push payloads carry a monotonic `timestamp`; the push entitlement is present.
- [ ] If `START_MODE = push-to-start`: `Activity.pushToStartTokenUpdates` is observed at launch and the token is registered server-side (iOS 17.2+ guarded).
- [ ] `staleDate` is set on every `ActivityContent`; `relevanceScore` is set when multiple activities can compete for the Dynamic Island.
- [ ] All required Dynamic Island regions are implemented (compactLeading, compactTrailing, minimal — plus expanded regions for `full-expanded`).
- [ ] The activity is ended with the right `dismissalPolicy`, and `activityStateUpdates` is handled (`.ended` / `.dismissed` / `.stale`).
- [ ] Tested on a Dynamic Island device (or simulator) for compact, expanded, minimal, and Lock Screen presentations.

## Deep reference

`references/guide.md` — full setup, `ActivityAttributes`/`ContentState`, `ActivityContent` + stale dates, the start/update/end lifecycle, alert configuration, push-token and push-to-start handling, the `ActivityConfiguration` widget-extension UI with all Dynamic Island regions, best practices, common pitfalls, the iOS version matrix, and a complete delivery-tracker example. Load it for any concrete API question.

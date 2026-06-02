---
name: alarmkit
description: Schedule prominent, system-level alarms and countdown timers on iOS 26+ that break through silent mode and Focus — AlarmManager authorization + scheduling, AlarmConfiguration/AlarmAttributes, AlarmPresentation (alert/countdown/paused), stop/secondary buttons, custom sounds, and App Intents. Use when the user mentions AlarmKit, alarm, timer, scheduled alert, AlarmManager, wake-up, or countdown that must fire reliably. The countdown surface renders as a Live Activity — pair with the `activitykit` skill for the widget UI.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple AlarmKit docs via Context7 (/websites/developer_apple_alarmkit)
---

# AlarmKit

System-level alarms and countdown timers on iOS 26+ that sound through Silent Mode and Focus. The deep API reference — every component, authorization, scheduling, countdowns, Live Activity integration, App Intents, custom sounds, and a full worked example — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `ALARM_KIND` — `scheduled` (fires at a wall-clock time; `Alarm.Schedule.fixed` for one-shot or `.relative` for recurring/timezone-adaptive) · `countdown` (a running timer with countdown/paused UI; needs a Widget Extension) · `both` (a scheduled alarm that then runs a `postAlert` countdown, e.g. snooze).
2. `SECONDARY_ACTION` — `none` (stop button only) · `snooze` (`secondaryButtonBehavior: .countdown` + a `postAlert` duration) · `custom` (`secondaryButtonBehavior: .custom` + a `LiveActivityIntent` to open the app or run logic).
3. `LIVE_ACTIVITY` — `none` (plain scheduled alarm, no countdown UI needed) · `required` (any countdown surface — you MUST ship a Widget Extension with an `ActivityConfiguration(for: AlarmAttributes<Metadata>.self)`, see the `activitykit` skill).

## When to use

Building or reviewing any alarm or timer that must fire reliably regardless of mute/Focus — wake-up alarms, cooking/medication timers, workout intervals, time-critical reminders. Do NOT reach for AlarmKit for ordinary reminders or marketing nudges; that abuse is rejected at review and is what `UserNotifications` is for. If the alarm shows a live countdown, the countdown UI is a Live Activity — use the `activitykit` skill for the widget.

## Core rules

- iOS 26.0+ only. `import AlarmKit`; everything goes through `AlarmManager.shared`.
- Add `NSAlarmKitUsageDescription` to Info.plist before requesting authorization — without it the request fails.
- Authorize before scheduling: check `authorizationState`, call `requestAuthorization()` only when `.notDetermined`, and route `.denied` users to Settings. Ask at a moment that makes sense (when the user creates their first alarm), not on cold launch.
- `AlarmPresentation.Alert`'s initializer does **not** take `stopButton` — the system supplies the stop button. The `init(title:stopButton:...)` form is deprecated (iOS 26.0–26.1). Pass `title:` plus optional `secondaryButton:`/`secondaryButtonBehavior:`.
- Any countdown surface requires a Widget Extension Live Activity keyed on `AlarmAttributes<YourMetadata>`. No widget = no countdown UI.
- Track every alarm by its `UUID`; observe `alarmUpdates` for state, and `cancel(id:)` alarms you no longer need.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll pass `stopButton:` into `AlarmPresentation.Alert(...)` like the example." | That initializer is **deprecated** (iOS 26.0–26.1). The system provides the stop button automatically — use `Alert(title:secondaryButton:secondaryButtonBehavior:)` and set the `.stopButton` property only if you must customize it. |
| "My App Intent conforms to `AppIntent`, that's enough for the secondary button." | Intents attached to an alarm must conform to **`LiveActivityIntent`**, and they're passed as `stopIntent:`/`secondaryIntent:` on `AlarmConfiguration` — not just `secondaryIntent`. A plain `AppIntent` won't wire up. |
| "Skip the Info.plist key, I'll add it later." | `requestAuthorization()` fails without `NSAlarmKitUsageDescription`. The permission prompt has nothing to show. |
| "I'll just use a notification — same thing, less setup." | AlarmKit exists precisely because notifications get silenced by mute/Focus. If the event isn't time-critical, AlarmKit is the wrong tool and gets rejected at review; if it is, a notification won't reliably reach the user. |
| "I scheduled a countdown; the timer will show on the Lock Screen." | Only if you ship a Widget Extension Live Activity for `AlarmAttributes<Metadata>`. Without it the countdown has no UI to render. |
| "I'll mark metadata as a normal struct." | In Xcode 26 (MainActor-isolated by default) an `AlarmMetadata` type must be `nonisolated` to satisfy the protocol, or conformance fails to compile. |

## Verification gate

Before shipping AlarmKit code, confirm every line:

- [ ] `NSAlarmKitUsageDescription` is in Info.plist with a user-facing reason.
- [ ] Authorization is requested (only when `.notDetermined`) and `.denied` is handled with a Settings hand-off — not on cold launch.
- [ ] `AlarmPresentation.Alert` is built with the current initializer (no `stopButton:` argument); deprecated form is gone.
- [ ] Any App Intent attached to an alarm conforms to `LiveActivityIntent` and is passed as `stopIntent:`/`secondaryIntent:`.
- [ ] Every countdown alarm has a matching Widget Extension Live Activity for `AlarmAttributes<Metadata>` (handles `.countdown`/`.paused`/`.alert`); see `activitykit`.
- [ ] `AlarmMetadata` types are `nonisolated`.
- [ ] Alarms are tracked by `UUID`, observed via `alarmUpdates`, and cancelled when no longer needed.
- [ ] AlarmKit is justified (time-critical, must break Silent/Focus) — not used as a dressed-up notification.

## Deep reference

`references/guide.md` — full project setup, authorization, scheduling (fixed + relative/recurring), countdown timers, Live Activity integration, lifecycle management, App Intents, custom sounds, observation, best practices, and a complete worked example. The guide opens with an API-currency note flagging the two patterns (deprecated `stopButton` initializer; `stopIntent`/`LiveActivityIntent`) corrected against Apple's docs on 2026-06-02. Load it for any concrete API question.

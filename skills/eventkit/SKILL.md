---
name: eventkit
description: Read and write calendar events and reminders with EventKit — EKEventStore access, the iOS 17+ full-access vs write-only authorization split, creating/fetching/editing events and reminders, recurrence rules, and EKEventEditViewController. Use when the user mentions EventKit, calendar, reminders, EKEventStore, calendar permission, events, recurring events, or adding something to the user's calendar.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple EventKit docs via Context7 (/websites/developer_apple_eventkit)
---

# EventKit

Calendar and reminder access on Apple platforms — events, reminders, recurrence, alarms, and the native EventKitUI controllers. The deep API reference — setup, authorization, every CRUD path, recurrence rules, alarms, EventKitUI wrappers, and common use cases — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `ENTITY` — `events` (calendar) · `reminders` · `both`. Each entity has its own authorization status, its own usage-description key, and its own calendars; you request and check them independently.
2. `ACCESS_LEVEL` — `write-only` (iOS 17+ `requestWriteOnlyAccessToEvents()`, default when you only *add* events — better privacy, no read of existing data) · `full` (`requestFullAccessToEvents()` / `requestFullAccessToReminders()` when you must read or edit existing items). Reminders have no write-only tier.
3. `UI` — `native` (EventKitUI: `EKEventEditViewController` to add/edit — on iOS 17+ this lets the user save an event with no prior authorization prompt) · `custom` (your own SwiftUI, requires explicit authorization first).

## When to use

Building or reviewing any code that reads, creates, edits, or deletes calendar events or reminders through EventKit, requests calendar/reminder permission, builds recurrence rules, or presents the native event editor. If you only need to drop one event into the user's calendar and never read it back, prefer the `native` + `write-only` path — it is the least-privilege option.

## Core rules

- iOS 17+ authorization model is the default. `requestFullAccessToEvents()`, `requestWriteOnlyAccessToEvents()`, `requestFullAccessToReminders()` (async/await). Only fall back to `requestAccess(to:)` behind `if #available(iOS 17, *)` for explicit pre-17 support.
- One `EKEventStore` instance per app, created once and reused — constructing it is expensive.
- Authorization is per-entity. Check `EKEventStore.authorizationStatus(for: .event)` and `for: .reminder` separately; gate on `.fullAccess` / `.writeOnly`, not a cached `Bool`.
- The matching usage-description key must be in Info.plist or the app crashes on request: `NSCalendarsFullAccessUsageDescription`, `NSCalendarsWriteOnlyAccessUsageDescription`, `NSRemindersFullAccessUsageDescription`.
- Observe `.EKEventStoreChanged` and refresh — the database changes underneath you (other apps, other devices, sync).

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I only add events, so I'll request full access — simpler." | iOS 17+ write-only (`requestWriteOnlyAccessToEvents()`) is the least-privilege path and a better App Review/privacy story. Request full access only when you must read or edit existing items. Reminders, note, have no write-only tier. |
| "I'll use `requestAccess(to:)` — it's the API I know." | Deprecated since iOS 17. Use `requestFullAccessToEvents()` / `requestWriteOnlyAccessToEvents()` / `requestFullAccessToReminders()`. Keep the old call only inside an `if #available(iOS 17, *)` else-branch for pre-17 targets. |
| "I'll add the usage string later, the request works in the simulator." | No matching Info.plist usage-description key = hard crash the instant you call the request method. `NSCalendars*` and `NSReminders*` keys must ship before the first request. |
| "`save(event, span: .thisEvent)` is fine for the recurring meeting." | On a recurring event, `.thisEvent` edits only that one occurrence; `.futureEvents` edits this and all following. Pick the span deliberately — the wrong one silently corrupts or fails to update the series. Same applies to `remove(_:span:)`. |
| "I'll fetch events in the View body / on the main thread." | `events(matching:)` and `enumerateEvents` are synchronous and can block on large date ranges. Query a bounded range off the main actor; never `distantPast`…`distantFuture`. Reminders are completion-handler based — wrap `fetchReminders(matching:)` in `withCheckedContinuation`. |
| "Access was `.fullAccess` at launch, so I'm good for the session." | The user can revoke in Settings and the store changes from other apps/devices mid-session. Re-check status before privileged work and observe `.EKEventStoreChanged` to refresh; `@unknown default` the status switch. |

## Verification gate

Before shipping EventKit code, confirm every line:

- [ ] Uses iOS 17+ request methods (`requestFullAccessToEvents` / `requestWriteOnlyAccessToEvents` / `requestFullAccessToReminders`); any `requestAccess(to:)` is only in a pre-17 `#available` branch.
- [ ] Access level is the minimum needed — write-only for add-only event flows.
- [ ] Every requested entity has its matching `NSCalendars*` / `NSReminders*` usage-description key in Info.plist.
- [ ] Authorization checked per-entity, gated on `.fullAccess`/`.writeOnly`, with denied/restricted handled (Settings deep-link), no cached `Bool`.
- [ ] Recurring `save`/`remove` pass an intentional `EKSpan` (`.thisEvent` vs `.futureEvents`).
- [ ] Event fetches use a bounded date range off the main actor; reminder fetches are wrapped in async (`withCheckedContinuation`).
- [ ] A single shared `EKEventStore`; `.EKEventStoreChanged` observed to refresh cached events/reminders.
- [ ] Batch writes use `commit: false` then a single `commit()`.

## Deep reference

`references/guide.md` — full setup, authorization (incl. backward-compatible paths), EKEventStore/EKCalendar/EKSource, SwiftUI observable manager patterns, event + reminder CRUD, recurrence rules with worked examples, alarms (time + location), EventKitUI wrappers (`EKEventEditViewController`, `EKEventViewController`, `EKCalendarChooser`), iOS 18/26 considerations, and common use cases. Load it for any concrete API question.

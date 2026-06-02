---
name: watchconnectivity
description: Implement and review iPhone-to-Apple-Watch communication with WatchConnectivity — WCSession activation, sendMessage, application context, userInfo and file transfers, complication updates, and reachability. Use when the user mentions Apple Watch, watchOS, WatchConnectivity, WCSession, paired device, phone-watch sync, or complication updates.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple WatchConnectivity docs via Context7 (/websites/developer_apple_watchconnectivity)
---

# WatchConnectivity

Two-way communication between an iOS app and its paired watchOS app over a single `WCSession`. The deep API reference — setup, every transfer method, the delegate, SwiftUI/`@Observable` integration, async wrappers, complications, troubleshooting — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `TRANSFER` — `interactive-sendMessage` (real-time, needs both apps live + `isReachable`) · `background-context` (`updateApplicationContext`, latest-state-only sync) · `userInfo-queue` (`transferUserInfo`, ordered guaranteed delivery) · `file` (`transferFile`, large payloads). Pick per payload; most apps use several.
2. `ACTIVATION` — `single-watch` (activate once, no re-activation needed) · `multi-watch` (iOS must re-`activate()` inside `sessionDidDeactivate` to follow a watch switch). Default to `multi-watch` on iOS — it costs one line and prevents a dead session.
3. `DIRECTION` — `phone->watch` (config/auth push down) · `watch->phone` (workout/sensor data up; phone is woken in background) · `bidirectional` (request/reply via `sendMessage` replyHandler).

## When to use

Building or reviewing any code that syncs state, sends messages, queues data, transfers files, or updates complications between an iPhone app and its paired Apple Watch app. The manager type is shared across both targets (`#if os(iOS)` guards the iOS-only surface). If there is no watchOS target, you don't need this skill.

## Core rules

- One `WCSession.default`, guarded by `WCSession.isSupported()`. Set `session.delegate = self` **before** `session.activate()` — a delegate assigned after activation misses the activation callback and early deliveries.
- Activate on **both** apps. The counterpart receives nothing until its own side has activated; an active phone session does not imply an active watch session.
- Match the method to the payload (the `TRANSFER` dial). `sendMessage` is the only one that needs `isReachable`; the background methods (`updateApplicationContext`, `transferUserInfo`, `transferFile`) deliver later without it.
- Only property-list types in any dictionary (`String`, `Int`, `Double`, `Bool`, `Data`, `Date`, plist arrays/dicts). Encode custom types to `Data` first. Keep payloads small.
- Delegate callbacks are `nonisolated`; hop to `@MainActor` (`Task { @MainActor in … }`) before touching `@Observable` state.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll set the delegate after `activate()` — order doesn't matter." | It does. Assign `delegate` first, then `activate()`. A late delegate silently drops the `activationDidCompleteWith` callback and any messages queued before it was set. |
| "`sendMessage` is simplest, I'll use it for everything." | `sendMessage` fails unless `isReachable` (watch app foregrounded / phone reachable). For anything that must survive backgrounding, use `transferUserInfo`/`updateApplicationContext`/`transferFile` — they queue and deliver later. Gate `sendMessage` on `isReachable` and fall back. |
| "`updateApplicationContext` queues my events like a log." | No. It keeps **only the latest** context — a new call overwrites the undelivered previous one. Use it for current-state sync (settings, auth token). For every-event-matters delivery use `transferUserInfo`, which is an ordered queue. |
| "I'll fire transfers as fast as I produce them." | The system throttles and coalesces background transfers on its own schedule (and complication transfers have a hard ~daily budget — check `remainingComplicationUserInfoTransfers`). Batch, don't spam; check `outstandingUserInfoTransfers` / `outstandingFileTransfers`. |
| "Activating the phone session is enough." | Each side must activate its own `WCSession`. Until the watch app activates too, your phone-side transfers sit undelivered. Activate early in **both** apps' `App.init`/manager init. |
| "`sessionDidDeactivate` is just a teardown hook, I can leave it empty." | On iOS it fires when the user switches to a different watch. If you don't call `session.activate()` again inside it, the session stays dead for the new watch and all future transfers fail silently. Re-activate there. |
| "It worked in the Simulator, ship it." | The watchOS Simulator does **not** run `transferFile`, `transferUserInfo`, or `transferCurrentComplicationUserInfo`. Background-transfer paths must be tested on physical paired devices. |

## Verification gate

Before shipping WatchConnectivity code, confirm every line:

- [ ] `WCSession.isSupported()` checked; `delegate` set **before** `activate()`; activation happens early on **both** iOS and watchOS targets.
- [ ] iOS delegate implements `activationDidCompleteWith`, `sessionDidBecomeInactive`, **and** `sessionDidDeactivate` (the last re-calls `activate()` for multi-watch). watchOS implements `activationDidCompleteWith`.
- [ ] Transfer method matches payload: `sendMessage` only when `isReachable`, with a background fallback; `updateApplicationContext` for latest-state; `transferUserInfo` for ordered queue; `transferFile` for files.
- [ ] No reliance on `updateApplicationContext` to deliver multiple distinct events (it keeps only the latest).
- [ ] All transfer dictionaries are plist-only; custom types encoded to `Data`; payloads kept small.
- [ ] Received files moved off `file.fileURL` to permanent storage inside the `didReceive file:` callback (the source URL is temporary).
- [ ] Complication updates check `remainingComplicationUserInfoTransfers` and fall back to `transferUserInfo` when the budget is exhausted.
- [ ] Delegate callbacks hop to `@MainActor` before mutating observable state; closures are `@Sendable` under Swift 6.
- [ ] Background-transfer paths tested on physical paired devices, not only the Simulator.

## Deep reference

`references/guide.md` — full setup for both targets, session activation/state, interactive messaging, application context, userInfo and file transfers, complication updates, `@Observable` SwiftUI integration, async/await wrappers, common use cases, best practices, and troubleshooting. Load it for any concrete API question.

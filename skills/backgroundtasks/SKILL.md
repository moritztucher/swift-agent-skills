---
name: backgroundtasks
description: Schedule and run deferred work with the BackgroundTasks framework — app refresh, background processing, and (iOS 26) continued processing tasks via BGTaskScheduler. Use when the user mentions background refresh, BGTask, BGTaskScheduler, background processing, background fetch, deferred work, BGAppRefreshTask, BGProcessingTask, or keeping app content fresh while backgrounded.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple BackgroundTasks docs via Context7 (/websites/developer_apple_backgroundtasks)
---

# BackgroundTasks

System-scheduled background work on Apple platforms via `BGTaskScheduler` — app refresh, processing, and continued processing. The deep API reference — setup, registration, scheduling, execution, testing, iOS 18/26 additions, and every use case — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `TASK_TYPE` — `app-refresh` (`BGAppRefreshTask`, ~30s, lightweight content freshness) · `processing` (`BGProcessingTask`, minutes, maintenance/ML/large sync) · `continued` (iOS 26 `BGContinuedProcessingTask`, user-initiated, progress-reporting, cancellable).
2. `CONSTRAINTS` — only on `processing`: `requiresNetworkConnectivity` (run only with network) · `requiresExternalPower` (run only while charging). `continued` uses `requiredResources` (e.g. `.gpu`) instead.
3. `SCHEDULING` — `opportunistic` (default; submit a request with `earliestBeginDate`, system picks the moment) · `immediate` (only `continued` via `SubmissionStrategy.fail`, which throws `immediateRunIneligible` if the system can't start now).

## When to use

Building or reviewing any code that schedules deferred work to run while the app is backgrounded or suspended — content sync, widget refresh, DB maintenance, cache cleanup, ML updates, or a user-started export that should finish in the background. Not for keeping a foreground session alive (use `beginBackgroundTask`) and not for guaranteed/timely delivery (the system decides if and when).

## Core rules

- iOS 13+ for `BGTaskScheduler`; `BGContinuedProcessingTask` is iOS 26+. iOS 26 is the default target.
- **Register every handler before launch finishes** — `register(forTaskWithIdentifier:using:launchHandler:)` in `App.init` (or `didFinishLaunching`), before the method returns. Late registration is never called.
- **Every identifier you register/submit must be in `Info.plist` under `BGTaskSchedulerPermittedIdentifiers`** — otherwise `submit` throws `.notPermitted` and `register` returns false.
- Background work is **opportunistic, never guaranteed**. The system decides timing from usage patterns, battery, and network; Low Power Mode and the user's Background App Refresh setting can disable it entirely.
- Always call `task.setTaskCompleted(success:)` on every path, and wire `task.expirationHandler` to cancel in-flight work — the runtime budget is small and revocable.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll register the handler lazily when I first schedule." | Handlers must be registered before `application(_:didFinishLaunching…)` / `App.init` returns. Register lazily and the launch handler is never invoked. |
| "The identifier is just a string I pass to `submit`." | If it isn't listed in `Info.plist` `BGTaskSchedulerPermittedIdentifiers`, `submit(_:)` throws `.notPermitted` and `register` returns false. Code and plist must match exactly. |
| "I scheduled it for 15 minutes from now, so it runs then." | `earliestBeginDate` is a floor, not a schedule. The system runs it when *it* decides — could be hours later or never. Never depend on timing or on it running at all. |
| "The work finishes fast, I don't need an expiration handler." | Runtime is small (~30s for refresh) and the system can pull it at any moment. Without `expirationHandler` cancelling your `Task`, the OS kills the app and may throttle future scheduling. Always wire it and always call `setTaskCompleted`. |
| "It didn't fire in the Simulator, so my code is broken." | You can't observe real scheduling on demand. Test on a real device by pausing in LLDB and running `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"…"]` (and `_simulateExpirationForTaskWithIdentifier:` for the expiration path). |
| "I submit the next request from a timer / on next foreground." | A background task only re-arms if you submit the next request **from inside the handler**, first thing — before doing the work. Skip it and the chain dies after one run. |

## Verification gate

Before shipping background work, confirm every line:

- [ ] Every task identifier is registered before launch returns AND listed in `Info.plist` `BGTaskSchedulerPermittedIdentifiers` (exact string match).
- [ ] Background Modes capability enabled (Background fetch for refresh, Background processing for processing).
- [ ] Each handler submits the next request first (for repeating refresh), then does the work.
- [ ] `task.expirationHandler` cancels the in-flight `Task`; work calls `Task.checkCancellation()` at loop boundaries.
- [ ] `task.setTaskCompleted(success:)` is called on success, failure, and cancellation — every path.
- [ ] `submit(_:)` errors handled: `.notPermitted`, `.tooManyPendingTaskRequests` (1 refresh / 10 processing pending), `.unavailable`; for `continued` `.fail`, handle `.immediateRunIneligible`.
- [ ] `processing` constraints (`requiresExternalPower` / `requiresNetworkConnectivity`) set to match the work's real needs.
- [ ] Verified on a real device via the LLDB `_simulateLaunchForTaskWithIdentifier:` / `_simulateExpirationForTaskWithIdentifier:` commands — not assumed from the Simulator.

## Deep reference

`references/guide.md` — full setup, handler registration (UIKit/SwiftUI/`.backgroundTask` modifier), app-refresh and processing scheduling, execution and cancellation patterns, LLDB testing, iOS 18/26 features (`BGContinuedProcessingTask`, progress reporting, background GPU), and worked use cases (sync, DB maintenance, ML updates, cache cleanup, widget refresh). Load it for any concrete API question.

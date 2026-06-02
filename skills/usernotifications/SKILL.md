---
name: usernotifications
description: Implement and review local and remote notifications with the UserNotifications framework — authorization, scheduling triggers, content, categories/actions, the delegate, APNs registration, and badge management. Use when the user mentions push notification, local notification, UserNotifications, UNUserNotificationCenter, notification permission, badge, APNs, device token, notification category/action, or scheduling a reminder/alert.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple UserNotifications docs via Context7 (/websites/developer_apple_usernotifications)
---

# UserNotifications

Local and remote (push) notifications on Apple platforms. The deep API reference — authorization, every trigger type, content/attachments, categories and actions, the delegate, APNs registration, badge management, and worked use cases — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `DELIVERY` — `local` (default; you schedule via `UNUserNotificationCenter.add` with a trigger) · `remote` (APNs push: requires the Push Notifications capability, `registerForRemoteNotifications`, a server, and a device-token round-trip) · `both` (local for app-side reminders, remote for server-driven events — they share one delegate and one authorization).
2. `AUTH_LEVEL` — `standard` (`[.alert, .sound, .badge]`, prompts once) · `provisional` (`.provisional`, delivers quietly to Notification Center with no prompt; user promotes later) · `critical` (`.criticalAlert` + `defaultCriticalSound`, bypasses mute/Focus — requires a special Apple entitlement, do not request without one).
3. `INTERRUPTION` — `passive` (silent, list only) · `active` (default) · `timeSensitive` (breaks through Focus — needs the Time Sensitive Notifications entitlement) · `critical` (bypasses mute, entitlement-gated). Pick per notification, not per app.

## When to use

Building or reviewing any code that requests notification permission, schedules local notifications, registers for or handles push, defines categories/actions, implements `UNUserNotificationCenterDelegate`, or manages the app badge. If notifications are delivered by a third-party SDK (e.g. a push provider's wrapper), still use this skill for the authorization, delegate, and category layer — those remain `UserNotifications`.

## Core rules

- iOS 15+ for the API surface used here; `setBadgeCount(_:)` needs iOS 16+. iOS 26 is the default target.
- Async/await throughout: `requestAuthorization(options:)`, `notificationSettings()`, `add(_:)`, `setBadgeCount(_:)`, and the async delegate variants. No completion-handler StoreKit-1-style code unless maintaining legacy.
- **Authorization is a fact you read, never a flag you cache.** Re-read `center.notificationSettings().authorizationStatus` on every relevant launch/foreground — the user can revoke in Settings at any time.
- **One delegate, set before the app finishes launching.** Assign `UNUserNotificationCenter.current().delegate` and call `setNotificationCategories(_:)` in `App.init` / `didFinishLaunching`, before any notification can arrive — otherwise the launching tap is dropped.
- Request permission at a contextually relevant moment (when the user turns on a feature), not blindly at first launch.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "`requestAuthorization` returned `true`, so I'll cache `notificationsOn = true`." | Authorization is revocable in Settings and can be `.provisional`/`.ephemeral`. Read `notificationSettings().authorizationStatus` each time; never gate on a stored bool. |
| "I'll register for push right after launch so the token is ready." | `registerForRemoteNotifications()` must follow a *granted* authorization, and on iOS 26 `didRegisterForRemoteNotificationsWithDeviceToken` can fire before auth completes — gate the token send on `authorizationStatus == .authorized`. |
| "I set the delegate in `onAppear`, that's early enough." | A notification tapped from a cold launch is delivered as the app finishes launching, before any view appears. Set the delegate + categories in `init`/`didFinishLaunching` or you lose that response. |
| "I'll set `content.badge = app.unreadCount` on each notification." | `content.badge` only sets the badge when *that* notification is delivered and races with others. Use `center.setBadgeCount(_:)` (iOS 16+) as the single source of truth for the badge number. |
| "I'll group conversations with `summaryArgument`/`summaryArgumentCount`." | Both were deprecated in iOS 15 and do nothing on current OS. Grouping is `threadIdentifier` only; the system writes the summary text itself. |
| "Foreground notifications just show — nothing to do." | If the app is foregrounded, nothing appears unless you implement `willPresent` and return options like `[.banner, .sound, .list]`. No delegate method = silent in-app. |
| "Tested in the simulator, push works." | The simulator cannot register with APNs for a real device token; remote push must be verified on a physical device. Local notifications and the delegate can be tested in the simulator. |

## Verification gate

Before shipping notifications, confirm every line:

- [ ] `UNUserNotificationCenter.current().delegate` is set in `init`/`didFinishLaunching`, before any UI, and `setNotificationCategories(_:)` is called there too.
- [ ] Permission is requested at a contextual moment with explicit options; the granted/denied path is both handled (denied → deep link to Settings via `UIApplication.openSettingsURLString`).
- [ ] Authorization is re-read from `notificationSettings()` on launch/foreground — no cached boolean gates scheduling.
- [ ] `willPresent` is implemented and returns sensible foreground options (otherwise foreground notifications are silent).
- [ ] `didReceive` handles `UNNotificationDefaultActionIdentifier`, `UNNotificationDismissActionIdentifier`, every custom action identifier, and unwraps `UNTextInputNotificationResponse` for text actions.
- [ ] Remote: Push Notifications capability added; `registerForRemoteNotifications()` called only after auth granted; token send gated on `.authorized`; verified on a real device.
- [ ] Badge driven by `setBadgeCount(_:)`, not per-notification `content.badge`; cleared when the user views the relevant content.
- [ ] No `summaryArgument`/`summaryArgumentCount`; `.criticalAlert`/`.timeSensitive` used only with the matching entitlement.

## Deep reference

`references/guide.md` — full setup and authorization, `@Observable` `NotificationManager`, all three trigger types (time-interval/calendar/location), content and attachments, interruption levels, categories and actions, the `UNUserNotificationCenterDelegate`, deep-link handling, APNs registration and payload, iOS 18/26 notes, and worked reminder/messaging/habit examples. Load it for any concrete API question.

---
name: widgetkit
description: Build and review WidgetKit widgets — home screen widgets, lock screen (accessory) widgets, StandBy, Control Center controls, TimelineProvider/AppIntentTimelineProvider, interactive widgets, and App Group data sharing. Use when the user mentions widget, home screen widget, lock screen widget, WidgetKit, TimelineProvider, Timeline, widget extension, interactive widget, Control Center control, StandBy, accessory widget, or widgetURL deep links. For Live Activities / Dynamic Island use the `activitykit` skill; for the AppIntent that configures a widget or backs an interactive Button/Toggle/control use the `appintents` skill.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple WidgetKit docs via Context7 (/websites/developer_apple)
---

# WidgetKit

Glanceable widgets on home screen, lock screen, StandBy, and Control Center. Widgets are not mini apps — they render a system-scheduled timeline of static SwiftUI snapshots in a memory-constrained extension. The deep API reference — extension setup, timeline providers, every family, configuration, interactive widgets, App Group data sharing, lock screen, StandBy, controls — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `CONFIGURATION` — `static` (`StaticConfiguration` + `TimelineProvider`; no user options) · `app-intent` (`AppIntentConfiguration` + `AppIntentTimelineProvider`, iOS 17+; user picks parameters via a `WidgetConfigurationIntent` — see the `appintents` skill).
2. `FAMILIES` — declare the exact `supportedFamilies` you actually design and lay out: `system{Small,Medium,Large,ExtraLarge}` (home screen; ExtraLarge is iPad/Mac) · `accessory{Circular,Rectangular,Inline}` (lock screen, iOS 16+) · `control` (Control Center / Lock Screen / Action button via `ControlWidget`, iOS 18+).
3. `UPDATE_STRATEGY` — `timeline` (provider returns entries + `.after`/`.atEnd` reload policy; system budget applies) · `reload` (`.never` policy; main app/intent calls `WidgetCenter.shared.reloadTimelines(ofKind:)` when data changes) · `push` (`.never` policy + APNs `WidgetPushHandler`, iOS 18+, for server-driven updates without burning the local budget).

## When to use

Building or reviewing any widget, lock-screen accessory, StandBy layout, Control Center control, timeline provider, or widget data-sharing code. If the surface is a Live Activity or Dynamic Island, use `activitykit` (it shares the WidgetKit bundle but is driven by `ActivityKit`, not timelines). If the work is the `AppIntent` itself — widget configuration parameters or the intent behind an interactive Button/Toggle/control — use `appintents`.

## Core rules

- SwiftUI only; no UIKit. The widget view is rendered, not run — no `onAppear` side effects, no `Task {}`, no async work in the view body.
- Do all data loading in the provider (`getTimeline`/`timeline(for:in:)`), reading from a shared App Group container — never fetch in the view.
- iOS 17+ for `containerBackground(_:for:)`, interactive widgets, `AppIntentConfiguration`, StandBy. iOS 18+ for `ControlWidget` and `WidgetPushHandler`. iOS 26 is the default target.
- Keep `TimelineEntry` small and `Codable`-friendly: primitives and value types, never managers, view models, or `UIImage`s.
- Interactivity is `Button(intent:)` / `Toggle(isOn:intent:)` backed by an `AppIntent` — closures (`Button(action:)`) silently do nothing in a widget.
- Reload narrowly: `reloadTimelines(ofKind:)` only when that widget's data actually changed, not `reloadAllTimelines()` on every save.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll set `.after(15 min)` so it always feels fresh." | The system enforces a per-app budget (~40–70 reloads/day) and ignores greedy schedules. Pick the slowest acceptable cadence; for event-driven freshness use `reloadTimelines(ofKind:)` or APNs `WidgetPushHandler`, not a tight timer. |
| "I'll just `reloadAllTimelines()` after any change to be safe." | That spends every widget's budget for one widget's change and starves the ones that matter. Reload only the affected `ofKind:`, only when its data actually changed. |
| "I'll `await fetchFromServer()` inside the widget view." | The view is a pure render of an already-computed entry — no async, no `Task`, no `onAppear` work. Fetch in the provider; better, have the app prefetch into the App Group and let the provider read cached data. |
| "The image is only a few MB, the widget can load it." | Widget extensions run under a hard memory limit (~30 MB); a couple of full-res images crash it to blank. Use SF Symbols, or downscale to thumbnails before storing them in the shared container. |
| "`Button(action:)` is simpler than wiring up an AppIntent." | In a widget that closure never fires. Interactivity requires `Button(intent:)`/`Toggle(isOn:intent:)` with an `AppIntent` that has an `init()` — see `appintents`. |
| "I'll register a tap handler / `onTapGesture` for navigation." | Widgets route taps only through `Link(destination:)` (per-region) and `.widgetURL(_:)` (whole-widget fallback), handled in the app via `onOpenURL`. Gesture recognizers don't exist here. |
| "Sandbox/UserDefaults sharing works, so storage is fine." | Both targets must share the exact same App Group ID, and after saving you must call a `reloadTimelines` — otherwise the widget shows stale data even though the write succeeded. |

## Verification gate

Before shipping a widget, confirm every line:

- [ ] `supportedFamilies` lists only families with a real, tested layout; each branch in the view handles its family (no fallback rendering the wrong size).
- [ ] `containerBackground(_:for: .widget)` is set (required iOS 17+; also what makes StandBy/removable backgrounds work).
- [ ] All data is loaded in the provider from the shared App Group; the view body has no async work, no `Task`, no network, no `onAppear` side effects.
- [ ] `TimelineEntry` holds only lightweight value types; no large images (SF Symbols or downscaled thumbnails only) — extension stays under the memory limit.
- [ ] Reload policy matches the dial: `timeline` uses a realistic `.after`/`.atEnd`; `reload`/`push` use `.never` plus `reloadTimelines(ofKind:)` or `WidgetPushHandler`. No tight-interval timers fighting the budget.
- [ ] Main app calls `reloadTimelines(ofKind:)` (narrow, not `reloadAllTimelines()`) after the underlying data changes.
- [ ] Interactivity uses `Button(intent:)`/`Toggle(isOn:intent:)` with an `AppIntent` that has a no-arg `init()`; deep links use `Link`/`.widgetURL`, handled by `onOpenURL` in the app.
- [ ] Accessory/lock-screen views use `.widgetAccentable()` and read correctly in vibrant rendering; `@main` is on the `WidgetBundle`/`Widget`.

## Deep reference

`references/guide.md` — full extension setup, App Group configuration, `TimelineProvider`/`AppIntentTimelineProvider`, all widget families and layout adaptation, static vs. app-intent configuration, interactive widgets, data sharing (UserDefaults/file/Realm), lock screen, StandBy, Live Activities, Control widgets, best practices, common pitfalls, and a quick-reference of environment values, families, policies, and version compatibility. Load it for any concrete API question.

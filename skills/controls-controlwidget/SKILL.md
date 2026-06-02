---
name: controls-controlwidget
description: Build and review iOS 18+ Controls — the interactive tiles users add to Control Center, the Lock Screen, and the Action Button. Covers ControlWidget, StaticControlConfiguration vs AppIntentControlConfiguration, ControlWidgetButton, ControlWidgetToggle, the ControlValueProvider + SetValueIntent that make toggles reflect real state, and ControlCenter.shared.reloadControls. Use when the user mentions a Control Center control, ControlWidget, Lock Screen control, the Action Button, ControlWidgetButton, ControlWidgetToggle, or a custom control. Controls are built on WidgetKit + App Intents — for the hosting widget extension see the `widgetkit` skill; for the AppIntent/SetValueIntent a control runs see the `appintents` skill.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple Developer docs via Context7 (/websites/developer_apple)
---

# Controls — ControlWidget

The interactive tiles a user can place in **Control Center**, on the **Lock Screen**, and assign to
the **Action Button** (iOS 18+). A Control is a `ControlWidget` living in your widget extension,
built on WidgetKit + App Intents. The deep API reference — both configuration kinds, button vs.
toggle, the value provider, the backing intents, refreshing, extension setup, and pitfalls — lives
in `references/guide.md`. This file is the decision and discipline layer: read it first, open the
guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `KIND` — `button` (`ControlWidgetButton`, fires an `AppIntent` once per tap, no state) · `toggle`
   (`ControlWidgetToggle`, stateful on/off, needs a `ControlValueProvider` + `SetValueIntent`).
2. `CONFIG` — `static` (`StaticControlConfiguration`; same action every time, no add-time setup) ·
   `app-intent` (`AppIntentControlConfiguration`; user picks what it acts on via a
   `ControlConfigurationIntent`'s `@Parameter`s).
3. `SURFACE` — `control-center` · `lock-screen` · `action-button`. You don't choose this — the user
   assigns it; the dial only frames which surface(s) the control should read well on.

## When to use

Building or reviewing any custom Control for Control Center, the Lock Screen, or the Action Button —
the `ControlWidget`, its configuration, the `Label`, the backing `AppIntent`/`SetValueIntent`, the
value provider, and the reload calls. For the widget extension that hosts it (and home/Lock Screen
*widgets*), use `widgetkit`. For the intent's `perform()`, `@Parameter`, and `AppEntity`/`EntityQuery`
behind a configured control, use `appintents`. Don't reach for these for normal widgets — a Control
is a different top-level type with no timeline.

## Core rules

- A Control is a **`ControlWidget`**, declared in the widget extension's `WidgetBundle` alongside
  widgets. It is **not** a `Widget`/`StaticConfiguration` and has **no `TimelineProvider`**.
- iOS 18.0+ only. The Action Button surface additionally needs hardware that has one (iPhone 15 Pro+).
- The action is an **App Intent**, not a closure: `ControlWidgetButton` runs an `AppIntent`,
  `ControlWidgetToggle` runs a `SetValueIntent`. Do the work in `perform()`, on **shared** state.
- A toggle reflects real state only via a **`ControlValueProvider`**. Without one it's stuck on its
  placeholder `isOn:`.
- Extension and app are separate processes — share the value through an **App Group**.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "A control is just a small widget — I'll use a `TimelineProvider`." | A Control is a `ControlWidget`, not a `Widget`. There is no timeline. State comes from a `ControlValueProvider` on demand; you refresh with `ControlCenter`, not `WidgetCenter`. |
| "I set `isOn:` so the toggle shows the right state." | A hard-coded `isOn:` is a placeholder. Without a `ControlValueProvider` supplying `currentValue()`, the toggle never reflects reality and looks stuck. |
| "I'll pass the toggle a plain `AppIntent`." | A toggle's `action` must be a **`SetValueIntent`** with a `value` `@Parameter` — that's how the system hands it the new on/off value. A plain `AppIntent` only backs a *button*. |
| "I'll flip a bool in app memory inside the action." | The intent runs in a separate process. Mutate **shared** state (App Group), not in-memory app objects, or the app and control disagree. |
| "The state changed in-app, the control will catch up." | A control only re-renders on its own tap or when you call `ControlCenter.shared.reloadControls(ofKind:)`. External changes need an explicit reload or the control shows stale state. |
| "I'll force my control onto the Action Button." | You only publish the control. The user assigns it to Control Center, the Lock Screen, or the Action Button — surface placement is entirely user-controlled. |

## Verification gate

Before shipping a Control, confirm every line:

- [ ] Type conforms to `ControlWidget` and is listed in the extension's `@main WidgetBundle` — no `TimelineProvider`.
- [ ] `CONFIG` chosen deliberately: `StaticControlConfiguration` for fixed action, `AppIntentControlConfiguration` (+ `.promptsForUserConfiguration()` when useless until configured) for user-picked targets.
- [ ] Button → `ControlWidgetButton(action: someAppIntent())`; toggle → `ControlWidgetToggle(isOn:action: someSetValueIntent())`.
- [ ] Every toggle has a `ControlValueProvider` whose value type matches `isOn`, with a real `currentValue()` reading shared state.
- [ ] The `SetValueIntent` has a `@Parameter var value` and applies it in `perform()` against shared state.
- [ ] State touched outside a tap triggers `ControlCenter.shared.reloadControls(ofKind:)` (not `reloadAllControls()` unless broad).
- [ ] App and extension share the value via an App Group; intents compiled into both targets.
- [ ] `.displayName` / `.description` set for the gallery; `Label` symbol + title read well at control size and change with toggle state.
- [ ] Control gated to iOS 18.0+; Action Button behavior verified on capable hardware.

## Deep reference

`references/guide.md` — `ControlWidget` and the configuration builder, `StaticControlConfiguration`
vs `AppIntentControlConfiguration`, `ControlWidgetButton`, `ControlWidgetToggle`, the
`ControlValueProvider`/`AppIntentControlValueProvider`, the `SetValueIntent`/`ControlConfigurationIntent`
wiring, refreshing via `ControlCenter`, the widget-extension setup, tinting, pitfalls, and a
quick-reference of every type. Load it for any concrete API question.

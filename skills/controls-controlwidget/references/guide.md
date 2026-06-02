# Controls — ControlWidget (iOS 18+)

The deep reference for building **Controls**: the small interactive tiles users can place in
**Control Center**, on the **Lock Screen**, and assign to the **Action Button**. Controls are a
WidgetKit + App Intents feature introduced in **iOS 18 / iPadOS 18**. This guide covers the
`ControlWidget` protocol, the two configuration kinds, button vs. toggle controls, value-driven
state via a `ControlValueProvider`, wiring the backing intent, refreshing state, the extension
setup, and the pitfalls that bite.

A Control is **not** a normal home-screen widget. It does not have a `TimelineProvider` and is not
a `Widget`/`StaticConfiguration`. It is a distinct top-level type (`ControlWidget`) that lives in
your **widget extension** and renders one of two system-drawn templates whose only real "view" is
a `Label` (symbol + text). The app provides the action and the current value; the system draws and
places the control.

Related skills: `widgetkit` (the extension that hosts controls + accessory widgets) and
`appintents` (the `AppIntent` / `SetValueIntent` that a control runs).

---

## 1. What Controls are, and the three surfaces

A Control is a single tappable tile that performs one quick action without launching the app. The
**same `ControlWidget`** can appear in three places — the user, not you, decides where:

| Surface | How it gets there |
|---|---|
| **Control Center** | User taps **+** in Control Center → "Add a Control" → picks your control from the gallery. |
| **Lock Screen** | User edits the Lock Screen → control slots below the clock → picks your control. |
| **Action Button** | (iPhone 15 Pro and later) Settings → Action Button → "Controls" → user assigns your control. |

You do **not** choose the surface. You ship a `ControlWidget`; the system lists it in the gallery
for all three. You influence presentation only through the control's `displayName`, the `Label`
(SF Symbol + title), and the optional tint.

There are exactly **two kinds** of control template:

- **Button control** (`ControlWidgetButton`) — runs an `AppIntent` once per tap. Fire-and-forget:
  start a timer, capture a photo, log a glass of water.
- **Toggle control** (`ControlWidgetToggle`) — a stateful on/off switch. Reflects a current value
  and flips it via a `SetValueIntent`. Turn a light on/off, mute, start/stop recording.

---

## 2. The `ControlWidget` protocol

A control is a top-level type conforming to `ControlWidget`, with a `body` returning some
`ControlWidgetConfiguration`. It is declared in the widget extension's `@main` bundle alongside any
widgets.

```swift
import WidgetKit
import SwiftUI
import AppIntents

struct GarageDoorControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.example.app.garage") {
            ControlWidgetToggle(
                "Garage Door",
                isOn: false,                       // placeholder; real value comes from a provider
                action: ToggleGarageIntent()
            ) { isOpen in
                Label(isOpen ? "Open" : "Closed",
                      systemImage: isOpen ? "door.garage.open" : "door.garage.closed")
            }
        }
        .displayName("Garage Door")
        .description("Open and close the garage door.")
    }
}
```

The `body` is built with the `@ControlWidgetConfigurationBuilder` result builder, so you can put
local `let kind = …` statements before returning the configuration.

### Two configuration types

| Type | Use when | Backing |
|---|---|---|
| `StaticControlConfiguration` | The control needs **no per-instance user setup** — it always does the same thing (toggle *the* garage door, start *a* timer). | A `kind` string + the template. Optionally a `ControlValueProvider` for live state. |
| `AppIntentControlConfiguration` | The user must **pick what the control acts on** (which light, which timer, which account) when they add it. | A `ControlConfigurationIntent` whose `@Parameter`s become the configuration UI; its values flow into the template. |

Both produce a control; the difference is whether the user configures it at add-time.

---

## 3. Button controls — `ControlWidgetButton`

A button control runs an `AppIntent` once per tap. The intent is what does the work — there is **no
closure**. You pass an *instance* of the intent.

```swift
struct StartTimerControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.example.app.startTimer") {
            ControlWidgetButton(action: StartTimerIntent()) {
                Label("Start Timer", systemImage: "timer")
            }
        }
        .displayName("Start Timer")
    }
}

struct StartTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Timer"
    // A control intent that just performs work needs no UI surface beyond the control.
    func perform() async throws -> some IntentResult {
        TimerStore.shared.start()
        return .result()
    }
}
```

Key points:
- The `Label` is the entire visible content. The system draws the tile; you do not control layout.
- `perform()` runs in the **extension's** process for static controls, or your app's process if the
  intent is declared to open the app. Most quick actions run in-process in the extension — keep
  them fast and avoid UI-thread heavy work.
- A button control has no persistent state to reflect; it just fires.

---

## 4. Toggle controls — `ControlWidgetToggle`

A toggle control is **stateful**. It shows a current on/off value and flips it. Two things are
required to make it reflect *real* state rather than a hard-coded placeholder:

1. A **`ControlValueProvider`** that supplies the current value when the system renders the control.
2. A **`SetValueIntent`** that the toggle runs to apply the new value the user just chose.

```swift
struct GarageToggleControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "com.example.app.garage",
            provider: GarageValueProvider()        // supplies the current value
        ) { isOpen in
            ControlWidgetToggle(
                "Garage Door",
                isOn: isOpen,
                action: ToggleGarageIntent()        // a SetValueIntent
            ) { isOpen in
                Label(isOpen ? "Open" : "Closed",
                      systemImage: isOpen ? "door.garage.open" : "door.garage.closed")
            }
            .tint(.green)
        }
        .displayName("Garage Door")
    }
}
```

### The value provider

`ControlValueProvider` (async) returns the current value when the control is rendered. For a
configured control you implement `currentValue(configuration:)`; for a static control you provide a
`previewValue` plus `currentValue()`.

```swift
struct GarageValueProvider: ControlValueProvider {
    // Shown in the gallery / before the real value loads.
    var previewValue: Bool { false }

    // The real, current value — read from shared state.
    func currentValue() async throws -> Bool {
        try await GarageService.shared.isOpen()
    }
}
```

The provider's value type must match the toggle's `isOn` binding (here `Bool`). For a configured
toggle, use `AppIntentControlValueProvider` so the configuration intent's parameters reach
`currentValue(configuration:)`.

### The `SetValueIntent`

The toggle's `action` is a `SetValueIntent` — an `AppIntent` that receives the desired value in a
`@Parameter` marked as the value, applies it, and returns. The system passes the *new* value (the
opposite of the current `isOn`) when the user taps.

```swift
struct ToggleGarageIntent: SetValueIntent, AppIntent {
    static let title: LocalizedStringResource = "Toggle Garage Door"

    // The new value the user is setting. Required by SetValueIntent.
    @Parameter(title: "Open")
    var value: Bool

    func perform() async throws -> some IntentResult {
        try await GarageService.shared.setOpen(value)
        return .result()
    }
}
```

Flow per tap: system reads current value via the provider → user taps → system runs the
`SetValueIntent` with `value = !current` → intent applies it → control re-renders with the provider's
new value. If you skip the provider, the toggle always shows its hard-coded placeholder and will
look "stuck" even though the intent ran.

---

## 5. Configured controls — `AppIntentControlConfiguration`

When the control must act on a *specific* thing the user selects at add-time (which light, which
account), back it with a `ControlConfigurationIntent`. Its `@Parameter`s become the configuration
form the system shows when the user adds the control.

```swift
struct LightControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: "com.example.app.light",
            provider: LightValueProvider()
        ) { configuration, isOn in
            ControlWidgetToggle(
                configuration.lightName,
                isOn: isOn,
                action: SetLightIntent(lightID: configuration.lightID)
            ) { isOn in
                Label(isOn ? "On" : "Off", systemImage: "lightbulb")
            }
        }
        .displayName("Light")
        .promptsForUserConfiguration()              // force the config sheet when added
    }
}

struct LightConfiguration: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Choose Light"

    @Parameter(title: "Light")
    var light: LightEntity                          // an AppEntity with an EntityQuery

    var lightID: String { light.id }
    var lightName: String { light.name }
}
```

Modifiers:
- **`.displayName(_:)`** — the label shown in the controls gallery. Use a clear, short noun.
- **`.description(_:)`** — supporting text in the gallery.
- **`.promptsForUserConfiguration()`** — tells the system to present the configuration UI as soon as
  the user adds the control, instead of adding it with defaults. Use it when the control is useless
  until configured (a light control with no light picked).

The `EntityQuery` behind the parameter must return real options; a missing default can crash the
template build (set a default in the `@Parameter` initializer or via `Query.default(...)`).

---

## 6. Refreshing control state

Controls are **not** on a timeline — there is no `TimelineProvider`, no `reloadTimelines`. The
system asks the value provider for the current value when it renders, but it will **not** notice
state that changed *outside* a tap (the garage opened from another device, a download finished, the
user toggled in-app). You must tell WidgetKit to re-query.

Use `ControlCenter` from your **app** (or the extension, after applying a change):

```swift
import WidgetKit

// Reload one control kind:
ControlCenter.shared.reloadControls(ofKind: "com.example.app.garage")

// Reload everything you publish:
ControlCenter.shared.reloadAllControls()
```

Call this whenever the underlying state changes through a path the control didn't drive:
- After a change pushed from your server / a remote device.
- After the user changes the same setting inside the app.
- At the end of a background refresh that updated the value.

`reloadControls(ofKind:)` is the targeted, cheaper call; prefer it over `reloadAllControls()`.
This is the **controls analogue of `WidgetCenter.shared.reloadTimelines(...)`** — a different class
(`ControlCenter`, not `WidgetCenter`) with the same job for controls.

You generally do **not** need to call reload after a tap: running the toggle's `SetValueIntent`
already causes the system to re-render the control with the provider's fresh value.

---

## 7. Extension setup

Controls live in a **widget extension** (the same target type as widgets). There is no separate
"controls extension."

1. **Target.** Add a Widget Extension target (File → New → Target → Widget Extension), or reuse the
   app's existing one. Controls and widgets coexist in the same bundle.
2. **Bundle.** List the control alongside widgets in the `@main WidgetBundle`:

   ```swift
   @main
   struct MyWidgets: WidgetBundle {
       var body: some Widget {
           MyHomeScreenWidget()
           GarageToggleControl()        // ControlWidget conforms to Widget's bundle requirements
           StartTimerControl()
       }
   }
   ```

3. **Shared state.** The extension and app are separate processes. Read/write the value the control
   reflects through a shared store — an **App Group** (`UserDefaults(suiteName:)` or a shared file /
   SQLite / SwiftData container) so both the provider (extension) and your reload calls (app) see
   the same truth.
4. **App Intents availability.** The `AppIntent` / `SetValueIntent` / `ControlConfigurationIntent`
   types must be compiled into the extension (and the app, if the app also runs them). Put intents
   in a shared file/framework included by both targets.
5. **Deployment target.** The control types require **iOS 18.0+**. Gate the whole control with
   availability if the rest of the app targets earlier OSes — but the control file simply won't be
   compiled into older runtimes via the extension's min deployment.

---

## 8. Tinting and presentation

- `ControlWidgetToggle` and `ControlWidgetButton` accept a `.tint(_:)` for the active color.
- The toggle's value label closure receives the current value so the **symbol and title can change
  with state** (`lightbulb` vs `lightbulb.fill`, "On" vs "Off").
- You cannot supply arbitrary SwiftUI layout — the content is a `Label`. The system owns the tile's
  size, shape, and placement across the three surfaces.
- Choose SF Symbols that read at small sizes and have a clear on/off distinction for toggles.

---

## 9. Pitfalls

- **Treating a control like a widget.** It's a `ControlWidget`, not a `Widget`/`StaticConfiguration`,
  and has **no `TimelineProvider`**. Don't reach for `WidgetCenter.reloadTimelines` — controls
  refresh via `ControlCenter.shared.reloadControls`.
- **Toggle stuck on its placeholder.** A `ControlWidgetToggle` with a hard-coded `isOn:` and **no
  `ControlValueProvider`** never reflects real state. Wire a provider so the configuration's value
  closure receives the live value.
- **Forgetting the `SetValueIntent`.** A toggle's `action` must be a `SetValueIntent` with a `value`
  `@Parameter`. A plain `AppIntent` can back a *button* but cannot carry the new toggle value.
- **Expecting a closure to run on tap.** The action is an **App Intent**, run by the system in a
  separate process — not a Swift closure with captured app state. Pass an intent instance; do the
  work in `perform()`; read/write shared state, not in-memory app objects.
- **State drift after external changes.** If the value changes outside a control tap and you never
  call `ControlCenter.shared.reloadControls(ofKind:)`, the control shows stale state until the next
  natural re-render.
- **Assuming you control placement.** You only publish the control. The user assigns it to Control
  Center, the Lock Screen, or the Action Button — you cannot force a surface, and the Action Button
  assignment is entirely user-controlled.
- **Crash building the control template.** A configuration intent `@Parameter` with no resolvable
  value can crash template building. Give parameters a default (in the initializer or via
  `Query.default(...)`).
- **Missing App Group.** Extension and app are separate processes; without shared storage the
  provider reads different data than the app writes, so the control and app disagree.

---

## 10. Quick reference

| Type / member | Role |
|---|---|
| `ControlWidget` | Top-level control type; `body: some ControlWidgetConfiguration`. |
| `@ControlWidgetConfigurationBuilder` | Result builder for the `body`. |
| `StaticControlConfiguration` | Control with no per-instance user setup; `kind` + optional `provider`. |
| `AppIntentControlConfiguration` | User-configured control; backed by a `ControlConfigurationIntent`. |
| `ControlWidgetButton(action:)` | Fire-once control; runs an `AppIntent`. |
| `ControlWidgetToggle(_:isOn:action:)` | Stateful on/off control; runs a `SetValueIntent`. |
| `ControlValueProvider` | Supplies the toggle's current value (`previewValue` + `currentValue()`). |
| `AppIntentControlValueProvider` | Provider variant that receives the configuration intent. |
| `SetValueIntent` | App Intent carrying the new value (`@Parameter var value`). |
| `ControlConfigurationIntent` | Intent whose `@Parameter`s form the add-time config UI. |
| `.displayName(_:)` / `.description(_:)` | Gallery label and supporting text. |
| `.promptsForUserConfiguration()` | Present the config sheet when the control is added. |
| `.tint(_:)` | Active color for the control. |
| `ControlCenter.shared.reloadControls(ofKind:)` | Re-query one control kind's value. |
| `ControlCenter.shared.reloadAllControls()` | Re-query every published control. |

Minimum OS: **iOS 18.0 / iPadOS 18.0+**. Action Button surface requires hardware that has one
(iPhone 15 Pro and later). Controls live in a **widget extension** and depend on **WidgetKit** +
**App Intents**.

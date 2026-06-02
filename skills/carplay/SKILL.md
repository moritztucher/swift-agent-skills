---
name: carplay
description: Build and review CarPlay apps — the dedicated CPTemplateApplicationScene, CPInterfaceController template stack, and the category-specific template set (CPListTemplate, CPGridTemplate, CPMapTemplate, CPTabBarTemplate, CPNowPlayingTemplate, CPPointOfInterestTemplate, CPInformationTemplate). Use when the user mentions CarPlay, CPTemplate, CPInterfaceController, an in-car / car app, the CarPlay entitlement, or projecting an iPhone app to the vehicle display.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple CarPlay docs via Context7 (/websites/developer_apple)
---

# CarPlay

In-vehicle UI projected from the iPhone. The phone runs all logic; the car renders a
template-based, driver-safe interface and sends back input. The deep API reference —
every template, the scene delegate, the navigation map/trip APIs, error handling, SwiftUI
integration, iOS 26 changes — lives in `references/guide.md`. This file is the decision and
discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means and which entitlement you need.

1. `APP_CATEGORY` — `audio` · `communication` · `navigation` · `ev-charging` · `fueling` · `parking` · `quick-food` · `driving-task`. Pick exactly **one** (only EV-charging + fueling may combine). This decides your entitlement key, your allowed templates, and your template-depth limit (audio/comm/nav/EV/parking = 5, fueling = 3, quick-food/driving-task = 2).
2. `SCENE` — always a **dedicated `CPTemplateApplicationScene`** separate from the phone's `UIWindowScene`, wired in the Info.plist scene manifest with its own delegate. Navigation apps also get a `CPWindow` (the `didConnect ... to window:` callback) to draw the map; every other category uses the interface controller only.
3. `TEMPLATES` — the concrete set you'll build from, drawn only from the templates Apple allows for `APP_CATEGORY` (e.g. audio → `CPTabBarTemplate` + `CPListTemplate` + `CPGridTemplate` + `CPNowPlayingTemplate`; navigation → `CPMapTemplate` + `CPSearchTemplate`; EV/parking → `CPPointOfInterestTemplate` + `CPListTemplate` + `CPInformationTemplate`). No custom views.

## When to use

Building or reviewing any CarPlay scene, template, or in-car flow. If the task is "add CarPlay
to this app," start by fixing `APP_CATEGORY` — everything else (entitlement, templates, depth)
follows from it. Not for Android Auto, not for general SwiftUI/UIKit phone UI.

## Core rules

- **CarPlay is a separate scene with its own delegate.** Wire `CPTemplateApplicationSceneSessionRoleApplication` in the Info.plist scene manifest pointing at a `CPTemplateApplicationSceneDelegate`. For SwiftUI `@main` apps, set `INFOPLIST_KEY_UIApplicationSceneManifest_Generation = NO` and supply the manifest by hand, or the CarPlay scene never connects.
- **Retain `interfaceController` (and `window` for navigation) for the whole session.** Drop them only in the disconnect callback. A nil interface controller crashes on first template push.
- **One source of truth shared between phone and car.** Drive both UIs from one observable model (`@Observable` singleton / injected store). Don't duplicate state per scene.
- **Always call the completion / handler closure.** `CPListItem.handler`, push/pop completions, search completions — failing to call them freezes the car UI.
- **Glanceable, lock-safe, voice-friendly.** The app must work with the iPhone locked or in the trunk; never tell the user to touch their phone.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll just build the CarPlay UI and ship it." | CarPlay needs a **per-category entitlement granted by Apple** (`com.apple.developer.carplay-audio`, `-maps`, `-communication`, `-charging`, `-fueling`, `-parking`, `-quick-ordering`, `-driving-task`). You request it at developer.apple.com/carplay, sign the addendum, and wait for review. Without it the scene won't connect — you cannot self-grant it. |
| "I'll design a custom screen / draw my own controls." | You only get the **templates Apple allows for your category**. There is no arbitrary drawing — the one exception is the navigation `CPWindow`, and that's solely for rendering your map, not custom widgets. Off-template UI = rejection. |
| "I'll cram all my items into one list / grid." | Item counts are **enforced for driver safety**. `CPGridTemplate` shows only the first 8 buttons; `CPListTemplate` exposes `maximumItemCount` / `maximumSectionCount`; `CPPointOfInterestTemplate` caps at ~12 POIs. Query the runtime limits — they vary by vehicle — don't hardcode and overflow. |
| "I'll push templates as deep as the flow needs." | Depth is capped **by category** (2–5). Pushing past it throws a maximum-level exception. Use `CPTabBarTemplate` for breadth instead of deep stacks. |
| "I'll reuse the phone's `UIWindowScene` / SceneDelegate for CarPlay." | CarPlay is a **distinct scene** with its own role and delegate. Sharing the phone scene gives the "does not implement CarPlay template application lifecycle methods" error. |
| "It compiles, so it works in the car." | There's no device-free shortcut: test in the **CarPlay Simulator** (Simulator → I/O → External Displays → CarPlay) and exercise every push/pop and handler. Connection/lock/handler bugs only surface there. |

## Verification gate

Before shipping CarPlay, confirm every line:

- [ ] `APP_CATEGORY` chosen, the matching entitlement requested from Apple and present in `.entitlements`.
- [ ] Dedicated CarPlay scene in the Info.plist manifest, pointing at a `CPTemplateApplicationSceneDelegate` (SwiftUI: manifest generation disabled).
- [ ] `interfaceController` (and navigation `CPWindow`) retained for the session, released only on disconnect.
- [ ] Every template used is one Apple permits for the category — no custom drawing outside the navigation map window.
- [ ] Item / button / POI counts respect the runtime limits (`maximumItemCount`, grid 8, POI ~12); template depth stays within the category cap.
- [ ] Every `handler` and push/pop/search completion closure is called on every path.
- [ ] Phone and car read from one shared source of truth.
- [ ] Walked through the full flow in the CarPlay Simulator, including connect, disconnect, and lock screen.

## Deep reference

`references/guide.md` — full requirements/entitlements, scene + interface controller lifecycle, every template with worked examples (audio, navigation, EV/parking), dynamic updates, alerts/action sheets, SwiftUI integration, error handling, testing, troubleshooting, and iOS 26 changes (Liquid Glass, widgets, Live Activities, multitouch, parked video). Load it for any concrete API question.

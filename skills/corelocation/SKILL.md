---
name: corelocation
description: Implement and review user location with Core Location — authorization (when-in-use/always), full vs reduced accuracy, the async CLLocationUpdate.liveUpdates stream, CLMonitor geofencing/beacons, visits, significant-change and background updates. Use when the user mentions Core Location, CLLocationManager, GPS, user location, geofencing, location permission, region monitoring, beacons, or CLLocationUpdate.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple Core Location docs via Context7 (/websites/developer_apple)
---

# Core Location

Determining the user's location, geofencing, beacons, and visits on Apple platforms. The deep API reference — setup, authorization, the live-updates stream, CLMonitor, geocoding, beacons, visits, background, battery tuning, pitfalls, a full `@Observable` manager — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `AUTH_SCOPE` — `when-in-use` (default; foreground only) · `always` (background presence, geofences, visits — only request *after* when-in-use is already granted and you can justify it; App Review scrutinizes this) · `one-shot` (`LocationButton` / a single `requestLocation`, no persisted grant).
2. `UPDATE_MODE` — `one-shot` (single `requestLocation`) · `live` (default for continuous; iOS 17+ `CLLocationUpdate.liveUpdates()`) · `significant-change` (battery-cheap background presence) · `visits` (place arrival/departure, needs `always`).
3. `MONITORING` — `none` · `geofence` (iOS 17+ `CLMonitor` + `CircularGeographicCondition`) · `beacon` (`CLMonitor` + `BeaconIdentityCondition`).

## When to use

Building or reviewing any code that reads the user's position, monitors regions/beacons, tracks visits, or requests location permission. For drawing maps, annotations, or directions use MapKit (a later skill) — Core Location only supplies the coordinates and authorization.

## Core rules

- iOS 17+: prefer the async-native surface — `CLLocationUpdate.liveUpdates()` for continuous updates and `CLMonitor` for geofences/beacons. Drop to the `CLLocationManagerDelegate` bridge only for older deployment targets or existing code.
- iOS 18+ is the guide's baseline; iOS 26 is the default target. Gate anything newer with availability checks.
- **Authorization is a state machine, never an assumption.** Read `authorizationStatus` + `accuracyAuthorization`, request the *minimum* scope, and react in the change callback / via `update.authorizationDenied`. Requesting before checking `.notDetermined` fails silently.
- One-time `requestLocation()` and the `liveUpdates()` stream are async — bridge the delegate with a checked continuation or use the stream directly. Don't busy-poll.
- Stop what you start: cancel the `Task` driving `liveUpdates()` (a SwiftUI `.task {}` does this for free), or call the matching `stop…` for legacy delegate updates.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll add the Info.plist string later." | Calling a request method without `NSLocationWhenInUseUsageDescription` (and `NSLocationAlwaysAndWhenInUseUsageDescription` for always) silently fails or crashes. The string ships before the first request, always. |
| "Just request Always — it covers everything." | Always must follow an existing when-in-use grant; requesting it cold gets downgraded and flagged by App Review. Request when-in-use first, escalate to always only when a real background feature needs it. |
| "Status is authorized, so I have precise GPS." | Authorization and accuracy are independent. Users grant `.reducedAccuracy` (~5km); check `accuracyAuthorization` and call `requestTemporaryFullAccuracyAuthorization(withPurposeKey:)` (needs `NSLocationTemporaryUsageDescriptionDictionary`) only when the feature truly needs it. |
| "I'll loop calling `requestLocation()` to keep it fresh." | Polling drains battery and fights the framework. Iterate `CLLocationUpdate.liveUpdates()` (iOS 17+) or use significant-change monitoring — the system coalesces and powers down between fixes. |
| "I'll keep using `CLCircularRegion` + `startMonitoring(for:)`." | That delegate path is the legacy API. On iOS 17+ use the `CLMonitor` actor with `CircularGeographicCondition`/`BeaconIdentityCondition` and its `events` async sequence; it persists across launches and exposes diagnostics. |
| "Background location just works once authorized." | Background needs all of: the `location` UIBackgroundMode, `allowsBackgroundLocationUpdates = true`, `always` authorization, and (per Apple) `showsBackgroundLocationIndicator`. Miss one and updates stop the moment you background. |
| "Whatever fix arrives first is good enough." | Early fixes are cached/inaccurate. Reject locations with `horizontalAccuracy <= 0`, accuracy worse than you need, or a stale `timestamp`. |

## Verification gate

Before shipping location code, confirm every line:

- [ ] Every authorization scope used has its matching Info.plist usage string (when-in-use, always, temporary-accuracy dictionary).
- [ ] When-in-use is requested before any always request; always is only requested when a background feature justifies it.
- [ ] Code branches on `authorizationStatus` (incl. `.denied`/`.restricted` → Settings path) and reacts to changes in the callback / `update.authorizationDenied`.
- [ ] `accuracyAuthorization` handled: reduced-accuracy works or explicitly requests temporary full accuracy with a purpose key.
- [ ] Continuous updates use `CLLocationUpdate.liveUpdates()` (iOS 17+) driven by a cancellable `Task`/`.task {}`, not a manual poll loop; legacy `startUpdatingLocation` always has a matching stop.
- [ ] Geofencing/beacons use `CLMonitor` on iOS 17+ (≤20 regions, ~100–200m radius); legacy region monitoring only for older targets.
- [ ] Background updates have UIBackgroundMode `location` + `allowsBackgroundLocationUpdates` + `always` + `showsBackgroundLocationIndicator`; visits use `always`.
- [ ] Locations validated for accuracy/age before use; `CLError` cases (`.denied`, `.locationUnknown`, `.network`) handled distinctly.

## Deep reference

`references/guide.md` — full setup and Info.plist keys, authorization + accuracy flow, the `liveUpdates()` stream and legacy delegate bridge, `CLMonitor` and legacy region/beacon monitoring, visits, significant-change, geocoding (incl. iOS 26 MapKit replacements), background config, `LocationButton`, battery/accuracy tuning, common pitfalls, version compatibility, and a complete `@Observable` manager. Load it for any concrete API question.

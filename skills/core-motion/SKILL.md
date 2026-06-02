---
name: core-motion
description: Read and process device motion and environmental sensor data with Core Motion — accelerometer, gyroscope, fused device motion (attitude/rotation/gravity/userAcceleration), step counting, motion activity, headphone motion, and barometric altitude. Use when the user mentions Core Motion, CMMotionManager, accelerometer, gyroscope, device motion, attitude, pedometer, step count, CMPedometer, motion activity, CMHeadphoneMotionManager, AirPods head tracking, altimeter, CMAltimeter, or motion sensors on iOS.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple Core Motion docs via Context7 (/websites/developer_apple)
---

# Core Motion

Reading the device's motion and environmental sensors: raw accelerometer/gyro, fused device motion, steps, activity classification, headphone motion, and altitude. The deep API reference — every manager, the push/pull delivery models, attitude reference frames, permissions, and battery discipline — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `SENSOR` — `device-motion` (default; fused `CMDeviceMotion` — attitude, rotationRate, gravity, userAcceleration) · `raw-accel-gyro` (unprocessed streams; only when you need raw signal) · `pedometer` (steps/distance/floors via `CMPedometer`) · `activity` (`CMMotionActivityManager`) · `headphone` (AirPods motion, iOS 14+) · `altimeter` (relative altitude/pressure).
2. `DELIVERY` — `push-updates` (default; `start…Updates(to:withHandler:)` on a background `OperationQueue`, event-driven) · `pull-query` (`start…Updates()` then read the snapshot from a render/timer tick; or `queryPedometerData`/`queryActivityStarting` against the system cache).
3. `FREQUENCY` — the update interval (`…UpdateInterval`, in seconds). Pick the lowest rate the feature needs: UI/parallax 30–60 Hz, gestures ~20 Hz, games 60 Hz. Don't max it.

## When to use

Building or reviewing any feature that reads motion sensors: tilt/orientation UI, level/compass, shake or gesture detection, step counters and fitness tracking, activity-aware behavior, AirPods head tracking, or barometric altitude. If you only need device *heading*, prefer Core Location's heading API; Core Motion's north-referenced frames are heavier.

## Core rules

- One shared `CMMotionManager` for the whole app, held as a long-lived property. Never instantiate per view/request — multiple instances degrade delivery rate.
- Prefer fused `CMDeviceMotion` over raw accelerometer/gyro for any orientation/tilt/motion feature: gravity and userAcceleration are separated and attitude is drift-corrected.
- `CMPedometer`, `CMMotionActivityManager`, `CMAltimeter`, and `CMHeadphoneMotionManager` require `NSMotionUsageDescription` in Info.plist — the app **crashes** on first call without it. Plain `CMMotionManager` accel/gyro/device-motion needs no permission.
- Always gate on the relevant `is…Available()` check before starting (sensors vary by device; the Simulator reports almost nothing available).
- Always pair every `start…Updates` with a `stop…Updates` — on view dismissal and on backgrounding when the data isn't needed. Leaving sensors running is the #1 battery bug.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll just make a `CMMotionManager` wherever I need motion." | Apple says share **one** instance. Multiple managers fight over the hardware service and degrade your delivery rate. Hold a single long-lived one. |
| "Pedometer's a read, no permission needed." | `CMPedometer` / `CMMotionActivityManager` / `CMAltimeter` / `CMHeadphoneMotionManager` require `NSMotionUsageDescription`. Missing key = **hard crash** on first call, not a denied result. |
| "Accelerometer tells me the tilt." | Raw accelerometer = gravity + userAcceleration mashed together, plus noise. For orientation use `CMDeviceMotion` — it splits `gravity` from `userAcceleration` and gives a drift-corrected `attitude`. |
| "I'll leave updates running so it's ready when they come back." | A running motion service keeps sensors/coprocessor powered and drains battery. Stop on `onDisappear` and on background; restart on demand. |
| "Set the interval to the max so I never miss anything." | Higher rates burn battery and flood the handler; requesting above hardware max is silently clamped anyway. Pick the lowest rate the feature actually needs. |
| "Update my SwiftUI state right in the handler." | Push handlers run on the `OperationQueue` you passed, not main. Use a dedicated background queue and hop to `@MainActor` for UI — and don't put `OperationQueue.main` under a 60 Hz stream. |

## Verification gate

Before shipping motion code, confirm every line:

- [ ] Exactly one shared `CMMotionManager` instance, held as a long-lived property — none created per view/call.
- [ ] `NSMotionUsageDescription` is in Info.plist if using `CMPedometer`, `CMMotionActivityManager`, `CMAltimeter`, or `CMHeadphoneMotionManager`.
- [ ] Every service is gated on its `is…Available()` check before `start…Updates`.
- [ ] Orientation/tilt features use fused `CMDeviceMotion` (gravity / attitude / userAcceleration), not raw accelerometer.
- [ ] Every `start…Updates` has a matching `stop…Updates` on dismissal and on backgrounding.
- [ ] Update interval is set to the lowest rate the feature needs, before starting.
- [ ] Push handlers deliver on a background `OperationQueue`; UI mutations are marshaled to `@MainActor`.
- [ ] `authorizationStatus()` `.denied` is handled gracefully (no second prompt; explain + Settings deep-link).
- [ ] Tested on a physical device (Simulator lacks most sensors).

## Deep reference

`references/guide.md` — sensors overview, `CMMotionManager` setup + the singleton rule, intervals, push vs. pull delivery and the queue caveat, device motion (attitude reference frames, rotation, gravity, userAcceleration), pedometer + activity, headphone motion, altimeter, the full permissions matrix, battery/lifecycle pitfalls, and a quick-reference of key APIs. Load it for any concrete API question.

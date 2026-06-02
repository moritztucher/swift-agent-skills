# Core Motion — Deep Reference

Core Motion reports motion and environmental data from a device's hardware: accelerometer, gyroscope, magnetometer, barometer, and the system's fused/processed services (device motion, pedometer, activity classification, headphone motion). This guide covers the real APIs, the lifecycle and battery discipline they demand, and the permission rules that crash your app if ignored.

`import CoreMotion`

---

## 1. The sensors and the managers

Core Motion exposes raw sensor streams and higher-level *processed* services. Prefer the processed services — they fuse multiple sensors and remove bias/noise you'd otherwise fight by hand.

| Manager | What it gives you | Min iOS |
|---|---|---|
| `CMMotionManager` | Raw accelerometer, gyro, magnetometer **and** fused `CMDeviceMotion` | iOS 4+ |
| `CMPedometer` | Step count, distance, floors, pace, cadence (live + historical) | iOS 8+ |
| `CMMotionActivityManager` | Activity classification: walking / running / cycling / automotive / stationary | iOS 7+ |
| `CMAltimeter` | Relative altitude + barometric pressure | iOS 8+ |
| `CMHeadphoneMotionManager` | Device motion from AirPods (attitude/rotation), connect/disconnect | iOS 14+ |

Raw vs. processed:
- **Raw** (`CMAccelerometerData`, `CMGyroData`, `CMMagnetometerData`) — exactly what each sensor reads, including gravity baked into accelerometer values and gyro drift. Use only when you genuinely need unprocessed signal (e.g. logging, custom filters).
- **Processed** (`CMDeviceMotion`) — Core Motion's sensor-fusion output. Separates `gravity` from `userAcceleration`, gives a drift-corrected `attitude`, and a bias-free `rotationRate`. This is what almost every "which way is the device pointing / how is it moving" feature should use.

---

## 2. CMMotionManager — setup and the singleton rule

### Use ONE shared instance

Apple is explicit: **create a single `CMMotionManager` and share it.** Multiple instances "can affect the rate of data delivery to your app." Each instance fights the others over the underlying hardware service. Make it a long-lived property (a small `@Observable` service, an app-level singleton) — never `let m = CMMotionManager()` inside a view's `onAppear` or per request.

```swift
import CoreMotion

@Observable
final class MotionService {
    private let manager = CMMotionManager()        // the one and only
    private let queue = OperationQueue()            // dedicated delivery queue

    var attitude: CMAttitude?
}
```

### Availability and active flags

Each sensor has an `is…Available` check and an `is…Active` flag. Always gate on availability — gyro/magnetometer/barometer are not on every device, and the Simulator reports almost nothing as available.

```swift
manager.isAccelerometerAvailable
manager.isGyroAvailable
manager.isMagnetometerAvailable
manager.isDeviceMotionAvailable

manager.isAccelerometerActive   // currently delivering?
manager.isDeviceMotionActive
```

### Update intervals

Each service has its own interval property, in seconds. Set it *before* starting updates:

```swift
manager.accelerometerUpdateInterval = 1.0 / 60.0   // 60 Hz
manager.gyroUpdateInterval          = 1.0 / 60.0
manager.magnetometerUpdateInterval  = 1.0 / 10.0
manager.deviceMotionUpdateInterval  = 1.0 / 50.0   // 50 Hz
```

The maximum frequency is hardware dependent but usually at least 100 Hz. **If you request a rate higher than the hardware supports, Core Motion silently clamps to the maximum.** Don't max it out reflexively — higher rates burn battery and flood your handler. Pick the lowest rate that satisfies the feature (UI parallax: 30–60 Hz; a step/shake gesture: 20 Hz; a game: 60 Hz).

---

## 3. Two delivery models: push vs. pull

Every service supports two styles. Pick one per service; don't mix.

### Push — `start…Updates(to:withHandler:)`

You hand Core Motion an `OperationQueue` and a closure. The closure runs on that queue each time a sample arrives. This is the recommended model for continuous streams.

```swift
func startDeviceMotion() {
    guard manager.isDeviceMotionAvailable else { return }
    manager.deviceMotionUpdateInterval = 1.0 / 50.0

    manager.startDeviceMotionUpdates(to: queue) { [weak self] data, error in
        guard let data else { return }
        // Runs on `queue` (background). Hop to main for UI.
        Task { @MainActor in self?.attitude = data.attitude }
    }
}
```

### Pull — `start…Updates()` + read the latest sample

You start the service with no handler, then read the manager's snapshot property (`deviceMotion`, `accelerometerData`, `gyroData`, …) whenever you want — typically from a render loop, `Timer`, or `CADisplayLink`. Core Motion keeps only the latest sample.

```swift
func startPullStyle() {
    guard manager.isDeviceMotionAvailable else { return }
    manager.deviceMotionUpdateInterval = 1.0 / 50.0
    manager.startDeviceMotionUpdates()        // no handler

    timer = Timer(fire: Date(), interval: 1.0 / 50.0, repeats: true) { [weak self] _ in
        if let data = self?.manager.deviceMotion {
            // read data.attitude, data.userAcceleration, …
        }
    }
    RunLoop.current.add(timer!, forMode: .default)
}
```

Use **pull** when your app already has a render/update tick and wants the freshest value at the top of each frame (games, real-time graphics). Use **push** when you want every sample and event-driven processing.

### The delivery-queue caveat

The push handler runs on the `OperationQueue` you pass — **not** the main thread. Two practical rules:

1. **Don't pass `OperationQueue.main` for high-rate streams.** A 60 Hz handler on the main queue competes with UI work and can stutter scrolling/animation. Use a dedicated background queue, then dispatch the small UI-relevant slice to `@MainActor`.
2. **Never touch UIKit/SwiftUI state directly from the handler.** Marshal to the main actor.

A `maxConcurrentOperationCount = 1` serial queue keeps samples ordered:

```swift
let queue = OperationQueue()
queue.maxConcurrentOperationCount = 1
queue.qualityOfService = .userInitiated
```

---

## 4. Device motion — attitude, rotation, acceleration, gravity

`CMDeviceMotion` is the fused payload. Its four pillars:

| Property | Type | Meaning |
|---|---|---|
| `attitude` | `CMAttitude` | Orientation: `roll`, `pitch`, `yaw` (radians), plus `quaternion` and `rotationMatrix` |
| `rotationRate` | `CMRotationRate` | Bias-corrected angular velocity (rad/s) around x/y/z — cleaner than raw `CMGyroData` |
| `userAcceleration` | `CMAcceleration` | Acceleration from the *user*, gravity removed (G units) |
| `gravity` | `CMAcceleration` | The gravity vector alone (G units) — use to know "which way is down" |
| `magneticField` | `CMCalibratedMagneticField` | Calibrated field + an accuracy enum (needs a north-referenced frame) |

Key insight: raw accelerometer = `gravity + userAcceleration` mashed together. Device motion splits them for you. For tilt/orientation use `gravity` or `attitude`; for taps/shakes/throws use `userAcceleration`.

### Attitude reference frames

`startDeviceMotionUpdates(using:to:withHandler:)` takes a `CMAttitudeReferenceFrame`:

- `.xArbitraryZVertical` — Z is vertical (gravity), X arbitrary. No magnetometer needed. Default-ish, cheapest.
- `.xArbitraryCorrectedZVertical` — same but magnetometer-corrected to reduce yaw drift.
- `.xMagneticNorthZVertical` — X points to magnetic north. Needs magnetometer + calibration.
- `.xTrueNorthZVertical` — X points to true north. Needs magnetometer **and** location (Core Location running).

```swift
manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: queue) { data, _ in
    guard let a = data?.attitude else { return }
    let pitch = a.pitch, roll = a.roll, yaw = a.yaw   // radians
}
```

If you only need relative orientation (parallax, a level, steering), use `.xArbitraryZVertical` — requesting a north-referenced frame needlessly powers up the magnetometer (and possibly Core Location). `showsDeviceMovementDisplay = true` lets the system show the figure-8 calibration HUD when a magnetic frame needs calibration.

### Referencing one attitude against another

`CMAttitude.multiply(byInverseOf:)` rebases an attitude relative to a stored reference — e.g. capture the attitude at "start" and report rotation since:

```swift
if reference == nil { reference = data.attitude.copy() as? CMAttitude }
let relative = data.attitude
relative.multiply(byInverseOf: reference!)   // relative now == change since reference
```

---

## 5. Pedometer — CMPedometer

`CMPedometer` reads system-maintained pedestrian data. The system continuously logs steps in a background cache (the motion coprocessor does this even when your app is dead), so you can both **query history** and **stream live**.

### Permission and availability — CRITICAL

`CMPedometer` requires the **`NSMotionUsageDescription`** key in `Info.plist`. *If the key is absent, the system crashes your app when you call the API.* This is non-negotiable and applies to `CMPedometer`, `CMMotionActivityManager`, `CMSensorRecorder`, and `CMMovementDisorderManager` (NOT to plain `CMMotionManager` accelerometer/gyro/device-motion, which need no permission).

```swift
// Always gate on hardware support first.
guard CMPedometer.isStepCountingAvailable() else { return }

// Capability checks are per-feature:
CMPedometer.isDistanceAvailable()
CMPedometer.isFloorCountingAvailable()
CMPedometer.isPaceAvailable()
CMPedometer.isCadenceAvailable()

// Authorization status (does NOT request — first API call triggers the prompt):
switch CMPedometer.authorizationStatus() {
case .authorized:    break
case .denied:        break   // user said no — feature off, no prompt again
case .restricted:    break   // parental controls etc.
case .notDetermined: break   // prompt happens on first query/startUpdates
@unknown default:    break
}
```

### Query historical data

```swift
let pedometer = CMPedometer()
let start = Calendar.current.startOfDay(for: Date())

pedometer.queryPedometerData(from: start, to: Date()) { data, error in
    guard let data else { return }
    let steps = data.numberOfSteps.intValue
    let meters = data.distance?.doubleValue
    let floorsUp = data.floorsAscended?.intValue
    // handler runs on an arbitrary serial queue — hop to main for UI
}
```

### Live updates

```swift
pedometer.startUpdates(from: Date()) { data, error in
    guard let data else { return }
    Task { @MainActor in self.steps = data.numberOfSteps.intValue }
}
// later
pedometer.stopUpdates()
```

`CMPedometerData` fields (all `NSNumber`, several optional):
`numberOfSteps`, `distance` (m), `averageActivePace` / `currentPace` (s/m), `currentCadence` (steps/s), `floorsAscended`, `floorsDescended`, plus `startDate` / `endDate`.

### Pedometer events

`startEventUpdates(handler:)` delivers `CMPedometerEvent` with `.pause` / `.resume` types — useful for knowing when the user stops/starts walking without polling step deltas. Gate on `CMPedometer.isPedometerEventTrackingAvailable()`.

---

## 6. Motion activity — CMMotionActivityManager

Classifies what the user is doing. Same `NSMotionUsageDescription` + crash-on-missing-key rule as the pedometer.

```swift
guard CMMotionActivityManager.isActivityAvailable() else { return }
let activityManager = CMMotionActivityManager()

activityManager.startActivityUpdates(to: .main) { activity in
    guard let activity else { return }
    // Booleans (more than one can be true):
    _ = activity.walking
    _ = activity.running
    _ = activity.cycling
    _ = activity.automotive
    _ = activity.stationary
    _ = activity.unknown
    // confidence: .low / .medium / .high
    _ = activity.confidence
}
// activityManager.stopActivityUpdates()
```

Historical query: `queryActivityStarting(from:to:to:withHandler:)` returns `[CMMotionActivity]` from the background cache. `CMMotionActivityManager.authorizationStatus()` mirrors the pedometer's `CMAuthorizationStatus`.

---

## 7. Headphone motion — CMHeadphoneMotionManager (iOS 14+)

Device motion from motion-capable AirPods. Same `CMDeviceMotion` shape (attitude/rotation/userAcceleration/gravity) coming from the buds, useful for head tracking, spatial UI, fitness form.

### Permission and availability

Also requires `NSMotionUsageDescription` — *the system crashes your app when you start device-motion updates if the key is missing.* Check `isDeviceMotionAvailable` (false on a device with no compatible AirPods connected) before starting.

```swift
let headphones = CMHeadphoneMotionManager()
headphones.delegate = self   // optional, for connect/disconnect

guard headphones.isDeviceMotionAvailable else { return }

CMHeadphoneMotionManager.authorizationStatus()   // CMAuthorizationStatus

headphones.startDeviceMotionUpdates(to: .main) { motion, error in
    guard let motion else { return }
    let yaw = motion.attitude.yaw   // head turn
}
// headphones.stopDeviceMotionUpdates()
```

Properties mirror `CMMotionManager`: `isDeviceMotionAvailable`, `isDeviceMotionActive`, `startDeviceMotionUpdates()` (pull) and `startDeviceMotionUpdates(to:withHandler:)` (push).

### Connection status (iOS 17.4+ enhancement)

Adopt `CMHeadphoneMotionManagerDelegate` for `headphoneMotionManagerDidConnect` / `headphoneMotionManagerDidDisconnect`. `startConnectionStatusUpdates()` lets you observe connect/disconnect **outside** of an active motion session (and supports AirPods motion on watchOS).

```swift
extension MotionService: CMHeadphoneMotionManagerDelegate {
    func headphoneMotionManagerDidConnect(_ m: CMHeadphoneMotionManager) { /* … */ }
    func headphoneMotionManagerDidDisconnect(_ m: CMHeadphoneMotionManager) { /* … */ }
}
```

---

## 8. Altimeter — CMAltimeter (iOS 8+)

Relative altitude (change since you started) and raw barometric pressure. **No absolute altitude** — that's Core Location's job (GPS). Subject to `NSMotionUsageDescription` as well.

```swift
guard CMAltimeter.isRelativeAltitudeAvailable() else { return }   // needs a barometer
let altimeter = CMAltimeter()

CMAltimeter.authorizationStatus()   // CMAuthorizationStatus

altimeter.startRelativeAltitudeUpdates(to: .main) { data, error in
    guard let data else { return }
    let metersClimbed = data.relativeAltitude.doubleValue   // m, relative to start
    let kPa = data.pressure.doubleValue                     // kilopascals
}
// altimeter.stopRelativeAltitudeUpdates()
```

`relativeAltitude` is zero at the first sample and accumulates from there — store and diff it yourself if you want segment-level gains. iOS 15+ adds `startAbsoluteAltitudeUpdates(to:withHandler:)` (`CMAbsoluteAltitudeData`) on supported hardware, fusing barometer with other signals for an absolute estimate.

---

## 9. Permissions summary

| API | Needs `NSMotionUsageDescription`? | Crashes if missing? |
|---|---|---|
| `CMMotionManager` (accel/gyro/mag/device motion) | No | No |
| `CMPedometer` | **Yes** | **Yes** |
| `CMMotionActivityManager` | **Yes** | **Yes** |
| `CMAltimeter` | **Yes** | **Yes** |
| `CMHeadphoneMotionManager` | **Yes** | **Yes** (on start) |
| `CMSensorRecorder`, `CMMovementDisorderManager` | **Yes** | **Yes** |

The first call to a permission-gated API triggers the system prompt. There is no separate "request" call — `authorizationStatus()` only *reads* the current state. `.denied` means the prompt already happened and the user refused; you won't get a second prompt, so handle it gracefully (explain in-app, deep-link to Settings).

Info.plist string example:

```xml
<key>NSMotionUsageDescription</key>
<string>We use motion data to count your steps and track your workouts.</string>
```

---

## 10. Battery and lifecycle pitfalls

Motion services keep sensors and the motion coprocessor powered. The single biggest correctness/battery bug is **forgetting to stop**.

- **Always pair start/stop.** Stop updates in `onDisappear`, when the feature view is dismissed, and on `scenePhase == .background` if the data isn't needed in the background. A running `startDeviceMotionUpdates` with no consumer is pure battery waste.
- **Choose the lowest viable interval.** 100 Hz vs 20 Hz is a real power difference. Don't request 60 Hz for a UI that updates 10×/sec.
- **Prefer device motion to raw streams** when you need orientation — the fusion is "free" relative to running gyro + accelerometer + your own filter, and the result is drift-corrected.
- **One shared `CMMotionManager`.** Multiple instances degrade delivery rate (see §2).
- **Prefer north-free reference frames** (`.xArbitraryZVertical`) unless you truly need heading — magnetic/true-north frames spin up the magnetometer and possibly Core Location.
- **Don't block the delivery queue.** Heavy work in a push handler at 60 Hz backs up the queue. Keep the handler thin; offload heavy processing.
- **Historical queries don't need the service running.** `CMPedometer.queryPedometerData` and `queryActivityStarting` read the system's always-on cache, so you don't have to keep a live session open just to read the day's steps.
- **Simulator reports little as available.** Test sensors on a physical device; `is…Available()` will be `false` for most things in the Simulator.

---

## 11. Quick reference

```swift
// Shared manager
let manager = CMMotionManager()

// Availability
manager.isDeviceMotionAvailable / .isAccelerometerAvailable / .isGyroAvailable

// Intervals (set before start)
manager.deviceMotionUpdateInterval = 1.0 / 50.0

// Push (background queue) — recommended for streams
manager.startDeviceMotionUpdates(to: queue) { data, error in … }
manager.startAccelerometerUpdates(to: queue) { data, error in … }   // raw
manager.startGyroUpdates(to: queue) { data, error in … }            // raw

// Pull (read snapshot)
manager.startDeviceMotionUpdates()
let latest = manager.deviceMotion        // CMDeviceMotion?

// Stop (do it!)
manager.stopDeviceMotionUpdates()

// CMDeviceMotion payload
data.attitude.roll / .pitch / .yaw / .quaternion / .rotationMatrix
data.rotationRate.x/y/z
data.userAcceleration.x/y/z
data.gravity.x/y/z

// Pedometer
CMPedometer.isStepCountingAvailable()
CMPedometer.authorizationStatus()
pedometer.queryPedometerData(from:to:withHandler:)
pedometer.startUpdates(from:withHandler:) / stopUpdates()

// Activity
CMMotionActivityManager.isActivityAvailable()
activityManager.startActivityUpdates(to:withHandler:) / stopActivityUpdates()

// Headphones (iOS 14+)
headphones.isDeviceMotionAvailable
headphones.startDeviceMotionUpdates(to:withHandler:) / stopDeviceMotionUpdates()

// Altimeter (iOS 8+)
CMAltimeter.isRelativeAltitudeAvailable()
altimeter.startRelativeAltitudeUpdates(to:withHandler:) / stopRelativeAltitudeUpdates()
```

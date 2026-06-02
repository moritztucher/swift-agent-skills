# CoreHaptics Framework Guide

A comprehensive guide for implementing custom haptic feedback in iOS applications using Apple's CoreHaptics framework.

---

## Table of Contents

1. [Overview & Purpose](#overview--purpose)
2. [Setup & Device Capability Check](#setup--device-capability-check)
3. [Core Concepts](#core-concepts)
4. [Creating Haptic Patterns](#creating-haptic-patterns)
5. [Transient vs Continuous Haptics](#transient-vs-continuous-haptics)
6. [Audio-Haptic Synchronization](#audio-haptic-synchronization)
7. [AHAP File Format](#ahap-file-format)
8. [SwiftUI Integration Patterns](#swiftui-integration-patterns)
9. [iOS 18/26 Specific Features](#ios-1826-specific-features)
10. [Common Use Cases](#common-use-cases)
11. [Best Practices & Battery Considerations](#best-practices--battery-considerations)

---

## Overview & Purpose

CoreHaptics is an event-based audio and haptic rendering API introduced in iOS 13. It provides fine-grained control over the iPhone's Taptic Engine, allowing developers to create rich, custom haptic experiences that go beyond the simple predefined feedback types.

### Key Capabilities

- **Custom Haptic Patterns**: Create complex vibration patterns with precise timing
- **Audio-Haptic Synchronization**: Combine audio and haptic events for immersive experiences
- **Dynamic Control**: Modify haptic parameters in real-time during playback
- **AHAP File Support**: Load haptic patterns from external JSON-based files
- **Parameter Curves**: Create smooth transitions in intensity and sharpness over time

### When to Use CoreHaptics

| Use Case | Recommended Approach |
|----------|---------------------|
| Simple UI feedback (success, error) | `UIFeedbackGenerator` or SwiftUI `.sensoryFeedback()` |
| Custom game effects | `CHHapticEngine` |
| Synchronized audio-haptic experiences | `CHHapticEngine` |
| Complex haptic patterns | `CHHapticEngine` with AHAP files |
| Real-time parameter modulation | `CHHapticAdvancedPatternPlayer` |

### Supported Devices

CoreHaptics is available on iPhone 8 and later models equipped with the Taptic Engine. iPad does not support haptic feedback.

---

## Setup & Device Capability Check

### Import Framework

```swift
import CoreHaptics
```

### Check Device Capabilities

Always verify haptic support before creating the engine:

```swift
func supportsHaptics() -> Bool {
    CHHapticEngine.capabilitiesForHardware().supportsHaptics
}

func supportsAudio() -> Bool {
    CHHapticEngine.capabilitiesForHardware().supportsAudio
}
```

### HapticManager Implementation

Create a dedicated manager class to handle all haptic operations:

```swift
import CoreHaptics

@Observable
final class HapticManager {

    // MARK: - Properties

    private var engine: CHHapticEngine?
    private(set) var isAvailable = false

    // MARK: - Initialization

    init() {
        setupEngine()
    }

    // MARK: - Setup

    private func setupEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            isAvailable = false
            return
        }

        do {
            engine = try CHHapticEngine()
            configureEngineHandlers()
            isAvailable = true
        } catch {
            print("Failed to create haptic engine: \(error.localizedDescription)")
            isAvailable = false
        }
    }

    private func configureEngineHandlers() {
        // Handle engine stopping due to external factors
        engine?.stoppedHandler = { [weak self] reason in
            print("Haptic engine stopped: \(reason)")
            self?.isAvailable = false
        }

        // Handle engine reset after server failure
        engine?.resetHandler = { [weak self] in
            print("Haptic engine reset")
            Task { @MainActor in
                await self?.startEngine()
            }
        }
    }

    // MARK: - Engine Control

    func startEngine() async {
        guard let engine else { return }

        do {
            try await engine.start()
            isAvailable = true
        } catch {
            print("Failed to start haptic engine: \(error.localizedDescription)")
            isAvailable = false
        }
    }

    func stopEngine() {
        engine?.stop(completionHandler: nil)
        isAvailable = false
    }
}
```

### Engine Lifecycle Notes

- **Start**: Call `start()` before playing any patterns for lowest latency
- **Stop**: The engine auto-stops when idle if `autoShutdownEnabled` is true (default)
- **Reset**: The `resetHandler` is called after server failures; restart the engine there
- **Stopped**: The `stoppedHandler` notifies you when the engine stops externally

---

## Core Concepts

### CHHapticEngine

The central object that connects to the haptic server. Multiple instances can exist simultaneously.

```swift
let engine = try CHHapticEngine()

// Configure options
engine.playsHapticsOnly = true  // Disable audio output
engine.isMutedForAudio = false  // Allow audio events
engine.isMutedForHaptics = false  // Allow haptic events
engine.isAutoShutdownEnabled = true  // Auto-stop when idle
```

### CHHapticEvent

The fundamental building block of haptic patterns. Each event has:

- **Type**: What kind of haptic/audio to produce
- **Time**: When to start (relative to pattern start)
- **Duration**: How long it lasts (continuous events only)
- **Parameters**: Customization values (intensity, sharpness, etc.)

```swift
let event = CHHapticEvent(
    eventType: .hapticTransient,
    parameters: [
        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
    ],
    relativeTime: 0
)
```

### CHHapticPattern

A collection of events and optional parameter curves that define the complete haptic experience.

```swift
let pattern = try CHHapticPattern(events: [event1, event2], parameters: [])
```

### CHHapticPatternPlayer

Plays a pattern once. Fire-and-forget usage is supported.

```swift
let player = try engine.makePlayer(with: pattern)
try player.start(atTime: CHHapticTimeImmediate)
```

### CHHapticAdvancedPatternPlayer

Extended player with looping, seeking, pausing, and real-time parameter control.

```swift
let advancedPlayer = try engine.makeAdvancedPlayer(with: pattern)
advancedPlayer.loopEnabled = true
try advancedPlayer.start(atTime: CHHapticTimeImmediate)

// Later: pause, resume, seek
try advancedPlayer.pause(atTime: CHHapticTimeImmediate)
try advancedPlayer.resume(atTime: CHHapticTimeImmediate)
try advancedPlayer.seek(toOffset: 0.5)
```

---

## Creating Haptic Patterns

### Simple Transient Pattern

```swift
extension HapticManager {

    func playTransient(intensity: Float = 1.0, sharpness: Float = 0.5) async {
        guard isAvailable, let engine else { return }

        do {
            try await engine.start()

            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                ],
                relativeTime: 0
            )

            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to play transient haptic: \(error.localizedDescription)")
        }
    }
}
```

### Continuous Pattern

```swift
extension HapticManager {

    func playContinuous(
        intensity: Float = 0.8,
        sharpness: Float = 0.3,
        duration: TimeInterval = 1.0
    ) async {
        guard isAvailable, let engine else { return }

        do {
            try await engine.start()

            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                ],
                relativeTime: 0,
                duration: duration
            )

            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to play continuous haptic: \(error.localizedDescription)")
        }
    }
}
```

### Multi-Event Pattern

```swift
extension HapticManager {

    func playHeartbeat() async {
        guard isAvailable, let engine else { return }

        do {
            try await engine.start()

            var events: [CHHapticEvent] = []

            // Create heartbeat pattern: two quick beats followed by pause
            for beat in 0..<4 {
                let time = TimeInterval(beat) * 0.8

                // First beat (stronger)
                events.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                    ],
                    relativeTime: time
                ))

                // Second beat (softer)
                events.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                    ],
                    relativeTime: time + 0.15
                ))
            }

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to play heartbeat: \(error.localizedDescription)")
        }
    }
}
```

### Pattern with Parameter Curves

Parameter curves allow smooth transitions over time:

```swift
extension HapticManager {

    func playFadeOut(duration: TimeInterval = 2.0) async {
        guard isAvailable, let engine else { return }

        do {
            try await engine.start()

            // Continuous base event
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: 0,
                duration: duration
            )

            // Intensity curve: fade from 1.0 to 0.0
            let intensityCurve = CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: [
                    CHHapticParameterCurve.ControlPoint(relativeTime: 0, value: 0),
                    CHHapticParameterCurve.ControlPoint(relativeTime: duration, value: -1.0)
                ],
                relativeTime: 0
            )

            let pattern = try CHHapticPattern(
                events: [event],
                parameterCurves: [intensityCurve]
            )

            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to play fade out: \(error.localizedDescription)")
        }
    }
}
```

---

## Transient vs Continuous Haptics

### Transient Haptics

- **Instantaneous**: No duration, like a tap or click
- **Use Cases**: Button presses, selections, notifications
- **Feel**: Sharp, precise, momentary

```swift
// Sharp tap
CHHapticEvent(
    eventType: .hapticTransient,
    parameters: [
        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
    ],
    relativeTime: 0
)

// Soft thud
CHHapticEvent(
    eventType: .hapticTransient,
    parameters: [
        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.0)
    ],
    relativeTime: 0
)
```

### Continuous Haptics

- **Duration-based**: Runs for specified time (max 30 seconds)
- **Use Cases**: Engine rumble, charging indication, texture simulation
- **Feel**: Sustained vibration with customizable texture

```swift
// Engine rumble
CHHapticEvent(
    eventType: .hapticContinuous,
    parameters: [
        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
    ],
    relativeTime: 0,
    duration: 2.0
)

// Electric buzz
CHHapticEvent(
    eventType: .hapticContinuous,
    parameters: [
        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
    ],
    relativeTime: 0,
    duration: 0.5
)
```

### Parameter Reference

| Parameter | Range | Low Value | High Value |
|-----------|-------|-----------|------------|
| `hapticIntensity` | 0.0 - 1.0 | Weak | Strong |
| `hapticSharpness` | 0.0 - 1.0 | Rounded, organic | Precise, mechanical |

---

## Audio-Haptic Synchronization

CoreHaptics can play audio alongside haptics for immersive experiences.

### Event Types for Audio

| Event Type | Description |
|------------|-------------|
| `.audioContinuous` | Looped waveform with duration |
| `.audioCustom` | Custom audio file playback |

### Audio Parameters

| Parameter | Description |
|-----------|-------------|
| `.audioVolume` | Playback volume (0.0 - 1.0) |
| `.audioPitch` | Pitch adjustment (-1.0 to 1.0) |
| `.audioPan` | Stereo panning (-1.0 to 1.0) |
| `.decayTime` | Envelope decay duration |
| `.sustained` | Whether intensity sustains or decays |

### Register Custom Audio

```swift
extension HapticManager {

    func registerAudioResource(named filename: String, extension ext: String) async throws -> CHHapticAudioResourceID {
        guard let engine else {
            throw HapticError.engineUnavailable
        }

        guard let url = Bundle.main.url(forResource: filename, withExtension: ext) else {
            throw HapticError.resourceNotFound
        }

        return try engine.registerAudioResource(url)
    }
}

enum HapticError: LocalizedError {
    case engineUnavailable
    case resourceNotFound

    var errorDescription: String? {
        switch self {
        case .engineUnavailable:
            return "Haptic engine is not available"
        case .resourceNotFound:
            return "Audio resource not found"
        }
    }
}
```

### Play Synchronized Audio-Haptic Pattern

```swift
extension HapticManager {

    func playImpactWithSound(audioResourceID: CHHapticAudioResourceID) async {
        guard isAvailable, let engine else { return }

        do {
            try await engine.start()

            // Haptic event
            let hapticEvent = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                ],
                relativeTime: 0
            )

            // Audio event using registered resource
            let audioEvent = CHHapticEvent(
                audioResourceID: audioResourceID,
                parameters: [
                    CHHapticEventParameter(parameterID: .audioVolume, value: 0.8)
                ],
                relativeTime: 0
            )

            let pattern = try CHHapticPattern(events: [hapticEvent, audioEvent], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to play audio-haptic: \(error.localizedDescription)")
        }
    }

    func playContinuousWithAudio(duration: TimeInterval = 1.0) async {
        guard isAvailable, let engine else { return }

        do {
            try await engine.start()

            // Continuous haptic
            let hapticEvent = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                ],
                relativeTime: 0,
                duration: duration
            )

            // Continuous audio
            let audioEvent = CHHapticEvent(
                eventType: .audioContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .audioVolume, value: 0.5),
                    CHHapticEventParameter(parameterID: .audioPitch, value: 0.2),
                    CHHapticEventParameter(parameterID: .decayTime, value: 0.5),
                    CHHapticEventParameter(parameterID: .sustained, value: 0)
                ],
                relativeTime: 0,
                duration: duration
            )

            let pattern = try CHHapticPattern(events: [hapticEvent, audioEvent], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to play continuous audio-haptic: \(error.localizedDescription)")
        }
    }
}
```

---

## AHAP File Format

Apple Haptic Audio Pattern (AHAP) is a JSON-based format for defining haptic patterns externally.

### Basic Structure

```json
{
    "Version": 1.0,
    "Metadata": {
        "Project": "MyApp",
        "Created": "2024-01-15",
        "Description": "Custom haptic feedback pattern"
    },
    "Pattern": [
        {
            "Event": {
                "Time": 0.0,
                "EventType": "HapticTransient",
                "EventParameters": [
                    { "ParameterID": "HapticIntensity", "ParameterValue": 1.0 },
                    { "ParameterID": "HapticSharpness", "ParameterValue": 0.5 }
                ]
            }
        }
    ]
}
```

### Event Types in AHAP

| AHAP EventType | CHHapticEvent.EventType |
|----------------|-------------------------|
| `HapticTransient` | `.hapticTransient` |
| `HapticContinuous` | `.hapticContinuous` |
| `AudioContinuous` | `.audioContinuous` |
| `AudioCustom` | `.audioCustom` |

### Continuous Event with Duration

```json
{
    "Event": {
        "Time": 0.0,
        "EventType": "HapticContinuous",
        "EventDuration": 1.5,
        "EventParameters": [
            { "ParameterID": "HapticIntensity", "ParameterValue": 0.8 },
            { "ParameterID": "HapticSharpness", "ParameterValue": 0.3 }
        ]
    }
}
```

### Audio Event with Waveform Path

```json
{
    "Event": {
        "Time": 0.0,
        "EventType": "AudioCustom",
        "EventWaveformPath": "Sounds/impact.wav",
        "EventParameters": [
            { "ParameterID": "AudioVolume", "ParameterValue": 0.8 }
        ]
    }
}
```

### Parameter Curves in AHAP

```json
{
    "ParameterCurve": {
        "ParameterID": "HapticIntensityControl",
        "Time": 0.0,
        "ParameterCurveControlPoints": [
            { "Time": 0.0, "ParameterValue": 0.0 },
            { "Time": 0.5, "ParameterValue": 1.0 },
            { "Time": 1.0, "ParameterValue": 0.0 }
        ]
    }
}
```

### Complete AHAP Example

```json
{
    "Version": 1.0,
    "Metadata": {
        "Project": "GameApp",
        "Created": "2024-01-15",
        "Description": "Explosion impact haptic"
    },
    "Pattern": [
        {
            "Event": {
                "Time": 0.0,
                "EventType": "HapticTransient",
                "EventParameters": [
                    { "ParameterID": "HapticIntensity", "ParameterValue": 1.0 },
                    { "ParameterID": "HapticSharpness", "ParameterValue": 1.0 }
                ]
            }
        },
        {
            "Event": {
                "Time": 0.05,
                "EventType": "HapticContinuous",
                "EventDuration": 0.8,
                "EventParameters": [
                    { "ParameterID": "HapticIntensity", "ParameterValue": 0.6 },
                    { "ParameterID": "HapticSharpness", "ParameterValue": 0.2 }
                ]
            }
        },
        {
            "ParameterCurve": {
                "ParameterID": "HapticIntensityControl",
                "Time": 0.05,
                "ParameterCurveControlPoints": [
                    { "Time": 0.0, "ParameterValue": 0.0 },
                    { "Time": 0.8, "ParameterValue": -0.6 }
                ]
            }
        }
    ]
}
```

### Loading AHAP Files

```swift
extension HapticManager {

    func playPattern(from filename: String) async {
        guard isAvailable, let engine else { return }

        guard let url = Bundle.main.url(forResource: filename, withExtension: "ahap") else {
            print("AHAP file not found: \(filename)")
            return
        }

        do {
            try await engine.start()
            try engine.playPattern(from: url)
        } catch {
            print("Failed to play AHAP pattern: \(error.localizedDescription)")
        }
    }

    func playPattern(from data: Data) async {
        guard isAvailable, let engine else { return }

        do {
            try await engine.start()
            try engine.playPattern(from: data)
        } catch {
            print("Failed to play AHAP from data: \(error.localizedDescription)")
        }
    }
}
```

---

## SwiftUI Integration Patterns

### Using HapticManager with Environment

```swift
@main
struct MyApp: App {
    @State private var hapticManager = HapticManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(hapticManager)
        }
    }
}
```

### Basic SwiftUI View with Haptics

```swift
struct HapticDemoView: View {
    @Environment(HapticManager.self) private var hapticManager

    var body: some View {
        VStack(spacing: 20) {
            Button("Tap Haptic") {
                Task {
                    await hapticManager.playTransient()
                }
            }

            Button("Continuous Haptic") {
                Task {
                    await hapticManager.playContinuous(duration: 0.5)
                }
            }

            Button("Heartbeat") {
                Task {
                    await hapticManager.playHeartbeat()
                }
            }
        }
        .task {
            await hapticManager.startEngine()
        }
    }
}
```

### SwiftUI sensoryFeedback Modifier (iOS 17+)

For simple haptic feedback, use SwiftUI's built-in modifier:

```swift
struct FeedbackDemoView: View {
    @State private var counter = 0
    @State private var isComplete = false
    @State private var hasError = false

    var body: some View {
        VStack(spacing: 20) {
            // Trigger on value change
            Button("Increment: \(counter)") {
                counter += 1
            }
            .sensoryFeedback(.increase, trigger: counter)

            // Success feedback
            Button("Complete Task") {
                isComplete = true
            }
            .sensoryFeedback(.success, trigger: isComplete)

            // Error feedback
            Button("Trigger Error") {
                hasError = true
            }
            .sensoryFeedback(.error, trigger: hasError)

            // Impact with customization
            Button("Heavy Impact") {
                counter += 1
            }
            .sensoryFeedback(.impact(weight: .heavy, intensity: 1.0), trigger: counter)

            // Conditional feedback
            Button("Conditional") {
                counter += 1
            }
            .sensoryFeedback(.selection, trigger: counter) { oldValue, newValue in
                newValue > oldValue
            }
        }
    }
}
```

### Available SensoryFeedback Types

| Type | Use Case |
|------|----------|
| `.success` | Task completed successfully |
| `.warning` | Caution needed |
| `.error` | Error occurred |
| `.selection` | Item selected |
| `.increase` | Value increased |
| `.decrease` | Value decreased |
| `.start` | Activity started |
| `.stop` | Activity stopped |
| `.alignment` | Alignment snapping |
| `.levelChange` | Level or mode change |
| `.impact(weight:intensity:)` | Collision with weight |
| `.impact(flexibility:intensity:)` | Collision with flexibility |

### Dynamic Feedback Selection

```swift
struct DynamicFeedbackView: View {
    @State private var value = 50.0

    var body: some View {
        Slider(value: $value, in: 0...100)
            .sensoryFeedback(trigger: value) { oldValue, newValue in
                let change = abs(newValue - oldValue)
                if change > 10 {
                    return .impact(weight: .heavy, intensity: 1.0)
                } else if change > 5 {
                    return .impact(weight: .medium, intensity: 0.7)
                } else {
                    return .impact(weight: .light, intensity: 0.4)
                }
            }
    }
}
```

### Combining CoreHaptics with SwiftUI Gestures

```swift
struct GestureHapticsView: View {
    @Environment(HapticManager.self) private var hapticManager
    @State private var offset: CGSize = .zero
    @State private var isDragging = false

    var body: some View {
        Circle()
            .fill(.blue)
            .frame(width: 100, height: 100)
            .offset(offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        offset = value.translation

                        if !isDragging {
                            isDragging = true
                            Task {
                                await hapticManager.playTransient(intensity: 0.5, sharpness: 0.3)
                            }
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                        withAnimation(.spring()) {
                            offset = .zero
                        }
                        Task {
                            await hapticManager.playTransient(intensity: 1.0, sharpness: 0.8)
                        }
                    }
            )
    }
}
```

---

## iOS 18/26 Specific Features

### iOS 17+ sensoryFeedback

The `.sensoryFeedback()` modifier was introduced in iOS 17 and remains the recommended approach for simple haptic feedback in SwiftUI applications.

### CoreHaptics Stability

CoreHaptics has remained stable since its introduction in iOS 13. The core API (`CHHapticEngine`, `CHHapticPattern`, `CHHapticEvent`) has not changed significantly in iOS 18 or iOS 26.

### Best Practices for iOS 18+

1. **Prefer SwiftUI sensoryFeedback** for simple feedback scenarios
2. **Use CoreHaptics** only when you need:
   - Custom patterns
   - Audio-haptic synchronization
   - Real-time parameter modulation
   - AHAP file playback

### Accessibility Considerations

Always respect user preferences for reduced motion:

```swift
struct AccessibleHapticsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(HapticManager.self) private var hapticManager
    @State private var counter = 0

    var body: some View {
        Button("Action") {
            counter += 1

            if !reduceMotion {
                Task {
                    await hapticManager.playTransient()
                }
            }
        }
    }
}
```

---

## Common Use Cases

### Gaming - Collision Impact

```swift
extension HapticManager {

    func playCollision(intensity: Float) async {
        guard isAvailable else { return }

        let clampedIntensity = min(max(intensity, 0), 1)

        await playTransient(
            intensity: clampedIntensity,
            sharpness: 0.8 * clampedIntensity
        )
    }

    func playExplosion() async {
        guard isAvailable, let engine else { return }

        do {
            try await engine.start()

            var events: [CHHapticEvent] = []

            // Initial impact
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                ],
                relativeTime: 0
            ))

            // Rumble
            events.append(CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                ],
                relativeTime: 0.03,
                duration: 0.5
            ))

            // Debris impacts
            for i in 1...5 {
                let time = 0.1 + Double(i) * 0.08
                let decay = 1.0 - (Float(i) * 0.15)

                events.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: decay),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                    ],
                    relativeTime: time
                ))
            }

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to play explosion: \(error.localizedDescription)")
        }
    }
}
```

### UI Feedback - Success/Error

```swift
extension HapticManager {

    func playSuccess() async {
        guard isAvailable, let engine else { return }

        do {
            try await engine.start()

            let events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                    ],
                    relativeTime: 0.1
                )
            ]

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to play success: \(error.localizedDescription)")
        }
    }

    func playError() async {
        guard isAvailable, let engine else { return }

        do {
            try await engine.start()

            var events: [CHHapticEvent] = []

            // Three short buzzes
            for i in 0..<3 {
                events.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                    ],
                    relativeTime: Double(i) * 0.1
                ))
            }

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to play error: \(error.localizedDescription)")
        }
    }
}
```

### Progress Indication

```swift
extension HapticManager {

    func playProgressTick(progress: Double) async {
        guard isAvailable else { return }

        let intensity = Float(0.3 + progress * 0.7)
        let sharpness = Float(0.2 + progress * 0.6)

        await playTransient(intensity: intensity, sharpness: sharpness)
    }

    func playProgressComplete() async {
        guard isAvailable, let engine else { return }

        do {
            try await engine.start()

            // Rising pattern
            var events: [CHHapticEvent] = []

            for i in 0..<4 {
                let time = Double(i) * 0.08
                let intensity = 0.4 + Float(i) * 0.2

                events.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                    ],
                    relativeTime: time
                ))
            }

            // Final strong tap
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                ],
                relativeTime: 0.35
            ))

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to play progress complete: \(error.localizedDescription)")
        }
    }
}
```

### Texture Simulation

```swift
extension HapticManager {

    private var texturePlayer: CHHapticAdvancedPatternPlayer?

    func startTextureSimulation(roughness: Float = 0.5) async {
        guard isAvailable, let engine else { return }

        do {
            try await engine.start()

            // Create repeating texture pattern
            var events: [CHHapticEvent] = []
            let eventCount = 10
            let interval = 0.05

            for i in 0..<eventCount {
                let randomIntensity = 0.2 + roughness * Float.random(in: 0...0.6)

                events.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: randomIntensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: roughness)
                    ],
                    relativeTime: Double(i) * interval
                ))
            }

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makeAdvancedPlayer(with: pattern)
            player.loopEnabled = true
            try player.start(atTime: CHHapticTimeImmediate)

            // Store reference (in actual implementation, use a property)
            // self.texturePlayer = player
        } catch {
            print("Failed to start texture simulation: \(error.localizedDescription)")
        }
    }
}
```

---

## Best Practices & Battery Considerations

### Engine Management

```swift
// DO: Create engine once and reuse
class AppHaptics {
    static let shared = HapticManager()
}

// DON'T: Create new engine for each haptic
func badExample() {
    let engine = try? CHHapticEngine() // Avoid this pattern
    // ...
}
```

### Battery Optimization

1. **Use Auto-Shutdown**: Let the engine stop when idle

```swift
engine.isAutoShutdownEnabled = true
```

2. **Minimize Continuous Haptics**: Limit duration and frequency

```swift
// Limit continuous haptics to 30 seconds max
let duration = min(requestedDuration, 30.0)
```

3. **Batch Related Haptics**: Combine events in single patterns

```swift
// DO: Single pattern with multiple events
let pattern = try CHHapticPattern(events: [event1, event2, event3], parameters: [])

// DON'T: Multiple separate patterns
try player1.start(atTime: 0)
try player2.start(atTime: 0.1)
try player3.start(atTime: 0.2)
```

### Error Handling

```swift
extension HapticManager {

    func safePlay(_ action: @escaping () async throws -> Void) async {
        do {
            try await action()
        } catch let error as CHHapticEngine.Error {
            handleHapticError(error)
        } catch {
            print("Unexpected haptic error: \(error.localizedDescription)")
        }
    }

    private func handleHapticError(_ error: CHHapticEngine.Error) {
        switch error {
        case .engineNotRunning:
            Task {
                await startEngine()
            }
        case .notSupported:
            isAvailable = false
        case .serverInitFailed, .serverInterrupted:
            // Engine will call resetHandler
            break
        default:
            print("Haptic error: \(error.localizedDescription)")
        }
    }
}
```

### User Preferences

```swift
@Observable
final class HapticManager {
    var isEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: "hapticsEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "hapticsEnabled")
        }
    }

    func playIfEnabled(_ action: @escaping () async -> Void) async {
        guard isEnabled, isAvailable else { return }
        await action()
    }
}
```

### Testing Considerations

- **Simulator**: Haptics do not work in the iOS Simulator
- **Device Testing**: Always test on physical devices
- **Accessibility**: Test with Reduce Motion enabled

### Performance Tips

1. **Pre-create Players**: For frequently used patterns, create players in advance

```swift
private var impactPlayer: CHHapticPatternPlayer?

func prepareImpactPlayer() async throws {
    guard let engine else { return }

    let event = CHHapticEvent(
        eventType: .hapticTransient,
        parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
        ],
        relativeTime: 0
    )

    let pattern = try CHHapticPattern(events: [event], parameters: [])
    impactPlayer = try engine.makePlayer(with: pattern)
}
```

2. **Use CHHapticTimeImmediate**: For lowest latency playback

```swift
try player.start(atTime: CHHapticTimeImmediate)
```

3. **Avoid Blocking Main Thread**: Use async/await patterns

```swift
// DO: Use Task for haptic operations
Task {
    await hapticManager.playTransient()
}

// DON'T: Call synchronously on main thread
// hapticManager.playTransientSync() // Avoid this
```

---

## Summary

CoreHaptics provides powerful control over haptic feedback in iOS applications. Key takeaways:

1. **Use SwiftUI `.sensoryFeedback()`** for simple UI feedback (iOS 17+)
2. **Use CoreHaptics** for complex patterns, audio sync, and real-time control
3. **Check device capability** before creating the engine
4. **Handle engine lifecycle** with `stoppedHandler` and `resetHandler`
5. **Use AHAP files** to separate haptic content from code
6. **Respect user preferences** and accessibility settings
7. **Optimize for battery** by using auto-shutdown and batching events

---

## References

- [Core Haptics - Apple Developer Documentation](https://developer.apple.com/documentation/corehaptics/)
- [CHHapticEngine - Apple Developer Documentation](https://developer.apple.com/documentation/corehaptics/chhapticengine)
- [CHHapticPattern - Apple Developer Documentation](https://developer.apple.com/documentation/corehaptics/chhapticpattern)
- [Representing haptic patterns in AHAP files - Apple Developer Documentation](https://developer.apple.com/documentation/corehaptics/representing-haptic-patterns-in-ahap-files)
- [Playing a Custom Haptic Pattern from a File - Apple Developer Documentation](https://developer.apple.com/documentation/corehaptics/playing-a-custom-haptic-pattern-from-a-file)
- [Introducing Core Haptics - WWDC19](https://developer.apple.com/videos/play/wwdc2019/520/)

# AlarmKit Framework Guide for iOS 26

A comprehensive guide to Apple's AlarmKit framework introduced in iOS 26, enabling developers to create system-level alarms and countdown timers with Live Activity support.

---

## Table of Contents

1. [Overview](#overview)
2. [Key Features](#key-features)
3. [Core Components](#core-components)
4. [Project Setup](#project-setup)
5. [Authorization](#authorization)
6. [Scheduling Alarms](#scheduling-alarms)
7. [Countdown Timers](#countdown-timers)
8. [Live Activities Integration](#live-activities-integration)
9. [Alarm Lifecycle Management](#alarm-lifecycle-management)
10. [Custom Actions with App Intents](#custom-actions-with-app-intents)
11. [Custom Sounds](#custom-sounds)
12. [Observing Alarm Updates](#observing-alarm-updates)
13. [Best Practices](#best-practices)
14. [Complete Example](#complete-example)

---

## Overview

AlarmKit is a new framework introduced in iOS 26 that allows developers to create alarms and countdown timers with system-level privileges. Unlike standard notifications that can be silenced or ignored, alarms built with AlarmKit:

- **Break through Silent Mode** - Alarms sound even when the device is muted
- **Override Focus Settings** - Critical time-based events reach users regardless of Focus mode
- **Integrate with System UI** - Appear on Lock Screen, Dynamic Island, StandBy mode, and Apple Watch
- **Support Live Activities** - Display countdown interfaces that update in real-time

### Ideal Use Cases

- Wake-up alarms
- Cooking/food timers
- Medication reminders
- Workout intervals
- Meeting countdowns
- Any time-critical alerts requiring guaranteed delivery

**Note:** AlarmKit is NOT intended to replace general notifications. Use it only for scenarios requiring time-critical prominence.

---

## Key Features

| Feature | Description |
|---------|-------------|
| Schedule-based Alarms | Set alarms for specific dates and times |
| Countdown Timers | Create interval-based timers with visual countdown |
| Recurring Alarms | Support for daily, weekly, or custom recurrence patterns |
| Snooze Support | Built-in snooze functionality with configurable duration |
| Live Activities | Real-time countdown UI on Lock Screen and Dynamic Island |
| Custom Actions | App Intents integration for custom button actions |
| Custom Sounds | Support for custom alarm sounds |

---

## Core Components

### AlarmManager

The central singleton coordinator for all alarm operations:

```swift
import AlarmKit

// Access the shared instance
let alarmManager = AlarmManager.shared
```

**Key Properties:**
- `authorizationState` - Current authorization status
- `authorizationUpdates` - AsyncSequence for authorization changes
- `alarmUpdates` - AsyncSequence for alarm state changes
- `alarms` - Array of currently scheduled alarms

**Key Methods:**
- `requestAuthorization()` - Request permission to schedule alarms
- `schedule(id:configuration:)` - Schedule a new alarm
- `cancel(id:)` - Cancel an alarm
- `stop(id:)` - Stop an active alarm
- `pause(id:)` - Pause a countdown
- `resume(id:)` - Resume a paused countdown
- `countdown(id:)` - Transition alarm to countdown state

### AlarmConfiguration

Defines the behavior and presentation of alarms:

```swift
typealias AlarmConfiguration = AlarmManager.AlarmConfiguration<YourMetadata>

let configuration = AlarmConfiguration(
    countdownDuration: duration,
    schedule: schedule,
    attributes: attributes,
    secondaryIntent: snoozeIntent,
    sound: .default
)
```

### AlarmAttributes

A generic struct that configures alarm visual presentation:

```swift
let attributes = AlarmAttributes<YourMetadata>(
    presentation: presentation,
    metadata: YourMetadata(),
    tintColor: .blue
)
```

### AlarmPresentation

Controls how alarms appear in different states:

```swift
let presentation = AlarmPresentation(
    alert: alertPresentation,
    countdown: countdownPresentation,
    paused: pausedPresentation
)
```

### AlarmButton

Defines button appearance:

```swift
let stopButton = AlarmButton(
    text: "Dismiss",
    textColor: .white,
    systemImageName: "stop.circle"
)
```

### AlarmMetadata Protocol

Custom data to associate with alarms:

```swift
// Simple empty metadata
nonisolated struct EmptyMetadata: AlarmMetadata {}

// Custom metadata with data
nonisolated struct CookingMetadata: AlarmMetadata {
    var recipeName: String
    var cookingMethod: String
}
```

**Important:** In Xcode 26 projects where types are MainActor-isolated by default, mark your metadata type as `nonisolated` to satisfy protocol conformance.

---

## Project Setup

### 1. Add Info.plist Entry

Add the `NSAlarmKitUsageDescription` key to your Info.plist:

```xml
<key>NSAlarmKitUsageDescription</key>
<string>This app needs alarm permissions to schedule reminders and timers.</string>
```

### 2. Import Framework

```swift
import AlarmKit
```

### 3. Widget Extension (Required for Countdown Features)

For countdown functionality, you must create a Widget Extension to display Live Activities. See [Live Activities Integration](#live-activities-integration).

---

## Authorization

### Request Authorization

```swift
import AlarmKit

@Observable
class AlarmViewModel {
    private let alarmManager = AlarmManager.shared

    func requestPermission() async -> Bool {
        switch alarmManager.authorizationState {
        case .notDetermined:
            do {
                let state = try await alarmManager.requestAuthorization()
                return state == .authorized
            } catch {
                print("Authorization failed: \(error)")
                return false
            }
        case .authorized:
            return true
        case .denied:
            // Guide user to Settings to enable
            return false
        @unknown default:
            return false
        }
    }
}
```

### Authorization States

| State | Description |
|-------|-------------|
| `.notDetermined` | User hasn't been asked yet |
| `.authorized` | User granted permission |
| `.denied` | User denied permission |

### Observe Authorization Changes

```swift
func observeAuthorizationUpdates() {
    Task {
        for await state in alarmManager.authorizationUpdates {
            switch state {
            case .authorized:
                print("Alarms authorized")
            case .denied:
                print("Alarms denied")
            case .notDetermined:
                print("Authorization not determined")
            @unknown default:
                break
            }
        }
    }
}
```

---

## Scheduling Alarms

### Basic Alarm (No Countdown)

```swift
import AlarmKit

func scheduleBasicAlarm() async throws {
    let id = UUID()

    // Create alert presentation
    let alert = AlarmPresentation.Alert(
        title: "Wake Up!",
        stopButton: AlarmButton(
            text: "Dismiss",
            textColor: .white,
            systemImageName: "checkmark.circle"
        )
    )

    // Create attributes
    let attributes = AlarmAttributes<EmptyMetadata>(
        presentation: AlarmPresentation(alert: alert),
        tintColor: .blue
    )

    // Schedule for 7:30 AM tomorrow
    let schedule = Alarm.Schedule.fixed(
        Date().addingTimeInterval(86400).settingTime(hour: 7, minute: 30)
    )

    let configuration = AlarmManager.AlarmConfiguration<EmptyMetadata>(
        schedule: schedule,
        attributes: attributes
    )

    let alarm = try await AlarmManager.shared.schedule(
        id: id,
        configuration: configuration
    )

    print("Alarm scheduled: \(alarm.id)")
}
```

### Recurring Weekday Alarm

```swift
func scheduleMorningAlarm() async throws {
    let id = UUID()

    // Set time: 7:30 AM
    let time = Alarm.Schedule.Relative.Time(hour: 7, minute: 30)

    // Repeat Monday through Friday
    let recurrence = Alarm.Schedule.Relative.Recurrence.weekly([
        .monday, .tuesday, .wednesday, .thursday, .friday
    ])

    let schedule = Alarm.Schedule.relative(
        Alarm.Schedule.Relative(time: time, repeats: recurrence)
    )

    // Create snooze button
    let snoozeButton = AlarmButton(
        text: "Snooze",
        textColor: .white,
        systemImageName: "zzz"
    )

    let alert = AlarmPresentation.Alert(
        title: "Good Morning!",
        stopButton: AlarmButton(
            text: "I'm Awake",
            textColor: .white,
            systemImageName: "sun.max"
        ),
        secondaryButton: snoozeButton,
        secondaryButtonBehavior: .countdown  // Enables snooze
    )

    // 5-minute snooze duration
    let duration = Alarm.CountdownDuration(
        preAlert: nil,
        postAlert: TimeInterval(5 * 60)
    )

    let attributes = AlarmAttributes<EmptyMetadata>(
        presentation: AlarmPresentation(alert: alert),
        tintColor: .orange
    )

    let configuration = AlarmManager.AlarmConfiguration<EmptyMetadata>(
        countdownDuration: duration,
        schedule: schedule,
        attributes: attributes
    )

    try await AlarmManager.shared.schedule(id: id, configuration: configuration)
}
```

### Schedule Types

#### Fixed Schedule (Absolute Time)

```swift
// Schedule for a specific date and time
let schedule = Alarm.Schedule.fixed(specificDate)
```

#### Relative Schedule (Timezone-Adaptive, Recurring)

```swift
// Daily at 8:00 AM
let schedule = Alarm.Schedule.relative(
    Alarm.Schedule.Relative(
        time: Alarm.Schedule.Relative.Time(hour: 8, minute: 0),
        repeats: .daily
    )
)

// Specific weekdays
let schedule = Alarm.Schedule.relative(
    Alarm.Schedule.Relative(
        time: Alarm.Schedule.Relative.Time(hour: 8, minute: 0),
        repeats: .weekly([.monday, .wednesday, .friday])
    )
)
```

---

## Countdown Timers

Countdown timers display a visual countdown interface and require a Widget Extension for Live Activities.

### Basic Timer

```swift
func scheduleTimer(duration: TimeInterval) async throws {
    let id = UUID()

    let alert = AlarmPresentation.Alert(
        title: "Timer Complete!",
        stopButton: AlarmButton(
            text: "Done",
            textColor: .white,
            systemImageName: "checkmark"
        )
    )

    let attributes = AlarmAttributes<EmptyMetadata>(
        presentation: AlarmPresentation(alert: alert),
        tintColor: .green
    )

    // Use .timer convenience method
    let alarm = try await AlarmManager.shared.schedule(
        id: id,
        configuration: .timer(duration: duration, attributes: attributes)
    )

    print("Timer scheduled for \(duration) seconds")
}
```

### Timer with Pause/Resume Support

```swift
func scheduleTimerWithPauseSupport() async throws {
    let id = UUID()

    // Alert state (when timer completes)
    let alert = AlarmPresentation.Alert(
        title: "Time's Up!",
        stopButton: AlarmButton(
            text: "Stop",
            textColor: .white,
            systemImageName: "stop.circle"
        ),
        secondaryButton: AlarmButton(
            text: "Repeat",
            textColor: .white,
            systemImageName: "repeat"
        ),
        secondaryButtonBehavior: .countdown
    )

    // Countdown state (while timer is running)
    let countdown = AlarmPresentation.Countdown(
        title: "Cooking Timer",
        pauseButton: AlarmButton(
            text: "Pause",
            textColor: .yellow,
            systemImageName: "pause.circle"
        )
    )

    // Paused state
    let paused = AlarmPresentation.Paused(
        title: "Timer Paused",
        resumeButton: AlarmButton(
            text: "Resume",
            textColor: .green,
            systemImageName: "play.circle"
        )
    )

    let presentation = AlarmPresentation(
        alert: alert,
        countdown: countdown,
        paused: paused
    )

    let attributes = AlarmAttributes<CookingMetadata>(
        presentation: presentation,
        metadata: CookingMetadata(recipeName: "Pizza", cookingMethod: "Oven"),
        tintColor: .red
    )

    // 10 minutes with 5-minute repeat option
    let duration = Alarm.CountdownDuration(
        preAlert: TimeInterval(10 * 60),
        postAlert: TimeInterval(5 * 60)
    )

    let configuration = AlarmManager.AlarmConfiguration<CookingMetadata>(
        countdownDuration: duration,
        attributes: attributes
    )

    let alarm = try await AlarmManager.shared.schedule(
        id: id,
        configuration: configuration
    )

    // Start the countdown immediately
    try await AlarmManager.shared.countdown(id: id)
}
```

### Countdown Duration

The `Alarm.CountdownDuration` uses a two-phase approach:

| Phase | Description |
|-------|-------------|
| `preAlert` | Duration before the alarm triggers (countdown UI) |
| `postAlert` | Duration for snooze/repeat functionality |

```swift
// 5-minute countdown, 2-minute snooze
let duration = Alarm.CountdownDuration(
    preAlert: TimeInterval(5 * 60),
    postAlert: TimeInterval(2 * 60)
)
```

---

## Live Activities Integration

For countdown functionality, you MUST implement a Widget Extension with Live Activities.

### Widget Extension Setup

1. Add a new target: File > New > Target > Widget Extension
2. Check "Include Live Activity"

### Basic Live Activity Implementation

```swift
import WidgetKit
import SwiftUI
import AlarmKit

@main
struct TimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        TimerLiveActivity()
    }
}

struct TimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<TimerMetadata>.self) { context in
            // Lock Screen / Banner UI
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded regions
                DynamicIslandExpandedRegion(.leading) {
                    LeadingExpandedView(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TrailingExpandedView(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    CenterExpandedView(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    BottomExpandedView(context: context)
                }
            } compactLeading: {
                CompactLeadingView(context: context)
            } compactTrailing: {
                CompactTrailingView(context: context)
            } minimal: {
                MinimalView(context: context)
            }
        }
    }
}
```

### Handling Alarm States in Live Activity

```swift
struct LockScreenView: View {
    let context: ActivityViewContext<AlarmAttributes<TimerMetadata>>

    var body: some View {
        switch context.state.mode {
        case .countdown:
            CountdownView(context: context)
        case .paused:
            PausedView(context: context)
        case .alert:
            AlertView(context: context)
        }
    }
}

struct CountdownView: View {
    let context: ActivityViewContext<AlarmAttributes<TimerMetadata>>

    var body: some View {
        VStack {
            Text(context.attributes.presentation.countdown?.title ?? "Timer")
                .font(.headline)

            // Display remaining time
            if let fireDate = context.state.fireDate {
                Text(fireDate, style: .timer)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
            }
        }
        .padding()
    }
}

struct PausedView: View {
    let context: ActivityViewContext<AlarmAttributes<TimerMetadata>>

    var body: some View {
        VStack {
            Text(context.attributes.presentation.paused?.title ?? "Paused")
                .font(.headline)

            Text("Timer is paused")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

struct AlertView: View {
    let context: ActivityViewContext<AlarmAttributes<TimerMetadata>>

    var body: some View {
        VStack {
            Text(context.attributes.presentation.alert.title)
                .font(.title)
                .fontWeight(.bold)
        }
        .padding()
    }
}
```

### AlarmPresentationState Properties

The `context.state` provides:

| Property | Description |
|----------|-------------|
| `mode` | Current state: `.countdown`, `.paused`, or `.alert` |
| `fireDate` | When the alarm will fire |
| `startDate` | When the countdown started |
| `previouslyElapsedDuration` | Time elapsed before pause |
| `totalCountdownDuration` | Total countdown duration |

---

## Alarm Lifecycle Management

### Cancel an Alarm

```swift
func cancelAlarm(id: UUID) async throws {
    try await AlarmManager.shared.cancel(id: id)
}
```

### Stop an Active Alarm

```swift
func stopAlarm(id: UUID) async throws {
    try await AlarmManager.shared.stop(id: id)
}
```

### Pause a Countdown

```swift
func pauseCountdown(id: UUID) async throws {
    try await AlarmManager.shared.pause(id: id)
}
```

### Resume a Paused Countdown

```swift
func resumeCountdown(id: UUID) async throws {
    try await AlarmManager.shared.resume(id: id)
}
```

### Start Countdown (Transition to Countdown State)

```swift
func startCountdown(id: UUID) async throws {
    try await AlarmManager.shared.countdown(id: id)
}
```

---

## Custom Actions with App Intents

AlarmKit integrates with App Intents for custom button actions.

### Create a Custom Intent

```swift
import AppIntents
import AlarmKit

struct OpenTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Timer"
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Alarm ID")
    var alarmId: String

    init() {}

    init(alarmId: UUID) {
        self.alarmId = alarmId.uuidString
    }

    func perform() async throws -> some IntentResult {
        // Handle the action - open specific screen, log event, etc.
        print("Opening timer: \(alarmId)")
        return .result()
    }
}
```

### Use Custom Intent as Secondary Button

```swift
func scheduleAlarmWithCustomAction() async throws {
    let id = UUID()

    let openIntent = OpenTimerIntent(alarmId: id)

    let alert = AlarmPresentation.Alert(
        title: "Timer Done!",
        stopButton: AlarmButton(
            text: "Stop",
            textColor: .white,
            systemImageName: "stop.circle"
        ),
        secondaryButton: AlarmButton(
            text: "Open App",
            textColor: .white,
            systemImageName: "arrow.up.right"
        ),
        secondaryButtonBehavior: .custom  // Use custom for App Intent
    )

    let attributes = AlarmAttributes<EmptyMetadata>(
        presentation: AlarmPresentation(alert: alert),
        tintColor: .purple
    )

    let configuration = AlarmManager.AlarmConfiguration<EmptyMetadata>(
        countdownDuration: Alarm.CountdownDuration(preAlert: 60, postAlert: nil),
        attributes: attributes,
        secondaryIntent: openIntent  // Attach the intent
    )

    try await AlarmManager.shared.schedule(id: id, configuration: configuration)
}
```

### Secondary Button Behaviors

| Behavior | Description |
|----------|-------------|
| `.countdown` | Transitions to countdown state (snooze/repeat) |
| `.custom` | Executes the attached App Intent |

---

## Custom Sounds

### Using Custom Alarm Sounds

Custom sounds must be placed in:
- App's main bundle
- `Library/Sounds` folder

```swift
let configuration = AlarmManager.AlarmConfiguration<EmptyMetadata>(
    countdownDuration: duration,
    attributes: attributes,
    sound: .named("custom-alarm-sound")  // Without file extension
)
```

### Sound Requirements

- Supported formats: CAF, AIFF, WAV, MP3
- Maximum duration: 30 seconds recommended
- Include in app bundle or Library/Sounds

---

## Observing Alarm Updates

### Monitor All Alarms

```swift
@Observable
class AlarmViewModel {
    private let alarmManager = AlarmManager.shared
    var alarms: [Alarm] = []

    func observeAlarms() {
        Task {
            for await updatedAlarms in alarmManager.alarmUpdates {
                await MainActor.run {
                    self.alarms = updatedAlarms
                }
            }
        }
    }
}
```

### Get Current Alarms

```swift
let currentAlarms = AlarmManager.shared.alarms
```

---

## Best Practices

### Design Guidelines

1. **Clear Alert Titles** - Use descriptive titles that explain what the alarm is for
2. **Explicit Button Labels** - Make button actions clear (e.g., "Dismiss" vs "Stop")
3. **Thoughtful Dynamic Island** - Prioritize essential countdown information
4. **Test Across States** - Test countdown, paused, and alert states thoroughly

### Implementation Guidelines

1. **Request Authorization Early** - Ask for permission at an appropriate time, not on first launch
2. **Handle Denied State** - Provide guidance to enable alarms in Settings
3. **Use Unique IDs** - Always use unique identifiers to track alarms
4. **Clean Up Alarms** - Cancel alarms that are no longer needed
5. **Test on Real Devices** - Live Activities and alarms behave differently on simulator

### Performance Guidelines

1. **Don't Over-Schedule** - Limit the number of concurrent alarms
2. **Use Relative Schedules** - For recurring alarms, use relative schedules for timezone adaptability
3. **Implement Live Activities** - Always implement Live Activities for countdown features

### Accessibility

1. **Provide Clear Audio Cues** - Ensure alarm sounds are distinct
2. **Support VoiceOver** - Label all interactive elements in Live Activities
3. **Consider Visual Alternatives** - Provide visual feedback alongside audio

---

## Complete Example

### AlarmViewModel

```swift
import SwiftUI
import AlarmKit

nonisolated struct TimerMetadata: AlarmMetadata {
    var label: String
}

@Observable
@MainActor
class AlarmViewModel {
    private let alarmManager = AlarmManager.shared

    var alarms: [Alarm] = []
    var isAuthorized = false
    var errorMessage: String?

    init() {
        observeAlarms()
        observeAuthorization()
    }

    // MARK: - Authorization

    func requestPermission() async {
        switch alarmManager.authorizationState {
        case .notDetermined:
            do {
                let state = try await alarmManager.requestAuthorization()
                isAuthorized = (state == .authorized)
            } catch {
                errorMessage = "Failed to request authorization: \(error.localizedDescription)"
            }
        case .authorized:
            isAuthorized = true
        case .denied:
            isAuthorized = false
            errorMessage = "Alarm permission denied. Please enable in Settings."
        @unknown default:
            break
        }
    }

    private func observeAuthorization() {
        Task {
            for await state in alarmManager.authorizationUpdates {
                isAuthorized = (state == .authorized)
            }
        }
    }

    // MARK: - Alarm Observation

    private func observeAlarms() {
        Task {
            for await updatedAlarms in alarmManager.alarmUpdates {
                self.alarms = updatedAlarms
            }
        }
    }

    // MARK: - Schedule Timer

    func scheduleTimer(duration: TimeInterval, label: String) async {
        let id = UUID()

        let alert = AlarmPresentation.Alert(
            title: label,
            stopButton: AlarmButton(
                text: "Stop",
                textColor: .white,
                systemImageName: "stop.circle"
            ),
            secondaryButton: AlarmButton(
                text: "Repeat",
                textColor: .white,
                systemImageName: "repeat"
            ),
            secondaryButtonBehavior: .countdown
        )

        let countdown = AlarmPresentation.Countdown(
            title: label,
            pauseButton: AlarmButton(
                text: "Pause",
                textColor: .yellow,
                systemImageName: "pause.circle"
            )
        )

        let paused = AlarmPresentation.Paused(
            title: "Paused",
            resumeButton: AlarmButton(
                text: "Resume",
                textColor: .green,
                systemImageName: "play.circle"
            )
        )

        let presentation = AlarmPresentation(
            alert: alert,
            countdown: countdown,
            paused: paused
        )

        let attributes = AlarmAttributes<TimerMetadata>(
            presentation: presentation,
            metadata: TimerMetadata(label: label),
            tintColor: .blue
        )

        let countdownDuration = Alarm.CountdownDuration(
            preAlert: duration,
            postAlert: duration
        )

        let configuration = AlarmManager.AlarmConfiguration<TimerMetadata>(
            countdownDuration: countdownDuration,
            attributes: attributes
        )

        do {
            try await alarmManager.schedule(id: id, configuration: configuration)
            try await alarmManager.countdown(id: id)
        } catch {
            errorMessage = "Failed to schedule timer: \(error.localizedDescription)"
        }
    }

    // MARK: - Schedule Recurring Alarm

    func scheduleRecurringAlarm(
        hour: Int,
        minute: Int,
        weekdays: [Alarm.Schedule.Relative.Recurrence.Weekday],
        label: String
    ) async {
        let id = UUID()

        let time = Alarm.Schedule.Relative.Time(hour: hour, minute: minute)
        let recurrence = Alarm.Schedule.Relative.Recurrence.weekly(weekdays)
        let schedule = Alarm.Schedule.relative(
            Alarm.Schedule.Relative(time: time, repeats: recurrence)
        )

        let alert = AlarmPresentation.Alert(
            title: label,
            stopButton: AlarmButton(
                text: "Dismiss",
                textColor: .white,
                systemImageName: "checkmark.circle"
            ),
            secondaryButton: AlarmButton(
                text: "Snooze",
                textColor: .white,
                systemImageName: "zzz"
            ),
            secondaryButtonBehavior: .countdown
        )

        let duration = Alarm.CountdownDuration(
            preAlert: nil,
            postAlert: TimeInterval(5 * 60)  // 5-minute snooze
        )

        let attributes = AlarmAttributes<TimerMetadata>(
            presentation: AlarmPresentation(alert: alert),
            metadata: TimerMetadata(label: label),
            tintColor: .orange
        )

        let configuration = AlarmManager.AlarmConfiguration<TimerMetadata>(
            countdownDuration: duration,
            schedule: schedule,
            attributes: attributes
        )

        do {
            try await alarmManager.schedule(id: id, configuration: configuration)
        } catch {
            errorMessage = "Failed to schedule alarm: \(error.localizedDescription)"
        }
    }

    // MARK: - Lifecycle Actions

    func cancelAlarm(_ alarm: Alarm) async {
        do {
            try await alarmManager.cancel(id: alarm.id)
        } catch {
            errorMessage = "Failed to cancel alarm: \(error.localizedDescription)"
        }
    }

    func pauseAlarm(_ alarm: Alarm) async {
        do {
            try await alarmManager.pause(id: alarm.id)
        } catch {
            errorMessage = "Failed to pause alarm: \(error.localizedDescription)"
        }
    }

    func resumeAlarm(_ alarm: Alarm) async {
        do {
            try await alarmManager.resume(id: alarm.id)
        } catch {
            errorMessage = "Failed to resume alarm: \(error.localizedDescription)"
        }
    }

    func stopAlarm(_ alarm: Alarm) async {
        do {
            try await alarmManager.stop(id: alarm.id)
        } catch {
            errorMessage = "Failed to stop alarm: \(error.localizedDescription)"
        }
    }
}
```

### ContentView

```swift
import SwiftUI
import AlarmKit

struct ContentView: View {
    @State private var viewModel = AlarmViewModel()
    @State private var timerDuration: Double = 60
    @State private var timerLabel = "Timer"

    var body: some View {
        NavigationStack {
            List {
                Section("Quick Timer") {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Label", text: $timerLabel)

                        HStack {
                            Text("Duration: \(Int(timerDuration)) seconds")
                            Spacer()
                        }

                        Slider(value: $timerDuration, in: 10...600, step: 10)

                        Button("Start Timer") {
                            Task {
                                await viewModel.scheduleTimer(
                                    duration: timerDuration,
                                    label: timerLabel
                                )
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!viewModel.isAuthorized)
                    }
                    .padding(.vertical, 8)
                }

                Section("Active Alarms") {
                    if viewModel.alarms.isEmpty {
                        Text("No active alarms")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.alarms, id: \.id) { alarm in
                            AlarmRow(alarm: alarm, viewModel: viewModel)
                        }
                    }
                }
            }
            .navigationTitle("AlarmKit Demo")
            .task {
                await viewModel.requestPermission()
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let message = viewModel.errorMessage {
                    Text(message)
                }
            }
        }
    }
}

struct AlarmRow: View {
    let alarm: Alarm
    let viewModel: AlarmViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(alarm.id.uuidString.prefix(8))
                    .font(.headline)
                Spacer()
                Text(alarm.state.description)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.secondary.opacity(0.2))
                    .clipShape(Capsule())
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    Task { await viewModel.cancelAlarm(alarm) }
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Button("Pause") {
                    Task { await viewModel.pauseAlarm(alarm) }
                }
                .buttonStyle(.bordered)

                Button("Resume") {
                    Task { await viewModel.resumeAlarm(alarm) }
                }
                .buttonStyle(.bordered)
                .tint(.green)
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}
```

---

## References

- [AlarmKit - Apple Developer Documentation](https://developer.apple.com/documentation/AlarmKit)
- [Scheduling an alarm with AlarmKit - Apple Developer Documentation](https://developer.apple.com/documentation/AlarmKit/scheduling-an-alarm-with-alarmkit)
- [Wake up to the AlarmKit API - WWDC25 Video](https://developer.apple.com/videos/play/wwdc2025/230/)
- [WWDC 2025 - Wake up to the AlarmKit API - DEV Community](https://dev.to/arshtechpro/wwdc-2025-wake-up-to-the-alarmkit-api-ios-26-4e67)
- [Scheduling and Managing Alarms in SwiftUI with AlarmKit](https://www.createwithswift.com/scheduling-and-managing-alarms-in-swiftui-with-alarmkit/)
- [Schedule a countdown timer with AlarmKit](https://nilcoalescing.com/blog/CountdownTimerWithAlarmKit/)
- [AlarmKit API in Swift: Native iOS Alarms Without Background Hacks](https://www.svpdigitalstudio.com/blog/how-to-use-alarmkit-api-in-swift-ios-schedule-alarms-natively)

---

*Last updated: February 2026*
*Requires iOS 26.0+*

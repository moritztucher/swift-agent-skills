# DeviceActivity Framework Guide

The DeviceActivity framework enables apps to schedule monitoring of device usage and receive callbacks when specific events occur. This is the scheduling and monitoring layer of the Screen Time API.

---

## Overview

DeviceActivity provides:
- **Scheduled Monitoring**: Define time intervals for monitoring device activity
- **Usage Thresholds**: Get notified when app usage exceeds specified limits
- **Background Execution**: Monitor extension runs independently of your app
- **Event Callbacks**: Respond to interval start/end and threshold events

---

## Core Components

| Component | Purpose |
|-----------|---------|
| `DeviceActivityCenter` | Schedule and manage monitoring activities |
| `DeviceActivitySchedule` | Define when monitoring occurs |
| `DeviceActivityEvent` | Define threshold events to watch for |
| `DeviceActivityMonitor` | Extension that receives callbacks |
| `DeviceActivityName` | Unique identifier for an activity |

---

## DeviceActivityCenter

The `DeviceActivityCenter` is used to start and stop monitoring activities.

### Starting Monitoring

```swift
import DeviceActivity
import FamilyControls

class UsageMonitor {
    let center = DeviceActivityCenter()

    func startDailyMonitoring(
        for apps: Set<ApplicationToken>,
        timeLimit: DateComponents
    ) throws {
        // Define the monitoring schedule
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        // Define the usage limit event
        let event = DeviceActivityEvent(
            applications: apps,
            threshold: timeLimit
        )

        // Start monitoring
        try center.startMonitoring(
            .dailyUsage,
            during: schedule,
            events: [.usageLimit: event]
        )
    }
}

// Define activity and event names
extension DeviceActivityName {
    static let dailyUsage = Self("dailyUsage")
}

extension DeviceActivityEvent.Name {
    static let usageLimit = Self("usageLimit")
}
```

### Stopping Monitoring

```swift
// Stop specific activities
center.stopMonitoring([.dailyUsage])

// Stop all monitoring
center.stopMonitoring()
```

### Checking Active Monitoring

```swift
let activeActivities = center.activities
for activity in activeActivities {
    print("Monitoring: \(activity.rawValue)")
}
```

---

## DeviceActivitySchedule

Defines when monitoring should occur.

### Schedule Properties

```swift
struct DeviceActivitySchedule {
    let intervalStart: DateComponents    // When monitoring begins
    let intervalEnd: DateComponents      // When monitoring ends
    let repeats: Bool                    // Whether to repeat daily
    let warningTime: DateComponents?     // Optional warning before end
}
```

### Daily Schedule (Midnight to Midnight)

```swift
let dailySchedule = DeviceActivitySchedule(
    intervalStart: DateComponents(hour: 0, minute: 0),
    intervalEnd: DateComponents(hour: 23, minute: 59),
    repeats: true
)
```

### Work Hours Schedule

```swift
let workSchedule = DeviceActivitySchedule(
    intervalStart: DateComponents(hour: 9, minute: 0),
    intervalEnd: DateComponents(hour: 17, minute: 0),
    repeats: true
)
```

### Schedule with Warning

```swift
let scheduleWithWarning = DeviceActivitySchedule(
    intervalStart: DateComponents(hour: 0, minute: 0),
    intervalEnd: DateComponents(hour: 23, minute: 59),
    repeats: true,
    warningTime: DateComponents(minute: 5)  // Warn 5 min before interval ends
)
```

### One-Time Schedule (Non-Repeating)

```swift
let oneTimeSchedule = DeviceActivitySchedule(
    intervalStart: DateComponents(hour: 14, minute: 0),
    intervalEnd: DateComponents(hour: 16, minute: 0),
    repeats: false  // Only runs once
)
```

### Custom Day Schedule

```swift
// Schedule that only runs on weekdays
// Note: You'll need to create separate schedules and manage them
let weekdaySchedule = DeviceActivitySchedule(
    intervalStart: DateComponents(hour: 9, minute: 0, weekday: 2),  // Monday
    intervalEnd: DateComponents(hour: 17, minute: 0),
    repeats: true
)
```

---

## DeviceActivityEvent

Defines threshold events that trigger callbacks.

### Event Properties

```swift
struct DeviceActivityEvent {
    let applications: Set<ApplicationToken>?      // Specific apps to monitor
    let categories: Set<ActivityCategoryToken>?   // Categories to monitor
    let webDomains: Set<WebDomainToken>?          // Domains to monitor
    let threshold: DateComponents                 // Time threshold
    let includesAllActivity: Bool                 // Monitor all device activity
}
```

### App Usage Threshold

```swift
// Trigger when combined usage of selected apps reaches 30 minutes
let appLimitEvent = DeviceActivityEvent(
    applications: selectedAppTokens,
    threshold: DateComponents(minute: 30)
)
```

### Category Usage Threshold

```swift
// Trigger when social media usage reaches 1 hour
let socialLimitEvent = DeviceActivityEvent(
    categories: socialMediaCategoryTokens,
    threshold: DateComponents(hour: 1)
)
```

### Combined App and Category Threshold

```swift
// Monitor both specific apps and categories
let combinedEvent = DeviceActivityEvent(
    applications: appTokens,
    categories: categoryTokens,
    threshold: DateComponents(hour: 2)
)
```

### Total Device Usage

```swift
// Monitor all device activity
let totalUsageEvent = DeviceActivityEvent(
    includesAllActivity: true,
    threshold: DateComponents(hour: 4)
)
```

### Multiple Thresholds

```swift
// Set up multiple warning levels
let events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [
    .warning15min: DeviceActivityEvent(
        applications: apps,
        threshold: DateComponents(minute: 15)
    ),
    .warning30min: DeviceActivityEvent(
        applications: apps,
        threshold: DateComponents(minute: 30)
    ),
    .hardLimit: DeviceActivityEvent(
        applications: apps,
        threshold: DateComponents(hour: 1)
    )
]

extension DeviceActivityEvent.Name {
    static let warning15min = Self("warning15min")
    static let warning30min = Self("warning30min")
    static let hardLimit = Self("hardLimit")
}
```

---

## DeviceActivityMonitor Extension

The DeviceActivityMonitor is an app extension that receives callbacks for activity events. It runs independently of your main app.

### Creating the Extension

1. In Xcode, go to File → New → Target
2. Select "Device Activity Monitor Extension"
3. Name it (e.g., "DeviceActivityMonitorExtension")
4. Add it to your App Group

### Extension Structure

```swift
import DeviceActivity
import ManagedSettings
import FamilyControls

class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    // Called when monitoring interval begins
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        // Example: Clear previous day's shields at midnight
        if activity == .dailyUsage {
            let store = ManagedSettingsStore()
            store.clearAllSettings()
        }
    }

    // Called when monitoring interval ends
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        // Example: Log that the day ended
        logDayEnd(for: activity)
    }

    // Called when usage threshold is reached
    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)

        // Example: Apply shields when limit is reached
        if event == .hardLimit {
            applyShields()
        } else if event == .warning30min {
            // Could trigger a notification (via shared data)
            recordWarning()
        }
    }

    // Called when warning time is reached (if configured)
    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)

        // Prepare for interval end
    }

    // MARK: - Helper Methods

    private func applyShields() {
        let store = ManagedSettingsStore()

        // Load saved selection from shared container
        guard let data = sharedDefaults?.data(forKey: "selectedApps"),
              let selection = try? PropertyListDecoder().decode(
                  FamilyActivitySelection.self,
                  from: data
              ) else {
            return
        }

        store.shield.applications = selection.applicationTokens
    }

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: "group.com.yourcompany.yourapp")
    }

    private func logDayEnd(for activity: DeviceActivityName) {
        // Log or update shared data
    }

    private func recordWarning() {
        sharedDefaults?.set(true, forKey: "warningTriggered")
    }
}
```

### Extension Info.plist

Ensure your extension's Info.plist contains:

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.deviceactivitymonitor</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).DeviceActivityMonitorExtension</string>
</dict>
```

---

## Callback Methods

### intervalDidStart

Called when the monitoring interval begins (e.g., at midnight for daily schedules).

```swift
override func intervalDidStart(for activity: DeviceActivityName) {
    super.intervalDidStart(for: activity)

    switch activity {
    case .dailyUsage:
        // Reset daily limits
        ManagedSettingsStore().clearAllSettings()

    case .focusSession:
        // Apply focus mode restrictions
        applyFocusModeShields()

    default:
        break
    }
}
```

### intervalDidEnd

Called when the monitoring interval ends.

```swift
override func intervalDidEnd(for activity: DeviceActivityName) {
    super.intervalDidEnd(for: activity)

    switch activity {
    case .focusSession:
        // Remove focus mode restrictions
        ManagedSettingsStore().clearAllSettings()

    default:
        break
    }
}
```

### eventDidReachThreshold

Called when usage exceeds the threshold defined in a DeviceActivityEvent.

```swift
override func eventDidReachThreshold(
    _ event: DeviceActivityEvent.Name,
    activity: DeviceActivityName
) {
    super.eventDidReachThreshold(event, activity: activity)

    switch event {
    case .usageLimit:
        // Block the apps
        applyShields()

    case .warning15min:
        // Record warning for main app to display
        recordWarningForMainApp()

    default:
        break
    }
}
```

### intervalWillEndWarning

Called when the warning time before interval end is reached.

```swift
override func intervalWillEndWarning(for activity: DeviceActivityName) {
    super.intervalWillEndWarning(for: activity)

    // Prepare for interval end
    // Could notify user that restrictions will reset soon
}
```

---

## Memory Limits

The DeviceActivityMonitor extension has a strict **6MB memory budget**. Exceeding this will cause the extension to be terminated.

### Best Practices for Memory

```swift
// DO: Keep imports minimal
import DeviceActivity
import ManagedSettings
// import FamilyControls  // Only if needed for decoding

// DON'T: Import heavy frameworks
// import SwiftUI        // Not needed in extension
// import UIKit          // Not needed in extension

// DO: Use lightweight data access
private var sharedDefaults: UserDefaults? {
    UserDefaults(suiteName: "group.com.yourcompany.yourapp")
}

// DO: Decode only what you need
private func loadAppTokens() -> Set<ApplicationToken>? {
    guard let data = sharedDefaults?.data(forKey: "appTokens") else {
        return nil
    }
    return try? PropertyListDecoder().decode(Set<ApplicationToken>.self, from: data)
}

// DON'T: Load entire selection if you only need tokens
// let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)

// DO: Avoid storing large data structures
// DON'T: Create arrays of images, large strings, etc.
```

### Memory-Efficient Pattern

```swift
class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    // Lazy initialization to avoid memory allocation until needed
    private lazy var store = ManagedSettingsStore()

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: "group.com.yourcompany.yourapp")
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)

        // Minimal memory footprint
        guard event == .usageLimit,
              let data = sharedDefaults?.data(forKey: "appTokens"),
              let tokens = try? PropertyListDecoder().decode(
                  Set<ApplicationToken>.self,
                  from: data
              ) else {
            return
        }

        store.shield.applications = tokens
    }
}
```

---

## Schedule Limits

You can have a maximum of **20 active schedules** per app.

### Managing Multiple Schedules

```swift
class ScheduleManager {
    let center = DeviceActivityCenter()

    // Track active schedules
    private var activeSchedules: Set<DeviceActivityName> = []

    func startSchedule(_ name: DeviceActivityName,
                       schedule: DeviceActivitySchedule,
                       events: [DeviceActivityEvent.Name: DeviceActivityEvent]) throws {
        // Check limit
        guard activeSchedules.count < 20 else {
            throw ScheduleError.limitReached
        }

        try center.startMonitoring(name, during: schedule, events: events)
        activeSchedules.insert(name)
    }

    func stopSchedule(_ name: DeviceActivityName) {
        center.stopMonitoring([name])
        activeSchedules.remove(name)
    }

    func stopAllSchedules() {
        center.stopMonitoring()
        activeSchedules.removeAll()
    }

    enum ScheduleError: Error {
        case limitReached
    }
}
```

---

## Complete Example

### Main App

```swift
import SwiftUI
import DeviceActivity
import FamilyControls
import ManagedSettings

@MainActor
@Observable
class UsageLimitManager {
    private let center = DeviceActivityCenter()
    private let storage: UserDefaults?

    var selection = FamilyActivitySelection()
    var dailyLimit = DateComponents(hour: 1)
    var isMonitoring = false

    init() {
        storage = UserDefaults(suiteName: "group.com.yourcompany.yourapp")
        loadSavedSelection()
    }

    // MARK: - Monitoring

    func startMonitoring() throws {
        // Save selection for extension to access
        saveSelection()

        // Create daily schedule
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        // Create usage events
        let events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [
            .warning: DeviceActivityEvent(
                applications: selection.applicationTokens,
                threshold: warningThreshold
            ),
            .limit: DeviceActivityEvent(
                applications: selection.applicationTokens,
                threshold: dailyLimit
            )
        ]

        try center.startMonitoring(.daily, during: schedule, events: events)
        isMonitoring = true
    }

    func stopMonitoring() {
        center.stopMonitoring([.daily])
        ManagedSettingsStore().clearAllSettings()
        isMonitoring = false
    }

    // MARK: - Persistence

    private func saveSelection() {
        guard let data = try? PropertyListEncoder().encode(selection.applicationTokens) else {
            return
        }
        storage?.set(data, forKey: "appTokens")
    }

    private func loadSavedSelection() {
        guard let data = storage?.data(forKey: "appTokens"),
              let tokens = try? PropertyListDecoder().decode(
                  Set<ApplicationToken>.self,
                  from: data
              ) else {
            return
        }
        selection.applicationTokens = tokens
    }

    private var warningThreshold: DateComponents {
        // Warning at 80% of limit
        var warning = dailyLimit
        if let minutes = warning.minute {
            warning.minute = Int(Double(minutes) * 0.8)
        }
        if let hours = warning.hour {
            let totalMinutes = hours * 60 + (warning.minute ?? 0)
            let warningMinutes = Int(Double(totalMinutes) * 0.8)
            warning.hour = warningMinutes / 60
            warning.minute = warningMinutes % 60
        }
        return warning
    }
}

// Activity and event names
extension DeviceActivityName {
    static let daily = Self("daily")
}

extension DeviceActivityEvent.Name {
    static let warning = Self("warning")
    static let limit = Self("limit")
}

// SwiftUI View
struct UsageLimitView: View {
    @State private var manager = UsageLimitManager()
    @State private var showPicker = false
    @State private var selectedHours = 1

    var body: some View {
        NavigationStack {
            Form {
                Section("Apps to Limit") {
                    Button("Select Apps") {
                        showPicker = true
                    }

                    if !manager.selection.applicationTokens.isEmpty {
                        Text("\(manager.selection.applicationTokens.count) apps selected")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Daily Limit") {
                    Picker("Hours", selection: $selectedHours) {
                        ForEach(1...8, id: \.self) { hours in
                            Text("\(hours) hour\(hours > 1 ? "s" : "")")
                        }
                    }
                    .onChange(of: selectedHours) { _, newValue in
                        manager.dailyLimit = DateComponents(hour: newValue)
                    }
                }

                Section {
                    if manager.isMonitoring {
                        Button("Stop Monitoring", role: .destructive) {
                            manager.stopMonitoring()
                        }
                    } else {
                        Button("Start Monitoring") {
                            do {
                                try manager.startMonitoring()
                            } catch {
                                print("Failed to start: \(error)")
                            }
                        }
                        .disabled(manager.selection.applicationTokens.isEmpty)
                    }
                }

                if manager.isMonitoring {
                    Section {
                        Label("Monitoring Active", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("Usage Limits")
            .familyActivityPicker(
                isPresented: $showPicker,
                selection: $manager.selection
            )
        }
    }
}
```

### Extension

```swift
import DeviceActivity
import ManagedSettings

class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private lazy var store = ManagedSettingsStore()

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: "group.com.yourcompany.yourapp")
    }

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        if activity.rawValue == "daily" {
            // New day - clear yesterday's shields
            store.clearAllSettings()
            sharedDefaults?.set(false, forKey: "warningShown")
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        // Day ended
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)

        switch event.rawValue {
        case "warning":
            // Flag for main app to show notification
            sharedDefaults?.set(true, forKey: "warningShown")

        case "limit":
            // Apply shields
            applyShields()

        default:
            break
        }
    }

    private func applyShields() {
        guard let data = sharedDefaults?.data(forKey: "appTokens"),
              let tokens = try? PropertyListDecoder().decode(
                  Set<ApplicationToken>.self,
                  from: data
              ) else {
            return
        }

        store.shield.applications = tokens
    }
}
```

---

## Debugging

### Check Active Schedules

```swift
let center = DeviceActivityCenter()
print("Active activities: \(center.activities.map { $0.rawValue })")
```

### Verify Extension is Embedded

In Xcode:
1. Select your app target
2. Go to "Embed & Sign" in Frameworks
3. Verify your extension is listed

### Test Schedule Triggering

For testing, use short intervals:

```swift
// Test schedule - triggers quickly
let testSchedule = DeviceActivitySchedule(
    intervalStart: DateComponents(hour: Calendar.current.component(.hour, from: Date()),
                                  minute: Calendar.current.component(.minute, from: Date())),
    intervalEnd: DateComponents(hour: Calendar.current.component(.hour, from: Date()),
                               minute: Calendar.current.component(.minute, from: Date()) + 5),
    repeats: false
)
```

### Console Logging

Use `os_log` for debugging in extensions:

```swift
import os.log

let logger = Logger(subsystem: "com.yourcompany.yourapp", category: "DeviceActivity")

override func eventDidReachThreshold(
    _ event: DeviceActivityEvent.Name,
    activity: DeviceActivityName
) {
    logger.info("Threshold reached: \(event.rawValue) for \(activity.rawValue)")
    super.eventDidReachThreshold(event, activity: activity)
}
```

---

## Troubleshooting

### Extension Not Triggering

1. **Verify embedding**: Extension must be embedded in your app
2. **Check entitlements**: App Group must be configured correctly
3. **Verify schedule**: Ensure schedule times are valid
4. **Test with device**: Extension callbacks may not work in Simulator

### Threshold Not Reached

1. **Verify tokens**: Check that app tokens are valid
2. **Check usage**: Ensure you're actually using the monitored apps
3. **Wait for accumulation**: Usage is tracked over time, not instantly

### Data Not Shared

1. **App Group**: Verify both app and extension use same App Group
2. **Suite name**: Use correct suite name for UserDefaults
3. **Encoding**: Use PropertyListEncoder for tokens

### Memory Crashes

1. **Reduce imports**: Only import necessary frameworks
2. **Avoid images**: Don't load or process images
3. **Minimize data**: Decode only required data

---

## Related Frameworks

- [FamilyControls Guide](familycontrols-guide.md) - Authorization and app selection
- [ManagedSettings Guide](managedsettings-guide.md) - Apply shields and restrictions
- [Screen Time API Overview](screen-time-api-guide.md) - Complete API overview

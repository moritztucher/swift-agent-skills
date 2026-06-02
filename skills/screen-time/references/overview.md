# Screen Time API Guide

A comprehensive guide to Apple's Screen Time API for iOS/iPadOS development. This API enables apps to help users manage and monitor device usage, implement parental controls, and build digital wellness features.

---

## Overview

The Screen Time API was introduced in iOS 15 and consists of three interconnected frameworks that work together to provide comprehensive device activity monitoring and management capabilities:

| Framework | Purpose |
|-----------|---------|
| **FamilyControls** | Authorization and app/category selection |
| **ManagedSettings** | Applying restrictions and shields to apps |
| **DeviceActivity** | Scheduling and monitoring usage events |

> The `DeviceActivity` framework also ships the SwiftUI `DeviceActivityReport` view plus a `DeviceActivityReportExtension` — the privacy-preserving way to *display* usage data. Raw per-app usage numbers are only readable inside that extension (via `DeviceActivityResults`), never in the host app, and the report renders as a sandboxed view you embed but cannot read back. It's the read/visualize counterpart to the schedule/monitor APIs in `deviceactivity.md`. Confirmed current against Apple docs 2026-06-02.

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Your App                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────┐  ┌──────────────────┐  ┌───────────────┐  │
│  │  FamilyControls  │  │  ManagedSettings │  │ DeviceActivity│  │
│  │                  │  │                  │  │               │  │
│  │ • Authorization  │  │ • Shield apps    │  │ • Schedule    │  │
│  │ • App picker     │  │ • Block content  │  │ • Monitor     │  │
│  │ • Token storage  │  │ • Web filters    │  │ • Thresholds  │  │
│  └────────┬─────────┘  └────────┬─────────┘  └───────┬───────┘  │
│           │                     │                     │          │
│           └─────────────────────┼─────────────────────┘          │
│                                 │                                │
│                    ┌────────────▼────────────┐                   │
│                    │      App Groups         │                   │
│                    │   (Shared Container)    │                   │
│                    └────────────┬────────────┘                   │
│                                 │                                │
└─────────────────────────────────┼────────────────────────────────┘
                                  │
                    ┌─────────────▼─────────────┐
                    │  DeviceActivityMonitor    │
                    │      (Extension)          │
                    │                           │
                    │  • intervalDidStart       │
                    │  • intervalDidEnd         │
                    │  • eventDidReachThreshold │
                    └───────────────────────────┘
```

---

## Requirements

### Entitlements

The Screen Time API requires a special entitlement that must be requested from Apple:

```xml
<!-- Required in your app's entitlements file -->
<key>com.apple.developer.family-controls</key>
<dict>
    <key>AuthorizationMode</key>
    <string>individual</string>  <!-- or "child" for parental control apps -->
</dict>
```

**Important:** You must request the Family Controls capability through Apple Developer Portal. Apple reviews these requests and requires justification for how your app will use the API.

### Authorization Types

| Type | Use Case | Requirements |
|------|----------|--------------|
| `.individual` | Personal digital wellness apps | User authenticates with their own Apple ID |
| `.child` | Parental control apps | Child's device enrolled in Family Sharing |

### App Groups Setup

To share data between your main app and the DeviceActivityMonitor extension:

1. **Enable App Groups** in your app target's capabilities
2. **Create an App Group** identifier (e.g., `group.com.yourcompany.yourapp`)
3. **Add the same App Group** to your DeviceActivityMonitor extension target

```swift
// Access shared container
let sharedDefaults = UserDefaults(suiteName: "group.com.yourcompany.yourapp")
```

### Minimum Requirements

- iOS 15.0+ / iPadOS 15.0+
- Xcode 13.0+
- Family Controls entitlement from Apple

---

## Quick Start Guide

### Step 1: Request Authorization

```swift
import FamilyControls

@MainActor
class ScreenTimeManager: ObservableObject {
    static let shared = ScreenTimeManager()

    @Published var isAuthorized = false

    func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
    }
}
```

### Step 2: Let User Select Apps

```swift
import SwiftUI
import FamilyControls

struct AppSelectionView: View {
    @State private var showPicker = false
    @State private var selection = FamilyActivitySelection()

    var body: some View {
        VStack {
            Button("Select Apps to Monitor") {
                showPicker = true
            }

            Text("Selected \(selection.applicationTokens.count) apps")
        }
        .familyActivityPicker(isPresented: $showPicker, selection: $selection)
        .onChange(of: selection) { _, newValue in
            saveSelection(newValue)
        }
    }

    private func saveSelection(_ selection: FamilyActivitySelection) {
        // Persist selection for later use
        let encoder = PropertyListEncoder()
        if let data = try? encoder.encode(selection) {
            UserDefaults(suiteName: "group.com.yourcompany.yourapp")?
                .set(data, forKey: "selectedApps")
        }
    }
}
```

### Step 3: Shield Selected Apps

```swift
import ManagedSettings

class ShieldManager {
    let store = ManagedSettingsStore()

    func shieldApps(_ selection: FamilyActivitySelection) {
        // Apply shields to selected apps
        store.shield.applications = selection.applicationTokens
        store.shield.applicationCategories = .specific(selection.categoryTokens)
    }

    func clearShields() {
        store.clearAllSettings()
    }
}
```

### Step 4: Monitor Usage with Thresholds

```swift
import DeviceActivity
import FamilyControls

class UsageMonitor {
    let center = DeviceActivityCenter()

    func startMonitoring(apps: Set<ApplicationToken>, timeLimit: DateComponents) throws {
        // Create daily schedule
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        // Create usage limit event
        let event = DeviceActivityEvent(
            applications: apps,
            threshold: timeLimit
        )

        // Start monitoring
        try center.startMonitoring(
            .daily,
            during: schedule,
            events: [.usageLimit: event]
        )
    }

    func stopMonitoring() {
        center.stopMonitoring([.daily])
    }
}

// Define activity names
extension DeviceActivityName {
    static let daily = Self("daily")
}

extension DeviceActivityEvent.Name {
    static let usageLimit = Self("usageLimit")
}
```

### Step 5: Create DeviceActivityMonitor Extension

Create a new target of type "Device Activity Monitor Extension":

```swift
import DeviceActivity
import ManagedSettings

class MyDeviceActivityMonitor: DeviceActivityMonitor {
    let store = ManagedSettingsStore()

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        // Called when monitoring interval begins
        // Example: Clear shields at start of new day
        store.clearAllSettings()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        // Called when monitoring interval ends
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)

        // Called when usage threshold is reached
        // Load saved selection and apply shields
        if let data = UserDefaults(suiteName: "group.com.yourcompany.yourapp")?
            .data(forKey: "selectedApps"),
           let selection = try? PropertyListDecoder().decode(
               FamilyActivitySelection.self,
               from: data
           ) {
            store.shield.applications = selection.applicationTokens
        }
    }
}
```

---

## Token System

The Screen Time API uses an opaque token system to protect user privacy. You never see actual app names or bundle IDs - instead, you work with tokens:

| Token Type | Represents | Usage |
|------------|------------|-------|
| `ApplicationToken` | A specific app | Shield individual apps |
| `ActivityCategoryToken` | App Store category | Shield all apps in a category |
| `WebDomainToken` | A website domain | Block specific websites |

### Important Token Rules

1. **Tokens are opaque** - You cannot extract app names or bundle IDs from tokens
2. **Tokens are device-specific** - A token from one device won't work on another
3. **Tokens can be persisted** - Use PropertyListEncoder to save selections
4. **Tokens are Hashable** - Can be stored in Sets for efficient operations

```swift
// Encoding tokens for persistence
let selection = FamilyActivitySelection()
let encoder = PropertyListEncoder()
let data = try encoder.encode(selection)

// Decoding tokens
let decoder = PropertyListDecoder()
let restored = try decoder.decode(FamilyActivitySelection.self, from: data)
```

---

## Common Use Cases

### Digital Wellness App
- User selects distracting apps
- Set daily usage limits (e.g., 30 minutes for social media)
- Show usage statistics
- Shield apps when limit is reached

### Focus App
- Schedule focus sessions
- Block selected apps during focus time
- Automatically unblock when session ends

### Parental Control App
- Parent selects apps to restrict
- Set time-based schedules (homework hours, bedtime)
- Monitor child's usage patterns
- Apply web content filters

### Productivity Tracker
- Monitor work app usage
- Track time spent in different categories
- Generate usage reports

---

## Best Practices

### 1. Request Authorization Early
```swift
// Check status on app launch
func checkAuthorization() {
    switch AuthorizationCenter.shared.authorizationStatus {
    case .notDetermined:
        // Show onboarding to explain why you need access
        break
    case .denied:
        // Guide user to Settings to grant permission
        break
    case .approved:
        // Ready to use Screen Time features
        break
    @unknown default:
        break
    }
}
```

### 2. Handle Authorization Changes
```swift
// Observe authorization status changes
AuthorizationCenter.shared.authorizationStatus
    .sink { status in
        // Update UI based on new status
    }
```

### 3. Use Named Stores for Flexibility (iOS 16+)
```swift
// Create separate stores for different purposes
let focusModeStore = ManagedSettingsStore(named: .focusMode)
let bedtimeStore = ManagedSettingsStore(named: .bedtime)

extension ManagedSettingsStore.Name {
    static let focusMode = Self("focusMode")
    static let bedtime = Self("bedtime")
}
```

### 4. Respect Memory Limits in Extensions
The DeviceActivityMonitor extension has a strict **6MB memory budget**. Keep your extension lightweight:
- Don't import heavy frameworks
- Avoid loading images
- Keep data processing minimal
- Use shared containers for complex data

### 5. Schedule Limits
You can have a maximum of **20 active schedules** per app. Plan your monitoring strategy accordingly.

---

## Related Documentation

- [FamilyControls Guide](familycontrols-guide.md) - Authorization and app selection
- [ManagedSettings Guide](managedsettings-guide.md) - Applying restrictions and shields
- [DeviceActivity Guide](deviceactivity-guide.md) - Scheduling and monitoring usage

---

## Troubleshooting

### Authorization Denied
- Ensure entitlements are properly configured
- Check that the device is not in supervised mode
- Verify Family Sharing setup for child authorization

### Tokens Not Persisting
- Use PropertyListEncoder/Decoder for serialization
- Verify App Groups are configured correctly
- Check shared container access in extension

### Extension Not Triggering
- Verify the extension target is embedded in the app
- Check that monitoring was started successfully
- Review schedule configuration for validity

### Memory Issues in Extension
- Reduce imports to essential frameworks only
- Avoid storing large data structures
- Use shared UserDefaults for data access

---

## References

- [Apple Documentation: Screen Time](https://developer.apple.com/documentation/screentime)
- [WWDC21: Meet the Screen Time API](https://developer.apple.com/videos/play/wwdc2021/10123/)
- [WWDC22: What's new in Screen Time API](https://developer.apple.com/videos/play/wwdc2022/110336/)

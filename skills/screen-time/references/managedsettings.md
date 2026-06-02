# ManagedSettings Framework Guide

The ManagedSettings framework enables apps to apply restrictions and shields to apps, websites, and device features. This is the enforcement layer of the Screen Time API, allowing you to block or limit access to selected content.

---

## Overview

ManagedSettings provides:
- **App Shields**: Block access to specific apps with a customizable overlay
- **Category Shields**: Block entire App Store categories
- **Web Domain Shields**: Block specific websites
- **Web Content Filters**: Filter inappropriate web content
- **Application Settings**: Control app-specific behaviors
- **Named Stores**: Manage multiple independent restriction configurations (iOS 16+)

---

## ManagedSettingsStore

The `ManagedSettingsStore` is the central class for managing restrictions. Settings applied to a store remain in effect until explicitly cleared or the app is deleted.

### Basic Usage

```swift
import ManagedSettings
import FamilyControls

class ShieldManager {
    let store = ManagedSettingsStore()

    func shieldApps(_ selection: FamilyActivitySelection) {
        // Shield specific apps
        store.shield.applications = selection.applicationTokens

        // Shield entire categories
        store.shield.applicationCategories = .specific(selection.categoryTokens)

        // Shield web domains
        store.shield.webDomains = selection.webDomainTokens
    }

    func clearAllRestrictions() {
        store.clearAllSettings()
    }
}
```

### Named Stores (iOS 16+)

Named stores allow you to manage multiple independent sets of restrictions. This is useful for different modes like "Focus Time", "Bedtime", or "Homework".

```swift
import ManagedSettings

// Define store names
extension ManagedSettingsStore.Name {
    static let focusMode = Self("focusMode")
    static let bedtime = Self("bedtime")
    static let homework = Self("homework")
}

class MultiModeShieldManager {
    private let focusStore = ManagedSettingsStore(named: .focusMode)
    private let bedtimeStore = ManagedSettingsStore(named: .bedtime)
    private let homeworkStore = ManagedSettingsStore(named: .homework)

    func activateFocusMode(blocking apps: Set<ApplicationToken>) {
        focusStore.shield.applications = apps
    }

    func activateBedtime(blocking apps: Set<ApplicationToken>) {
        bedtimeStore.shield.applications = apps
    }

    func deactivateFocusMode() {
        focusStore.clearAllSettings()
    }

    func deactivateBedtime() {
        bedtimeStore.clearAllSettings()
    }

    func deactivateAll() {
        focusStore.clearAllSettings()
        bedtimeStore.clearAllSettings()
        homeworkStore.clearAllSettings()
    }
}
```

### Store Behavior

- Settings from **all active stores** are combined (union)
- If any store shields an app, that app is shielded
- Clearing one store doesn't affect other stores
- The default (unnamed) store persists across app restarts

---

## Shield Settings

### Shielding Applications

```swift
import ManagedSettings
import FamilyControls

let store = ManagedSettingsStore()

// Shield specific apps
func shieldSelectedApps(_ tokens: Set<ApplicationToken>) {
    store.shield.applications = tokens
}

// Add more apps to existing shields
func addAppsToShield(_ tokens: Set<ApplicationToken>) {
    let existing = store.shield.applications ?? []
    store.shield.applications = existing.union(tokens)
}

// Remove apps from shield
func removeAppsFromShield(_ tokens: Set<ApplicationToken>) {
    guard var existing = store.shield.applications else { return }
    existing.subtract(tokens)
    store.shield.applications = existing.isEmpty ? nil : existing
}

// Clear all app shields
func clearAppShields() {
    store.shield.applications = nil
}
```

### Shielding Categories

Shield entire App Store categories:

```swift
import ManagedSettings
import FamilyControls

let store = ManagedSettingsStore()

// Shield specific categories
func shieldCategories(_ tokens: Set<ActivityCategoryToken>) {
    store.shield.applicationCategories = .specific(tokens)
}

// Shield ALL categories (block all apps)
func shieldAllCategories() {
    store.shield.applicationCategories = .all()
}

// Shield all categories EXCEPT specified ones
func shieldAllExcept(_ tokens: Set<ActivityCategoryToken>) {
    store.shield.applicationCategories = .all(except: tokens)
}

// Clear category shields
func clearCategoryShields() {
    store.shield.applicationCategories = nil
}
```

### Category Shield Options

```swift
enum ShieldSettings.ActivityCategoryPolicy {
    case all()                                    // Block all categories
    case all(except: Set<ActivityCategoryToken>)  // Block all except specified
    case specific(Set<ActivityCategoryToken>)     // Block only specified categories
}
```

### Shielding Web Domains

```swift
import ManagedSettings
import FamilyControls

let store = ManagedSettingsStore()

// Shield specific domains
func shieldDomains(_ tokens: Set<WebDomainToken>) {
    store.shield.webDomains = tokens
}

// Clear domain shields
func clearDomainShields() {
    store.shield.webDomains = nil
}
```

---

## Shield Configuration

Customize how shields appear to users:

### ShieldSettings Properties

```swift
import ManagedSettings

let store = ManagedSettingsStore()

// Customize shield appearance
store.shield.applicationCategories = .all()

// The shield shows:
// - App icon (blurred)
// - "Time Limit" title
// - "You've reached your limit for this app" message
// - Optional "Ask For More Time" button
```

### Custom Shield Extension

For advanced customization, create a Shield Configuration Extension:

1. Add a new target: "Shield Configuration Extension"
2. Implement the extension:

```swift
import ManagedSettingsUI
import ManagedSettings

class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemMaterialDark,
            backgroundColor: .black.withAlphaComponent(0.8),
            icon: UIImage(systemName: "hourglass"),
            title: ShieldConfiguration.Label(
                text: "Take a Break",
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: "This app is currently blocked",
                color: .gray
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Dismiss",
                color: .white
            ),
            primaryButtonBackgroundColor: .systemBlue,
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Request More Time",
                color: .systemBlue
            )
        )
    }

    override func configuration(shielding application: Application,
                               in category: ActivityCategory) -> ShieldConfiguration {
        // Configuration when app is shielded via category
        configuration(shielding: application)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemMaterialDark,
            title: ShieldConfiguration.Label(
                text: "Website Blocked",
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: "This website is not available",
                color: .gray
            )
        )
    }
}
```

### Shield Action Extension

Handle button taps in your shield:

```swift
import ManagedSettingsUI
import ManagedSettings

class ShieldActionExtension: ShieldActionDelegate {

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            // User tapped primary button (e.g., "Dismiss")
            completionHandler(.close)

        case .secondaryButtonPressed:
            // User tapped secondary button (e.g., "Request More Time")
            // Could send notification to parent, log request, etc.
            completionHandler(.defer)

        @unknown default:
            completionHandler(.close)
        }
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(.close)
    }
}
```

### ShieldActionResponse Options

| Response | Behavior |
|----------|----------|
| `.close` | Dismiss the shield and return to previous screen |
| `.defer` | Keep shield visible (for async operations) |
| `.none` | No action |

---

## Application Settings

Control app-specific behaviors:

```swift
import ManagedSettings

let store = ManagedSettingsStore()

// Block App Store purchases
store.application.blockedApplications = selection.applicationTokens

// Prevent app deletion
store.application.denyAppRemoval = true

// Prevent app installation
store.application.denyAppInstallation = true
```

### Available Application Settings

| Setting | Description |
|---------|-------------|
| `blockedApplications` | Apps that cannot be launched |
| `denyAppInstallation` | Prevent installing new apps |
| `denyAppRemoval` | Prevent deleting apps |

---

## Web Content Settings

Filter web content across Safari and WebKit-based apps:

```swift
import ManagedSettings

let store = ManagedSettingsStore()

// Block specific domains
store.webContent.blockedByFilter = .specific(domainTokens)

// Block adult content
store.webContent.blockedByFilter = .auto(except: Set())

// Auto filter with exceptions (always allowed)
let alwaysAllowed: Set<WebDomainToken> = getEducationalDomains()
store.webContent.blockedByFilter = .auto(except: alwaysAllowed)

// Clear web content filters
store.webContent.blockedByFilter = nil
```

### Web Content Filter Options

```swift
enum WebContentSettings.FilterPolicy {
    case auto()                              // Apple's automatic adult content filter
    case auto(except: Set<WebDomainToken>)   // Auto filter with allowed exceptions
    case specific(Set<WebDomainToken>)       // Block only specified domains
}
```

---

## Media Settings

Control media content access:

```swift
import ManagedSettings

let store = ManagedSettingsStore()

// Restrict explicit music
store.media.denyExplicitContent = true

// Set movie rating limit
store.media.maximumMovieRating = 200  // PG-13 equivalent

// Set TV rating limit
store.media.maximumTVShowRating = 200

// Restrict music profiles
store.media.denyMusicService = true

// Restrict podcasts
store.media.denyBookstoreErotica = true
```

---

## Clearing Settings

### Clear All Settings

```swift
let store = ManagedSettingsStore()
store.clearAllSettings()
```

### Clear Specific Settings

```swift
let store = ManagedSettingsStore()

// Clear only shields
store.shield.applications = nil
store.shield.applicationCategories = nil
store.shield.webDomains = nil

// Clear only web content
store.webContent.blockedByFilter = nil

// Clear only application settings
store.application.blockedApplications = nil
store.application.denyAppInstallation = false
store.application.denyAppRemoval = false
```

### Clear Named Store

```swift
let focusStore = ManagedSettingsStore(named: .focusMode)
focusStore.clearAllSettings()  // Only clears focusMode store
```

---

## Sharing Between App and Extensions

Use App Groups to share store configurations:

```swift
// Both app and extension must use the same App Group
// Settings are automatically shared when using the default store

// In main app
let store = ManagedSettingsStore()
store.shield.applications = selectedApps

// In DeviceActivityMonitor extension
// The same settings are visible
let store = ManagedSettingsStore()
store.shield.applications = selectedApps  // Same tokens
```

### Named Store Access

Named stores are also shared via App Groups:

```swift
// In main app
extension ManagedSettingsStore.Name {
    static let focusMode = Self("focusMode")
}

let focusStore = ManagedSettingsStore(named: .focusMode)
focusStore.shield.applications = focusApps

// In extension - access the same named store
let focusStore = ManagedSettingsStore(named: .focusMode)
// focusStore.shield.applications contains the same apps
```

---

## Complete Example

```swift
import SwiftUI
import ManagedSettings
import FamilyControls

@MainActor
@Observable
class RestrictionManager {
    private let defaultStore = ManagedSettingsStore()
    private let focusStore = ManagedSettingsStore(named: .focusMode)
    private let bedtimeStore = ManagedSettingsStore(named: .bedtime)

    var isFocusModeActive = false
    var isBedtimeActive = false

    // MARK: - Focus Mode

    func activateFocusMode(blocking selection: FamilyActivitySelection) {
        focusStore.shield.applications = selection.applicationTokens
        focusStore.shield.applicationCategories = .specific(selection.categoryTokens)
        isFocusModeActive = true
    }

    func deactivateFocusMode() {
        focusStore.clearAllSettings()
        isFocusModeActive = false
    }

    // MARK: - Bedtime

    func activateBedtime(allowOnly allowedApps: Set<ApplicationToken>) {
        // Block all apps except allowed ones
        bedtimeStore.shield.applicationCategories = .all()

        // Remove shields from allowed apps (doesn't work directly)
        // Instead, use a different approach: block specific apps
        isBedtimeActive = true
    }

    func activateBedtime(blocking apps: Set<ApplicationToken>) {
        bedtimeStore.shield.applications = apps
        isBedtimeActive = true
    }

    func deactivateBedtime() {
        bedtimeStore.clearAllSettings()
        isBedtimeActive = false
    }

    // MARK: - Web Content

    func enableSafeSearch() {
        defaultStore.webContent.blockedByFilter = .auto()
    }

    func blockWebsites(_ domains: Set<WebDomainToken>) {
        defaultStore.shield.webDomains = domains
    }

    // MARK: - Parental Controls

    func enableParentalControls() {
        defaultStore.application.denyAppInstallation = true
        defaultStore.application.denyAppRemoval = true
        defaultStore.media.denyExplicitContent = true
    }

    func disableParentalControls() {
        defaultStore.application.denyAppInstallation = false
        defaultStore.application.denyAppRemoval = false
        defaultStore.media.denyExplicitContent = false
    }

    // MARK: - Reset

    func resetAllRestrictions() {
        defaultStore.clearAllSettings()
        focusStore.clearAllSettings()
        bedtimeStore.clearAllSettings()
        isFocusModeActive = false
        isBedtimeActive = false
    }
}

// Store name extension
extension ManagedSettingsStore.Name {
    static let focusMode = Self("focusMode")
    static let bedtime = Self("bedtime")
}

// SwiftUI View
struct RestrictionControlView: View {
    @State private var manager = RestrictionManager()
    @State private var selection = FamilyActivitySelection()
    @State private var showPicker = false

    var body: some View {
        NavigationStack {
            List {
                Section("Modes") {
                    Toggle("Focus Mode", isOn: Binding(
                        get: { manager.isFocusModeActive },
                        set: { isOn in
                            if isOn {
                                manager.activateFocusMode(blocking: selection)
                            } else {
                                manager.deactivateFocusMode()
                            }
                        }
                    ))

                    Toggle("Bedtime Mode", isOn: Binding(
                        get: { manager.isBedtimeActive },
                        set: { isOn in
                            if isOn {
                                manager.activateBedtime(blocking: selection.applicationTokens)
                            } else {
                                manager.deactivateBedtime()
                            }
                        }
                    ))
                }

                Section("App Selection") {
                    Button("Select Apps to Block") {
                        showPicker = true
                    }

                    if !selection.applicationTokens.isEmpty {
                        Text("\(selection.applicationTokens.count) apps selected")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Web Content") {
                    Button("Enable Safe Search") {
                        manager.enableSafeSearch()
                    }
                }

                Section {
                    Button("Reset All Restrictions", role: .destructive) {
                        manager.resetAllRestrictions()
                        selection = FamilyActivitySelection()
                    }
                }
            }
            .navigationTitle("Restrictions")
            .familyActivityPicker(isPresented: $showPicker, selection: $selection)
        }
    }
}
```

---

## Best Practices

### 1. Use Named Stores for Different Modes
```swift
// Separate concerns with named stores
let workStore = ManagedSettingsStore(named: .work)
let relaxStore = ManagedSettingsStore(named: .relax)

// Each can be activated/deactivated independently
```

### 2. Always Provide an Exit Strategy
```swift
// Users should always have a way to remove restrictions
func emergencyUnblock() {
    ManagedSettingsStore().clearAllSettings()
    ManagedSettingsStore(named: .focusMode).clearAllSettings()
    ManagedSettingsStore(named: .bedtime).clearAllSettings()
}
```

### 3. Persist Selection, Not Shields
```swift
// Store the selection, apply shields dynamically
func onAppLaunch() {
    let selection = loadSavedSelection()

    if shouldBlockApps() {
        store.shield.applications = selection.applicationTokens
    }
}
```

### 4. Handle Extension Memory Limits
```swift
// In DeviceActivityMonitor extension
override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name,
                                      activity: DeviceActivityName) {
    // Keep it simple - 6MB memory limit
    let store = ManagedSettingsStore()

    // Load minimal data
    if let data = sharedDefaults?.data(forKey: "tokens"),
       let tokens = try? PropertyListDecoder().decode(
           Set<ApplicationToken>.self,
           from: data
       ) {
        store.shield.applications = tokens
    }
}
```

---

## Troubleshooting

### Shields Not Appearing
- Verify authorization is approved
- Check that tokens are valid and not empty
- Ensure App Groups are configured correctly
- Verify the store isn't being cleared elsewhere

### Settings Not Persisting
- Don't rely on named stores persisting across app deletion
- Save selection data separately using PropertyListEncoder
- Re-apply settings on app launch if needed

### Extension Can't Access Store
- Verify App Groups are enabled on both targets
- Use the same App Group identifier
- Check entitlements are properly configured

### Multiple Stores Conflicting
- Remember: all stores' restrictions combine (union)
- Clear unused stores explicitly
- Use meaningful store names to track what's active

---

## Related Frameworks

- [FamilyControls Guide](familycontrols-guide.md) - Authorization and app selection
- [DeviceActivity Guide](deviceactivity-guide.md) - Monitor usage and schedule events
- [Screen Time API Overview](screen-time-api-guide.md) - Complete API overview

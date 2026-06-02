# FamilyControls Framework Guide

The FamilyControls framework provides authorization for Screen Time features and enables users to select apps and categories for monitoring and restriction. This framework is the entry point for any Screen Time API implementation.

---

## Overview

FamilyControls is responsible for:
- Requesting user authorization to access Screen Time features
- Providing the FamilyActivityPicker UI for app/category selection
- Managing opaque tokens that represent apps and categories
- Persisting user selections across app launches

---

## Authorization

### AuthorizationCenter

The `AuthorizationCenter` is a singleton that manages authorization status for your app.

```swift
import FamilyControls

@MainActor
class AuthorizationManager: ObservableObject {
    static let shared = AuthorizationManager()

    @Published var authorizationStatus: AuthorizationStatus = .notDetermined

    init() {
        // Initial status check
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }
}
```

### Requesting Authorization

```swift
import FamilyControls

@MainActor
func requestAuthorization() async {
    do {
        // For personal digital wellness apps
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        print("Authorization granted")
    } catch {
        print("Authorization failed: \(error.localizedDescription)")
    }
}
```

### Authorization Types

| Type | Description | Use Case |
|------|-------------|----------|
| `.individual` | User authorizes for themselves | Personal productivity/wellness apps |
| `.child` | Parent/guardian authorizes for child | Parental control apps |

#### Individual Authorization
- User authenticates with their Apple ID
- User must be the device owner
- Shows system authorization prompt

```swift
try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
```

#### Child Authorization (Family Sharing)
- Requires device to be enrolled in Family Sharing
- Parent must approve through their device
- Child's device receives authorization automatically

```swift
try await AuthorizationCenter.shared.requestAuthorization(for: .child)
```

### Authorization Status

```swift
enum AuthorizationStatus {
    case notDetermined  // User hasn't made a choice yet
    case denied         // User denied authorization
    case approved       // User granted authorization
}
```

### Checking Status

```swift
func checkAuthorizationStatus() {
    switch AuthorizationCenter.shared.authorizationStatus {
    case .notDetermined:
        // Show onboarding explaining why you need Screen Time access
        showOnboarding()

    case .denied:
        // Guide user to re-enable in Settings
        showSettingsPrompt()

    case .approved:
        // Ready to use Screen Time features
        enableFeatures()

    @unknown default:
        break
    }
}
```

### Observing Authorization Changes

Use Combine to observe when authorization status changes:

```swift
import Combine
import FamilyControls

class AuthorizationObserver {
    private var cancellables = Set<AnyCancellable>()

    init() {
        AuthorizationCenter.shared.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { status in
                self.handleStatusChange(status)
            }
            .store(in: &cancellables)
    }

    private func handleStatusChange(_ status: AuthorizationStatus) {
        switch status {
        case .approved:
            print("Screen Time access granted")
        case .denied:
            print("Screen Time access revoked")
        case .notDetermined:
            print("Authorization not yet requested")
        @unknown default:
            break
        }
    }
}
```

---

## FamilyActivityPicker

The `FamilyActivityPicker` is a system-provided UI component that lets users select apps and categories to monitor or restrict.

### Basic Usage

```swift
import SwiftUI
import FamilyControls

struct AppPickerView: View {
    @State private var isPickerPresented = false
    @State private var selection = FamilyActivitySelection()

    var body: some View {
        VStack(spacing: 20) {
            Text("Select apps to manage")
                .font(.headline)

            Button("Choose Apps") {
                isPickerPresented = true
            }
            .buttonStyle(.borderedProminent)

            // Display selection summary
            SelectionSummaryView(selection: selection)
        }
        .familyActivityPicker(
            isPresented: $isPickerPresented,
            selection: $selection
        )
    }
}
```

### Picker with Header Title

```swift
.familyActivityPicker(
    isPresented: $isPickerPresented,
    headerText: "Select apps to block during focus time",
    selection: $selection
)
```

### Picker with Footer Text

```swift
.familyActivityPicker(
    isPresented: $isPickerPresented,
    headerText: "Choose apps to monitor",
    footerText: "You can change these selections anytime in settings",
    selection: $selection
)
```

### Handling Selection Changes

```swift
struct AppSelectionView: View {
    @State private var isPickerPresented = false
    @State private var selection = FamilyActivitySelection()

    var body: some View {
        Button("Select Apps") {
            isPickerPresented = true
        }
        .familyActivityPicker(isPresented: $isPickerPresented, selection: $selection)
        .onChange(of: selection) { oldValue, newValue in
            handleSelectionChange(from: oldValue, to: newValue)
        }
    }

    private func handleSelectionChange(
        from oldSelection: FamilyActivitySelection,
        to newSelection: FamilyActivitySelection
    ) {
        let addedApps = newSelection.applicationTokens.subtracting(oldSelection.applicationTokens)
        let removedApps = oldSelection.applicationTokens.subtracting(newSelection.applicationTokens)

        print("Added \(addedApps.count) apps")
        print("Removed \(removedApps.count) apps")

        // Save the new selection
        saveSelection(newSelection)
    }
}
```

---

## FamilyActivitySelection

The `FamilyActivitySelection` struct holds the user's selection of apps and categories.

### Structure

```swift
struct FamilyActivitySelection: Codable, Equatable {
    var applicationTokens: Set<ApplicationToken>
    var categoryTokens: Set<ActivityCategoryToken>
    var webDomainTokens: Set<WebDomainToken>

    // Check if selection includes all apps in a category
    var includeEntireCategory: Bool
}
```

### Working with Selections

```swift
var selection = FamilyActivitySelection()

// Check if empty
if selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty {
    print("No apps selected")
}

// Get counts
let appCount = selection.applicationTokens.count
let categoryCount = selection.categoryTokens.count
let domainCount = selection.webDomainTokens.count

print("Selected \(appCount) apps, \(categoryCount) categories, \(domainCount) domains")
```

### Merging Selections

```swift
func mergeSelections(_ selection1: FamilyActivitySelection,
                     _ selection2: FamilyActivitySelection) -> FamilyActivitySelection {
    var merged = FamilyActivitySelection()

    merged.applicationTokens = selection1.applicationTokens
        .union(selection2.applicationTokens)
    merged.categoryTokens = selection1.categoryTokens
        .union(selection2.categoryTokens)
    merged.webDomainTokens = selection1.webDomainTokens
        .union(selection2.webDomainTokens)

    return merged
}
```

---

## Persisting Selections

Since tokens are opaque, you must use `PropertyListEncoder` to serialize and persist selections.

### Saving to UserDefaults

```swift
import FamilyControls

class SelectionStorage {
    private let defaults: UserDefaults
    private let selectionKey = "familyActivitySelection"

    init(suiteName: String? = nil) {
        if let suiteName = suiteName {
            self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
        } else {
            self.defaults = .standard
        }
    }

    func save(_ selection: FamilyActivitySelection) throws {
        let encoder = PropertyListEncoder()
        let data = try encoder.encode(selection)
        defaults.set(data, forKey: selectionKey)
    }

    func load() throws -> FamilyActivitySelection {
        guard let data = defaults.data(forKey: selectionKey) else {
            return FamilyActivitySelection()
        }

        let decoder = PropertyListDecoder()
        return try decoder.decode(FamilyActivitySelection.self, from: data)
    }

    func clear() {
        defaults.removeObject(forKey: selectionKey)
    }
}
```

### Sharing with Extensions via App Groups

```swift
// In your main app
class SharedSelectionManager {
    static let shared = SharedSelectionManager()

    private let storage: SelectionStorage

    init() {
        // Use App Group for sharing with extensions
        storage = SelectionStorage(suiteName: "group.com.yourcompany.yourapp")
    }

    func saveSelection(_ selection: FamilyActivitySelection) {
        do {
            try storage.save(selection)
            print("Selection saved successfully")
        } catch {
            print("Failed to save selection: \(error)")
        }
    }

    func loadSelection() -> FamilyActivitySelection {
        do {
            return try storage.load()
        } catch {
            print("Failed to load selection: \(error)")
            return FamilyActivitySelection()
        }
    }
}

// In your DeviceActivityMonitor extension
class MyDeviceActivityMonitor: DeviceActivityMonitor {
    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        // Load selection from shared container
        let storage = SelectionStorage(suiteName: "group.com.yourcompany.yourapp")
        if let selection = try? storage.load() {
            // Use selection to apply shields
            applyShields(for: selection)
        }
    }
}
```

### Saving Multiple Selections

```swift
class MultiSelectionStorage {
    private let defaults: UserDefaults

    init(suiteName: String) {
        self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    func save(_ selection: FamilyActivitySelection, for key: SelectionKey) throws {
        let encoder = PropertyListEncoder()
        let data = try encoder.encode(selection)
        defaults.set(data, forKey: key.rawValue)
    }

    func load(for key: SelectionKey) throws -> FamilyActivitySelection {
        guard let data = defaults.data(forKey: key.rawValue) else {
            return FamilyActivitySelection()
        }
        return try PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
    }
}

enum SelectionKey: String {
    case focusMode = "selection.focusMode"
    case bedtime = "selection.bedtime"
    case homework = "selection.homework"
}
```

---

## Token Types

### ApplicationToken

Represents a specific application. Cannot be decoded to reveal the app's name or bundle ID.

```swift
// ApplicationToken is Hashable and Codable
let appTokens: Set<ApplicationToken> = selection.applicationTokens

// Check if token set contains a specific token
if appTokens.contains(someToken) {
    print("Token is in selection")
}
```

### ActivityCategoryToken

Represents an App Store category (e.g., Games, Social Networking).

```swift
let categoryTokens: Set<ActivityCategoryToken> = selection.categoryTokens

// Use with ManagedSettingsStore
store.shield.applicationCategories = .specific(categoryTokens)
```

### WebDomainToken

Represents a specific web domain.

```swift
let domainTokens: Set<WebDomainToken> = selection.webDomainTokens

// Use with ManagedSettingsStore
store.shield.webDomains = domainTokens
```

---

## Complete Example

```swift
import SwiftUI
import FamilyControls

@MainActor
@Observable
class ScreenTimeViewModel {
    var isAuthorized = false
    var selection = FamilyActivitySelection()
    var showPicker = false

    private let storage = SelectionStorage(suiteName: "group.com.yourcompany.yourapp")

    init() {
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
        loadSavedSelection()
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
        } catch {
            print("Authorization failed: \(error)")
            isAuthorized = false
        }
    }

    func saveSelection() {
        do {
            try storage.save(selection)
        } catch {
            print("Failed to save: \(error)")
        }
    }

    private func loadSavedSelection() {
        if let saved = try? storage.load() {
            selection = saved
        }
    }
}

struct ContentView: View {
    @State private var viewModel = ScreenTimeViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if viewModel.isAuthorized {
                    authorizedContent
                } else {
                    unauthorizedContent
                }
            }
            .padding()
            .navigationTitle("Screen Time")
        }
    }

    private var unauthorizedContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "hourglass")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("Screen Time Access Required")
                .font(.headline)

            Text("Grant access to monitor and manage your app usage.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Enable Screen Time") {
                Task {
                    await viewModel.requestAuthorization()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var authorizedContent: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Screen Time Enabled")
            }
            .font(.headline)

            Button("Select Apps to Monitor") {
                viewModel.showPicker = true
            }
            .buttonStyle(.bordered)

            if !viewModel.selection.applicationTokens.isEmpty {
                Text("\(viewModel.selection.applicationTokens.count) apps selected")
                    .foregroundStyle(.secondary)
            }
        }
        .familyActivityPicker(
            isPresented: $viewModel.showPicker,
            selection: $viewModel.selection
        )
        .onChange(of: viewModel.selection) { _, _ in
            viewModel.saveSelection()
        }
    }
}
```

---

## Error Handling

### Common Authorization Errors

```swift
func handleAuthorizationError(_ error: Error) {
    if let familyControlsError = error as? FamilyControlsError {
        switch familyControlsError {
        case .restricted:
            // Device is in supervised mode or has restrictions
            showAlert("This device has restrictions that prevent Screen Time access.")

        case .unavailable:
            // Screen Time is not available on this device
            showAlert("Screen Time features are not available on this device.")

        case .invalidAccountType:
            // Invalid Apple ID configuration
            showAlert("Please sign in with a valid Apple ID.")

        case .invalidArgument:
            // Invalid parameters passed
            showAlert("An error occurred. Please try again.")

        case .authorizationConflict:
            // Another authorization is in progress
            showAlert("Please wait and try again.")

        case .authorizationCanceled:
            // User canceled the authorization
            showAlert("Authorization was canceled.")

        case .networkError:
            // Network connectivity issue
            showAlert("Please check your internet connection and try again.")

        @unknown default:
            showAlert("An unexpected error occurred: \(error.localizedDescription)")
        }
    }
}
```

### Graceful Degradation

```swift
func setupScreenTime() async {
    guard AuthorizationCenter.shared.authorizationStatus != .denied else {
        // Show limited functionality mode
        enableBasicMode()
        return
    }

    do {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        enableFullMode()
    } catch {
        handleAuthorizationError(error)
        enableBasicMode()
    }
}
```

---

## Best Practices

### 1. Explain Before Requesting
Always show an explanation screen before requesting authorization:

```swift
struct OnboardingView: View {
    @State private var showingAuth = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "hourglass.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            Text("Take Control of Your Time")
                .font(.title.bold())

            Text("We'll help you manage your app usage by monitoring which apps you use and for how long.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Get Started") {
                showingAuth = true
            }
            .buttonStyle(.borderedProminent)
        }
        .sheet(isPresented: $showingAuth) {
            AuthorizationRequestView()
        }
    }
}
```

### 2. Handle Denied State Gracefully
```swift
struct SettingsView: View {
    var isAuthorized: Bool

    var body: some View {
        if !isAuthorized {
            Section {
                Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                    Label("Enable in Settings", systemImage: "gear")
                }
            } header: {
                Text("Screen Time Access Required")
            } footer: {
                Text("Open Settings to grant Screen Time access for full functionality.")
            }
        }
    }
}
```

### 3. Persist Selection Immediately
Save selection as soon as it changes to prevent data loss:

```swift
.onChange(of: selection) { _, newValue in
    Task {
        try? storage.save(newValue)
    }
}
```

---

## Related Frameworks

- [ManagedSettings Guide](managedsettings-guide.md) - Apply shields and restrictions
- [DeviceActivity Guide](deviceactivity-guide.md) - Monitor usage and schedule events
- [Screen Time API Overview](screen-time-api-guide.md) - Complete API overview

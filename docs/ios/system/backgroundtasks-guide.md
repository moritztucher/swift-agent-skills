# BackgroundTasks Framework Guide for iOS

A comprehensive guide to implementing background tasks in iOS applications using the BackgroundTasks framework with Swift, SwiftUI, and async/await patterns.

---

## Table of Contents

1. [Overview & Purpose](#overview--purpose)
2. [Setup & Configuration](#setup--configuration)
3. [Core Concepts](#core-concepts)
4. [Registering Task Handlers](#registering-task-handlers)
5. [Scheduling App Refresh Tasks](#scheduling-app-refresh-tasks)
6. [Scheduling Processing Tasks](#scheduling-processing-tasks)
7. [Handling Task Execution](#handling-task-execution)
8. [Testing Background Tasks](#testing-background-tasks)
9. [iOS 18/26 Specific Features](#ios-1826-specific-features)
10. [Common Use Cases](#common-use-cases)
11. [Best Practices & Limitations](#best-practices--limitations)

---

## Overview & Purpose

The **BackgroundTasks** framework enables your app to perform work while it is not running in the foreground. It provides a system-managed approach to scheduling background work that respects device resources, battery life, and user preferences.

### Key Benefits

- **Content Freshness**: Keep app content up-to-date before user launches
- **Maintenance Operations**: Perform database cleanup, cache management, and sync operations
- **Resource-Aware Scheduling**: System optimizes task execution based on device state
- **Battery Efficiency**: Tasks run at optimal times to minimize battery impact

### Framework Import

```swift
import BackgroundTasks
```

### Supported Platforms

- iOS 13.0+
- iPadOS 13.0+
- Mac Catalyst 13.0+
- tvOS 13.0+
- watchOS (limited support)

---

## Setup & Configuration

### 1. Enable Background Modes Capability

In Xcode, navigate to your target's **Signing & Capabilities** tab:

1. Click **+ Capability**
2. Add **Background Modes**
3. Enable the following options as needed:
   - **Background fetch** (for `BGAppRefreshTask`)
   - **Background processing** (for `BGProcessingTask`)

### 2. Configure Info.plist

Add permitted task identifiers to your `Info.plist`:

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.yourcompany.yourapp.refresh</string>
    <string>com.yourcompany.yourapp.processing</string>
    <string>com.yourcompany.yourapp.databaseCleanup</string>
</array>
```

Or using Xcode's Property List Editor:
- Key: `Permitted background task scheduler identifiers`
- Type: Array
- Value: Your task identifier strings

### Task Identifier Naming Convention

Use reverse DNS notation prefixed with your bundle identifier:

```
com.yourcompany.yourapp.taskName
```

**Examples:**
- `com.myapp.sync.content`
- `com.myapp.maintenance.cleanup`
- `com.myapp.refresh.feed`

---

## Core Concepts

### BGTaskScheduler

The central class for managing background tasks. It is a singleton accessed via `BGTaskScheduler.shared`.

**Key Responsibilities:**
- Register task handlers at app launch
- Submit task requests for scheduling
- Cancel pending task requests
- Query supported resources (iOS 26+)

```swift
let scheduler = BGTaskScheduler.shared
```

### BGTask (Abstract Base)

The abstract base class for all background tasks. You never instantiate this directly.

**Properties:**
- `identifier`: The task's unique identifier string
- `expirationHandler`: Closure called when runtime is about to expire

**Methods:**
- `setTaskCompleted(success:)`: Mark task as finished

### BGAppRefreshTask

A short-duration task for refreshing app content. Ideal for:
- Fetching new data from servers
- Updating widgets
- Syncing lightweight content

**Characteristics:**
- Limited runtime (approximately 30 seconds)
- Scheduled based on user's app usage patterns
- Higher execution frequency for frequently-used apps

### BGProcessingTask

A longer-duration task for maintenance and processing work. Ideal for:
- Database maintenance
- Machine learning model updates
- Large data synchronization
- Cache cleanup

**Characteristics:**
- Extended runtime when device is charging
- Can require external power
- Can require network connectivity
- Lower execution priority than app refresh

### BGContinuedProcessingTask (iOS 26+)

A new task type for continuing user-initiated work in the background.

**Characteristics:**
- Must be initiated by explicit user action
- Provides progress updates in system UI
- User can monitor and cancel
- Supports background GPU access on supported devices

---

## Registering Task Handlers

Task handlers must be registered **immediately** during app launch, before the app finishes launching.

### UIKit App Delegate Registration

```swift
import UIKit
import BackgroundTasks

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        registerBackgroundTasks()
        return true
    }

    // MARK: - Background Task Registration

    private func registerBackgroundTasks() {
        // Register app refresh task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.myapp.refresh",
            using: nil  // nil uses main queue
        ) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }

        // Register processing task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.myapp.processing",
            using: nil
        ) { task in
            self.handleProcessing(task: task as! BGProcessingTask)
        }
    }

    private func handleAppRefresh(task: BGAppRefreshTask) {
        // Handle refresh (see Handling Task Execution section)
    }

    private func handleProcessing(task: BGProcessingTask) {
        // Handle processing (see Handling Task Execution section)
    }
}
```

### SwiftUI App Registration

For SwiftUI apps, register tasks in the `App` initializer:

```swift
import SwiftUI
import BackgroundTasks

@main
struct MyApp: App {

    init() {
        registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    // MARK: - Background Task Registration

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.myapp.refresh",
            using: nil
        ) { task in
            Task {
                await handleAppRefresh(task: task as! BGAppRefreshTask)
            }
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.myapp.processing",
            using: nil
        ) { task in
            Task {
                await handleProcessing(task: task as! BGProcessingTask)
            }
        }
    }

    private func handleAppRefresh(task: BGAppRefreshTask) async {
        // Implementation
    }

    private func handleProcessing(task: BGProcessingTask) async {
        // Implementation
    }
}
```

### SwiftUI Background Task Modifier (iOS 16+)

SwiftUI provides a declarative approach using the `backgroundTask` modifier:

```swift
import SwiftUI

@main
struct MyApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                scheduleAppRefresh()
            }
        }
        .backgroundTask(.appRefresh("com.myapp.refresh")) {
            await performAppRefresh()
        }
        .backgroundTask(.urlSession("com.myapp.upload")) {
            // Handle URL session background events
        }
    }

    private func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.myapp.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule app refresh: \(error)")
        }
    }

    private func performAppRefresh() async {
        // Async refresh implementation
        // SwiftUI automatically handles task completion
    }
}
```

---

## Scheduling App Refresh Tasks

### Creating and Submitting a Request

```swift
func scheduleAppRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: "com.myapp.refresh")

    // Set earliest begin date (minimum 15 minutes recommended)
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)

    do {
        try BGTaskScheduler.shared.submit(request)
        print("App refresh scheduled successfully")
    } catch BGTaskScheduler.Error.notPermitted {
        print("Background refresh not permitted - check capabilities and Info.plist")
    } catch BGTaskScheduler.Error.tooManyPendingTaskRequests {
        print("Too many pending requests - only 1 refresh task allowed at a time")
    } catch BGTaskScheduler.Error.unavailable {
        print("Background tasks unavailable on this device")
    } catch {
        print("Failed to schedule app refresh: \(error)")
    }
}
```

### Scheduling on App Background

Schedule refresh when the app moves to background:

```swift
// UIKit - SceneDelegate
func sceneDidEnterBackground(_ scene: UIScene) {
    scheduleAppRefresh()
}

// SwiftUI
@Environment(\.scenePhase) private var scenePhase

.onChange(of: scenePhase) { oldPhase, newPhase in
    if newPhase == .background {
        scheduleAppRefresh()
    }
}
```

### Important Constraints

- **Only 1 app refresh task** can be scheduled at a time
- System may adjust or delay execution based on:
  - User's app usage patterns
  - Battery level and charging state
  - Network conditions
  - Device activity

---

## Scheduling Processing Tasks

### Creating a Processing Task Request

```swift
func scheduleProcessingTask() {
    let request = BGProcessingTaskRequest(identifier: "com.myapp.databaseCleanup")

    // Set earliest begin date
    request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 hour from now

    // Require external power for battery-intensive work
    request.requiresExternalPower = true

    // Require network for tasks that need connectivity
    request.requiresNetworkConnectivity = true

    do {
        try BGTaskScheduler.shared.submit(request)
        print("Processing task scheduled")
    } catch {
        print("Failed to schedule processing task: \(error)")
    }
}
```

### Processing Task Options

| Property | Type | Description |
|----------|------|-------------|
| `earliestBeginDate` | `Date?` | Earliest time the task can begin |
| `requiresExternalPower` | `Bool` | Task only runs when device is charging |
| `requiresNetworkConnectivity` | `Bool` | Task only runs with network available |

### When to Use `requiresExternalPower`

Set to `true` for:
- Machine learning model training/updates
- Large database operations
- Computationally intensive tasks
- Tasks that would noticeably impact battery

```swift
// ML model update - requires power and network
let mlUpdateRequest = BGProcessingTaskRequest(identifier: "com.myapp.mlUpdate")
mlUpdateRequest.requiresExternalPower = true
mlUpdateRequest.requiresNetworkConnectivity = true
mlUpdateRequest.earliestBeginDate = Date(timeIntervalSinceNow: 2 * 60 * 60)

// Cache cleanup - doesn't need power or network
let cleanupRequest = BGProcessingTaskRequest(identifier: "com.myapp.cacheCleanup")
cleanupRequest.requiresExternalPower = false
cleanupRequest.requiresNetworkConnectivity = false
```

### Important Constraints

- **Up to 10 processing tasks** can be scheduled at a time
- Tasks requiring external power only run when charging
- System prioritizes based on device conditions

---

## Handling Task Execution

### Basic Task Handler Pattern

```swift
private func handleAppRefresh(task: BGAppRefreshTask) {
    // 1. Schedule the next refresh immediately
    scheduleAppRefresh()

    // 2. Create an async task for the work
    let refreshTask = Task {
        do {
            try await performRefresh()
            task.setTaskCompleted(success: true)
        } catch {
            task.setTaskCompleted(success: false)
        }
    }

    // 3. Set expiration handler to cancel work gracefully
    task.expirationHandler = {
        refreshTask.cancel()
    }
}

private func performRefresh() async throws {
    // Check for cancellation periodically
    try Task.checkCancellation()

    // Fetch new content
    let newContent = try await networkService.fetchLatestContent()

    try Task.checkCancellation()

    // Update local storage
    try await dataManager.update(with: newContent)
}
```

### Processing Task Handler with Progress

```swift
private func handleProcessingTask(task: BGProcessingTask) {
    let processingTask = Task {
        do {
            try await performDatabaseMaintenance()
            task.setTaskCompleted(success: true)
        } catch is CancellationError {
            // Task was cancelled due to expiration
            task.setTaskCompleted(success: false)
        } catch {
            print("Processing failed: \(error)")
            task.setTaskCompleted(success: false)
        }
    }

    task.expirationHandler = {
        processingTask.cancel()
    }
}

private func performDatabaseMaintenance() async throws {
    let items = try await database.fetchItemsNeedingCleanup()

    for item in items {
        try Task.checkCancellation()
        try await database.cleanup(item)
    }

    try Task.checkCancellation()
    try await database.vacuum()
}
```

### SwiftUI Background Task Handler

SwiftUI's `backgroundTask` modifier provides automatic task completion:

```swift
.backgroundTask(.appRefresh("com.myapp.refresh")) {
    // Schedule next refresh
    scheduleAppRefresh()

    // Perform async work
    await withTaskCancellationHandler {
        do {
            try await refreshContent()
        } catch {
            // Handle error
        }
    } onCancel: {
        // Cleanup when cancelled
    }

    // Task completion is automatic when closure returns
}
```

### Handling Cancellation Gracefully

```swift
private func handleAppRefresh(task: BGAppRefreshTask) async {
    scheduleAppRefresh()

    await withTaskCancellationHandler {
        do {
            // Use withCheckedThrowingContinuation for legacy APIs if needed
            try await performRefreshWork()
            task.setTaskCompleted(success: true)
        } catch is CancellationError {
            task.setTaskCompleted(success: false)
        } catch {
            task.setTaskCompleted(success: false)
        }
    } onCancel: {
        // This is called when task.expirationHandler fires
        print("Refresh task expired, cleaning up...")
    }
}
```

---

## Testing Background Tasks

### LLDB Debugger Commands

Since the system controls when background tasks run, Apple provides LLDB commands to simulate task execution during development.

#### Simulate Task Launch

1. Run your app on a **real device** (Simulator has limitations)
2. Pause execution in Xcode's debugger
3. Enter in the LLDB console:

```lldb
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.myapp.refresh"]
```

4. Resume execution - your task handler will be called

#### Simulate Task Expiration

To test your expiration handler:

```lldb
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateExpirationForTaskWithIdentifier:@"com.myapp.refresh"]
```

### Testing Checklist

1. **Test on Real Device**: Simulator doesn't accurately simulate background behavior
2. **Test Task Registration**: Verify handlers are called
3. **Test Expiration Handling**: Ensure graceful cancellation
4. **Test Error Scenarios**: Handle network failures, insufficient storage
5. **Verify Task Completion**: Always call `setTaskCompleted(success:)`

### Debugging Tips

**Problem**: Task handler never called

**Solutions**:
- Verify identifier in Info.plist matches exactly
- Ensure registration happens at launch
- Check Background Modes capability is enabled
- Test on real device, not simulator

**Problem**: Tasks scheduled but never run

**Considerations**:
- System optimizes based on user patterns
- Low Power Mode disables background refresh
- User may have disabled Background App Refresh
- Debugger prevents app suspension

### Testing Without Debugger

For realistic testing:

1. Run app from Home screen (not Xcode)
2. Use **Xcode > Debug > Attach to Process** if debugging needed
3. Wait for system to naturally schedule tasks
4. Check Console.app for system logs

---

## iOS 18/26 Specific Features

### BGContinuedProcessingTask (iOS 26+)

A new task type for continuing user-initiated foreground work in the background.

#### Key Characteristics

- **User-Initiated**: Must start from explicit user action (button tap, gesture)
- **Progress Visible**: Shows progress in system UI
- **User Control**: User can monitor and cancel at any time
- **Measurable Progress**: Must report clear progress updates

#### Info.plist Configuration

Supports wildcard notation for dynamic identifiers:

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.myapp.userTask.*</string>
</array>
```

#### Registration (Dynamic)

Unlike other tasks, `BGContinuedProcessingTask` can be registered dynamically:

```swift
func registerContinuedProcessingTask(identifier: String) {
    BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
        guard let continuedTask = task as? BGContinuedProcessingTask else { return }

        Task {
            await handleContinuedProcessing(task: continuedTask)
        }
    }
}
```

#### Submitting a Request

```swift
func startBackgroundExport(title: String, subtitle: String) {
    let identifier = "com.myapp.userTask.export"

    // Register if not already registered
    registerContinuedProcessingTask(identifier: identifier)

    let request = BGContinuedProcessingTaskRequest(
        identifier: identifier,
        title: title,
        subtitle: subtitle
    )

    // Optional: Fail immediately if can't start in background
    request.strategy = .fail

    do {
        try BGTaskScheduler.shared.submit(request)
    } catch {
        print("Failed to submit continued processing task: \(error)")
    }
}
```

#### Handling with Progress

```swift
func handleContinuedProcessing(task: BGContinuedProcessingTask) async {
    var shouldContinue = true

    // Set expiration handler
    task.expirationHandler = {
        shouldContinue = false
    }

    // Configure progress
    task.progress.totalUnitCount = 100
    task.progress.completedUnitCount = 0

    // Perform work with progress updates
    for i in 0..<100 {
        guard shouldContinue else {
            task.setTaskCompleted(success: false)
            return
        }

        await performWorkUnit(i)
        task.progress.completedUnitCount = Int64(i + 1)
    }

    task.setTaskCompleted(success: true)
}
```

### Background GPU Access (iOS 26+)

Continued processing tasks can access GPU in the background on supported devices:

```swift
// Check supported resources
let supportedResources = BGTaskScheduler.shared.supportedResources

// Enable in Xcode: Target > Signing & Capabilities > Background GPU
```

### Enhanced Scheduling Intelligence (iOS 18+)

iOS 18 introduced smarter scheduling with:
- Better battery and usage pattern analysis
- Improved rate limiting for push notifications
- More efficient coalescing of background work

---

## Common Use Cases

### 1. Content Synchronization

```swift
func handleContentSync(task: BGAppRefreshTask) {
    scheduleAppRefresh()

    let syncTask = Task {
        do {
            let changes = try await syncService.fetchChanges()
            try await dataStore.apply(changes)
            task.setTaskCompleted(success: true)
        } catch {
            task.setTaskCompleted(success: false)
        }
    }

    task.expirationHandler = {
        syncTask.cancel()
    }
}
```

### 2. Database Maintenance

```swift
func handleDatabaseMaintenance(task: BGProcessingTask) {
    let maintenanceTask = Task {
        do {
            // Delete old records
            try await database.deleteExpiredRecords()

            try Task.checkCancellation()

            // Compact database
            try await database.vacuum()

            try Task.checkCancellation()

            // Rebuild indexes
            try await database.rebuildIndexes()

            task.setTaskCompleted(success: true)
        } catch {
            task.setTaskCompleted(success: false)
        }
    }

    task.expirationHandler = {
        maintenanceTask.cancel()
    }
}
```

### 3. Machine Learning Model Updates

```swift
func handleMLModelUpdate(task: BGProcessingTask) {
    let updateTask = Task {
        do {
            // Download new model
            let modelData = try await mlService.downloadLatestModel()

            try Task.checkCancellation()

            // Validate model
            try await mlService.validateModel(modelData)

            try Task.checkCancellation()

            // Replace existing model
            try await mlService.installModel(modelData)

            task.setTaskCompleted(success: true)
        } catch {
            task.setTaskCompleted(success: false)
        }
    }

    task.expirationHandler = {
        updateTask.cancel()
    }
}

// Schedule with power requirement
func scheduleMLUpdate() {
    let request = BGProcessingTaskRequest(identifier: "com.myapp.mlUpdate")
    request.requiresExternalPower = true
    request.requiresNetworkConnectivity = true
    request.earliestBeginDate = Date(timeIntervalSinceNow: 24 * 60 * 60) // Tomorrow

    try? BGTaskScheduler.shared.submit(request)
}
```

### 4. Cache Cleanup

```swift
func handleCacheCleanup(task: BGProcessingTask) {
    let cleanupTask = Task {
        do {
            let cacheManager = CacheManager.shared

            // Remove expired items
            try await cacheManager.removeExpiredItems()

            try Task.checkCancellation()

            // Trim cache to size limit
            try await cacheManager.trimToSizeLimit()

            task.setTaskCompleted(success: true)
        } catch {
            task.setTaskCompleted(success: false)
        }
    }

    task.expirationHandler = {
        cleanupTask.cancel()
    }
}
```

### 5. Widget Data Refresh

```swift
func handleWidgetRefresh(task: BGAppRefreshTask) {
    scheduleAppRefresh()

    let refreshTask = Task {
        do {
            // Fetch fresh data
            let data = try await dataService.fetchWidgetData()

            // Update shared container for widget
            try await sharedDataStore.update(data)

            // Reload widget timelines
            WidgetCenter.shared.reloadAllTimelines()

            task.setTaskCompleted(success: true)
        } catch {
            task.setTaskCompleted(success: false)
        }
    }

    task.expirationHandler = {
        refreshTask.cancel()
    }
}
```

---

## Best Practices & Limitations

### Best Practices

#### 1. Register Tasks Immediately at Launch

```swift
// Do this in application(_:didFinishLaunchingWithOptions:) or App.init()
func registerBackgroundTasks() {
    BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.myapp.refresh", using: nil) { task in
        // Handler
    }
}
```

#### 2. Always Schedule Next Task

```swift
func handleRefresh(task: BGAppRefreshTask) {
    // FIRST: Schedule next occurrence
    scheduleAppRefresh()

    // THEN: Do work
    // ...
}
```

#### 3. Handle Expiration Gracefully

```swift
task.expirationHandler = {
    // Cancel ongoing work
    workTask.cancel()
    // Save progress
    saveCheckpoint()
}
```

#### 4. Always Complete Tasks

```swift
// ALWAYS call setTaskCompleted - even on failure
task.setTaskCompleted(success: false)
```

#### 5. Check Cancellation Frequently

```swift
for item in items {
    try Task.checkCancellation()
    await process(item)
}
```

#### 6. Use Appropriate Task Type

| Need | Use |
|------|-----|
| Quick content refresh | `BGAppRefreshTask` |
| Long maintenance work | `BGProcessingTask` |
| User-initiated background work | `BGContinuedProcessingTask` (iOS 26+) |

#### 7. Set Power Requirements Appropriately

```swift
// Heavy computation
request.requiresExternalPower = true

// Lightweight sync
request.requiresExternalPower = false
```

### Limitations

#### Time Constraints

| Task Type | Approximate Runtime |
|-----------|---------------------|
| BGAppRefreshTask | ~30 seconds |
| BGProcessingTask | Several minutes (when charging) |
| BGContinuedProcessingTask | Extended (with progress) |

#### Scheduling Limits

- **1 app refresh task** pending at a time
- **10 processing tasks** pending at a time
- System may delay or skip tasks based on conditions

#### System Control

The system decides when to run tasks based on:
- User's app usage patterns
- Battery level and charging state
- Network conditions
- Device activity and resources
- Time of day

#### Low Power Mode

- **Disables** background refresh entirely
- Processing tasks may be cancelled or delayed
- No guaranteed execution

#### User Settings

Users can disable Background App Refresh:
- Per-app in Settings > General > Background App Refresh
- Globally for all apps

#### Device State

- Tasks may not run if device is low on battery
- Tasks requiring network won't run without connectivity
- Heavy system load may delay task execution

### Common Mistakes to Avoid

1. **Relying on exact timing**: Tasks are opportunistic, not scheduled
2. **Not handling cancellation**: Always implement expiration handlers
3. **Forgetting to complete tasks**: Always call `setTaskCompleted`
4. **Registering tasks late**: Must register at launch
5. **Using background tasks for critical features**: They're unreliable by design
6. **Not testing on real devices**: Simulator behavior differs significantly

### Debugging Checklist

- [ ] Task identifier in Info.plist matches code exactly
- [ ] Background Modes capability enabled
- [ ] Registration happens at app launch
- [ ] Expiration handler implemented
- [ ] `setTaskCompleted` always called
- [ ] Testing on real device
- [ ] Checking device isn't in Low Power Mode
- [ ] Background App Refresh enabled in Settings

---

## References

- [Apple Developer Documentation - BackgroundTasks](https://developer.apple.com/documentation/backgroundtasks)
- [WWDC25 - Finish tasks in the background](https://developer.apple.com/videos/play/wwdc2025/227/)
- [WWDC22 - Efficiency awaits: Background tasks in SwiftUI](https://developer.apple.com/videos/play/wwdc2022/10142/)
- [Apple Developer Documentation - Starting and Terminating Tasks During Development](https://developer.apple.com/documentation/backgroundtasks/starting-and-terminating-tasks-during-development)
- [Apple Developer Documentation - Choosing Background Strategies for Your App](https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app)

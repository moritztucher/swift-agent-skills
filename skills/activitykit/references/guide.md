# ActivityKit Guide for iOS Development

**Date Created:** 2026-02-03
**iOS Version:** iOS 16.1+ (Live Activities), iOS 16.2+ (Push Updates)
**Framework:** ActivityKit
**Related Frameworks:** WidgetKit, SwiftUI

---

## Overview

ActivityKit enables Live Activities - real-time, glanceable updates that appear on the Lock Screen and in the Dynamic Island on iPhone 14 Pro and later. Live Activities help users stay informed about ongoing tasks, events, or activities without needing to open your app.

### Key Use Cases

- **Delivery Tracking:** Food delivery progress, package tracking
- **Sports:** Live game scores and statistics
- **Rides:** Ride-sharing trip progress
- **Timers:** Workout timers, cooking timers
- **Travel:** Flight status, boarding updates
- **Media:** Now playing information

### Display Locations

1. **Lock Screen:** Persistent widget-like presentation
2. **Dynamic Island (Compact):** Small indicators on either side of the camera cutout
3. **Dynamic Island (Expanded):** Full expanded view when long-pressed or during updates
4. **Dynamic Island (Minimal):** Smallest representation when another Live Activity is active
5. **StandBy Mode:** Full-screen presentation on iPhone in landscape charging mode (iOS 17+)

---

## Setup & Configuration

### 1. Info.plist Configuration

Add the following key to enable Live Activities:

```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

For push-based updates (iOS 16.2+), also add:

```xml
<key>NSSupportsLiveActivitiesFrequentUpdates</key>
<true/>
```

### 2. Widget Extension Target

Live Activities are part of WidgetKit, so you need a Widget Extension:

1. In Xcode, go to **File > New > Target**
2. Select **Widget Extension**
3. Name it appropriately (e.g., `YourAppWidgets`)
4. Ensure "Include Live Activity" is checked

### 3. Shared Framework for ActivityAttributes

Create a shared framework or place your `ActivityAttributes` definition in a location accessible by both your main app and widget extension. This is critical because both targets need access to the same type definition.

---

## Core Concepts & APIs

### ActivityAttributes Protocol

The `ActivityAttributes` protocol defines the static and dynamic data for your Live Activity.

```swift
import ActivityKit

struct DeliveryActivityAttributes: ActivityAttributes {
    // MARK: - ContentState (Dynamic Data)
    /// Data that changes throughout the activity's lifecycle
    struct ContentState: Codable, Hashable {
        var currentStatus: DeliveryStatus
        var driverName: String
        var estimatedDeliveryTime: Date
        var currentLocation: String
    }

    // MARK: - Static Data (Set at creation, never changes)
    let orderNumber: String
    let restaurantName: String
    let orderItems: [String]
}

enum DeliveryStatus: String, Codable {
    case preparing
    case pickedUp
    case onTheWay
    case arriving
    case delivered
}
```

**Key Points:**
- `ContentState` contains data that can be updated during the activity
- Properties outside `ContentState` are static and set when the activity starts
- Both must conform to `Codable` and `Hashable`

### ActivityContent

Wraps the current state with metadata like stale date:

```swift
let contentState = DeliveryActivityAttributes.ContentState(
    currentStatus: .preparing,
    driverName: "Alex",
    estimatedDeliveryTime: Date().addingTimeInterval(1800),
    currentLocation: "Restaurant"
)

let activityContent = ActivityContent(
    state: contentState,
    staleDate: Calendar.current.date(byAdding: .minute, value: 30, to: Date())
)
```

**Stale Date:** When the content is considered outdated. The system may dim or indicate staleness to users.

### Activity Class

The main class for managing Live Activities:

```swift
// Type alias for cleaner code
typealias DeliveryActivity = Activity<DeliveryActivityAttributes>
```

---

## Starting a Live Activity

### Basic Request

```swift
import ActivityKit

func startDeliveryActivity(orderNumber: String, restaurant: String, items: [String]) async throws -> Activity<DeliveryActivityAttributes> {
    // 1. Check if Live Activities are enabled
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
        throw LiveActivityError.notAuthorized
    }

    // 2. Define static attributes
    let attributes = DeliveryActivityAttributes(
        orderNumber: orderNumber,
        restaurantName: restaurant,
        orderItems: items
    )

    // 3. Define initial dynamic state
    let initialState = DeliveryActivityAttributes.ContentState(
        currentStatus: .preparing,
        driverName: "Assigning driver...",
        estimatedDeliveryTime: Date().addingTimeInterval(2400),
        currentLocation: restaurant
    )

    // 4. Create activity content with stale date
    let activityContent = ActivityContent(
        state: initialState,
        staleDate: Calendar.current.date(byAdding: .minute, value: 45, to: Date())
    )

    // 5. Request the activity
    let activity = try Activity.request(
        attributes: attributes,
        content: activityContent,
        pushType: nil  // Set to .token for push updates
    )

    print("Started Live Activity with ID: \(activity.id)")
    return activity
}
```

### With Push Token Support

```swift
func startDeliveryActivityWithPush(
    orderNumber: String,
    restaurant: String,
    items: [String]
) async throws -> (activity: Activity<DeliveryActivityAttributes>, pushToken: Data?) {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
        throw LiveActivityError.notAuthorized
    }

    let attributes = DeliveryActivityAttributes(
        orderNumber: orderNumber,
        restaurantName: restaurant,
        orderItems: items
    )

    let initialState = DeliveryActivityAttributes.ContentState(
        currentStatus: .preparing,
        driverName: "Assigning driver...",
        estimatedDeliveryTime: Date().addingTimeInterval(2400),
        currentLocation: restaurant
    )

    let activityContent = ActivityContent(
        state: initialState,
        staleDate: Calendar.current.date(byAdding: .minute, value: 45, to: Date())
    )

    // Request with push type
    let activity = try Activity.request(
        attributes: attributes,
        content: activityContent,
        pushType: .token  // Enable push updates
    )

    // Get the push token
    var pushToken: Data?
    for await token in activity.pushTokenUpdates {
        pushToken = token
        break  // Get first token and exit
    }

    return (activity, pushToken)
}
```

---

## Updating a Live Activity

### Local Updates

```swift
func updateDeliveryActivity(
    activity: Activity<DeliveryActivityAttributes>,
    newState: DeliveryActivityAttributes.ContentState
) async {
    let updatedContent = ActivityContent(
        state: newState,
        staleDate: Calendar.current.date(byAdding: .minute, value: 30, to: Date())
    )

    await activity.update(updatedContent)
}

// Usage
let newState = DeliveryActivityAttributes.ContentState(
    currentStatus: .onTheWay,
    driverName: "Alex",
    estimatedDeliveryTime: Date().addingTimeInterval(900),
    currentLocation: "5 minutes away"
)

await updateDeliveryActivity(activity: deliveryActivity, newState: newState)
```

### With Alert Configuration

```swift
func updateWithAlert(
    activity: Activity<DeliveryActivityAttributes>,
    newState: DeliveryActivityAttributes.ContentState,
    alertTitle: String,
    alertBody: String
) async {
    let updatedContent = ActivityContent(
        state: newState,
        staleDate: Calendar.current.date(byAdding: .minute, value: 30, to: Date())
    )

    let alertConfig = AlertConfiguration(
        title: LocalizedStringResource(stringLiteral: alertTitle),
        body: LocalizedStringResource(stringLiteral: alertBody),
        sound: .default
    )

    await activity.update(updatedContent, alertConfiguration: alertConfig)
}
```

### Finding Active Activities

```swift
func findDeliveryActivity(orderNumber: String) -> Activity<DeliveryActivityAttributes>? {
    Activity<DeliveryActivityAttributes>.activities.first { activity in
        activity.attributes.orderNumber == orderNumber
    }
}

// Get all active delivery activities
func getAllActiveDeliveries() -> [Activity<DeliveryActivityAttributes>] {
    Array(Activity<DeliveryActivityAttributes>.activities)
}
```

---

## Ending a Live Activity

### Immediate Dismissal

```swift
func endDeliveryActivity(activity: Activity<DeliveryActivityAttributes>) async {
    let finalState = DeliveryActivityAttributes.ContentState(
        currentStatus: .delivered,
        driverName: activity.content.state.driverName,
        estimatedDeliveryTime: Date(),
        currentLocation: "Delivered"
    )

    let finalContent = ActivityContent(
        state: finalState,
        staleDate: nil
    )

    await activity.end(finalContent, dismissalPolicy: .immediate)
}
```

### Dismissal After Delay

```swift
func endDeliveryActivityWithDelay(activity: Activity<DeliveryActivityAttributes>) async {
    let finalState = DeliveryActivityAttributes.ContentState(
        currentStatus: .delivered,
        driverName: activity.content.state.driverName,
        estimatedDeliveryTime: Date(),
        currentLocation: "Delivered"
    )

    let finalContent = ActivityContent(
        state: finalState,
        staleDate: nil
    )

    // Keep on Lock Screen for up to 4 hours or until user dismisses
    await activity.end(finalContent, dismissalPolicy: .default)

    // Or specify exact time
    // await activity.end(finalContent, dismissalPolicy: .after(Date().addingTimeInterval(3600)))
}
```

### End All Activities for an Order

```swift
func endAllActivitiesForOrder(_ orderNumber: String) async {
    for activity in Activity<DeliveryActivityAttributes>.activities {
        if activity.attributes.orderNumber == orderNumber {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
```

---

## Widget Extension Implementation

### ActivityConfiguration

```swift
import WidgetKit
import SwiftUI

@main
struct DeliveryWidgets: WidgetBundle {
    var body: some Widget {
        // Regular widgets
        DeliveryStatusWidget()

        // Live Activity
        DeliveryLiveActivity()
    }
}

struct DeliveryLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DeliveryActivityAttributes.self) { context in
            // Lock Screen presentation
            DeliveryLockScreenView(context: context)
                .activityBackgroundTint(.black.opacity(0.8))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded regions
                DynamicIslandExpandedRegion(.leading) {
                    DeliveryExpandedLeadingView(context: context)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    DeliveryExpandedTrailingView(context: context)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    DeliveryExpandedBottomView(context: context)
                }

                DynamicIslandExpandedRegion(.center) {
                    DeliveryExpandedCenterView(context: context)
                }
            } compactLeading: {
                // Compact leading (left side of Dynamic Island)
                Image(systemName: "box.truck.fill")
                    .foregroundColor(.green)
            } compactTrailing: {
                // Compact trailing (right side of Dynamic Island)
                Text(context.state.estimatedDeliveryTime, style: .timer)
                    .monospacedDigit()
                    .frame(width: 50)
                    .foregroundColor(.green)
            } minimal: {
                // Minimal (when another activity is active)
                Image(systemName: "box.truck.fill")
                    .foregroundColor(.green)
            }
            .widgetURL(URL(string: "myapp://order/\(context.attributes.orderNumber)"))
            .keylineTint(.green)
        }
    }
}
```

### Lock Screen View

```swift
struct DeliveryLockScreenView: View {
    let context: ActivityViewContext<DeliveryActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "box.truck.fill")
                    .font(.title2)
                    .foregroundColor(.green)

                VStack(alignment: .leading) {
                    Text("Order #\(context.attributes.orderNumber)")
                        .font(.headline)
                    Text(context.attributes.restaurantName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                StatusBadge(status: context.state.currentStatus)
            }

            Divider()

            // Progress info
            HStack {
                VStack(alignment: .leading) {
                    Text("Driver")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(context.state.driverName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("ETA")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(context.state.estimatedDeliveryTime, style: .time)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }

            // Location
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.blue)
                Text(context.state.currentLocation)
                    .font(.caption)
            }
        }
        .padding()
    }
}

struct StatusBadge: View {
    let status: DeliveryStatus

    var body: some View {
        Text(status.displayText)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.2))
            .foregroundColor(status.color)
            .clipShape(Capsule())
    }
}

extension DeliveryStatus {
    var displayText: String {
        switch self {
        case .preparing: return "Preparing"
        case .pickedUp: return "Picked Up"
        case .onTheWay: return "On the Way"
        case .arriving: return "Arriving"
        case .delivered: return "Delivered"
        }
    }

    var color: Color {
        switch self {
        case .preparing: return .orange
        case .pickedUp: return .blue
        case .onTheWay: return .purple
        case .arriving: return .green
        case .delivered: return .green
        }
    }
}
```

### Dynamic Island Expanded Views

```swift
struct DeliveryExpandedLeadingView: View {
    let context: ActivityViewContext<DeliveryActivityAttributes>

    var body: some View {
        VStack(alignment: .leading) {
            Image(systemName: "box.truck.fill")
                .font(.title2)
                .foregroundColor(.green)
            Text(context.state.currentStatus.displayText)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct DeliveryExpandedTrailingView: View {
    let context: ActivityViewContext<DeliveryActivityAttributes>

    var body: some View {
        VStack(alignment: .trailing) {
            Text(context.state.estimatedDeliveryTime, style: .timer)
                .font(.title2)
                .fontWeight(.bold)
                .monospacedDigit()
            Text("ETA")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct DeliveryExpandedCenterView: View {
    let context: ActivityViewContext<DeliveryActivityAttributes>

    var body: some View {
        Text(context.attributes.restaurantName)
            .font(.headline)
    }
}

struct DeliveryExpandedBottomView: View {
    let context: ActivityViewContext<DeliveryActivityAttributes>

    var body: some View {
        HStack {
            Image(systemName: "person.fill")
            Text(context.state.driverName)
            Spacer()
            Image(systemName: "location.fill")
            Text(context.state.currentLocation)
                .lineLimit(1)
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }
}
```

---

## Push Token Handling

### Observing Token Updates

Push tokens can change during the activity lifecycle. Always observe for updates:

```swift
class LiveActivityManager: ObservableObject {
    private var tokenUpdateTask: Task<Void, Never>?

    func observePushTokenUpdates(for activity: Activity<DeliveryActivityAttributes>) {
        tokenUpdateTask?.cancel()

        tokenUpdateTask = Task {
            for await pushToken in activity.pushTokenUpdates {
                let tokenString = pushToken.map { String(format: "%02x", $0) }.joined()
                print("New push token: \(tokenString)")

                // Send token to your server
                await sendTokenToServer(token: tokenString, activityId: activity.id)
            }
        }
    }

    func sendTokenToServer(token: String, activityId: String) async {
        // Implement server communication
        // Your server uses this token to send push updates
    }

    func stopObserving() {
        tokenUpdateTask?.cancel()
        tokenUpdateTask = nil
    }
}
```

### Observing Activity State Changes

```swift
func observeActivityState(activity: Activity<DeliveryActivityAttributes>) {
    Task {
        for await state in activity.activityStateUpdates {
            switch state {
            case .active:
                print("Activity is active")
            case .ended:
                print("Activity has ended")
            case .dismissed:
                print("Activity was dismissed by user")
            case .stale:
                print("Activity content is stale")
            @unknown default:
                print("Unknown state")
            }
        }
    }
}
```

### Push Notification Payload Format

Your server sends updates using this APNS payload format:

```json
{
    "aps": {
        "timestamp": 1234567890,
        "event": "update",
        "content-state": {
            "currentStatus": "onTheWay",
            "driverName": "Alex",
            "estimatedDeliveryTime": 1234568790,
            "currentLocation": "5 minutes away"
        },
        "alert": {
            "title": "Driver Update",
            "body": "Your order is on the way!"
        }
    }
}
```

**Event Types:**
- `update`: Update the Live Activity content
- `end`: End the Live Activity

---

## Best Practices

### Update Frequency

1. **Local Updates:** No hard limit, but keep them meaningful
2. **Push Updates:** Budget of approximately 15-20 updates per hour
3. **Frequent Updates:** Enable `NSSupportsLiveActivitiesFrequentUpdates` for sports scores, navigation (higher budget, more battery impact)

### Battery Efficiency

```swift
// Use stale dates to indicate when content becomes outdated
let activityContent = ActivityContent(
    state: contentState,
    staleDate: Calendar.current.date(byAdding: .minute, value: 15, to: Date())
)

// End activities promptly when no longer relevant
if orderStatus == .delivered {
    await activity.end(finalContent, dismissalPolicy: .immediate)
}

// Check if updates are reduced (e.g., on Apple Watch)
struct DeliveryLockScreenView: View {
    @Environment(\.isActivityUpdateReduced) var isUpdateReduced

    var body: some View {
        if isUpdateReduced {
            // Show simplified view for reduced update scenarios
            SimplifiedDeliveryView()
        } else {
            // Show full view
            FullDeliveryView()
        }
    }
}
```

### Content Guidelines

1. **Keep it glanceable:** Users should understand status in < 2 seconds
2. **Use timers wisely:** `Text(date, style: .timer)` auto-updates without consuming update budget
3. **Meaningful updates only:** Avoid updating just to show "activity"
4. **Clear end states:** Make it obvious when an activity has completed

### Size Considerations

```swift
// Use supplementalActivityFamilies for different size support
ActivityConfiguration(for: DeliveryActivityAttributes.self) { context in
    DeliveryLockScreenView(context: context)
} dynamicIsland: { context in
    // Dynamic Island implementation
}
.supplementalActivityFamilies([.small, .medium])
```

---

## Common Pitfalls

### 1. Push Token Not Available Immediately

```swift
// WRONG: Token may not be available yet
let activity = try Activity.request(attributes: attributes, content: content, pushType: .token)
let token = activity.pushToken // May be nil!

// CORRECT: Observe token updates
for await token in activity.pushTokenUpdates {
    // Token is now available
    await sendToServer(token)
    break
}
```

### 2. Accessing Activities from Wrong Target

```swift
// Activities requested from main app are not accessible from widget extension directly
// Use App Groups and shared UserDefaults to coordinate

// In main app
let defaults = UserDefaults(suiteName: "group.com.yourapp.shared")
defaults?.set(activity.id, forKey: "currentActivityId")

// In widget extension - use activityId for reference, not direct activity access
```

### 3. Not Handling Authorization Changes

```swift
class LiveActivityManager {
    func observeAuthorizationChanges() {
        Task {
            for await enabled in ActivityAuthorizationInfo().activityEnablementUpdates {
                if enabled {
                    print("Live Activities enabled")
                } else {
                    print("Live Activities disabled - handle gracefully")
                }
            }
        }
    }
}
```

### 4. Forgetting to Share ActivityAttributes

Both your main app and widget extension must have access to the same `ActivityAttributes` definition. Use:
- A shared framework
- Duplicate the file in both targets (not recommended)
- Put in a shared Swift Package

### 5. Not Testing StandBy Mode (iOS 17+)

```swift
// Check if in full-screen presentation
struct DeliveryLockScreenView: View {
    @Environment(\.isActivityFullscreen) var isFullscreen

    var body: some View {
        if isFullscreen {
            // StandBy mode - use larger fonts and simpler layout
            StandByDeliveryView()
        } else {
            // Normal Lock Screen
            RegularDeliveryView()
        }
    }
}
```

### 6. Content State Too Large

```swift
// WRONG: Large data in ContentState
struct ContentState: Codable, Hashable {
    var allOrderHistory: [Order] // Too much data!
    var fullMenuItems: [MenuItem] // Unnecessary
}

// CORRECT: Only include what's needed for display
struct ContentState: Codable, Hashable {
    var currentStatus: DeliveryStatus
    var driverName: String
    var eta: Date
}
```

---

## iOS Version Compatibility

| Feature | Minimum iOS Version |
|---------|---------------------|
| Live Activities (Lock Screen) | iOS 16.1 |
| Dynamic Island | iOS 16.1 (iPhone 14 Pro+) |
| Push Updates | iOS 16.2 |
| StandBy Mode | iOS 17.0 |
| `isActivityFullscreen` | iOS 17.0 |
| `activityFamily` environment | iOS 18.0 |
| `isActivityUpdateReduced` | iOS 18.0 |

### Version Checking

```swift
func startLiveActivityIfAvailable() async throws {
    if #available(iOS 16.1, *) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw LiveActivityError.notAuthorized
        }

        // Start activity
        if #available(iOS 16.2, *) {
            // Can use push updates
            try await startWithPushUpdates()
        } else {
            // Local updates only
            try await startWithLocalUpdates()
        }
    } else {
        throw LiveActivityError.unsupportedOS
    }
}
```

---

## Complete Example: Delivery Tracker

### DeliveryActivityAttributes.swift (Shared)

```swift
import ActivityKit
import Foundation

struct DeliveryActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var status: DeliveryStatus
        var driverName: String
        var estimatedArrival: Date
        var currentStep: Int
        var totalSteps: Int
    }

    let orderNumber: String
    let restaurantName: String
    let restaurantImageName: String
}

enum DeliveryStatus: String, Codable, CaseIterable {
    case confirmed
    case preparing
    case readyForPickup
    case driverAssigned
    case pickedUp
    case onTheWay
    case arriving
    case delivered

    var step: Int {
        switch self {
        case .confirmed, .preparing: return 1
        case .readyForPickup, .driverAssigned: return 2
        case .pickedUp, .onTheWay: return 3
        case .arriving: return 4
        case .delivered: return 5
        }
    }
}
```

### LiveActivityManager.swift (Main App)

```swift
import ActivityKit
import Foundation

enum LiveActivityError: LocalizedError {
    case notAuthorized
    case unsupportedOS
    case startFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Live Activities are not enabled"
        case .unsupportedOS:
            return "Live Activities require iOS 16.1 or later"
        case .startFailed(let error):
            return "Failed to start Live Activity: \(error.localizedDescription)"
        }
    }
}

@Observable
class LiveActivityManager {
    private(set) var currentActivity: Activity<DeliveryActivityAttributes>?
    private var tokenObservationTask: Task<Void, Never>?

    var isActivityActive: Bool {
        currentActivity != nil
    }

    @MainActor
    func startDeliveryTracking(
        orderNumber: String,
        restaurantName: String,
        restaurantImage: String
    ) async throws {
        guard #available(iOS 16.1, *) else {
            throw LiveActivityError.unsupportedOS
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw LiveActivityError.notAuthorized
        }

        let attributes = DeliveryActivityAttributes(
            orderNumber: orderNumber,
            restaurantName: restaurantName,
            restaurantImageName: restaurantImage
        )

        let initialState = DeliveryActivityAttributes.ContentState(
            status: .confirmed,
            driverName: "Finding driver...",
            estimatedArrival: Date().addingTimeInterval(2400),
            currentStep: 1,
            totalSteps: 5
        )

        let content = ActivityContent(
            state: initialState,
            staleDate: Calendar.current.date(byAdding: .hour, value: 1, to: Date())
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: .token
            )

            currentActivity = activity
            observePushToken(for: activity)

        } catch {
            throw LiveActivityError.startFailed(error)
        }
    }

    func updateStatus(_ status: DeliveryStatus, driverName: String? = nil, eta: Date? = nil) async {
        guard let activity = currentActivity else { return }

        let currentState = activity.content.state
        let newState = DeliveryActivityAttributes.ContentState(
            status: status,
            driverName: driverName ?? currentState.driverName,
            estimatedArrival: eta ?? currentState.estimatedArrival,
            currentStep: status.step,
            totalSteps: 5
        )

        let content = ActivityContent(
            state: newState,
            staleDate: Calendar.current.date(byAdding: .minute, value: 30, to: Date())
        )

        await activity.update(content)
    }

    func endDelivery() async {
        guard let activity = currentActivity else { return }

        let finalState = DeliveryActivityAttributes.ContentState(
            status: .delivered,
            driverName: activity.content.state.driverName,
            estimatedArrival: Date(),
            currentStep: 5,
            totalSteps: 5
        )

        let content = ActivityContent(state: finalState, staleDate: nil)
        await activity.end(content, dismissalPolicy: .default)

        tokenObservationTask?.cancel()
        currentActivity = nil
    }

    private func observePushToken(for activity: Activity<DeliveryActivityAttributes>) {
        tokenObservationTask?.cancel()

        tokenObservationTask = Task {
            for await token in activity.pushTokenUpdates {
                let tokenString = token.map { String(format: "%02x", $0) }.joined()
                print("Push token updated: \(tokenString)")

                // Send to your server for push updates
                await sendTokenToServer(token: tokenString, activityId: activity.id)
            }
        }
    }

    private func sendTokenToServer(token: String, activityId: String) async {
        // Implement your server communication here
    }
}
```

---

## References

- [Apple Developer Documentation: ActivityKit](https://developer.apple.com/documentation/activitykit)
- [Human Interface Guidelines: Live Activities](https://developer.apple.com/design/human-interface-guidelines/live-activities)
- [WWDC22: Meet ActivityKit](https://developer.apple.com/videos/play/wwdc2022/10011/)
- [WWDC23: Update Live Activities with push notifications](https://developer.apple.com/videos/play/wwdc2023/10185/)

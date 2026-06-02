# UserNotifications Framework Guide

A comprehensive guide to implementing local and push notifications in iOS using UserNotifications framework with SwiftUI, async/await, and modern iOS 18+ patterns.

---

## Table of Contents

1. [Overview](#overview)
2. [Setup & Permissions](#setup--permissions)
3. [Core Concepts](#core-concepts)
4. [SwiftUI Integration Patterns](#swiftui-integration-patterns)
5. [Local Notifications](#local-notifications)
6. [Push Notifications](#push-notifications)
7. [Notification Content](#notification-content)
8. [Notification Categories & Actions](#notification-categories--actions)
9. [Handling Notification Responses](#handling-notification-responses)
10. [iOS 18/26 Specific Features](#ios-1826-specific-features)
11. [Common Use Cases](#common-use-cases)
12. [Best Practices](#best-practices)

---

## Overview

The UserNotifications framework provides a unified API for scheduling and handling both local and remote (push) notifications in iOS applications. It replaces the older UILocalNotification API and provides a modern, consistent approach to notifications.

### Key Capabilities

- **Local Notifications**: Schedule notifications directly from your app
- **Remote Notifications**: Receive push notifications via Apple Push Notification service (APNs)
- **Rich Content**: Support for images, audio, video attachments
- **Interactive Actions**: Custom buttons and text input responses
- **Notification Categories**: Group related notification types with specific actions
- **Scheduling Flexibility**: Time-based, calendar-based, and location-based triggers

### Framework Import

```swift
import UserNotifications
```

---

## Setup & Permissions

### Requesting Authorization

Before scheduling any notifications, you must request user permission. Always request authorization early in your app lifecycle, but at a contextually appropriate moment.

```swift
import UserNotifications

@Observable
final class NotificationManager {

    // MARK: - Properties

    private let center = UNUserNotificationCenter.current()

    var authorizationStatus: UNAuthorizationStatus = .notDetermined

    // MARK: - Authorization

    /// Requests notification authorization from the user
    /// - Parameter options: The notification options to request
    /// - Returns: Whether authorization was granted
    @discardableResult
    func requestAuthorization(options: UNAuthorizationOptions = [.alert, .sound, .badge]) async throws -> Bool {
        let granted = try await center.requestAuthorization(options: options)
        await updateAuthorizationStatus()
        return granted
    }

    /// Updates the current authorization status
    func updateAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// Checks if notifications are authorized
    var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional
    }
}
```

### Authorization Options

```swift
// Common authorization options
let options: UNAuthorizationOptions = [
    .alert,           // Display alerts
    .sound,           // Play sounds
    .badge,           // Update app badge
    .carPlay,         // Display in CarPlay
    .criticalAlert,   // Critical alerts (requires entitlement)
    .providesAppNotificationSettings, // Show in-app settings button
    .provisional      // Deliver quietly without prompting
]
```

### Checking Current Settings

```swift
extension NotificationManager {

    /// Retrieves detailed notification settings
    func getNotificationSettings() async -> UNNotificationSettings {
        await center.notificationSettings()
    }

    /// Checks if specific notification features are enabled
    func checkSettings() async -> NotificationCapabilities {
        let settings = await center.notificationSettings()

        return NotificationCapabilities(
            alertsEnabled: settings.alertSetting == .enabled,
            soundsEnabled: settings.soundSetting == .enabled,
            badgesEnabled: settings.badgeSetting == .enabled,
            lockScreenEnabled: settings.lockScreenSetting == .enabled,
            notificationCenterEnabled: settings.notificationCenterSetting == .enabled
        )
    }
}

struct NotificationCapabilities {
    let alertsEnabled: Bool
    let soundsEnabled: Bool
    let badgesEnabled: Bool
    let lockScreenEnabled: Bool
    let notificationCenterEnabled: Bool
}
```

---

## Core Concepts

### UNUserNotificationCenter

The central object for managing notification-related activities. Always access it through `UNUserNotificationCenter.current()`.

```swift
let center = UNUserNotificationCenter.current()
```

### UNNotificationRequest

Represents a request to schedule a notification. Contains:
- **Identifier**: Unique string to identify the notification
- **Content**: The notification's payload (title, body, etc.)
- **Trigger**: When/where the notification should fire

```swift
let request = UNNotificationRequest(
    identifier: UUID().uuidString,
    content: content,
    trigger: trigger
)
```

### UNNotificationContent

Contains the content displayed to the user:
- Title and subtitle
- Body text
- Sound
- Badge count
- Attachments
- Category identifier
- User info dictionary

### UNNotificationTrigger

Defines when a notification is delivered:
- `UNTimeIntervalNotificationTrigger`: After a time interval
- `UNCalendarNotificationTrigger`: At a specific date/time
- `UNLocationNotificationTrigger`: When entering/exiting a region
- `nil`: Immediate delivery (for testing)

---

## SwiftUI Integration Patterns

### NotificationManager with @Observable

```swift
import SwiftUI
import UserNotifications

@Observable
final class NotificationManager {

    // MARK: - Properties

    private let center = UNUserNotificationCenter.current()

    var authorizationStatus: UNAuthorizationStatus = .notDetermined
    var pendingNotifications: [UNNotificationRequest] = []
    var deliveredNotifications: [UNNotification] = []

    // MARK: - Initialization

    init() {
        Task {
            await updateAuthorizationStatus()
        }
    }

    // MARK: - Authorization

    @discardableResult
    func requestAuthorization(options: UNAuthorizationOptions = [.alert, .sound, .badge]) async throws -> Bool {
        let granted = try await center.requestAuthorization(options: options)
        await updateAuthorizationStatus()
        return granted
    }

    func updateAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    // MARK: - Scheduling

    func scheduleNotification(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
        await refreshPendingNotifications()
    }

    // MARK: - Management

    func refreshPendingNotifications() async {
        pendingNotifications = await center.pendingNotificationRequests()
    }

    func refreshDeliveredNotifications() async {
        deliveredNotifications = await center.deliveredNotifications()
    }

    func removePendingNotification(withIdentifier identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        Task {
            await refreshPendingNotifications()
        }
    }

    func removeAllPendingNotifications() {
        center.removeAllPendingNotificationRequests()
        Task {
            await refreshPendingNotifications()
        }
    }

    func removeDeliveredNotification(withIdentifier identifier: String) {
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
        Task {
            await refreshDeliveredNotifications()
        }
    }

    func removeAllDeliveredNotifications() {
        center.removeAllDeliveredNotifications()
        Task {
            await refreshDeliveredNotifications()
        }
    }

    // MARK: - Badge Management

    func setBadgeCount(_ count: Int) async throws {
        try await center.setBadgeCount(count)
    }

    func clearBadge() async throws {
        try await center.setBadgeCount(0)
    }
}
```

### App Setup with Environment

```swift
import SwiftUI

@main
struct MyApp: App {

    @State private var notificationManager = NotificationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(notificationManager)
        }
    }
}
```

### Using in Views

```swift
import SwiftUI

struct NotificationSettingsView: View {

    @Environment(NotificationManager.self) private var notificationManager

    var body: some View {
        List {
            Section("Authorization Status") {
                StatusRow(status: notificationManager.authorizationStatus)
            }

            Section("Actions") {
                Button("Request Permission") {
                    Task {
                        try? await notificationManager.requestAuthorization()
                    }
                }
                .disabled(notificationManager.authorizationStatus == .authorized)

                Button("Schedule Test Notification") {
                    Task {
                        await scheduleTestNotification()
                    }
                }
                .disabled(notificationManager.authorizationStatus != .authorized)
            }

            Section("Pending Notifications (\(notificationManager.pendingNotifications.count))") {
                ForEach(notificationManager.pendingNotifications, id: \.identifier) { request in
                    NotificationRow(request: request)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let identifier = notificationManager.pendingNotifications[index].identifier
                        notificationManager.removePendingNotification(withIdentifier: identifier)
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .task {
            await notificationManager.refreshPendingNotifications()
        }
    }

    private func scheduleTestNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "This is a test notification from your app."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )

        try? await notificationManager.scheduleNotification(request)
    }
}

struct StatusRow: View {
    let status: UNAuthorizationStatus

    var body: some View {
        HStack {
            Text("Status")
            Spacer()
            Text(statusText)
                .foregroundStyle(statusColor)
        }
    }

    private var statusText: String {
        switch status {
        case .notDetermined: return "Not Determined"
        case .denied: return "Denied"
        case .authorized: return "Authorized"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        @unknown default: return "Unknown"
        }
    }

    private var statusColor: Color {
        switch status {
        case .authorized, .provisional, .ephemeral: return .green
        case .denied: return .red
        case .notDetermined: return .orange
        @unknown default: return .secondary
        }
    }
}

struct NotificationRow: View {
    let request: UNNotificationRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(request.content.title)
                .font(.headline)
            Text(request.content.body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("ID: \(request.identifier)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}
```

---

## Local Notifications

### Time Interval Trigger

Schedule a notification to fire after a specified time interval.

```swift
extension NotificationManager {

    /// Schedules a notification after a time interval
    /// - Parameters:
    ///   - title: Notification title
    ///   - body: Notification body
    ///   - timeInterval: Seconds until delivery
    ///   - repeats: Whether to repeat (minimum 60 seconds for repeating)
    /// - Returns: The notification identifier
    @discardableResult
    func scheduleTimeIntervalNotification(
        title: String,
        body: String,
        timeInterval: TimeInterval,
        repeats: Bool = false
    ) async throws -> String {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        // Note: Repeating notifications require at least 60 seconds interval
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: repeats ? max(timeInterval, 60) : timeInterval,
            repeats: repeats
        )

        let identifier = UUID().uuidString
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        try await scheduleNotification(request)
        return identifier
    }
}
```

### Calendar Trigger

Schedule a notification for a specific date and time.

```swift
extension NotificationManager {

    /// Schedules a notification at a specific date/time
    /// - Parameters:
    ///   - title: Notification title
    ///   - body: Notification body
    ///   - dateComponents: The date components for delivery
    ///   - repeats: Whether to repeat
    /// - Returns: The notification identifier
    @discardableResult
    func scheduleCalendarNotification(
        title: String,
        body: String,
        dateComponents: DateComponents,
        repeats: Bool = false
    ) async throws -> String {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: repeats
        )

        let identifier = UUID().uuidString
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        try await scheduleNotification(request)
        return identifier
    }

    /// Schedules a notification at a specific date
    /// - Parameters:
    ///   - title: Notification title
    ///   - body: Notification body
    ///   - date: The date for delivery
    /// - Returns: The notification identifier
    @discardableResult
    func scheduleNotification(
        title: String,
        body: String,
        at date: Date
    ) async throws -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )

        return try await scheduleCalendarNotification(
            title: title,
            body: body,
            dateComponents: components,
            repeats: false
        )
    }

    /// Schedules a daily notification at a specific time
    /// - Parameters:
    ///   - title: Notification title
    ///   - body: Notification body
    ///   - hour: Hour (0-23)
    ///   - minute: Minute (0-59)
    /// - Returns: The notification identifier
    @discardableResult
    func scheduleDailyNotification(
        title: String,
        body: String,
        hour: Int,
        minute: Int
    ) async throws -> String {
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        return try await scheduleCalendarNotification(
            title: title,
            body: body,
            dateComponents: dateComponents,
            repeats: true
        )
    }

    /// Schedules a weekly notification
    /// - Parameters:
    ///   - title: Notification title
    ///   - body: Notification body
    ///   - weekday: Day of week (1 = Sunday, 7 = Saturday)
    ///   - hour: Hour (0-23)
    ///   - minute: Minute (0-59)
    /// - Returns: The notification identifier
    @discardableResult
    func scheduleWeeklyNotification(
        title: String,
        body: String,
        weekday: Int,
        hour: Int,
        minute: Int
    ) async throws -> String {
        var dateComponents = DateComponents()
        dateComponents.weekday = weekday
        dateComponents.hour = hour
        dateComponents.minute = minute

        return try await scheduleCalendarNotification(
            title: title,
            body: body,
            dateComponents: dateComponents,
            repeats: true
        )
    }
}
```

### Location Trigger

Schedule a notification when entering or exiting a geographic region.

```swift
import CoreLocation

extension NotificationManager {

    /// Schedules a location-based notification
    /// - Parameters:
    ///   - title: Notification title
    ///   - body: Notification body
    ///   - region: The geographic region
    ///   - repeats: Whether to repeat
    /// - Returns: The notification identifier
    @discardableResult
    func scheduleLocationNotification(
        title: String,
        body: String,
        region: CLCircularRegion,
        repeats: Bool = false
    ) async throws -> String {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNLocationNotificationTrigger(region: region, repeats: repeats)

        let identifier = UUID().uuidString
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        try await scheduleNotification(request)
        return identifier
    }

    /// Schedules a notification when entering a location
    /// - Parameters:
    ///   - title: Notification title
    ///   - body: Notification body
    ///   - coordinate: The center coordinate
    ///   - radius: Radius in meters
    ///   - identifier: Region identifier
    /// - Returns: The notification identifier
    @discardableResult
    func scheduleEntryNotification(
        title: String,
        body: String,
        coordinate: CLLocationCoordinate2D,
        radius: CLLocationDistance = 100,
        regionIdentifier: String
    ) async throws -> String {
        let region = CLCircularRegion(
            center: coordinate,
            radius: radius,
            identifier: regionIdentifier
        )
        region.notifyOnEntry = true
        region.notifyOnExit = false

        return try await scheduleLocationNotification(
            title: title,
            body: body,
            region: region,
            repeats: true
        )
    }
}
```

---

## Push Notifications

### APNs Registration

Register for remote notifications using a SwiftUI App Delegate.

```swift
import SwiftUI
import UserNotifications

// MARK: - App Delegate

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("Device Token: \(token)")

        // Send token to your server
        Task {
            await sendDeviceTokenToServer(token: token)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }

    private func sendDeviceTokenToServer(token: String) async {
        // Send token to your backend server
    }
}

// MARK: - App Entry Point

@main
struct MyApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var notificationManager = NotificationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(notificationManager)
                .task {
                    await setupNotifications()
                }
        }
    }

    private func setupNotifications() async {
        do {
            let granted = try await notificationManager.requestAuthorization(
                options: [.alert, .sound, .badge]
            )

            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        } catch {
            print("Failed to request authorization: \(error.localizedDescription)")
        }
    }
}
```

### Push Notification Service

A service to manage push notification state.

```swift
import Foundation
import UIKit

@Observable
final class PushNotificationService {

    // MARK: - Properties

    private(set) var deviceToken: String?
    private(set) var isRegistered = false

    // MARK: - Registration

    func registerForPushNotifications() async throws {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        guard settings.authorizationStatus == .authorized ||
              settings.authorizationStatus == .provisional else {
            throw PushNotificationError.notAuthorized
        }

        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func handleDeviceToken(_ token: Data) {
        deviceToken = token.map { String(format: "%02.2hhx", $0) }.joined()
        isRegistered = true

        Task {
            await sendTokenToServer()
        }
    }

    func handleRegistrationError(_ error: Error) {
        print("Push registration failed: \(error.localizedDescription)")
        isRegistered = false
    }

    // MARK: - Server Communication

    private func sendTokenToServer() async {
        guard let token = deviceToken else { return }

        // Example: Send to your backend
        // await networkService.registerDeviceToken(token)
        print("Sending token to server: \(token)")
    }
}

enum PushNotificationError: LocalizedError {
    case notAuthorized
    case registrationFailed

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Push notifications are not authorized"
        case .registrationFailed:
            return "Failed to register for push notifications"
        }
    }
}
```

### APNs Payload Structure

Standard APNs JSON payload:

```json
{
    "aps": {
        "alert": {
            "title": "Notification Title",
            "subtitle": "Optional Subtitle",
            "body": "The notification body text"
        },
        "badge": 1,
        "sound": "default",
        "category": "MESSAGE_CATEGORY",
        "thread-id": "conversation-123",
        "content-available": 1,
        "mutable-content": 1
    },
    "customKey": "customValue"
}
```

---

## Notification Content

### Basic Content

```swift
let content = UNMutableNotificationContent()
content.title = "Meeting Reminder"
content.subtitle = "Team Standup"
content.body = "Your daily standup meeting starts in 5 minutes."
content.sound = .default
content.badge = 1
```

### Custom Sounds

```swift
// Default sound
content.sound = .default

// Named sound file (must be in app bundle, max 30 seconds)
content.sound = UNNotificationSound(named: UNNotificationSoundName("custom_sound.wav"))

// Critical alert sound (requires entitlement)
content.sound = .defaultCriticalSound(withAudioVolume: 1.0)
```

### Attachments

Add images, audio, or video to notifications.

```swift
extension NotificationManager {

    /// Creates notification content with an image attachment
    /// - Parameters:
    ///   - title: Notification title
    ///   - body: Notification body
    ///   - imageURL: URL to the image file
    /// - Returns: Configured notification content
    func createContentWithImage(
        title: String,
        body: String,
        imageURL: URL
    ) throws -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let attachment = try UNNotificationAttachment(
            identifier: UUID().uuidString,
            url: imageURL,
            options: nil
        )
        content.attachments = [attachment]

        return content
    }

    /// Downloads an image and creates attachment
    /// - Parameters:
    ///   - title: Notification title
    ///   - body: Notification body
    ///   - remoteImageURL: Remote URL to download from
    /// - Returns: Configured notification content
    func createContentWithRemoteImage(
        title: String,
        body: String,
        remoteImageURL: URL
    ) async throws -> UNMutableNotificationContent {
        // Download image to temporary location
        let (localURL, _) = try await URLSession.shared.download(from: remoteImageURL)

        // Move to permanent temporary location with proper extension
        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory
        let fileName = UUID().uuidString + ".jpg"
        let destinationURL = tempDirectory.appendingPathComponent(fileName)

        try? fileManager.removeItem(at: destinationURL)
        try fileManager.moveItem(at: localURL, to: destinationURL)

        return try createContentWithImage(
            title: title,
            body: body,
            imageURL: destinationURL
        )
    }
}
```

### Thread Identifiers

Group related notifications together.

```swift
content.threadIdentifier = "conversation-\(conversationId)"
```

### User Info

Pass custom data with notifications.

```swift
content.userInfo = [
    "conversationId": "12345",
    "messageId": "67890",
    "deepLink": "myapp://messages/12345"
]
```

### Interruption Level (iOS 15+)

Control notification prominence.

```swift
// Passive - Added to notification list silently
content.interruptionLevel = .passive

// Active - Default behavior
content.interruptionLevel = .active

// Time Sensitive - Highlighted, delivers during Focus
content.interruptionLevel = .timeSensitive

// Critical - Bypasses mute, requires entitlement
content.interruptionLevel = .critical
```

### Relevance Score

Prioritize notifications in summary.

```swift
content.relevanceScore = 0.8  // 0.0 to 1.0
```

---

## Notification Categories & Actions

### Defining Categories

Register categories when your app launches.

```swift
extension NotificationManager {

    /// Registers notification categories with the system
    func registerCategories() {
        // Message category with reply action
        let replyAction = UNTextInputNotificationAction(
            identifier: NotificationAction.reply.rawValue,
            title: "Reply",
            options: [],
            textInputButtonTitle: "Send",
            textInputPlaceholder: "Type your reply..."
        )

        let markReadAction = UNNotificationAction(
            identifier: NotificationAction.markRead.rawValue,
            title: "Mark as Read",
            options: []
        )

        let messageCategory = UNNotificationCategory(
            identifier: NotificationCategory.message.rawValue,
            actions: [replyAction, markReadAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        // Reminder category
        let completeAction = UNNotificationAction(
            identifier: NotificationAction.complete.rawValue,
            title: "Complete",
            options: [.foreground]
        )

        let snoozeAction = UNNotificationAction(
            identifier: NotificationAction.snooze.rawValue,
            title: "Snooze",
            options: []
        )

        let reminderCategory = UNNotificationCategory(
            identifier: NotificationCategory.reminder.rawValue,
            actions: [completeAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )

        // Register all categories
        center.setNotificationCategories([messageCategory, reminderCategory])
    }
}

// MARK: - Category & Action Identifiers

enum NotificationCategory: String {
    case message = "MESSAGE_CATEGORY"
    case reminder = "REMINDER_CATEGORY"
}

enum NotificationAction: String {
    case reply = "REPLY_ACTION"
    case markRead = "MARK_READ_ACTION"
    case complete = "COMPLETE_ACTION"
    case snooze = "SNOOZE_ACTION"
}
```

### Using Categories in Content

```swift
let content = UNMutableNotificationContent()
content.title = "New Message"
content.body = "John: Hey, are you free for lunch?"
content.categoryIdentifier = NotificationCategory.message.rawValue
content.sound = .default
```

### Action Options

```swift
// Opens app in foreground
UNNotificationAction(identifier: "id", title: "Open", options: [.foreground])

// Requires authentication
UNNotificationAction(identifier: "id", title: "Delete", options: [.authenticationRequired])

// Destructive action (red text)
UNNotificationAction(identifier: "id", title: "Delete", options: [.destructive])
```

---

## Handling Notification Responses

### UNUserNotificationCenterDelegate

Set up a delegate to handle notification interactions.

```swift
import UserNotifications

// MARK: - Notification Delegate

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    // MARK: - Properties

    weak var notificationManager: NotificationManager?

    // MARK: - Foreground Presentation

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Show notifications even when app is in foreground
        return [.banner, .sound, .badge, .list]
    }

    // MARK: - Response Handling

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier

        switch actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification
            await handleNotificationTap(userInfo: userInfo)

        case UNNotificationDismissActionIdentifier:
            // User dismissed the notification
            await handleNotificationDismiss(userInfo: userInfo)

        case NotificationAction.reply.rawValue:
            // Handle text input reply
            if let textResponse = response as? UNTextInputNotificationResponse {
                await handleReply(text: textResponse.userText, userInfo: userInfo)
            }

        case NotificationAction.markRead.rawValue:
            await handleMarkAsRead(userInfo: userInfo)

        case NotificationAction.complete.rawValue:
            await handleComplete(userInfo: userInfo)

        case NotificationAction.snooze.rawValue:
            await handleSnooze(userInfo: userInfo)

        default:
            break
        }
    }

    // MARK: - Response Handlers

    private func handleNotificationTap(userInfo: [AnyHashable: Any]) async {
        if let deepLink = userInfo["deepLink"] as? String {
            await MainActor.run {
                // Navigate to appropriate screen
                NotificationCenter.default.post(
                    name: .handleDeepLink,
                    object: nil,
                    userInfo: ["deepLink": deepLink]
                )
            }
        }
    }

    private func handleNotificationDismiss(userInfo: [AnyHashable: Any]) async {
        // Track dismissal analytics if needed
    }

    private func handleReply(text: String, userInfo: [AnyHashable: Any]) async {
        guard let conversationId = userInfo["conversationId"] as? String else { return }
        // Send reply to backend
        print("Reply to conversation \(conversationId): \(text)")
    }

    private func handleMarkAsRead(userInfo: [AnyHashable: Any]) async {
        guard let messageId = userInfo["messageId"] as? String else { return }
        // Mark message as read
        print("Marked message \(messageId) as read")
    }

    private func handleComplete(userInfo: [AnyHashable: Any]) async {
        guard let reminderId = userInfo["reminderId"] as? String else { return }
        // Complete the reminder
        print("Completed reminder \(reminderId)")
    }

    private func handleSnooze(userInfo: [AnyHashable: Any]) async {
        guard let reminderId = userInfo["reminderId"] as? String else { return }
        // Reschedule for later
        try? await notificationManager?.scheduleTimeIntervalNotification(
            title: "Snoozed Reminder",
            body: "Your reminder was snoozed",
            timeInterval: 600 // 10 minutes
        )
    }
}

extension Notification.Name {
    static let handleDeepLink = Notification.Name("handleDeepLink")
}
```

### Setting Up the Delegate

```swift
@main
struct MyApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var notificationManager = NotificationManager()

    private let notificationDelegate = NotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(notificationManager)
                .onAppear {
                    notificationDelegate.notificationManager = notificationManager
                    notificationManager.registerCategories()
                }
        }
    }
}
```

### SwiftUI Deep Link Handling

```swift
import SwiftUI

struct ContentView: View {

    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            HomeView()
                .navigationDestination(for: DeepLink.self) { deepLink in
                    deepLink.destination
                }
        }
        .onReceive(NotificationCenter.default.publisher(for: .handleDeepLink)) { notification in
            if let deepLinkString = notification.userInfo?["deepLink"] as? String,
               let deepLink = DeepLink(rawValue: deepLinkString) {
                navigationPath.append(deepLink)
            }
        }
    }
}

enum DeepLink: String, Hashable {
    case messages = "myapp://messages"
    case settings = "myapp://settings"
    case profile = "myapp://profile"

    @ViewBuilder
    var destination: some View {
        switch self {
        case .messages:
            MessagesView()
        case .settings:
            SettingsView()
        case .profile:
            ProfileView()
        }
    }
}
```

---

## iOS 18/26 Specific Features

### iOS 18 Updates

iOS 18 introduces refinements to notification handling and better integration with Focus modes.

```swift
// Check Focus status before scheduling notifications
extension NotificationManager {

    /// Checks current Focus status and adjusts notification behavior
    func scheduleWithFocusAwareness(
        title: String,
        body: String,
        timeInterval: TimeInterval
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        // Time sensitive notifications can break through Focus
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: timeInterval,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )

        try await scheduleNotification(request)
    }
}
```

### iOS 26 Considerations

iOS 26 introduces enhanced privacy features and Liquid Glass UI integration. Known issues to be aware of:

1. **Token Registration Timing**: In iOS 26, `didRegisterForRemoteNotificationsWithDeviceToken` may be called before user authorization is complete. Handle this appropriately:

```swift
final class AppDelegate: NSObject, UIApplicationDelegate {

    private var pendingDeviceToken: Data?

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Store token and send when authorization is confirmed
        pendingDeviceToken = deviceToken

        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            if settings.authorizationStatus == .authorized {
                await sendTokenToServer(deviceToken)
            }
        }
    }

    private func sendTokenToServer(_ token: Data) async {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        // Send to server
    }
}
```

2. **Notification Extension Issues**: iOS 26 has a known regression where `extensionContext.open(uri)` fails on cold start. As a workaround, use userInfo to pass deep link data instead:

```swift
// Instead of opening URL from extension, pass data to main app
content.userInfo = ["deepLink": "myapp://action/123"]
```

3. **Automatic Observation Tracking**: iOS 26 enables automatic observation tracking by default. For iOS 18 compatibility, add to Info.plist:

```xml
<key>UIObservationTrackingEnabled</key>
<true/>
```

---

## Common Use Cases

### Reminder App

```swift
@Observable
final class ReminderNotificationManager {

    private let notificationManager = NotificationManager()

    /// Schedules a reminder notification
    /// - Parameters:
    ///   - reminder: The reminder to schedule
    /// - Returns: The notification identifier
    @discardableResult
    func scheduleReminder(_ reminder: Reminder) async throws -> String {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.notes ?? "Reminder"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.reminder.rawValue
        content.userInfo = ["reminderId": reminder.id.uuidString]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminder.dueDate
        )

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: reminder.id.uuidString,
            content: content,
            trigger: trigger
        )

        try await notificationManager.scheduleNotification(request)
        return reminder.id.uuidString
    }

    /// Cancels a reminder notification
    func cancelReminder(_ reminder: Reminder) {
        notificationManager.removePendingNotification(withIdentifier: reminder.id.uuidString)
    }

    /// Reschedules a reminder
    func rescheduleReminder(_ reminder: Reminder) async throws {
        cancelReminder(reminder)
        try await scheduleReminder(reminder)
    }
}

struct Reminder: Identifiable {
    let id: UUID
    var title: String
    var notes: String?
    var dueDate: Date
}
```

### Messaging App

```swift
@Observable
final class MessageNotificationManager {

    private let notificationManager = NotificationManager()

    /// Shows a notification for an incoming message
    func showMessageNotification(
        from sender: String,
        message: String,
        conversationId: String,
        messageId: String,
        senderImageURL: URL? = nil
    ) async throws {
        var content = UNMutableNotificationContent()
        content.title = sender
        content.body = message
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.message.rawValue
        content.threadIdentifier = "conversation-\(conversationId)"
        content.userInfo = [
            "conversationId": conversationId,
            "messageId": messageId,
            "deepLink": "myapp://messages/\(conversationId)"
        ]

        // Add sender image if available
        if let imageURL = senderImageURL {
            content = try await notificationManager.createContentWithRemoteImage(
                title: sender,
                body: message,
                remoteImageURL: imageURL
            )
            content.categoryIdentifier = NotificationCategory.message.rawValue
            content.threadIdentifier = "conversation-\(conversationId)"
            content.userInfo = [
                "conversationId": conversationId,
                "messageId": messageId,
                "deepLink": "myapp://messages/\(conversationId)"
            ]
        }

        // Immediate delivery
        let request = UNNotificationRequest(
            identifier: messageId,
            content: content,
            trigger: nil
        )

        try await notificationManager.scheduleNotification(request)
    }

    /// Removes notifications for a conversation when opened
    func clearConversationNotifications(conversationId: String) async {
        await notificationManager.refreshDeliveredNotifications()

        let conversationNotifications = notificationManager.deliveredNotifications.filter {
            $0.request.content.threadIdentifier == "conversation-\(conversationId)"
        }

        for notification in conversationNotifications {
            notificationManager.removeDeliveredNotification(
                withIdentifier: notification.request.identifier
            )
        }
    }
}
```

### Daily Habit Tracker

```swift
@Observable
final class HabitNotificationManager {

    private let notificationManager = NotificationManager()

    /// Schedules daily notifications for a habit
    /// - Parameters:
    ///   - habit: The habit to schedule notifications for
    ///   - times: Array of times to notify (hour, minute tuples)
    func scheduleHabitNotifications(
        habit: Habit,
        times: [(hour: Int, minute: Int)]
    ) async throws {
        // Cancel existing notifications for this habit
        cancelHabitNotifications(habit: habit)

        for (index, time) in times.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "Time for \(habit.name)"
            content.body = habit.motivationalMessage ?? "Don't forget your daily habit!"
            content.sound = .default
            content.userInfo = [
                "habitId": habit.id.uuidString,
                "deepLink": "myapp://habits/\(habit.id.uuidString)"
            ]

            var dateComponents = DateComponents()
            dateComponents.hour = time.hour
            dateComponents.minute = time.minute

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: true
            )

            let identifier = "\(habit.id.uuidString)-\(index)"
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )

            try await notificationManager.scheduleNotification(request)
        }
    }

    /// Cancels all notifications for a habit
    func cancelHabitNotifications(habit: Habit) {
        let center = UNUserNotificationCenter.current()

        // Remove by prefix matching
        Task {
            let requests = await center.pendingNotificationRequests()
            let habitIdentifiers = requests
                .filter { $0.identifier.hasPrefix(habit.id.uuidString) }
                .map(\.identifier)

            center.removePendingNotificationRequests(withIdentifiers: habitIdentifiers)
        }
    }
}

struct Habit: Identifiable {
    let id: UUID
    var name: String
    var motivationalMessage: String?
    var isActive: Bool
}
```

---

## Best Practices

### 1. Request Permission at the Right Time

Request notification permission when it's contextually relevant, not immediately on app launch.

```swift
// Good: Request when user enables reminders feature
func enableReminders() async {
    do {
        let granted = try await notificationManager.requestAuthorization()
        if granted {
            // User understands why notifications are needed
            await scheduleReminders()
        }
    } catch {
        // Handle error
    }
}

// Bad: Request immediately on launch without context
// User doesn't know why they need notifications
```

### 2. Handle Authorization Denial Gracefully

```swift
struct NotificationPermissionView: View {

    @Environment(NotificationManager.self) private var notificationManager

    var body: some View {
        VStack(spacing: 16) {
            if notificationManager.authorizationStatus == .denied {
                Text("Notifications are disabled")
                    .font(.headline)

                Text("Enable notifications in Settings to receive reminders.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
        .padding()
    }
}
```

### 3. Use Appropriate Interruption Levels

```swift
extension UNMutableNotificationContent {

    /// Configures interruption level based on notification priority
    func configureInterruptionLevel(for priority: NotificationPriority) {
        switch priority {
        case .low:
            interruptionLevel = .passive
        case .normal:
            interruptionLevel = .active
        case .high:
            interruptionLevel = .timeSensitive
        case .critical:
            interruptionLevel = .critical
        }
    }
}

enum NotificationPriority {
    case low
    case normal
    case high
    case critical
}
```

### 4. Group Related Notifications

```swift
// Use thread identifiers to group related notifications
content.threadIdentifier = "project-\(projectId)"
```

> **Deprecated:** `content.summaryArgument` and `content.summaryArgumentCount` were deprecated in iOS 15 and have no effect on current OS versions — do not use them. Grouping is driven entirely by `threadIdentifier`; the system composes the summary text automatically.

### 5. Clean Up Old Notifications

```swift
extension NotificationManager {

    /// Removes outdated pending notifications
    func cleanupOldNotifications() async {
        await refreshPendingNotifications()

        let now = Date()
        let outdatedIdentifiers = pendingNotifications.compactMap { request -> String? in
            guard let trigger = request.trigger as? UNCalendarNotificationTrigger,
                  let nextTriggerDate = trigger.nextTriggerDate(),
                  nextTriggerDate < now else {
                return nil
            }
            return request.identifier
        }

        if !outdatedIdentifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: outdatedIdentifiers)
            await refreshPendingNotifications()
        }
    }
}
```

### 6. Test Notifications Properly

```swift
#if DEBUG
extension NotificationManager {

    /// Schedules an immediate test notification
    func sendTestNotification() async throws {
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "This is a test notification at \(Date().formatted())"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "test-\(UUID().uuidString)",
            content: content,
            trigger: nil // Immediate delivery
        )

        try await scheduleNotification(request)
    }
}
#endif
```

### 7. Respect User Preferences

```swift
@Observable
final class NotificationPreferences {

    // User preferences stored in UserDefaults
    var remindersEnabled: Bool {
        didSet { UserDefaults.standard.set(remindersEnabled, forKey: "remindersEnabled") }
    }

    var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled") }
    }

    var quietHoursStart: Int {
        didSet { UserDefaults.standard.set(quietHoursStart, forKey: "quietHoursStart") }
    }

    var quietHoursEnd: Int {
        didSet { UserDefaults.standard.set(quietHoursEnd, forKey: "quietHoursEnd") }
    }

    init() {
        remindersEnabled = UserDefaults.standard.bool(forKey: "remindersEnabled")
        soundEnabled = UserDefaults.standard.bool(forKey: "soundEnabled")
        quietHoursStart = UserDefaults.standard.integer(forKey: "quietHoursStart")
        quietHoursEnd = UserDefaults.standard.integer(forKey: "quietHoursEnd")
    }

    /// Checks if notifications should be silent based on quiet hours
    func isQuietTime() -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())

        if quietHoursStart < quietHoursEnd {
            return hour >= quietHoursStart && hour < quietHoursEnd
        } else {
            // Quiet hours span midnight
            return hour >= quietHoursStart || hour < quietHoursEnd
        }
    }
}
```

### 8. Handle Background Fetch Notifications

```swift
// In AppDelegate
func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any]
) async -> UIBackgroundFetchResult {
    // Process silent notification
    guard let data = userInfo["data"] as? [String: Any] else {
        return .noData
    }

    do {
        // Perform background work
        try await processBackgroundData(data)
        return .newData
    } catch {
        return .failed
    }
}

private func processBackgroundData(_ data: [String: Any]) async throws {
    // Update local data, sync, etc.
}
```

---

## Summary

The UserNotifications framework provides a comprehensive solution for both local and remote notifications in iOS. Key points to remember:

1. **Always request authorization** before scheduling notifications
2. **Use async/await** for all notification operations
3. **Register categories** early in the app lifecycle
4. **Handle responses** through `UNUserNotificationCenterDelegate`
5. **Respect user preferences** and Focus modes
6. **Group related notifications** using thread identifiers
7. **Clean up** old notifications regularly
8. **Test thoroughly** on real devices for push notifications

For iOS 26 specifically, be aware of the known issues with token registration timing and Notification Extension deep linking. Always test on the target iOS version to ensure compatibility.

---

## References

- [Apple Developer Documentation - UserNotifications](https://developer.apple.com/documentation/usernotifications)
- [Asking Permission to Use Notifications](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications)
- [Scheduling a Notification Locally](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app)
- [Registering Your App with APNs](https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns)

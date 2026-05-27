# WatchConnectivity Guide for iOS Development

A comprehensive guide for using the WatchConnectivity framework to communicate between iOS and watchOS apps with SwiftUI and async/await.

---

## Table of Contents

1. [Overview](#overview)
2. [Setup and Configuration](#setup-and-configuration)
3. [Core Concepts](#core-concepts)
4. [Session Activation and State](#session-activation-and-state)
5. [Interactive Messaging](#interactive-messaging)
6. [Application Context](#application-context)
7. [User Info Transfers](#user-info-transfers)
8. [File Transfers](#file-transfers)
9. [Complication Updates](#complication-updates)
10. [SwiftUI Integration with @Observable](#swiftui-integration-with-observable)
11. [Async/Await Wrappers](#asyncawait-wrappers)
12. [Common Use Cases](#common-use-cases)
13. [Best Practices](#best-practices)
14. [Troubleshooting](#troubleshooting)

---

## Overview

The WatchConnectivity framework enables two-way communication between an iOS app and its paired watchOS app. It provides multiple methods for transferring data, each suited for different scenarios.

### Import

```swift
import WatchConnectivity
```

### Data Transfer Methods

| Method | Use Case | Delivery | Background Support |
|--------|----------|----------|-------------------|
| `sendMessage` | Real-time communication | Immediate | iOS only (watch must be foreground) |
| `updateApplicationContext` | State synchronization | Latest value only | Yes |
| `transferUserInfo` | Guaranteed delivery queue | All messages in order | Yes |
| `transferFile` | File transfers | All files in order | Yes |
| `transferCurrentComplicationUserInfo` | Complication updates | Priority delivery | Yes |

### Data Type Restrictions

All transfer methods accept dictionaries of type `[String: Any]`, but only property list types are supported:
- String, Int, Double, Float, Bool
- Data, Date
- Array, Dictionary (containing only plist types)
- NSNumber, NSString, NSData, NSDate, NSArray, NSDictionary

Custom types must be encoded to Data before transfer.

---

## Setup and Configuration

### iOS App Setup

```swift
// In your iOS App file or AppDelegate
import SwiftUI
import WatchConnectivity

@main
struct MyApp: App {
    @State private var connectivityManager = WatchConnectivityManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(connectivityManager)
        }
    }
}
```

### watchOS App Setup

```swift
// In your watchOS App file
import SwiftUI
import WatchConnectivity

@main
struct MyWatchApp: App {
    @State private var connectivityManager = WatchConnectivityManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(connectivityManager)
        }
    }
}
```

### Shared Manager (Target Membership: iOS + watchOS)

```swift
import Foundation
import WatchConnectivity

@Observable
@MainActor
final class WatchConnectivityManager: NSObject {

    // MARK: - Properties

    private let session: WCSession

    var isSupported: Bool {
        WCSession.isSupported()
    }

    var activationState: WCSessionActivationState {
        session.activationState
    }

    var isReachable: Bool {
        session.isReachable
    }

    #if os(iOS)
    var isPaired: Bool {
        session.isPaired
    }

    var isWatchAppInstalled: Bool {
        session.isWatchAppInstalled
    }
    #endif

    // Received data
    var receivedMessage: [String: Any] = [:]
    var receivedApplicationContext: [String: Any] = [:]
    var receivedUserInfo: [String: Any] = [:]
    var receivedFile: WCSessionFile?

    // MARK: - Initialization

    override init() {
        self.session = WCSession.default
        super.init()

        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            print("Session activation failed: \(error.localizedDescription)")
        } else {
            print("Session activated with state: \(activationState.rawValue)")
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        print("Session became inactive")
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        print("Session deactivated")
        // Reactivate session for switching between multiple watches
        session.activate()
    }
    #endif

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            print("Reachability changed: \(session.isReachable)")
        }
    }
}
```

---

## Core Concepts

### WCSession

`WCSession` is the central object for Watch Connectivity. It manages the connection between the iPhone and Apple Watch.

```swift
// Access the default session
let session = WCSession.default

// Check if sessions are supported on this device
if WCSession.isSupported() {
    // Safe to use WCSession
}
```

### WCSessionDelegate

The delegate protocol defines methods for:
- Session activation completion
- Receiving messages, application context, user info, and files
- Monitoring reachability changes

### Required Delegate Methods

**iOS requires three methods:**
```swift
func session(_ session: WCSession, activationDidCompleteWith: WCSessionActivationState, error: Error?)
func sessionDidBecomeInactive(_ session: WCSession)
func sessionDidDeactivate(_ session: WCSession)
```

**watchOS requires only one method:**
```swift
func session(_ session: WCSession, activationDidCompleteWith: WCSessionActivationState, error: Error?)
```

---

## Session Activation and State

### Activation States

```swift
enum WCSessionActivationState: Int {
    case notActivated = 0  // Session not yet activated
    case inactive = 1      // Session transitioning (iOS only, during watch switching)
    case activated = 2     // Session ready for communication
}
```

### Checking Session State

```swift
@Observable
@MainActor
final class WatchConnectivityManager: NSObject {

    /// Check if communication is possible
    var canSendData: Bool {
        guard WCSession.isSupported() else { return false }

        let session = WCSession.default

        #if os(iOS)
        return session.activationState == .activated
            && session.isPaired
            && session.isWatchAppInstalled
        #else
        return session.activationState == .activated
        #endif
    }

    /// Check if interactive messaging is possible
    var canSendMessage: Bool {
        canSendData && WCSession.default.isReachable
    }
}
```

### Observing Reachability Changes

```swift
extension WatchConnectivityManager: WCSessionDelegate {

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            // Update UI or trigger actions based on reachability
            if session.isReachable {
                // Watch app is in foreground, can send messages
            } else {
                // Watch app not reachable, use background transfer methods
            }
        }
    }
}
```

---

## Interactive Messaging

Interactive messaging (`sendMessage`) provides real-time communication when both apps are active.

### Platform Behavior

- **iOS to watchOS:** Watch app must be in the foreground
- **watchOS to iOS:** iOS app can be in background (will be woken up)

### Sending Messages

```swift
extension WatchConnectivityManager {

    /// Send a message to the counterpart app
    func sendMessage(_ message: [String: Any]) async throws -> [String: Any]? {
        guard canSendMessage else {
            throw WatchConnectivityError.notReachable
        }

        return try await withCheckedThrowingContinuation { continuation in
            session.sendMessage(
                message,
                replyHandler: { @Sendable reply in
                    continuation.resume(returning: reply)
                },
                errorHandler: { @Sendable error in
                    continuation.resume(throwing: error)
                }
            )
        }
    }

    /// Send a message without expecting a reply
    func sendMessage(_ message: [String: Any]) throws {
        guard canSendMessage else {
            throw WatchConnectivityError.notReachable
        }

        session.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }

    /// Send binary data
    func sendMessageData(_ data: Data) async throws -> Data {
        guard canSendMessage else {
            throw WatchConnectivityError.notReachable
        }

        return try await withCheckedThrowingContinuation { continuation in
            session.sendMessageData(
                data,
                replyHandler: { @Sendable reply in
                    continuation.resume(returning: reply)
                },
                errorHandler: { @Sendable error in
                    continuation.resume(throwing: error)
                }
            )
        }
    }
}
```

### Receiving Messages

```swift
extension WatchConnectivityManager: WCSessionDelegate {

    // Message without reply handler
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Task { @MainActor in
            receivedMessage = message
            handleMessage(message)
        }
    }

    // Message with reply handler
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task { @MainActor in
            receivedMessage = message
            let response = await processMessage(message)
            replyHandler(response)
        }
    }

    // Binary data
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessageData messageData: Data
    ) {
        Task { @MainActor in
            handleMessageData(messageData)
        }
    }

    // Binary data with reply
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessageData messageData: Data,
        replyHandler: @escaping (Data) -> Void
    ) {
        Task { @MainActor in
            let response = await processMessageData(messageData)
            replyHandler(response)
        }
    }
}
```

---

## Application Context

Application context is ideal for syncing the latest app state. Only the most recent value is delivered.

### Sending Application Context

```swift
extension WatchConnectivityManager {

    /// Update the application context
    /// Only the latest context is delivered to the counterpart
    func updateApplicationContext(_ context: [String: Any]) throws {
        guard canSendData else {
            throw WatchConnectivityError.sessionNotActivated
        }

        try session.updateApplicationContext(context)
    }

    /// Get the most recently sent application context
    var applicationContext: [String: Any] {
        session.applicationContext
    }

    /// Get the most recently received application context
    var receivedContext: [String: Any] {
        session.receivedApplicationContext
    }
}
```

### Receiving Application Context

```swift
extension WatchConnectivityManager: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in
            receivedApplicationContext = applicationContext
            handleApplicationContextUpdate(applicationContext)
        }
    }
}
```

### Use Case Example: Settings Sync

```swift
// On iOS - when user changes settings
func syncSettings(_ settings: UserSettings) {
    let context: [String: Any] = [
        "theme": settings.theme.rawValue,
        "notifications": settings.notificationsEnabled,
        "fontSize": settings.fontSize
    ]

    try? connectivityManager.updateApplicationContext(context)
}

// On watchOS - receive and apply settings
func handleApplicationContextUpdate(_ context: [String: Any]) {
    if let themeValue = context["theme"] as? String,
       let theme = Theme(rawValue: themeValue) {
        settings.theme = theme
    }

    if let notifications = context["notifications"] as? Bool {
        settings.notificationsEnabled = notifications
    }

    if let fontSize = context["fontSize"] as? Int {
        settings.fontSize = fontSize
    }
}
```

---

## User Info Transfers

User info transfers provide guaranteed, sequential delivery. All transfers are queued and delivered in order.

### Sending User Info

```swift
extension WatchConnectivityManager {

    /// Transfer user info (queued, guaranteed delivery)
    @discardableResult
    func transferUserInfo(_ userInfo: [String: Any]) -> WCSessionUserInfoTransfer? {
        guard canSendData else { return nil }
        return session.transferUserInfo(userInfo)
    }

    /// Get all outstanding user info transfers
    var outstandingUserInfoTransfers: [WCSessionUserInfoTransfer] {
        session.outstandingUserInfoTransfers
    }

    /// Cancel a specific transfer
    func cancelTransfer(_ transfer: WCSessionUserInfoTransfer) {
        transfer.cancel()
    }
}
```

### Receiving User Info

```swift
extension WatchConnectivityManager: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any]
    ) {
        Task { @MainActor in
            receivedUserInfo = userInfo
            handleUserInfo(userInfo)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didFinish userInfoTransfer: WCSessionUserInfoTransfer,
        error: Error?
    ) {
        if let error {
            print("User info transfer failed: \(error.localizedDescription)")
        } else {
            print("User info transfer completed")
        }
    }
}
```

### Use Case Example: Activity Log Sync

```swift
// On watchOS - log completed workout
func logWorkout(_ workout: Workout) {
    let userInfo: [String: Any] = [
        "type": "workout",
        "id": workout.id.uuidString,
        "name": workout.name,
        "duration": workout.duration,
        "calories": workout.calories,
        "date": workout.date.timeIntervalSince1970
    ]

    connectivityManager.transferUserInfo(userInfo)
}

// On iOS - receive all logged workouts
func handleUserInfo(_ userInfo: [String: Any]) {
    guard let type = userInfo["type"] as? String else { return }

    switch type {
    case "workout":
        if let workout = Workout(from: userInfo) {
            workoutManager.addWorkout(workout)
        }
    default:
        break
    }
}
```

---

## File Transfers

File transfers allow sending files with optional metadata between devices.

### Sending Files

```swift
extension WatchConnectivityManager {

    /// Transfer a file to the counterpart
    @discardableResult
    func transferFile(at url: URL, metadata: [String: Any]? = nil) -> WCSessionFileTransfer? {
        guard canSendData else { return nil }
        return session.transferFile(url, metadata: metadata)
    }

    /// Get all outstanding file transfers
    var outstandingFileTransfers: [WCSessionFileTransfer] {
        session.outstandingFileTransfers
    }

    /// Cancel a specific file transfer
    func cancelFileTransfer(_ transfer: WCSessionFileTransfer) {
        transfer.cancel()
    }
}
```

### Receiving Files

```swift
extension WatchConnectivityManager: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        didReceive file: WCSessionFile
    ) {
        Task { @MainActor in
            await handleReceivedFile(file)
        }
    }

    @MainActor
    private func handleReceivedFile(_ file: WCSessionFile) async {
        let sourceURL = file.fileURL
        let metadata = file.metadata

        // Move file to permanent location before this method returns
        // The source URL is only valid during this callback
        let documentsURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!

        let fileName = metadata?["fileName"] as? String ?? sourceURL.lastPathComponent
        let destinationURL = documentsURL.appendingPathComponent(fileName)

        do {
            // Remove existing file if present
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            receivedFile = file

            print("File saved to: \(destinationURL)")
        } catch {
            print("Failed to save file: \(error.localizedDescription)")
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didFinish fileTransfer: WCSessionFileTransfer,
        error: Error?
    ) {
        if let error {
            print("File transfer failed: \(error.localizedDescription)")
        } else {
            print("File transfer completed: \(fileTransfer.file.fileURL)")
        }
    }
}
```

### Use Case Example: Audio Recording Transfer

```swift
// On watchOS - send recorded audio
func sendRecording(at url: URL) {
    let metadata: [String: Any] = [
        "fileName": "recording_\(Date().timeIntervalSince1970).m4a",
        "duration": audioDuration,
        "recordedAt": Date().timeIntervalSince1970
    ]

    connectivityManager.transferFile(at: url, metadata: metadata)
}

// On iOS - receive and process recording
func handleReceivedFile(_ file: WCSessionFile) async {
    guard let metadata = file.metadata,
          let fileName = metadata["fileName"] as? String else {
        return
    }

    // File is automatically saved in handleReceivedFile
    // Now process it (transcription, storage, etc.)
    await processAudioFile(named: fileName)
}
```

---

## Complication Updates

Use `transferCurrentComplicationUserInfo` to update Watch complications with priority delivery.

### Important Notes

- Limited to approximately 50 transfers per day
- Takes priority over regular user info transfers
- Does **not** work with WidgetKit-based complications

### Sending Complication Updates

```swift
#if os(iOS)
extension WatchConnectivityManager {

    /// Transfer complication data with priority
    @discardableResult
    func transferComplicationUserInfo(_ userInfo: [String: Any]) -> WCSessionUserInfoTransfer? {
        guard canSendData else { return nil }

        // Check remaining budget
        if session.remainingComplicationUserInfoTransfers > 0 {
            return session.transferCurrentComplicationUserInfo(userInfo)
        } else {
            // Fall back to regular user info transfer
            return session.transferUserInfo(userInfo)
        }
    }

    /// Remaining complication transfers in budget
    var remainingComplicationTransfers: Int {
        session.remainingComplicationUserInfoTransfers
    }
}
#endif
```

### Receiving Complication Data

```swift
// On watchOS - in your complication controller or extension delegate
extension WatchConnectivityManager: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any]
    ) {
        Task { @MainActor in
            // Check if this is complication data
            if let isComplicationData = userInfo["complication"] as? Bool,
               isComplicationData {
                updateComplication(with: userInfo)
            }
        }
    }

    @MainActor
    private func updateComplication(with data: [String: Any]) {
        // Update your complication data store
        // Then reload the complication timeline
        let server = CLKComplicationServer.sharedInstance()
        for complication in server.activeComplications ?? [] {
            server.reloadTimeline(for: complication)
        }
    }
}
```

---

## SwiftUI Integration with @Observable

### Complete Manager Implementation

```swift
import Foundation
import WatchConnectivity

// MARK: - Errors

enum WatchConnectivityError: LocalizedError {
    case notSupported
    case sessionNotActivated
    case notReachable
    case notPaired
    case watchAppNotInstalled
    case encodingFailed
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .notSupported:
            return "Watch Connectivity is not supported on this device"
        case .sessionNotActivated:
            return "Session is not activated"
        case .notReachable:
            return "Counterpart app is not reachable"
        case .notPaired:
            return "No Apple Watch is paired"
        case .watchAppNotInstalled:
            return "Watch app is not installed"
        case .encodingFailed:
            return "Failed to encode data"
        case .decodingFailed:
            return "Failed to decode data"
        }
    }
}

// MARK: - Manager

@Observable
@MainActor
final class WatchConnectivityManager: NSObject {

    // MARK: - Published State

    private(set) var isActivated = false
    private(set) var isReachable = false
    private(set) var lastReceivedMessage: [String: Any] = [:]
    private(set) var lastReceivedContext: [String: Any] = [:]
    private(set) var connectionError: Error?

    #if os(iOS)
    private(set) var isPaired = false
    private(set) var isWatchAppInstalled = false
    #endif

    // MARK: - Private

    private let session: WCSession

    // MARK: - Computed Properties

    var canCommunicate: Bool {
        #if os(iOS)
        return isActivated && isPaired && isWatchAppInstalled
        #else
        return isActivated
        #endif
    }

    var canSendMessage: Bool {
        canCommunicate && isReachable
    }

    // MARK: - Initialization

    override init() {
        self.session = WCSession.default
        super.init()

        guard WCSession.isSupported() else {
            connectionError = WatchConnectivityError.notSupported
            return
        }

        session.delegate = self
        session.activate()
    }

    // MARK: - Public Methods

    /// Send an interactive message with reply
    func sendMessage(_ message: [String: Any]) async throws -> [String: Any]? {
        guard canSendMessage else {
            throw WatchConnectivityError.notReachable
        }

        return try await withCheckedThrowingContinuation { continuation in
            session.sendMessage(
                message,
                replyHandler: { @Sendable reply in
                    continuation.resume(returning: reply)
                },
                errorHandler: { @Sendable error in
                    continuation.resume(throwing: error)
                }
            )
        }
    }

    /// Send a Codable object as a message
    func send<T: Codable>(_ object: T, key: String = "data") async throws -> [String: Any]? {
        let data = try JSONEncoder().encode(object)
        let message: [String: Any] = [key: data]
        return try await sendMessage(message)
    }

    /// Update application context
    func updateContext(_ context: [String: Any]) throws {
        guard canCommunicate else {
            throw WatchConnectivityError.sessionNotActivated
        }
        try session.updateApplicationContext(context)
    }

    /// Update context with a Codable object
    func updateContext<T: Codable>(_ object: T, key: String = "data") throws {
        let data = try JSONEncoder().encode(object)
        try updateContext([key: data])
    }

    /// Transfer user info
    @discardableResult
    func transferUserInfo(_ userInfo: [String: Any]) -> WCSessionUserInfoTransfer? {
        guard canCommunicate else { return nil }
        return session.transferUserInfo(userInfo)
    }

    /// Transfer a file
    @discardableResult
    func transferFile(at url: URL, metadata: [String: Any]? = nil) -> WCSessionFileTransfer? {
        guard canCommunicate else { return nil }
        return session.transferFile(url, metadata: metadata)
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            isActivated = activationState == .activated

            #if os(iOS)
            isPaired = session.isPaired
            isWatchAppInstalled = session.isWatchAppInstalled
            #endif

            isReachable = session.isReachable

            if let error {
                connectionError = error
            }
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor in
            isActivated = false
        }
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor in
            isActivated = false
        }
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            isPaired = session.isPaired
            isWatchAppInstalled = session.isWatchAppInstalled
        }
    }
    #endif

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isReachable = session.isReachable
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Task { @MainActor in
            lastReceivedMessage = message
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task { @MainActor in
            lastReceivedMessage = message
            // Process and reply
            let response = await handleMessageWithReply(message)
            replyHandler(response)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in
            lastReceivedContext = applicationContext
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any]
    ) {
        Task { @MainActor in
            handleUserInfo(userInfo)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceive file: WCSessionFile
    ) {
        Task { @MainActor in
            await handleFile(file)
        }
    }

    // MARK: - Message Handling

    @MainActor
    private func handleMessageWithReply(_ message: [String: Any]) async -> [String: Any] {
        // Override in subclass or handle via closure
        return ["status": "received"]
    }

    @MainActor
    private func handleUserInfo(_ userInfo: [String: Any]) {
        // Override in subclass or handle via closure
    }

    @MainActor
    private func handleFile(_ file: WCSessionFile) async {
        // Override in subclass or handle via closure
    }
}
```

### SwiftUI View Example

```swift
import SwiftUI

struct WatchConnectionView: View {
    @Environment(WatchConnectivityManager.self) private var connectivity

    @State private var messageToSend = ""
    @State private var isSending = false
    @State private var error: Error?

    var body: some View {
        Form {
            connectionStatusSection
            sendMessageSection
            receivedDataSection
        }
        .navigationTitle("Watch Connection")
    }

    // MARK: - Sections

    @ViewBuilder
    private var connectionStatusSection: some View {
        Section("Connection Status") {
            LabeledContent("Activated", value: connectivity.isActivated ? "Yes" : "No")
            LabeledContent("Reachable", value: connectivity.isReachable ? "Yes" : "No")

            #if os(iOS)
            LabeledContent("Paired", value: connectivity.isPaired ? "Yes" : "No")
            LabeledContent("App Installed", value: connectivity.isWatchAppInstalled ? "Yes" : "No")
            #endif

            if connectivity.canSendMessage {
                Label("Ready to communicate", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Label("Cannot send messages", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private var sendMessageSection: some View {
        Section("Send Message") {
            TextField("Message", text: $messageToSend)

            Button("Send") {
                sendMessage()
            }
            .disabled(!connectivity.canSendMessage || messageToSend.isEmpty || isSending)
        }
    }

    @ViewBuilder
    private var receivedDataSection: some View {
        Section("Received Data") {
            if connectivity.lastReceivedMessage.isEmpty {
                Text("No messages received")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(connectivity.lastReceivedMessage.keys), id: \.self) { key in
                    LabeledContent(key, value: "\(connectivity.lastReceivedMessage[key] ?? "")")
                }
            }
        }
    }

    // MARK: - Actions

    private func sendMessage() {
        isSending = true

        Task {
            do {
                let message: [String: Any] = ["text": messageToSend]
                _ = try await connectivity.sendMessage(message)
                messageToSend = ""
            } catch {
                self.error = error
            }
            isSending = false
        }
    }
}
```

---

## Async/Await Wrappers

### Using AsyncStream for Continuous Updates

```swift
extension WatchConnectivityManager {

    /// Stream of incoming messages
    var messageStream: AsyncStream<[String: Any]> {
        AsyncStream { continuation in
            let observation = withObservationTracking {
                _ = lastReceivedMessage
            } onChange: {
                Task { @MainActor in
                    continuation.yield(lastReceivedMessage)
                }
            }

            continuation.onTermination = { _ in
                // Cleanup if needed
            }
        }
    }

    /// Stream of application context updates
    var contextStream: AsyncStream<[String: Any]> {
        AsyncStream { continuation in
            let observation = withObservationTracking {
                _ = lastReceivedContext
            } onChange: {
                Task { @MainActor in
                    continuation.yield(lastReceivedContext)
                }
            }
        }
    }
}
```

### Using in SwiftUI with .task

```swift
struct ContentView: View {
    @Environment(WatchConnectivityManager.self) private var connectivity
    @State private var messages: [[String: Any]] = []

    var body: some View {
        List(messages.indices, id: \.self) { index in
            Text("\(messages[index])")
        }
        .task {
            for await message in connectivity.messageStream {
                messages.append(message)
            }
        }
    }
}
```

### Swift 6 Sendable Compliance

When using async/await with WatchConnectivity in Swift 6, ensure closures are marked `@Sendable`:

```swift
func sendMessage(_ message: [String: Any]) async throws -> [String: Any]? {
    return try await withCheckedThrowingContinuation { continuation in
        session.sendMessage(
            message,
            replyHandler: { @Sendable reply in
                continuation.resume(returning: reply)
            },
            errorHandler: { @Sendable error in
                continuation.resume(throwing: error)
            }
        )
    }
}
```

---

## Common Use Cases

### 1. Authentication Token Sync

```swift
// On iOS - after user logs in
func syncAuthToken(_ token: String) throws {
    let context: [String: Any] = [
        "authToken": token,
        "userId": currentUser.id,
        "timestamp": Date().timeIntervalSince1970
    ]
    try connectivity.updateContext(context)
}

// On watchOS - receive token
func handleContextUpdate(_ context: [String: Any]) {
    if let token = context["authToken"] as? String {
        authManager.setToken(token)
    }
}
```

### 2. Real-time Data Request

```swift
// On watchOS - request current weather
func requestWeather() async throws {
    let message: [String: Any] = ["action": "getWeather"]

    if let response = try await connectivity.sendMessage(message),
       let weatherData = response["weather"] as? Data {
        let weather = try JSONDecoder().decode(Weather.self, from: weatherData)
        self.currentWeather = weather
    }
}

// On iOS - handle request and reply
func handleMessageWithReply(_ message: [String: Any]) async -> [String: Any] {
    guard let action = message["action"] as? String else {
        return ["error": "Unknown action"]
    }

    switch action {
    case "getWeather":
        let weather = await weatherService.getCurrentWeather()
        let data = try? JSONEncoder().encode(weather)
        return ["weather": data ?? Data()]
    default:
        return ["error": "Unknown action"]
    }
}
```

### 3. Settings Sync

```swift
// Shared settings model
struct AppSettings: Codable {
    var theme: String
    var notificationsEnabled: Bool
    var hapticFeedback: Bool
}

// On iOS - sync when settings change
func settingsDidChange(_ settings: AppSettings) {
    do {
        let data = try JSONEncoder().encode(settings)
        try connectivity.updateContext(["settings": data])
    } catch {
        print("Failed to sync settings: \(error)")
    }
}

// On watchOS - apply received settings
func handleContextUpdate(_ context: [String: Any]) {
    guard let data = context["settings"] as? Data,
          let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
        return
    }

    self.settings = settings
}
```

### 4. Workout Data Sync

```swift
// On watchOS - queue workout for sync
func syncWorkout(_ workout: Workout) {
    do {
        let data = try JSONEncoder().encode(workout)
        let userInfo: [String: Any] = [
            "type": "workout",
            "data": data
        ]
        connectivity.transferUserInfo(userInfo)
    } catch {
        print("Failed to encode workout: \(error)")
    }
}

// On iOS - process all queued workouts
func handleUserInfo(_ userInfo: [String: Any]) {
    guard let type = userInfo["type"] as? String,
          type == "workout",
          let data = userInfo["data"] as? Data,
          let workout = try? JSONDecoder().decode(Workout.self, from: data) else {
        return
    }

    workoutStore.addWorkout(workout)
}
```

---

## Best Practices

### 1. Activate Session Early

```swift
// Activate in App init or AppDelegate
@main
struct MyApp: App {
    @State private var connectivity = WatchConnectivityManager()

    init() {
        // Session activates in manager init
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(connectivity)
        }
    }
}
```

### 2. Choose the Right Transfer Method

| Scenario | Method |
|----------|--------|
| Real-time interaction | `sendMessage` |
| Latest state/settings | `updateApplicationContext` |
| All events must be received | `transferUserInfo` |
| Large data or files | `transferFile` |
| Complication updates | `transferCurrentComplicationUserInfo` |

### 3. Keep Payloads Small

```swift
// DON'T send large objects directly
// let hugeImage = UIImage(...)
// try connectivity.updateContext(["image": hugeImage.pngData()!])

// DO compress or resize first
func compressedImageData(from image: UIImage, maxSize: Int = 100_000) -> Data? {
    var compression: CGFloat = 1.0
    var data = image.jpegData(compressionQuality: compression)

    while let d = data, d.count > maxSize, compression > 0.1 {
        compression -= 0.1
        data = image.jpegData(compressionQuality: compression)
    }

    return data
}
```

### 4. Handle Offline Gracefully

```swift
func syncData(_ data: [String: Any]) {
    if connectivity.canSendMessage {
        // Real-time sync
        Task {
            try? await connectivity.sendMessage(data)
        }
    } else if connectivity.canCommunicate {
        // Background sync
        connectivity.transferUserInfo(data)
    } else {
        // Queue locally for later
        pendingSync.append(data)
    }
}
```

### 5. Test on Real Devices

The watchOS Simulator has limitations:
- `transferFile` does not work
- `transferUserInfo` does not work
- `transferCurrentComplicationUserInfo` does not work

Always test data transfers on physical devices.

### 6. Handle Session State Changes

```swift
extension WatchConnectivityManager: WCSessionDelegate {

    #if os(iOS)
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // User may have switched watches
        // Reactivate to support multiple watches
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            isPaired = session.isPaired
            isWatchAppInstalled = session.isWatchAppInstalled

            // Prompt user to install watch app if needed
            if isPaired && !isWatchAppInstalled {
                showInstallPrompt = true
            }
        }
    }
    #endif
}
```

---

## Troubleshooting

### Common Issues

**Session not activating:**
- Ensure `WCSession.isSupported()` returns true
- Check that the delegate is set before calling `activate()`
- Verify both apps have the same App Group configured

**Messages not received:**
- Check `isReachable` before sending messages
- Ensure the watch app is in the foreground (for iOS to watchOS)
- Verify delegate methods are implemented

**Application context not updating:**
- Only the latest context is delivered
- Check `receivedApplicationContext` for the last received value
- Ensure you're not exceeding size limits

**User info not delivered:**
- Cannot be tested in Simulator
- Check `outstandingUserInfoTransfers` for pending transfers
- Verify the watch is connected

**File transfer fails:**
- Cannot be tested in Simulator
- Move received files immediately (URL is temporary)
- Check available storage on both devices

### Debugging

```swift
extension WatchConnectivityManager {

    func logSessionState() {
        print("=== WCSession State ===")
        print("Supported: \(WCSession.isSupported())")
        print("Activation State: \(session.activationState.rawValue)")
        print("Reachable: \(session.isReachable)")

        #if os(iOS)
        print("Paired: \(session.isPaired)")
        print("Watch App Installed: \(session.isWatchAppInstalled)")
        print("Complication Enabled: \(session.isComplicationEnabled)")
        print("Remaining Complication Transfers: \(session.remainingComplicationUserInfoTransfers)")
        #endif

        print("Outstanding User Info: \(session.outstandingUserInfoTransfers.count)")
        print("Outstanding Files: \(session.outstandingFileTransfers.count)")
        print("=======================")
    }
}
```

---

## References

- [WCSession - Apple Developer Documentation](https://developer.apple.com/documentation/watchconnectivity/wcsession)
- [Watch Connectivity Framework - Apple Developer Documentation](https://developer.apple.com/documentation/WatchConnectivity)
- [WCSessionDelegate - Apple Developer Documentation](https://developer.apple.com/documentation/watchconnectivity/wcsessiondelegate)
- [WWDC21: There and Back Again - Data Transfer on Apple Watch](https://developer.apple.com/videos/play/wwdc2021/10003/)

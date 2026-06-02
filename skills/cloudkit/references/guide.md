# CloudKit Guide for iOS Development

A comprehensive guide for using CloudKit in iOS apps with SwiftUI and async/await patterns.

---

## Table of Contents

1. [Overview](#overview)
2. [Setup and Configuration](#setup-and-configuration)
3. [Core Concepts](#core-concepts)
4. [CKContainer](#ckcontainer)
5. [CKDatabase](#ckdatabase)
6. [CKRecord](#ckrecord)
7. [CKQuery and Fetching](#ckquery-and-fetching)
8. [Subscriptions and Notifications](#subscriptions-and-notifications)
9. [CKSyncEngine (iOS 17+)](#cksyncengine-ios-17)
10. [SwiftUI Integration](#swiftui-integration)
11. [Error Handling](#error-handling)
12. [Conflict Resolution](#conflict-resolution)
13. [Best Practices](#best-practices)
14. [Common Pitfalls](#common-pitfalls)
15. [iOS Version Compatibility](#ios-version-compatibility)

---

## Overview

**CloudKit** is Apple's framework for storing and syncing data to iCloud. It enables:

- **iCloud Sync** - Automatic data synchronization across user devices
- **Public Database** - Shared data accessible to all users of your app
- **Private Database** - User-specific data accessible only to the account owner
- **Shared Database** - Collaborative data shared between specific users
- **Subscriptions** - Real-time notifications when data changes
- **Large Asset Storage** - Store files, images, and binary data

### Key Benefits

| Feature | Description |
|---------|-------------|
| Free Storage | Up to 1PB public storage, 1GB per user private storage |
| Apple Integration | Works seamlessly with Apple's ecosystem |
| Security | Data encrypted in transit and at rest |
| No Server Code | Backend infrastructure managed by Apple |
| Offline Support | With proper implementation, supports offline-first patterns |

### When to Use CloudKit

- Apps requiring iCloud sync between user devices
- Apps needing shared public data (leaderboards, public content)
- Apps with collaborative features (shared documents, lists)
- When you want to avoid maintaining server infrastructure

---

## Setup and Configuration

### 1. Enable CloudKit Capability

In Xcode:
1. Select your project target
2. Go to **Signing & Capabilities**
3. Click **+ Capability**
4. Add **iCloud**
5. Check **CloudKit** checkbox
6. Select or create a container

### 2. Create CloudKit Container

Container identifiers follow the format: `iCloud.com.yourcompany.appname`

```swift
// Default container (matches bundle ID)
let container = CKContainer.default()

// Custom container
let container = CKContainer(identifier: "iCloud.com.yourcompany.appname")
```

### 3. Configure Entitlements

Your entitlements file should include:

```xml
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.com.yourcompany.appname</string>
</array>
<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudKit</string>
</array>
```

### 4. CloudKit Dashboard

Access at [iCloud Dashboard](https://icloud.developer.apple.com) to:
- Define record types and schemas
- View and edit data
- Monitor usage and quotas
- Set up indexes for queries
- Configure subscriptions

### Import Statement

```swift
import CloudKit
```

---

## Core Concepts

### Architecture Overview

```
CKContainer
├── publicCloudDatabase   (shared by all users)
├── privateCloudDatabase  (per-user data)
└── sharedCloudDatabase   (collaborative data)
    └── CKRecordZone
        └── CKRecord
            ├── Fields (key-value pairs)
            └── CKAsset (binary data)
```

### Key Classes

| Class | Purpose |
|-------|---------|
| `CKContainer` | Entry point to CloudKit, represents your app's iCloud container |
| `CKDatabase` | Represents public, private, or shared database |
| `CKRecordZone` | Logical grouping of records within a database |
| `CKRecord` | Single item of data with key-value fields |
| `CKRecord.ID` | Unique identifier for a record |
| `CKQuery` | Defines criteria for searching records |
| `CKSubscription` | Monitors database for changes |
| `CKAsset` | Binary data attached to a record |
| `CKSyncEngine` | High-level sync engine (iOS 17+) |

---

## CKContainer

The container is your entry point to CloudKit services.

### Accessing Containers

```swift
// Default container (uses bundle ID)
let defaultContainer = CKContainer.default()

// Custom container
let customContainer = CKContainer(identifier: "iCloud.com.yourcompany.appname")
```

### Checking Account Status

```swift
@Observable
class CloudKitManager {
    var accountStatus: CKAccountStatus = .couldNotDetermine
    var isSignedIn: Bool { accountStatus == .available }

    func checkAccountStatus() async {
        do {
            let status = try await CKContainer.default().accountStatus()
            await MainActor.run {
                self.accountStatus = status
            }
        } catch {
            print("Failed to get account status: \(error)")
        }
    }
}
```

### Account Status Values

| Status | Description |
|--------|-------------|
| `.available` | User is signed in to iCloud |
| `.noAccount` | No iCloud account configured |
| `.restricted` | iCloud access is restricted (parental controls) |
| `.couldNotDetermine` | Status could not be determined |
| `.temporarilyUnavailable` | iCloud is temporarily unavailable |

### Requesting User Identity

```swift
func requestUserIdentity() async throws -> String? {
    let container = CKContainer.default()

    // Request permission
    let status = try await container.requestApplicationPermission(.userDiscoverability)

    guard status == .granted else { return nil }

    // Fetch user record ID
    let userRecordID = try await container.userRecordID()

    // Fetch user identity
    let identity = try await container.userIdentity(forUserRecordID: userRecordID)

    return identity?.nameComponents?.formatted()
}
```

---

## CKDatabase

CloudKit provides three databases per container.

### Database Types

```swift
let container = CKContainer.default()

// Public database - accessible to all users
let publicDB = container.publicCloudDatabase

// Private database - user's personal data
let privateDB = container.privateCloudDatabase

// Shared database - collaborative data
let sharedDB = container.sharedCloudDatabase
```

### Database Comparison

| Feature | Public | Private | Shared |
|---------|--------|---------|--------|
| Accessible by | All users | Owner only | Invited users |
| Storage quota | App's quota | User's iCloud quota | Participant quotas |
| Requires sign-in | No (read), Yes (write) | Yes | Yes |
| Subscriptions | Server-to-server only | Yes | Yes |
| Use case | Shared content, leaderboards | User data | Collaboration |

### Accessing Databases

```swift
@Observable
class CloudKitService {
    private let container: CKContainer
    private var privateDatabase: CKDatabase { container.privateCloudDatabase }
    private var publicDatabase: CKDatabase { container.publicCloudDatabase }

    init(containerIdentifier: String? = nil) {
        if let identifier = containerIdentifier {
            container = CKContainer(identifier: identifier)
        } else {
            container = CKContainer.default()
        }
    }
}
```

---

## CKRecord

Records are the fundamental data objects in CloudKit.

### Creating Records

```swift
// Create with auto-generated ID
let record = CKRecord(recordType: "Note")

// Create with custom ID
let recordID = CKRecord.ID(recordName: "unique-identifier")
let record = CKRecord(recordType: "Note", recordID: recordID)

// Create in custom zone
let zoneID = CKRecordZone.ID(zoneName: "MyZone", ownerName: CKCurrentUserDefaultName)
let recordID = CKRecord.ID(recordName: "unique-identifier", zoneID: zoneID)
let record = CKRecord(recordType: "Note", recordID: recordID)
```

### Setting Field Values

```swift
let record = CKRecord(recordType: "Note")

// Basic types
record["title"] = "My Note" as CKRecordValue
record["content"] = "Note content here"
record["priority"] = 1
record["isComplete"] = false
record["createdAt"] = Date()

// Arrays
record["tags"] = ["work", "important"] as [String]

// Location
record["location"] = CLLocation(latitude: 37.7749, longitude: -122.4194)

// Reference to another record
let parentID = CKRecord.ID(recordName: "parent-id")
record["parent"] = CKRecord.Reference(recordID: parentID, action: .deleteSelf)
```

### Reading Field Values

```swift
let title = record["title"] as? String
let priority = record["priority"] as? Int
let tags = record["tags"] as? [String]
let location = record["location"] as? CLLocation
```

### Supported Field Types

| Swift Type | CloudKit Type |
|------------|---------------|
| `String` | String |
| `Int`, `Int64` | Int64 |
| `Double` | Double |
| `Date` | Date/Time |
| `Data` | Bytes |
| `Bool` | Int64 (0 or 1) |
| `[String]`, `[Int]`, etc. | List |
| `CLLocation` | Location |
| `CKAsset` | Asset |
| `CKRecord.Reference` | Reference |

### Working with Assets

```swift
// Create asset from file URL
let fileURL = URL(fileURLWithPath: "/path/to/image.jpg")
let asset = CKAsset(fileURL: fileURL)
record["image"] = asset

// Create asset from data
func createTempAsset(from data: Data) -> CKAsset? {
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    do {
        try data.write(to: tempURL)
        return CKAsset(fileURL: tempURL)
    } catch {
        return nil
    }
}

// Read asset
if let asset = record["image"] as? CKAsset,
   let fileURL = asset.fileURL {
    let data = try Data(contentsOf: fileURL)
    // Use data
}
```

### Model Conversion Pattern

```swift
struct Note: Identifiable, Sendable {
    let id: String
    var title: String
    var content: String
    var createdAt: Date
    var modifiedAt: Date

    static let recordType = "Note"

    // Convert from CKRecord
    init?(record: CKRecord) {
        guard record.recordType == Self.recordType,
              let title = record["title"] as? String,
              let content = record["content"] as? String else {
            return nil
        }

        self.id = record.recordID.recordName
        self.title = title
        self.content = content
        self.createdAt = record.creationDate ?? Date()
        self.modifiedAt = record.modificationDate ?? Date()
    }

    // Convert to CKRecord
    func toRecord(existingRecord: CKRecord? = nil) -> CKRecord {
        let record = existingRecord ?? CKRecord(
            recordType: Self.recordType,
            recordID: CKRecord.ID(recordName: id)
        )
        record["title"] = title
        record["content"] = content
        return record
    }
}
```

---

## CKQuery and Fetching

### Saving Records

```swift
@Observable
class CloudKitService {
    private let database: CKDatabase

    init() {
        database = CKContainer.default().privateCloudDatabase
    }

    // Save single record
    func save(_ record: CKRecord) async throws -> CKRecord {
        try await database.save(record)
    }

    // Save multiple records
    func saveMultiple(_ records: [CKRecord]) async throws -> [CKRecord] {
        let operation = CKModifyRecordsOperation(recordsToSave: records)
        operation.savePolicy = .changedKeys

        return try await withCheckedThrowingContinuation { continuation in
            var savedRecords: [CKRecord] = []

            operation.perRecordSaveBlock = { _, result in
                switch result {
                case .success(let record):
                    savedRecords.append(record)
                case .failure(let error):
                    print("Failed to save record: \(error)")
                }
            }

            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: savedRecords)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            database.add(operation)
        }
    }
}
```

### Fetching by ID

```swift
extension CloudKitService {
    // Fetch single record by ID
    func fetch(recordID: CKRecord.ID) async throws -> CKRecord {
        try await database.record(for: recordID)
    }

    // Fetch multiple records by IDs
    func fetch(recordIDs: [CKRecord.ID]) async throws -> [CKRecord] {
        let results = try await database.records(for: recordIDs)
        return results.compactMap { _, result in
            try? result.get()
        }
    }
}
```

### Querying with CKQuery

```swift
extension CloudKitService {
    // Basic query
    func fetchNotes() async throws -> [Note] {
        let query = CKQuery(recordType: "Note", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        let (matchResults, _) = try await database.records(matching: query)

        return matchResults.compactMap { _, result in
            guard let record = try? result.get() else { return nil }
            return Note(record: record)
        }
    }

    // Query with predicate
    func fetchNotes(containing searchText: String) async throws -> [Note] {
        let predicate = NSPredicate(format: "title CONTAINS[cd] %@", searchText)
        let query = CKQuery(recordType: "Note", predicate: predicate)

        let (matchResults, _) = try await database.records(matching: query)

        return matchResults.compactMap { _, result in
            guard let record = try? result.get() else { return nil }
            return Note(record: record)
        }
    }

    // Query with multiple conditions
    func fetchRecentImportantNotes() async throws -> [Note] {
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let predicate = NSPredicate(
            format: "createdAt > %@ AND priority > %d",
            oneWeekAgo as NSDate,
            5
        )
        let query = CKQuery(recordType: "Note", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "priority", ascending: false)]

        let (matchResults, _) = try await database.records(matching: query)

        return matchResults.compactMap { _, result in
            guard let record = try? result.get() else { return nil }
            return Note(record: record)
        }
    }
}
```

### Common Predicate Patterns

```swift
// Equal
NSPredicate(format: "status == %@", "active")

// Contains (case-insensitive)
NSPredicate(format: "title CONTAINS[cd] %@", searchText)

// Begins with
NSPredicate(format: "title BEGINSWITH %@", prefix)

// In array
NSPredicate(format: "category IN %@", ["work", "personal"])

// Date comparison
NSPredicate(format: "createdAt > %@", date as NSDate)

// Reference
NSPredicate(format: "parent == %@", parentReference)

// Location (within radius)
let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
NSPredicate(format: "distanceToLocation:fromLocation:(location, %@) < 1000", location)

// Compound predicates
let p1 = NSPredicate(format: "status == %@", "active")
let p2 = NSPredicate(format: "priority > %d", 5)
let compound = NSCompoundPredicate(andPredicateWithSubpredicates: [p1, p2])
```

### Pagination with Cursor

```swift
extension CloudKitService {
    func fetchNotesPaginated(
        cursor: CKQueryOperation.Cursor? = nil,
        limit: Int = 50
    ) async throws -> (notes: [Note], cursor: CKQueryOperation.Cursor?) {
        let query = CKQuery(recordType: "Note", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        let (matchResults, queryCursor) = try await database.records(
            matching: query,
            inZoneWith: nil,
            desiredKeys: nil,
            resultsLimit: limit
        )

        let notes = matchResults.compactMap { _, result in
            guard let record = try? result.get() else { return nil }
            return Note(record: record)
        }

        return (notes, queryCursor)
    }

    // Continue from cursor
    func fetchMoreNotes(cursor: CKQueryOperation.Cursor) async throws -> (notes: [Note], cursor: CKQueryOperation.Cursor?) {
        let (matchResults, queryCursor) = try await database.records(continuingMatchFrom: cursor)

        let notes = matchResults.compactMap { _, result in
            guard let record = try? result.get() else { return nil }
            return Note(record: record)
        }

        return (notes, queryCursor)
    }
}
```

### Deleting Records

```swift
extension CloudKitService {
    // Delete single record
    func delete(recordID: CKRecord.ID) async throws {
        try await database.deleteRecord(withID: recordID)
    }

    // Delete multiple records
    func delete(recordIDs: [CKRecord.ID]) async throws {
        let operation = CKModifyRecordsOperation(recordIDsToDelete: recordIDs)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            database.add(operation)
        }
    }
}
```

---

## Subscriptions and Notifications

Subscriptions enable real-time notifications when data changes.

### Types of Subscriptions

| Type | Use Case |
|------|----------|
| `CKQuerySubscription` | Notify when records matching a query change |
| `CKRecordZoneSubscription` | Notify when any record in a zone changes |
| `CKDatabaseSubscription` | Notify when any record in the database changes |

### Creating Query Subscription

```swift
extension CloudKitService {
    func subscribeToNoteChanges() async throws {
        let predicate = NSPredicate(value: true)
        let subscription = CKQuerySubscription(
            recordType: "Note",
            predicate: predicate,
            subscriptionID: "note-changes",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )

        let notification = CKSubscription.NotificationInfo()
        notification.shouldSendContentAvailable = true  // Silent notification
        notification.alertBody = "Notes updated"        // Optional visible alert
        notification.soundName = "default"              // Optional sound

        subscription.notificationInfo = notification

        try await database.save(subscription)
    }
}
```

### Creating Zone Subscription

```swift
extension CloudKitService {
    func subscribeToZoneChanges(zoneName: String) async throws {
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        let subscription = CKRecordZoneSubscription(
            zoneID: zoneID,
            subscriptionID: "zone-\(zoneName)-changes"
        )

        let notification = CKSubscription.NotificationInfo()
        notification.shouldSendContentAvailable = true
        subscription.notificationInfo = notification

        try await database.save(subscription)
    }
}
```

### Handling Push Notifications

```swift
// In AppDelegate or App struct
func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any]
) async -> UIBackgroundFetchResult {
    guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
        return .noData
    }

    switch notification.notificationType {
    case .query:
        if let queryNotification = notification as? CKQueryNotification {
            await handleQueryNotification(queryNotification)
        }
    case .recordZone:
        if let zoneNotification = notification as? CKRecordZoneNotification {
            await handleZoneNotification(zoneNotification)
        }
    case .database:
        await handleDatabaseChange()
    default:
        break
    }

    return .newData
}

func handleQueryNotification(_ notification: CKQueryNotification) async {
    guard let recordID = notification.recordID else { return }

    switch notification.queryNotificationReason {
    case .recordCreated:
        // Fetch and add new record
        break
    case .recordUpdated:
        // Fetch and update record
        break
    case .recordDeleted:
        // Remove record from local cache
        break
    @unknown default:
        break
    }
}
```

### Register for Remote Notifications

```swift
// In your App or AppDelegate
func registerForPushNotifications() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
        if granted {
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
}
```

---

## CKSyncEngine (iOS 17+)

`CKSyncEngine` is Apple's high-level sync engine that handles the complexity of CloudKit syncing.

### When to Use CKSyncEngine

- You have your own local persistence (not Core Data or SwiftData)
- You want to sync with CloudKit without managing operations manually
- You need robust offline support with automatic sync

### Basic Setup

```swift
import CloudKit

@Observable
class SyncManager: CKSyncEngineDelegate {
    private var syncEngine: CKSyncEngine?
    private let container: CKContainer
    private let database: CKDatabase

    // Local data cache
    private(set) var notes: [String: Note] = [:]

    init() {
        container = CKContainer(identifier: "iCloud.com.yourcompany.appname")
        database = container.privateCloudDatabase
        initializeSyncEngine()
    }

    private func initializeSyncEngine() {
        let configuration = CKSyncEngine.Configuration(
            database: database,
            stateSerialization: loadSyncState(),
            delegate: self
        )
        syncEngine = CKSyncEngine(configuration)
    }

    private func loadSyncState() -> CKSyncEngine.State.Serialization? {
        // Load persisted sync state from disk
        guard let data = UserDefaults.standard.data(forKey: "syncEngineState") else {
            return nil
        }
        return try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
    }

    private func saveSyncState(_ state: CKSyncEngine.State.Serialization) {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: "syncEngineState")
        }
    }
}
```

### Implementing CKSyncEngineDelegate

```swift
extension SyncManager {
    // MARK: - Handle Events from Server
    // Note: as of the current SDK, CKSyncEngineDelegate's handleEvent and
    // nextRecordZoneChangeBatch are `async`. Mark them async and await inside.

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let stateUpdate):
            saveSyncState(stateUpdate.stateSerialization)

        case .accountChange(let accountChange):
            handleAccountChange(accountChange)

        case .fetchedDatabaseChanges(let changes):
            handleDatabaseChanges(changes)

        case .fetchedRecordZoneChanges(let changes):
            handleRecordZoneChanges(changes)

        case .sentDatabaseChanges(let sentChanges):
            handleSentDatabaseChanges(sentChanges)

        case .sentRecordZoneChanges(let sentChanges):
            handleSentRecordZoneChanges(sentChanges)

        case .willFetchChanges, .willFetchRecordZoneChanges, .didFetchRecordZoneChanges,
             .willSendChanges, .didSendChanges, .didFetchChanges:
            // Progress events - update UI if needed
            break

        @unknown default:
            break
        }
    }

    private func handleAccountChange(_ change: CKSyncEngine.Event.AccountChange) {
        switch change.changeType {
        case .signIn:
            // User signed in - sync data
            break
        case .signOut:
            // User signed out - clear local data or mark as offline
            notes.removeAll()
        case .switchAccounts:
            // Different account - reload everything
            notes.removeAll()
        @unknown default:
            break
        }
    }

    private func handleRecordZoneChanges(_ changes: CKSyncEngine.Event.FetchedRecordZoneChanges) {
        for modification in changes.modifications {
            if let note = Note(record: modification.record) {
                notes[note.id] = note
            }
        }

        for deletion in changes.deletions {
            notes.removeValue(forKey: deletion.recordID.recordName)
        }
    }

    private func handleSentRecordZoneChanges(_ changes: CKSyncEngine.Event.SentRecordZoneChanges) {
        // Handle successful saves
        for savedRecord in changes.savedRecords {
            if let note = Note(record: savedRecord) {
                notes[note.id] = note
            }
        }

        // Handle failures
        for failedSave in changes.failedRecordSaves {
            handleSaveFailure(failedSave)
        }
    }

    private func handleSaveFailure(_ failure: CKSyncEngine.RecordZoneChanges.SaveFailure) {
        switch failure.error.code {
        case .serverRecordChanged:
            // Conflict - server has newer version
            if let serverRecord = failure.error.serverRecord {
                resolveConflict(clientRecord: failure.record, serverRecord: serverRecord)
            }
        case .zoneNotFound:
            // Zone doesn't exist - create it
            createZoneAndRetry(for: failure.record)
        default:
            print("Failed to save record: \(failure.error)")
        }
    }
}
```

### Providing Changes to Sync

```swift
extension SyncManager {
    // MARK: - Provide Pending Changes

    func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        // Scope-filter pending changes so you only send what this batch asked for.
        let scope = context.options.scope
        let pendingChanges = syncEngine.state.pendingRecordZoneChanges.filter { scope.contains($0) }

        let batch = await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pendingChanges) { recordID in
            // Return the CKRecord for the given ID
            if let note = notes[recordID.recordName] {
                return note.toRecord()
            }
            return nil
        }

        return batch
    }

    // MARK: - Adding Local Changes

    func saveNote(_ note: Note) {
        // Update local cache
        notes[note.id] = note

        // Queue for sync
        let recordID = CKRecord.ID(recordName: note.id)
        syncEngine?.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
    }

    func deleteNote(_ noteID: String) {
        // Remove from local cache
        notes.removeValue(forKey: noteID)

        // Queue for sync
        let recordID = CKRecord.ID(recordName: noteID)
        syncEngine?.state.add(pendingRecordZoneChanges: [.deleteRecord(recordID)])
    }
}
```

### Setting Up Record Zone

```swift
extension SyncManager {
    static let zoneName = "Notes"

    func setupZone() {
        let zoneID = CKRecordZone.ID(zoneName: Self.zoneName, ownerName: CKCurrentUserDefaultName)
        let zone = CKRecordZone(zoneID: zoneID)

        syncEngine?.state.add(pendingDatabaseChanges: [.saveZone(zone)])
    }

    private func createZoneAndRetry(for record: CKRecord) {
        setupZone()
        // The sync engine will automatically retry the record save
    }
}
```

---

## SwiftUI Integration

### CloudKit Manager with @Observable

```swift
import CloudKit
import SwiftUI

@Observable
@MainActor
class CloudKitNotesManager {
    private let database: CKDatabase

    var notes: [Note] = []
    var isLoading = false
    var error: Error?

    init() {
        database = CKContainer.default().privateCloudDatabase
    }

    func fetchNotes() async {
        isLoading = true
        error = nil

        do {
            let query = CKQuery(recordType: "Note", predicate: NSPredicate(value: true))
            query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

            let (matchResults, _) = try await database.records(matching: query)

            notes = matchResults.compactMap { _, result in
                guard let record = try? result.get() else { return nil }
                return Note(record: record)
            }
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func saveNote(_ note: Note) async {
        do {
            let record = note.toRecord()
            let savedRecord = try await database.save(record)

            if let index = notes.firstIndex(where: { $0.id == note.id }) {
                notes[index] = Note(record: savedRecord) ?? note
            } else {
                if let newNote = Note(record: savedRecord) {
                    notes.insert(newNote, at: 0)
                }
            }
        } catch {
            self.error = error
        }
    }

    func deleteNote(_ note: Note) async {
        let recordID = CKRecord.ID(recordName: note.id)

        do {
            try await database.deleteRecord(withID: recordID)
            notes.removeAll { $0.id == note.id }
        } catch {
            self.error = error
        }
    }
}
```

### SwiftUI View Example

```swift
struct NotesListView: View {
    @State private var manager = CloudKitNotesManager()
    @State private var showingAddNote = false
    @State private var newNoteTitle = ""
    @State private var newNoteContent = ""

    var body: some View {
        NavigationStack {
            Group {
                if manager.isLoading {
                    ProgressView("Loading notes...")
                } else if manager.notes.isEmpty {
                    ContentUnavailableView(
                        "No Notes",
                        systemImage: "note.text",
                        description: Text("Tap + to create a note")
                    )
                } else {
                    notesList
                }
            }
            .navigationTitle("Notes")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddNote = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .task {
                await manager.fetchNotes()
            }
            .refreshable {
                await manager.fetchNotes()
            }
            .alert("Error", isPresented: .constant(manager.error != nil)) {
                Button("OK") {
                    manager.error = nil
                }
            } message: {
                Text(manager.error?.localizedDescription ?? "Unknown error")
            }
            .sheet(isPresented: $showingAddNote) {
                addNoteSheet
            }
        }
    }

    private var notesList: some View {
        List {
            ForEach(manager.notes) { note in
                VStack(alignment: .leading, spacing: 4) {
                    Text(note.title)
                        .font(.headline)
                    Text(note.content)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .onDelete(perform: deleteNotes)
        }
    }

    private var addNoteSheet: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $newNoteTitle)
                TextField("Content", text: $newNoteContent, axis: .vertical)
                    .lineLimit(5...10)
            }
            .navigationTitle("New Note")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingAddNote = false
                        resetForm()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveNewNote()
                        }
                    }
                    .disabled(newNoteTitle.isEmpty)
                }
            }
        }
    }

    private func deleteNotes(at offsets: IndexSet) {
        for index in offsets {
            let note = manager.notes[index]
            Task {
                await manager.deleteNote(note)
            }
        }
    }

    private func saveNewNote() async {
        let note = Note(
            id: UUID().uuidString,
            title: newNoteTitle,
            content: newNoteContent,
            createdAt: Date(),
            modifiedAt: Date()
        )

        await manager.saveNote(note)
        showingAddNote = false
        resetForm()
    }

    private func resetForm() {
        newNoteTitle = ""
        newNoteContent = ""
    }
}
```

### Environment Injection Pattern

```swift
@main
struct MyApp: App {
    @State private var cloudKitManager = CloudKitNotesManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(cloudKitManager)
        }
    }
}

struct ContentView: View {
    @Environment(CloudKitNotesManager.self) var cloudKitManager

    var body: some View {
        NotesListView()
    }
}
```

---

## Error Handling

### CloudKit Error Types

```swift
enum CloudKitError: LocalizedError {
    case notAuthenticated
    case networkUnavailable
    case quotaExceeded
    case serverError(String)
    case recordNotFound
    case conflictDetected(serverRecord: CKRecord)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to iCloud to sync your data."
        case .networkUnavailable:
            return "Network unavailable. Changes will sync when connection is restored."
        case .quotaExceeded:
            return "iCloud storage is full. Please free up space to continue syncing."
        case .serverError(let message):
            return "Server error: \(message)"
        case .recordNotFound:
            return "The requested item was not found."
        case .conflictDetected:
            return "A conflict was detected. The server version has been kept."
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}
```

### Error Mapping

```swift
extension CloudKitService {
    func mapError(_ error: Error) -> CloudKitError {
        guard let ckError = error as? CKError else {
            return .unknown(error)
        }

        switch ckError.code {
        case .notAuthenticated:
            return .notAuthenticated
        case .networkUnavailable, .networkFailure:
            return .networkUnavailable
        case .quotaExceeded:
            return .quotaExceeded
        case .serverRecordChanged:
            if let serverRecord = ckError.serverRecord {
                return .conflictDetected(serverRecord: serverRecord)
            }
            return .serverError("Record conflict")
        case .unknownItem:
            return .recordNotFound
        case .serviceUnavailable, .requestRateLimited:
            return .serverError("Service temporarily unavailable")
        default:
            return .unknown(error)
        }
    }
}
```

### Retry Logic

```swift
extension CloudKitService {
    func performWithRetry<T>(
        maxAttempts: Int = 3,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch let error as CKError {
                lastError = error

                // Check if error is retryable
                guard isRetryable(error) else {
                    throw error
                }

                // Calculate delay
                let delay = retryDelay(for: error, attempt: attempt)

                // Wait before retry
                if delay > 0 {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        throw lastError ?? CloudKitError.unknown(NSError(domain: "CloudKit", code: -1))
    }

    private func isRetryable(_ error: CKError) -> Bool {
        switch error.code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable,
             .requestRateLimited, .zoneBusy:
            return true
        default:
            return false
        }
    }

    private func retryDelay(for error: CKError, attempt: Int) -> TimeInterval {
        // Check for suggested retry delay from server
        if let retryAfter = error.userInfo[CKErrorRetryAfterKey] as? TimeInterval {
            return retryAfter
        }

        // Exponential backoff
        return min(pow(2.0, Double(attempt)), 60.0)
    }
}
```

---

## Conflict Resolution

### Understanding Conflicts

Conflicts occur when:
- Two devices modify the same record offline
- A record is modified while being saved

### Conflict Resolution Strategies

```swift
enum ConflictResolution {
    case keepLocal       // Overwrite server with local changes
    case keepServer      // Discard local changes
    case merge           // Combine changes intelligently
    case askUser         // Let user decide
}

extension CloudKitService {
    func resolveConflict(
        clientRecord: CKRecord,
        serverRecord: CKRecord,
        strategy: ConflictResolution = .merge
    ) -> CKRecord {
        switch strategy {
        case .keepLocal:
            // Copy client values to server record (preserves server's change tag)
            for key in clientRecord.allKeys() {
                serverRecord[key] = clientRecord[key]
            }
            return serverRecord

        case .keepServer:
            return serverRecord

        case .merge:
            return mergeRecords(client: clientRecord, server: serverRecord)

        case .askUser:
            // Return server record for now, UI should handle this
            return serverRecord
        }
    }

    private func mergeRecords(client: CKRecord, server: CKRecord) -> CKRecord {
        // Use modification dates to resolve field-by-field
        let clientModified = client.modificationDate ?? Date.distantPast
        let serverModified = server.modificationDate ?? Date.distantPast

        // If client is newer, prefer client values
        if clientModified > serverModified {
            for key in client.allKeys() {
                server[key] = client[key]
            }
        }

        return server
    }
}
```

### Automatic Conflict Handling

```swift
extension CloudKitService {
    func saveWithConflictResolution(
        _ record: CKRecord,
        resolution: ConflictResolution = .merge
    ) async throws -> CKRecord {
        do {
            return try await database.save(record)
        } catch let error as CKError where error.code == .serverRecordChanged {
            guard let serverRecord = error.serverRecord else {
                throw error
            }

            let resolvedRecord = resolveConflict(
                clientRecord: record,
                serverRecord: serverRecord,
                strategy: resolution
            )

            // Try saving resolved record
            return try await database.save(resolvedRecord)
        }
    }
}
```

---

## Best Practices

### 1. Design for Offline First

```swift
@Observable
class OfflineFirstManager {
    private var pendingChanges: [PendingChange] = []

    struct PendingChange: Codable {
        let id: String
        let type: ChangeType
        let data: Data
        let timestamp: Date

        enum ChangeType: String, Codable {
            case create, update, delete
        }
    }

    func saveLocally(_ note: Note) {
        // 1. Save to local storage immediately
        saveToLocalDatabase(note)

        // 2. Queue for sync
        let change = PendingChange(
            id: note.id,
            type: .update,
            data: try! JSONEncoder().encode(note),
            timestamp: Date()
        )
        pendingChanges.append(change)
        persistPendingChanges()

        // 3. Attempt sync in background
        Task {
            await syncPendingChanges()
        }
    }

    func syncPendingChanges() async {
        guard !pendingChanges.isEmpty else { return }

        for change in pendingChanges {
            do {
                try await syncChange(change)
                pendingChanges.removeAll { $0.id == change.id }
            } catch {
                // Keep in queue for retry
                break
            }
        }

        persistPendingChanges()
    }
}
```

### 2. Use Custom Zones for Private Data

```swift
extension CloudKitService {
    static let customZoneName = "AppData"

    func createCustomZone() async throws {
        let zoneID = CKRecordZone.ID(
            zoneName: Self.customZoneName,
            ownerName: CKCurrentUserDefaultName
        )
        let zone = CKRecordZone(zoneID: zoneID)

        try await database.save(zone)
    }

    func createRecordInCustomZone(_ recordType: String) -> CKRecord {
        let zoneID = CKRecordZone.ID(
            zoneName: Self.customZoneName,
            ownerName: CKCurrentUserDefaultName
        )
        let recordID = CKRecord.ID(
            recordName: UUID().uuidString,
            zoneID: zoneID
        )
        return CKRecord(recordType: recordType, recordID: recordID)
    }
}
```

### 3. Batch Operations for Efficiency

```swift
extension CloudKitService {
    func batchSave(_ records: [CKRecord]) async throws {
        // CloudKit limits: 400 records per operation
        let batchSize = 400
        let batches = records.chunked(into: batchSize)

        for batch in batches {
            let operation = CKModifyRecordsOperation(recordsToSave: batch)
            operation.savePolicy = .changedKeys
            operation.isAtomic = false  // Allow partial success

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                operation.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                database.add(operation)
            }
        }
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
```

### 4. Index Your Queryable Fields

In CloudKit Dashboard:
1. Go to Schema > Record Types
2. Select your record type
3. Add indexes for fields used in predicates
4. Choose appropriate index type (Queryable, Searchable, Sortable)

### 5. Monitor Network and Account Status

```swift
@Observable
class CloudKitStatusMonitor {
    var isAvailable = false
    var accountStatus: CKAccountStatus = .couldNotDetermine

    private var statusTask: Task<Void, Never>?

    init() {
        startMonitoring()
    }

    func startMonitoring() {
        // Monitor account changes
        NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.checkStatus()
            }
        }

        // Initial check
        Task {
            await checkStatus()
        }
    }

    func checkStatus() async {
        do {
            let status = try await CKContainer.default().accountStatus()
            await MainActor.run {
                self.accountStatus = status
                self.isAvailable = status == .available
            }
        } catch {
            await MainActor.run {
                self.isAvailable = false
            }
        }
    }
}
```

---

## Common Pitfalls

### 1. Not Handling Account Changes

```swift
// WRONG: Assuming user is always signed in
func fetchData() async {
    let records = try? await database.records(matching: query) // May fail silently
}

// CORRECT: Check account status first
func fetchData() async throws {
    let status = try await CKContainer.default().accountStatus()
    guard status == .available else {
        throw CloudKitError.notAuthenticated
    }

    return try await database.records(matching: query)
}
```

### 2. Ignoring Rate Limits

```swift
// WRONG: Rapid-fire requests
for note in notes {
    try await database.save(note.toRecord())
}

// CORRECT: Batch operations
let records = notes.map { $0.toRecord() }
try await batchSave(records)
```

### 3. Not Persisting Sync State (CKSyncEngine)

```swift
// WRONG: Losing sync state on restart
func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) {
    // Not saving state updates
}

// CORRECT: Persist state updates
func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) {
    if case .stateUpdate(let stateUpdate) = event {
        saveSyncState(stateUpdate.stateSerialization)
    }
}
```

### 4. Blocking UI During Sync

```swift
// WRONG: Blocking main thread
@MainActor
func syncAllData() async {
    for note in allNotes {
        try? await database.save(note.toRecord()) // UI freezes
    }
}

// CORRECT: Background sync with UI updates
func syncAllData() async {
    await MainActor.run { isLoading = true }

    await withTaskGroup(of: Void.self) { group in
        for note in allNotes {
            group.addTask {
                try? await self.database.save(note.toRecord())
            }
        }
    }

    await MainActor.run { isLoading = false }
}
```

### 5. Not Setting Up Indexes

Queries on non-indexed fields fail. Always:
1. Define record types in CloudKit Dashboard
2. Add indexes for queryable fields
3. Deploy schema to production before app release

### 6. Forgetting Remote Notifications for CKSyncEngine

```swift
// CKSyncEngine requires remote notifications to work properly
// Simulators cannot register for push notifications

// In your app setup:
func configureForCloudKit() {
    #if !targetEnvironment(simulator)
    UIApplication.shared.registerForRemoteNotifications()
    #endif
}
```

---

## iOS Version Compatibility

| Feature | iOS Version | Notes |
|---------|-------------|-------|
| CloudKit Basic | iOS 8+ | Core functionality |
| `async/await` APIs | iOS 15+ | Modern concurrency |
| `CKSyncEngine` | iOS 17+ | High-level sync engine |
| Sharing | iOS 10+ | CKShare, UICloudSharingController |
| CKQuerySubscription | iOS 10+ | Query-based subscriptions |
| CKDatabaseSubscription | iOS 10+ | Database-level subscriptions |
| Encrypted Fields | iOS 15+ | End-to-end encryption |

### Version-Specific Code

```swift
func setupSync() {
    if #available(iOS 17, *) {
        // Use CKSyncEngine for simplified sync
        setupCKSyncEngine()
    } else {
        // Fall back to manual sync with subscriptions
        setupManualSync()
    }
}

@available(iOS 17, *)
func setupCKSyncEngine() {
    let configuration = CKSyncEngine.Configuration(
        database: database,
        stateSerialization: loadSyncState(),
        delegate: self
    )
    syncEngine = CKSyncEngine(configuration)
}

func setupManualSync() {
    // Use CKFetchRecordZoneChangesOperation for incremental sync
    // Use CKSubscription for change notifications
}
```

### Minimum Deployment Target Recommendations

| Use Case | Recommended Minimum |
|----------|---------------------|
| Basic CloudKit with async/await | iOS 15 |
| CKSyncEngine-based sync | iOS 17 |
| Legacy app support | iOS 13 |

---

## Additional Resources

- [Apple CloudKit Documentation](https://developer.apple.com/documentation/cloudkit)
- [WWDC 2023: Sync to iCloud with CKSyncEngine](https://developer.apple.com/videos/play/wwdc2023/10188/)
- [WWDC 2021: What's new in CloudKit](https://developer.apple.com/videos/play/wwdc2021/10086/)
- [Apple Sample: CKSyncEngine](https://github.com/apple/sample-cloudkit-sync-engine)
- [CloudKit Dashboard](https://icloud.developer.apple.com)

---

## Quick Reference

### Container & Database Access

```swift
let container = CKContainer.default()
let publicDB = container.publicCloudDatabase
let privateDB = container.privateCloudDatabase
```

### Basic CRUD

```swift
// Create/Update
let record = CKRecord(recordType: "Note")
record["title"] = "My Note"
let saved = try await database.save(record)

// Read
let fetched = try await database.record(for: recordID)

// Delete
try await database.deleteRecord(withID: recordID)

// Query
let query = CKQuery(recordType: "Note", predicate: NSPredicate(value: true))
let (results, _) = try await database.records(matching: query)
```

### CKSyncEngine Quick Setup (iOS 17+)

```swift
let config = CKSyncEngine.Configuration(
    database: privateDB,
    stateSerialization: loadState(),
    delegate: self
)
syncEngine = CKSyncEngine(config)

// Add changes
syncEngine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
```

# Apple GameSave Framework Guide for iOS 26

## Overview

The **GameSave** framework is a new Apple framework introduced in iOS 26 (WWDC 2025) that provides an easy way to enable cloud saves in games. It is powered by iCloud and designed with user privacy and data security in mind.

**Key Benefits:**
- Automatic cloud synchronization across all devices with the same iCloud account
- Built-in UI components for common scenarios
- Offline support and graceful handling of sign-out states
- Privacy-focused design
- Simple integration with minimal setup

**Platform Availability:**
- iOS 26+
- iPadOS 26+
- macOS Tahoe (26)+
- tvOS 26+
- visionOS 26+

**Documentation:** [Apple GameSave Documentation](https://developer.apple.com/documentation/GameSave)

---

## Use Case

The GameSave framework enables seamless cross-device gaming experiences:

1. Player starts a game on their Mac at home
2. They reach a milestone and save their progress
3. The save data uploads to iCloud automatically
4. Player opens the game on their iPhone - progress is synced
5. Player continues on their iPad at a cafe - same progress available

This "continue where you left off" experience is what makes games stand apart on Apple platforms.

---

## Setup Requirements

### Step 1: Enable iCloud Capability in Xcode

1. Open your project in Xcode
2. Select your app target
3. Go to **Signing & Capabilities**
4. Click **+ Capability** and add **iCloud**
5. Check the **iCloud Documents** checkbox
6. Add your iCloud container identifier (e.g., `iCloud.com.yourcompany.yourgame`)

### Step 2: Configure Provisioning Profile

1. Log in to your [Apple Developer Account](https://developer.apple.com/account)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Select your app identifier
4. Ensure the iCloud capability is enabled
5. Include the iCloud entitlement in your provisioning profile
6. Download and install the updated profile

### Step 3: Add Entitlements

Your app's entitlements file should include:

```xml
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.com.yourcompany.yourgame</string>
</array>
<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudDocuments</string>
</array>
<key>com.apple.developer.ubiquity-container-identifiers</key>
<array>
    <string>iCloud.com.yourcompany.yourgame</string>
</array>
```

---

## Core API

> **⚠️ Symbol-naming correction (verified 2026-06-02 against developer.apple.com/documentation/GameSave).**
> The examples in this guide use the placeholder symbol names `GSSyncedDirectory`, `GSSyncedDirectoryState`, and `GSSyncStateError`. These are **NOT** the shipping API names. The real GameSave framework (iOS 26) exposes:
> - **`GameSaveSyncedDirectory`** — the cloud-synced directory class (not `GSSyncedDirectory`).
> - **`GameSaveSyncedFile`** — represents an individual synced save file.
> - The directory-state / error enum, sync-availability states, and conflict types are likewise spelled with the `GameSave…` prefix, not `GS…`.
>
> Before writing code, confirm the exact signatures (`open`, conflict handling, availability/sync state) directly against the official docs. The Objective-C-flavored `GS…` names and the `finishSyncing:` call shapes in the snippets below are approximations and have NOT been verified against the shipping SDK. Treat the *patterns* (open → wait for sync → read state → access URL → handle conflict/sign-out) as correct; treat the literal *symbol spellings* as suspect.

### Primary Class: GameSaveSyncedDirectory (shown below as `GSSyncedDirectory`)

The main class for interacting with GameSave is `GameSaveSyncedDirectory`. (The snippets below write it as `GSSyncedDirectory` — substitute the real name.)

#### Opening a Synced Directory

**Objective-C:**
```objc
#import <GameSave/GameSave.h>

// Open directory with specific container identifier
NSString *containerIdentifier = @"iCloud.com.yourcompany.yourgame";
GSSyncedDirectory *directory = [GSSyncedDirectory openDirectoryForContainerIdentifier:containerIdentifier];

// Or use nil to use the first container in your entitlement array
GSSyncedDirectory *directory = [GSSyncedDirectory openDirectoryForContainerIdentifier:nil];
```

**Swift (Equivalent):**
```swift
import GameSave

// Open directory with specific container identifier
let containerIdentifier = "iCloud.com.yourcompany.yourgame"
let directory = GSSyncedDirectory.openDirectory(forContainerIdentifier: containerIdentifier)

// Or use nil to use the first container
let directory = GSSyncedDirectory.openDirectory(forContainerIdentifier: nil)
```

### Monitoring Sync Progress

Use `finishSyncing:completionHandler:` to monitor when synchronization completes.

**Objective-C:**
```objc
// statusDisplay is a UIWindow or NSWindow where alerts will be anchored
[directory finishSyncing:statusDisplay completionHandler:^{
    // Sync has finished - now safe to access save data
    [self handleSyncCompletion:directory];
}];
```

**Swift:**
```swift
directory.finishSyncing(statusDisplay) {
    // Sync has finished - now safe to access save data
    self.handleSyncCompletion(directory)
}
```

### Checking Directory State

After syncing completes, check the state to determine if synchronization was successful.

**Objective-C:**
```objc
GSSyncedDirectoryState *directoryState = [directory directoryState];

switch (directoryState.state) {
    case GSSyncStateError:
        NSError *error = directoryState.error;
        NSLog(@"Sync failed with error: %@", error.localizedDescription);
        [self handleSyncError:error];
        break;
    default:
        NSLog(@"Sync completed successfully");
        NSURL *saveURL = directoryState.url;
        [self loadSaveData:saveURL];
        break;
}
```

**Swift:**
```swift
let directoryState = directory.directoryState()

switch directoryState.state {
case .error:
    if let error = directoryState.error {
        print("Sync failed with error: \(error.localizedDescription)")
        handleSyncError(error)
    }
default:
    print("Sync completed successfully")
    if let saveURL = directoryState.url {
        loadSaveData(from: saveURL)
    }
}
```

### Accessing Save Data

The `directoryState.url` provides the local file URL where save data is stored.

**Objective-C:**
```objc
NSURL *saveURL = directoryState.url;

// Read save data
NSData *saveData = [NSData dataWithContentsOfURL:[saveURL URLByAppendingPathComponent:@"savegame.dat"]];

// Write save data
NSURL *saveFileURL = [saveURL URLByAppendingPathComponent:@"savegame.dat"];
[saveData writeToURL:saveFileURL atomically:YES];
```

**Swift:**
```swift
guard let saveURL = directoryState.url else { return }

// Read save data
let saveFileURL = saveURL.appendingPathComponent("savegame.dat")
let saveData = try? Data(contentsOf: saveFileURL)

// Write save data
try? saveData?.write(to: saveFileURL, options: .atomic)
```

---

## Complete Implementation Example

### Objective-C Implementation

```objc
#import <GameSave/GameSave.h>

@interface GameSaveManager : NSObject

@property (nonatomic, strong) GSSyncedDirectory *syncedDirectory;
@property (nonatomic, strong) NSURL *saveDirectoryURL;

- (void)initializeCloudSaves:(UIWindow *)statusWindow completion:(void(^)(BOOL success, NSError *error))completion;
- (void)saveGameProgress:(NSData *)saveData filename:(NSString *)filename;
- (NSData *)loadGameProgress:(NSString *)filename;

@end

@implementation GameSaveManager

- (void)initializeCloudSaves:(UIWindow *)statusWindow completion:(void(^)(BOOL success, NSError *error))completion {
    // Step 1: Open the synced directory
    NSString *containerID = @"iCloud.com.yourcompany.yourgame";
    self.syncedDirectory = [GSSyncedDirectory openDirectoryForContainerIdentifier:containerID];

    // Step 2: Wait for sync to complete with status display
    __weak typeof(self) weakSelf = self;
    [self.syncedDirectory finishSyncing:statusWindow completionHandler:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;

        // Step 3: Check the sync state
        GSSyncedDirectoryState *state = [strongSelf.syncedDirectory directoryState];

        if (state.state == GSSyncStateError) {
            NSError *error = state.error;
            NSLog(@"Cloud sync failed: %@", error.localizedDescription);
            if (completion) {
                completion(NO, error);
            }
        } else {
            // Step 4: Store the save directory URL
            strongSelf.saveDirectoryURL = state.url;
            NSLog(@"Cloud saves ready at: %@", strongSelf.saveDirectoryURL);
            if (completion) {
                completion(YES, nil);
            }
        }
    }];
}

- (void)saveGameProgress:(NSData *)saveData filename:(NSString *)filename {
    if (!self.saveDirectoryURL) {
        NSLog(@"Save directory not initialized");
        return;
    }

    NSURL *fileURL = [self.saveDirectoryURL URLByAppendingPathComponent:filename];
    NSError *error = nil;

    if ([saveData writeToURL:fileURL options:NSDataWritingAtomic error:&error]) {
        NSLog(@"Game saved successfully to: %@", fileURL);
    } else {
        NSLog(@"Failed to save game: %@", error.localizedDescription);
    }
}

- (NSData *)loadGameProgress:(NSString *)filename {
    if (!self.saveDirectoryURL) {
        NSLog(@"Save directory not initialized");
        return nil;
    }

    NSURL *fileURL = [self.saveDirectoryURL URLByAppendingPathComponent:filename];
    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfURL:fileURL options:0 error:&error];

    if (error) {
        NSLog(@"Failed to load game: %@", error.localizedDescription);
    }

    return data;
}

@end
```

### Swift Implementation

```swift
import GameSave
import Foundation

@Observable
class GameSaveManager {

    // MARK: - Properties

    private var syncedDirectory: GSSyncedDirectory?
    private(set) var saveDirectoryURL: URL?
    private(set) var isSyncing = false
    private(set) var lastError: Error?

    private let containerIdentifier: String

    // MARK: - Initialization

    init(containerIdentifier: String = "iCloud.com.yourcompany.yourgame") {
        self.containerIdentifier = containerIdentifier
    }

    // MARK: - Public Methods

    /// Initialize cloud saves with sync status display
    /// - Parameters:
    ///   - statusWindow: Window to anchor sync status alerts
    ///   - completion: Callback with success/failure status
    func initializeCloudSaves(statusWindow: UIWindow?, completion: @escaping (Bool, Error?) -> Void) {
        isSyncing = true
        lastError = nil

        // Step 1: Open the synced directory
        syncedDirectory = GSSyncedDirectory.openDirectory(forContainerIdentifier: containerIdentifier)

        guard let directory = syncedDirectory else {
            isSyncing = false
            let error = GameSaveError.failedToOpenDirectory
            lastError = error
            completion(false, error)
            return
        }

        // Step 2: Wait for sync to complete
        directory.finishSyncing(statusWindow) { [weak self] in
            guard let self = self else { return }

            self.isSyncing = false

            // Step 3: Check sync state
            let state = directory.directoryState()

            if state.state == .error {
                let error = state.error ?? GameSaveError.unknownSyncError
                self.lastError = error
                print("Cloud sync failed: \(error.localizedDescription)")
                completion(false, error)
            } else {
                // Step 4: Store save directory URL
                self.saveDirectoryURL = state.url
                print("Cloud saves ready at: \(state.url?.path ?? "unknown")")
                completion(true, nil)
            }
        }
    }

    /// Initialize cloud saves using async/await
    @MainActor
    func initializeCloudSaves(statusWindow: UIWindow?) async throws {
        try await withCheckedThrowingContinuation { continuation in
            initializeCloudSaves(statusWindow: statusWindow) { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? GameSaveError.unknownSyncError)
                }
            }
        }
    }

    /// Save game data to cloud-synced directory
    /// - Parameters:
    ///   - data: Save data to write
    ///   - filename: Name of the save file
    func saveGame(_ data: Data, filename: String) throws {
        guard let saveURL = saveDirectoryURL else {
            throw GameSaveError.notInitialized
        }

        let fileURL = saveURL.appendingPathComponent(filename)
        try data.write(to: fileURL, options: .atomic)
        print("Game saved to: \(fileURL.path)")
    }

    /// Load game data from cloud-synced directory
    /// - Parameter filename: Name of the save file
    /// - Returns: Save data if available
    func loadGame(filename: String) throws -> Data {
        guard let saveURL = saveDirectoryURL else {
            throw GameSaveError.notInitialized
        }

        let fileURL = saveURL.appendingPathComponent(filename)
        return try Data(contentsOf: fileURL)
    }

    /// Check if a save file exists
    /// - Parameter filename: Name of the save file
    /// - Returns: True if file exists
    func saveExists(filename: String) -> Bool {
        guard let saveURL = saveDirectoryURL else { return false }
        let fileURL = saveURL.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    /// List all save files
    /// - Returns: Array of save file names
    func listSaves() -> [String] {
        guard let saveURL = saveDirectoryURL else { return [] }

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: saveURL,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )
            return contents.map { $0.lastPathComponent }
        } catch {
            print("Failed to list saves: \(error.localizedDescription)")
            return []
        }
    }

    /// Delete a save file
    /// - Parameter filename: Name of the save file to delete
    func deleteSave(filename: String) throws {
        guard let saveURL = saveDirectoryURL else {
            throw GameSaveError.notInitialized
        }

        let fileURL = saveURL.appendingPathComponent(filename)
        try FileManager.default.removeItem(at: fileURL)
        print("Save deleted: \(fileURL.path)")
    }
}

// MARK: - Error Types

enum GameSaveError: LocalizedError {
    case notInitialized
    case failedToOpenDirectory
    case unknownSyncError
    case saveNotFound

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Cloud saves not initialized. Call initializeCloudSaves first."
        case .failedToOpenDirectory:
            return "Failed to open the synced directory."
        case .unknownSyncError:
            return "An unknown error occurred during sync."
        case .saveNotFound:
            return "The requested save file was not found."
        }
    }
}
```

---

## Built-in UI Components

The GameSave framework provides default UI components for common scenarios:

### 1. Sync Progress Display
Shows progress while save data synchronizes with iCloud.

```swift
// The statusWindow parameter enables the built-in sync progress UI
directory.finishSyncing(statusWindow) {
    // Completion handler
}
```

### 2. Conflict Resolution UI
Automatically notifies players about save data conflicts and provides options to resolve them.

### 3. iCloud Sign-Out Alert
Alerts the player when they are signed out of iCloud, helping them understand why saves may not be available.

### Custom UI Integration

If you want to customize the player experience, you can use the GameSave API to integrate with your own UI:

```swift
// Check sync state manually without built-in UI
directory.finishSyncing(nil) { [weak self] in
    let state = directory.directoryState()

    // Update your custom UI based on state
    DispatchQueue.main.async {
        self?.updateSyncStatusUI(state: state)
    }
}
```

---

## SwiftUI Integration

### GameSave View Model

```swift
import SwiftUI
import GameSave

@Observable
class CloudSaveViewModel {
    var isLoading = false
    var isSynced = false
    var errorMessage: String?
    var availableSaves: [SaveFileInfo] = []

    private let saveManager = GameSaveManager()

    @MainActor
    func initialize() async {
        isLoading = true
        errorMessage = nil

        // Get the key window for status display
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first

        do {
            try await saveManager.initializeCloudSaves(statusWindow: window)
            isSynced = true
            refreshSaveList()
        } catch {
            errorMessage = error.localizedDescription
            isSynced = false
        }

        isLoading = false
    }

    func refreshSaveList() {
        let fileNames = saveManager.listSaves()
        availableSaves = fileNames.map { SaveFileInfo(filename: $0) }
    }

    func save(data: Data, filename: String) {
        do {
            try saveManager.saveGame(data, filename: filename)
            refreshSaveList()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func load(filename: String) -> Data? {
        do {
            return try saveManager.loadGame(filename: filename)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func delete(filename: String) {
        do {
            try saveManager.deleteSave(filename: filename)
            refreshSaveList()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct SaveFileInfo: Identifiable {
    let id = UUID()
    let filename: String
}
```

### SwiftUI View

```swift
import SwiftUI

struct CloudSaveView: View {
    @State private var viewModel = CloudSaveViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Syncing with iCloud...")
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView {
                        Label("Sync Error", systemImage: "exclamationmark.icloud")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Retry") {
                            Task { await viewModel.initialize() }
                        }
                    }
                } else if viewModel.isSynced {
                    saveListContent
                } else {
                    ContentUnavailableView(
                        "Not Connected",
                        systemImage: "icloud.slash",
                        description: Text("Sign in to iCloud to access cloud saves")
                    )
                }
            }
            .navigationTitle("Cloud Saves")
            .task {
                await viewModel.initialize()
            }
        }
    }

    @ViewBuilder
    private var saveListContent: some View {
        if viewModel.availableSaves.isEmpty {
            ContentUnavailableView(
                "No Saves",
                systemImage: "gamecontroller",
                description: Text("Your cloud saves will appear here")
            )
        } else {
            List {
                ForEach(viewModel.availableSaves) { save in
                    SaveFileRow(filename: save.filename) {
                        viewModel.delete(filename: save.filename)
                    }
                }
            }
        }
    }
}

struct SaveFileRow: View {
    let filename: String
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "doc.fill")
                .foregroundStyle(.blue)

            Text(filename)

            Spacer()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
        }
    }
}
```

---

## Error Handling

### Sync State Enumeration

The `GSSyncedDirectoryState` provides a `state` property with the following values:

| State | Description |
|-------|-------------|
| `GSSyncStateError` | An error occurred during synchronization |
| Other states | Sync completed successfully |

### Handling Common Errors

```swift
func handleSyncState(_ state: GSSyncedDirectoryState) {
    switch state.state {
    case .error:
        if let error = state.error {
            handleError(error)
        }
    default:
        // Success - proceed with save/load operations
        if let url = state.url {
            proceedWithSaveOperations(at: url)
        }
    }
}

func handleError(_ error: Error) {
    let nsError = error as NSError

    switch nsError.domain {
    case NSURLErrorDomain:
        // Network-related errors
        switch nsError.code {
        case NSURLErrorNotConnectedToInternet:
            showOfflineMessage()
        case NSURLErrorTimedOut:
            showTimeoutMessage()
        default:
            showGenericNetworkError(error)
        }

    default:
        // Other errors (iCloud account issues, permissions, etc.)
        showGenericError(error)
    }
}
```

### Offline Support

GameSave handles offline scenarios gracefully:

```swift
func initializeWithOfflineSupport() async {
    do {
        try await saveManager.initializeCloudSaves(statusWindow: nil)

        if saveManager.saveDirectoryURL != nil {
            // Local saves available even if sync failed
            loadLocalSaves()
        }
    } catch {
        // Check if we have cached local data
        if let localURL = getLocalCacheURL() {
            // Use local cache when offline
            useLocalCache(localURL)
        }
    }
}
```

---

## Conflict Resolution

### How Conflicts Occur

Conflicts happen when:
1. A player makes progress on Device A while offline
2. Meanwhile, they also play on Device B
3. When Device A comes online, there are two different save states

### Built-in Conflict Resolution

The GameSave framework provides automatic conflict resolution UI:
- Notifies the player about the conflict
- Shows both save versions with timestamps
- Lets the player choose which save to keep

### Custom Conflict Resolution

For games requiring custom merge logic:

```swift
class CustomConflictHandler {

    struct SaveConflict {
        let localSave: GameSaveData
        let remoteSave: GameSaveData
        let localTimestamp: Date
        let remoteTimestamp: Date
    }

    /// Automatic merge strategy - keep the most recent
    func resolveByTimestamp(_ conflict: SaveConflict) -> GameSaveData {
        return conflict.localTimestamp > conflict.remoteTimestamp
            ? conflict.localSave
            : conflict.remoteSave
    }

    /// Merge strategy - combine progress from both saves
    func mergeProgress(_ conflict: SaveConflict) -> GameSaveData {
        var merged = GameSaveData()

        // Take the higher level
        merged.level = max(conflict.localSave.level, conflict.remoteSave.level)

        // Combine collected items
        merged.items = Set(conflict.localSave.items).union(conflict.remoteSave.items)

        // Take the higher score
        merged.highScore = max(conflict.localSave.highScore, conflict.remoteSave.highScore)

        // Combine achievements
        merged.achievements = Set(conflict.localSave.achievements)
            .union(conflict.remoteSave.achievements)

        return merged
    }
}
```

---

## Best Practices

### 1. Initialize Early

Call `openDirectoryForContainerIdentifier:` early in your game's lifecycle:

```swift
class GameCoordinator {
    let cloudSaveManager = GameSaveManager()

    func applicationDidFinishLaunching() {
        // Start sync early so it's ready when needed
        Task {
            try? await cloudSaveManager.initializeCloudSaves(statusWindow: nil)
        }
    }
}
```

### 2. Show Sync Status to Users

Be transparent about sync status:

```swift
struct GameMenuView: View {
    @Environment(GameSaveManager.self) var saveManager

    var body: some View {
        VStack {
            // Show sync status indicator
            HStack {
                if saveManager.isSyncing {
                    ProgressView()
                    Text("Syncing...")
                } else if saveManager.saveDirectoryURL != nil {
                    Image(systemName: "checkmark.icloud")
                    Text("Cloud Saves Active")
                } else {
                    Image(systemName: "icloud.slash")
                    Text("Offline Mode")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            // Game menu content
        }
    }
}
```

### 3. Save Frequently But Wisely

```swift
class AutoSaveManager {
    private var lastSaveTime: Date = .distantPast
    private let minimumSaveInterval: TimeInterval = 60 // 1 minute

    func autoSave(data: GameSaveData, saveManager: GameSaveManager) {
        let now = Date()

        // Don't save too frequently to avoid excessive iCloud traffic
        guard now.timeIntervalSince(lastSaveTime) >= minimumSaveInterval else {
            return
        }

        do {
            let encoded = try JSONEncoder().encode(data)
            try saveManager.saveGame(encoded, filename: "autosave.json")
            lastSaveTime = now
        } catch {
            print("Auto-save failed: \(error)")
        }
    }

    // Also save on significant events
    func saveOnMilestone(data: GameSaveData, saveManager: GameSaveManager) {
        do {
            let encoded = try JSONEncoder().encode(data)
            try saveManager.saveGame(encoded, filename: "autosave.json")
            lastSaveTime = Date()
        } catch {
            print("Milestone save failed: \(error)")
        }
    }
}
```

### 4. Handle iCloud Account Changes

```swift
class iCloudAccountObserver {

    func startObserving() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accountChanged),
            name: NSUbiquityIdentityDidChange,
            object: nil
        )
    }

    @objc private func accountChanged() {
        // Re-initialize cloud saves when account changes
        Task { @MainActor in
            await reinitializeCloudSaves()
        }
    }
}
```

### 5. Provide Offline Fallback

Always have a local save as backup:

```swift
class HybridSaveManager {
    let cloudManager = GameSaveManager()
    let localSaveURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        localSaveURL = docs.appendingPathComponent("LocalSaves")

        try? FileManager.default.createDirectory(at: localSaveURL, withIntermediateDirectories: true)
    }

    func save(_ data: Data, filename: String) throws {
        // Always save locally first
        let localPath = localSaveURL.appendingPathComponent(filename)
        try data.write(to: localPath)

        // Then try cloud save
        do {
            try cloudManager.saveGame(data, filename: filename)
        } catch {
            print("Cloud save failed, local save succeeded: \(error)")
        }
    }

    func load(filename: String) throws -> Data {
        // Try cloud first
        if let cloudData = try? cloudManager.loadGame(filename: filename) {
            return cloudData
        }

        // Fall back to local
        let localPath = localSaveURL.appendingPathComponent(filename)
        return try Data(contentsOf: localPath)
    }
}
```

### 6. Test Across Multiple Devices

Before release, thoroughly test:
- Saving on Device A, loading on Device B
- Playing on both devices while one is offline
- Conflict resolution scenarios
- iCloud sign-out during gameplay
- Large save files and sync times

---

## Migration from GKSavedGame

If you're migrating from the older GameKit `GKSavedGame` API:

### Key Differences

| Feature | GKSavedGame | GameSave |
|---------|-------------|----------|
| Requires Game Center | Yes | No |
| Built-in UI | No | Yes |
| Conflict Resolution | Manual | Automatic with UI |
| Setup Complexity | Higher | Lower |
| iCloud Integration | Through Game Center | Direct |

### Migration Steps

1. **Add GameSave capability** alongside existing Game Center
2. **Implement GameSave manager** as shown above
3. **Migrate existing saves** during first launch:

```swift
class SaveMigrationManager {

    func migrateFromGameKit(
        gameSaveManager: GameSaveManager,
        completion: @escaping (Bool) -> Void
    ) {
        // Check if migration is needed
        let migrationKey = "gamesave_migration_complete"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else {
            completion(true)
            return
        }

        // Fetch existing Game Center saves
        GKLocalPlayer.local.fetchSavedGames { savedGames, error in
            guard let savedGames = savedGames, error == nil else {
                completion(false)
                return
            }

            // Migrate each save
            let group = DispatchGroup()
            var migrationSuccess = true

            for save in savedGames {
                group.enter()

                save.loadData { data, error in
                    defer { group.leave() }

                    guard let data = data, error == nil else {
                        migrationSuccess = false
                        return
                    }

                    let filename = "\(save.name ?? "save")_\(save.deviceName ?? "device").dat"

                    do {
                        try gameSaveManager.saveGame(data, filename: filename)
                    } catch {
                        migrationSuccess = false
                    }
                }
            }

            group.notify(queue: .main) {
                if migrationSuccess {
                    UserDefaults.standard.set(true, forKey: migrationKey)
                }
                completion(migrationSuccess)
            }
        }
    }
}
```

4. **Remove GameKit dependency** once migration is complete and verified
5. **Update App Store description** to note iCloud saves (no longer requires Game Center)

---

## Troubleshooting

### Common Issues

#### 1. Sync Never Completes

**Symptoms:** `finishSyncing` completion handler never called

**Solutions:**
- Ensure iCloud is enabled on the device (Settings > Apple ID > iCloud)
- Verify the container identifier matches your entitlements
- Check network connectivity
- Ensure the user is signed into iCloud

#### 2. Save Directory URL is Nil

**Symptoms:** `directoryState.url` returns nil after successful sync

**Solutions:**
- Verify entitlements are correctly configured
- Ensure the iCloud container exists in Developer Portal
- Re-download and install the provisioning profile

#### 3. Saves Not Appearing on Other Devices

**Symptoms:** Data saved on one device doesn't appear on another

**Solutions:**
- Ensure both devices use the same iCloud account
- Wait for sync to complete on both devices
- Check if iCloud Drive is enabled for your app
- Verify network connectivity

#### 4. "iCloud Container Not Found" Error

**Solutions:**
- Double-check container identifier spelling
- Ensure container is created in Apple Developer Portal
- Update provisioning profiles
- Clean build folder and rebuild

### Debug Logging

```swift
class GameSaveDebugger {

    static func logSyncState(_ state: GSSyncedDirectoryState) {
        #if DEBUG
        print("=== GameSave Debug ===")
        print("State: \(state.state)")
        print("URL: \(state.url?.path ?? "nil")")
        if let error = state.error {
            print("Error: \(error)")
            print("Error Domain: \((error as NSError).domain)")
            print("Error Code: \((error as NSError).code)")
        }
        print("=====================")
        #endif
    }

    static func listDirectoryContents(at url: URL) {
        #if DEBUG
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
                options: []
            )
            print("=== Save Directory Contents ===")
            for file in contents {
                let resources = try file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                print("- \(file.lastPathComponent): \(resources.fileSize ?? 0) bytes, modified \(resources.contentModificationDate ?? Date())")
            }
            print("===============================")
        } catch {
            print("Failed to list directory: \(error)")
        }
        #endif
    }
}
```

---

## References

- [Apple GameSave Documentation](https://developer.apple.com/documentation/GameSave)
- [WWDC 2025: Level up your games](https://developer.apple.com/videos/play/wwdc2025/209/)
- [Saving the player's game data to an iCloud account](https://developer.apple.com/documentation/gamekit/saving-the-player-s-game-data-to-an-icloud-account)
- [GKSavedGame Documentation](https://developer.apple.com/documentation/gamekit/gksavedgame) (Legacy)

---

## Summary

The GameSave framework simplifies cloud save implementation for iOS games by:

1. **Reducing setup complexity** - Just enable iCloud Documents capability
2. **Providing built-in UI** - Automatic sync progress, conflict resolution, and error alerts
3. **Handling edge cases** - Offline support, account changes, and conflict resolution
4. **Enabling cross-device play** - Seamless save synchronization across Apple devices

For new games, GameSave is the recommended approach for cloud saves. For existing games using GKSavedGame, consider migrating to take advantage of the simpler API and better user experience.

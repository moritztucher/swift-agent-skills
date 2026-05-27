# SwiftData Guide for iOS Development

A comprehensive guide for using SwiftData in iOS 17+ and iOS 26 apps with SwiftUI.

---

## Overview

SwiftData is Apple's modern persistence framework that provides:

- **Declarative Data Modeling** - Use `@Model` macro for Swift-native definitions
- **Automatic Persistence** - Changes are tracked and saved automatically
- **SwiftUI Integration** - Native `@Query` property wrapper for reactive data
- **CloudKit Sync** - Built-in iCloud synchronization support
- **Type Safety** - Compile-time checks for predicates and queries

### Use Cases

- Local data persistence
- Offline-first apps
- iCloud-synced data across devices
- Caching server responses
- User-generated content storage

---

## Requirements

- **Minimum iOS Version**: iOS 17.0+
- **Framework**: SwiftData (import SwiftData)
- **CloudKit Sync**: Requires iCloud capability and CloudKit container

### Info.plist (for CloudKit)

No additional keys required for local-only storage. For CloudKit sync, enable iCloud capability in your target.

---

## Core Concepts

### Key Types

| Type | Description |
|------|-------------|
| `@Model` | Macro that makes a class persistable |
| `ModelContainer` | Manages the storage and schema |
| `ModelContext` | Interface for CRUD operations |
| `@Query` | Property wrapper for fetching in SwiftUI |
| `FetchDescriptor` | Configures fetch requests |
| `#Predicate` | Type-safe filtering macro |

---

## Basic Implementation

### Step 1: Define Your Model

```swift
import SwiftData

@Model
class Task {
    var title: String
    var isCompleted: Bool
    var createdAt: Date
    var priority: TaskPriority

    init(title: String, priority: TaskPriority = .medium) {
        self.title = title
        self.isCompleted = false
        self.createdAt = Date()
        self.priority = priority
    }
}

enum TaskPriority: String, Codable, CaseIterable {
    case low, medium, high, urgent
}
```

### Step 2: Configure ModelContainer

```swift
import SwiftUI
import SwiftData

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Task.self])
    }
}
```

### Step 3: Use @Query in Views

```swift
struct TaskListView: View {
    @Query(sort: \Task.createdAt, order: .reverse)
    private var tasks: [Task]

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List(tasks) { task in
            TaskRowView(task: task)
        }
    }
}
```

---

## Model Attributes

### @Attribute Options

```swift
@Model
class User {
    // Unique constraint
    @Attribute(.unique) var email: String

    // Store large data externally
    @Attribute(.externalStorage) var profileImage: Data?

    // Encrypt sensitive data
    @Attribute(.encrypt) var sensitiveNotes: String?

    // Preserve on deletion (iOS 26+)
    @Attribute(.preserveValueOnDeletion) var auditId: UUID

    // Spotlight indexing
    @Attribute(.spotlight) var name: String

    var createdAt: Date

    init(email: String, name: String) {
        self.email = email
        self.name = name
        self.auditId = UUID()
        self.createdAt = Date()
    }
}
```

### @Transient for Non-Persisted Properties

```swift
@Model
class Task {
    var title: String
    var isCompleted: Bool

    // Not persisted
    @Transient var displayTitle: String {
        isCompleted ? "✓ \(title)" : title
    }

    init(title: String) {
        self.title = title
        self.isCompleted = false
    }
}
```

---

## Relationships

### One-to-Many

```swift
@Model
class Project {
    var name: String

    @Relationship(deleteRule: .cascade)
    var tasks: [Task] = []

    init(name: String) {
        self.name = name
    }
}

@Model
class Task {
    var title: String

    @Relationship(inverse: \Project.tasks)
    var project: Project?

    init(title: String) {
        self.title = title
    }
}
```

### Delete Rules

| Rule | Behavior |
|------|----------|
| `.cascade` | Delete related objects |
| `.nullify` | Set relationship to nil |
| `.deny` | Prevent deletion if related objects exist |
| `.noAction` | Do nothing |

---

## ModelContainer Configuration

### Basic Configuration

```swift
let container = try ModelContainer(for: Task.self)
```

### Custom Configuration

```swift
let config = ModelConfiguration(
    schema: Schema([Task.self, Project.self]),
    isStoredInMemoryOnly: false,
    allowsSave: true,
    cloudKitDatabase: .private("iCloud.com.myapp")
)

let container = try ModelContainer(
    for: Task.self, Project.self,
    configurations: config
)
```

### In-Memory for Testing

```swift
let config = ModelConfiguration(isStoredInMemoryOnly: true)
let container = try ModelContainer(for: Task.self, configurations: config)
```

---

## Fetching Data

### Using @Query

```swift
struct TaskListView: View {
    // Basic query
    @Query private var tasks: [Task]

    // With sorting
    @Query(sort: \Task.createdAt, order: .reverse)
    private var sortedTasks: [Task]

    // With predicate
    @Query(filter: #Predicate<Task> { !$0.isCompleted })
    private var pendingTasks: [Task]

    // Combined
    @Query(
        filter: #Predicate<Task> { $0.priority == .high },
        sort: \Task.createdAt
    )
    private var highPriorityTasks: [Task]

    var body: some View {
        List(tasks) { task in
            Text(task.title)
        }
    }
}
```

### Using FetchDescriptor

```swift
func fetchTasks() throws -> [Task] {
    var descriptor = FetchDescriptor<Task>(
        predicate: #Predicate { !$0.isCompleted },
        sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
    )
    descriptor.fetchLimit = 20
    descriptor.fetchOffset = 0

    return try modelContext.fetch(descriptor)
}
```

### Predicate Examples

```swift
// Simple comparison
#Predicate<Task> { $0.isCompleted == true }

// String contains
#Predicate<Task> { $0.title.contains("important") }

// Compound predicates
#Predicate<Task> {
    !$0.isCompleted && $0.priority == .high
}

// Date comparison
let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
#Predicate<Task> { $0.createdAt >= yesterday }

// Optional handling
#Predicate<Task> { $0.project != nil }
```

---

## CRUD Operations

### Create

```swift
func addTask(title: String) {
    let task = Task(title: title)
    modelContext.insert(task)
    // Auto-saved if autosave is enabled
}
```

### Update

```swift
func toggleCompletion(_ task: Task) {
    task.isCompleted.toggle()
    // Changes tracked automatically
}
```

### Delete

```swift
func deleteTask(_ task: Task) {
    modelContext.delete(task)
}

// Batch delete
func deleteAllCompleted() throws {
    try modelContext.delete(
        model: Task.self,
        where: #Predicate { $0.isCompleted }
    )
}
```

### Save Explicitly

```swift
func saveChanges() throws {
    if modelContext.hasChanges {
        try modelContext.save()
    }
}
```

---

## SwiftUI Integration

### App Setup

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Task.self, Project.self])
    }
}
```

### Environment Access

```swift
struct TaskDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let task: Task

    var body: some View {
        Form {
            TextField("Title", text: Bindable(task).title)
            Toggle("Completed", isOn: Bindable(task).isCompleted)
        }
    }
}
```

### Preview Setup

```swift
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, configurations: config)

    // Add sample data
    let task = Task(title: "Sample Task")
    container.mainContext.insert(task)

    return TaskListView()
        .modelContainer(container)
}
```

---

## Common Patterns

### DataManager Pattern

```swift
@Observable
@MainActor
class TaskManager {
    private let modelContext: ModelContext

    var tasks: [Task] = []
    var isLoading = false
    var error: Error?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchTasks() {
        isLoading = true
        defer { isLoading = false }

        do {
            let descriptor = FetchDescriptor<Task>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            tasks = try modelContext.fetch(descriptor)
        } catch {
            self.error = error
        }
    }

    func addTask(title: String) {
        let task = Task(title: title)
        modelContext.insert(task)
        fetchTasks()
    }

    func deleteTask(_ task: Task) {
        modelContext.delete(task)
        fetchTasks()
    }
}
```

### Dynamic Query

```swift
struct SearchableTaskList: View {
    @State private var searchText = ""

    var body: some View {
        TaskListContent(searchText: searchText)
            .searchable(text: $searchText)
    }
}

struct TaskListContent: View {
    let searchText: String

    @Query private var tasks: [Task]

    init(searchText: String) {
        self.searchText = searchText

        if searchText.isEmpty {
            _tasks = Query(sort: \Task.createdAt)
        } else {
            _tasks = Query(
                filter: #Predicate<Task> {
                    $0.title.localizedStandardContains(searchText)
                },
                sort: \Task.createdAt
            )
        }
    }

    var body: some View {
        List(tasks) { task in
            Text(task.title)
        }
    }
}
```

---

## Schema Migration

### Versioned Schema

```swift
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Task.self] }

    @Model
    class Task {
        var title: String
        var isCompleted: Bool

        init(title: String) {
            self.title = title
            self.isCompleted = false
        }
    }
}

enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [Task.self] }

    @Model
    class Task {
        var title: String
        var isCompleted: Bool
        var priority: Int // New property

        init(title: String, priority: Int = 0) {
            self.title = title
            self.isCompleted = false
            self.priority = priority
        }
    }
}
```

### Migration Plan

```swift
enum TaskMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self
    )
}

// Using migration
let container = try ModelContainer(
    for: SchemaV2.Task.self,
    migrationPlan: TaskMigrationPlan.self
)
```

---

## Error Handling

```swift
enum SwiftDataError: LocalizedError {
    case containerCreationFailed(Error)
    case fetchFailed(Error)
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .containerCreationFailed(let error):
            return "Failed to create data container: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch data: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "Failed to save data: \(error.localizedDescription)"
        }
    }
}
```

---

## Best Practices

1. **Use @Query for reactive data** - Let SwiftUI handle updates automatically
2. **Keep models simple** - Business logic belongs in ViewModels/Managers
3. **Use FetchDescriptor limits** - Don't fetch more data than needed
4. **Batch operations** - Disable autosave for bulk imports
5. **Test with in-memory storage** - Use `isStoredInMemoryOnly: true`
6. **Handle errors gracefully** - Wrap operations in do-catch

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Failed to find container" | Add `.modelContainer` modifier to App |
| Query not updating | Ensure predicate captures values correctly |
| Slow performance | Use `fetchLimit` and proper indexes |
| Memory issues | Use batch fetching with `enumerate()` |
| CloudKit not syncing | Verify iCloud entitlements and container |

---

## iOS 26 Changes

### History Tracking

```swift
let config = ModelConfiguration(
    schema: schema,
    allowsSave: true
)

// Fetch history changes
let descriptor = HistoryDescriptor<DefaultHistoryTransaction>()
let transactions = try modelContext.fetchHistory(descriptor)
```

### Preserved Values on Deletion

```swift
@Model
class Task {
    @Attribute(.preserveValueOnDeletion)
    var trackingId: UUID

    var title: String

    init(title: String) {
        self.trackingId = UUID()
        self.title = title
    }
}
```

### Enhanced CloudKit Integration

- Improved conflict resolution options
- Better offline handling
- Faster sync performance

---

## Quick Reference

```swift
// Setup
.modelContainer(for: [Task.self])

// Query
@Query var tasks: [Task]

// Context
@Environment(\.modelContext) var modelContext

// Insert
modelContext.insert(task)

// Delete
modelContext.delete(task)

// Save
try modelContext.save()

// Fetch
let descriptor = FetchDescriptor<Task>()
let tasks = try modelContext.fetch(descriptor)
```

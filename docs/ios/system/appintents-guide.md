# AppIntents Guide for iOS Development

A comprehensive guide for using the AppIntents framework in iOS 18+ and iOS 26 apps with SwiftUI.

---

## Table of Contents

1. [Overview](#overview)
2. [Basic AppIntent](#basic-appintent)
3. [Parameters](#parameters)
4. [IntentResult and Dialogs](#intentresult-and-dialogs)
5. [AppEntity](#appentity)
6. [EntityQuery](#entityquery)
7. [AppEnum](#appenum)
8. [AppShortcutsProvider](#appshortcutsprovider)
9. [Siri Integration](#siri-integration)
10. [Widget Integration](#widget-integration)
11. [Control Center & Lock Screen (iOS 18+)](#control-center--lock-screen-ios-18)
12. [Spotlight Integration](#spotlight-integration)
13. [Best Practices](#best-practices)

---

## Overview

The AppIntents framework exposes your app's functionality to system services:

- **Siri** - Voice-activated commands
- **Shortcuts App** - User-customizable automations
- **Spotlight** - Quick actions from search
- **Action Button** - iPhone 15 Pro+ hardware button
- **Widgets** - Interactive widget buttons (iOS 17+)
- **Control Center** - Quick toggles (iOS 18+)
- **Lock Screen Controls** - Lock screen actions (iOS 18+)
- **Apple Intelligence** - AI-powered suggestions (iOS 26+)

### Import

```swift
import AppIntents
```

---

## Basic AppIntent

### Minimal Intent

```swift
struct AddTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Task"

    func perform() async throws -> some IntentResult {
        // Perform action
        return .result()
    }
}
```

### Intent with Description

```swift
struct AddTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Add a New Task"
    static var description = IntentDescription("Creates a new task in your task list.")

    func perform() async throws -> some IntentResult {
        // Implementation
        return .result()
    }
}
```

### Intent That Opens App

```swift
struct CreateDocumentIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Document"
    static var openAppWhenRun: Bool = true  // Opens app when executed

    func perform() async throws -> some IntentResult {
        // Navigate to creation screen
        return .result()
    }
}
```

---

## Parameters

### Basic Parameter

```swift
struct AddTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Task"

    @Parameter(title: "Task Name")
    var taskName: String

    func perform() async throws -> some IntentResult {
        // Use taskName
        TaskManager.shared.addTask(name: taskName)
        return .result()
    }
}
```

### Optional Parameter with Default

```swift
struct AddTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Task"

    @Parameter(title: "Task Name")
    var taskName: String

    @Parameter(title: "Priority", default: .medium)
    var priority: TaskPriority?

    func perform() async throws -> some IntentResult {
        let actualPriority = priority ?? .medium
        TaskManager.shared.addTask(name: taskName, priority: actualPriority)
        return .result()
    }
}
```

### Request Parameter Value at Runtime

```swift
struct AddTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Task"

    @Parameter(title: "Task Name")
    var taskName: String?

    func perform() async throws -> some IntentResult {
        // Prompt user if not provided
        let name = taskName ?? try await $taskName.requestValue("What's the task name?")

        TaskManager.shared.addTask(name: name)
        return .result()
    }
}
```

### Parameter Summary

Controls how parameters display in Shortcuts:

```swift
struct LogCaffeineIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Caffeine"

    @Parameter(title: "Drink Type")
    var drinkType: CaffeineDrink

    @Parameter(title: "Amount (mg)")
    var amount: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount)mg from \(\.$drinkType)")
    }

    func perform() async throws -> some IntentResult {
        // Implementation
        return .result()
    }
}
```

### Conditional Parameter Summary

```swift
static var parameterSummary: some ParameterSummary {
    When(\.$includeNotes, .equalTo, true) {
        Summary("Add \(\.$taskName) with notes") {
            \.$notes
        }
    } otherwise: {
        Summary("Add \(\.$taskName)")
    }
}
```

### File Parameters

```swift
struct ImportFilesIntent: AppIntent {
    static var title: LocalizedStringResource = "Import Files"

    @Parameter(
        title: "Files",
        description: "Files to import",
        supportedTypeIdentifiers: ["public.image", "public.pdf"],
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var files: [IntentFile]?

    func perform() async throws -> some IntentResult {
        if let fileURLs = files?.compactMap({ $0.fileURL }) {
            // Process files
        }
        return .result()
    }
}
```

---

## IntentResult and Dialogs

### Basic Result

```swift
func perform() async throws -> some IntentResult {
    return .result()
}
```

### Result with Dialog (Siri speaks this)

```swift
func perform() async throws -> some IntentResult & ProvidesDialog {
    return .result(dialog: "Task added successfully!")
}
```

### Result with Return Value

```swift
func perform() async throws -> some IntentResult & ReturnsValue<Int> {
    let count = TaskManager.shared.taskCount
    return .result(value: count)
}
```

### Combined Result

```swift
func perform() async throws -> some IntentResult & ReturnsValue<Double> & ProvidesDialog {
    let caffeine = CaffeineManager.shared.todayTotal
    let formatted = String(format: "%.0f", caffeine)
    return .result(
        value: caffeine,
        dialog: "You've had \(formatted)mg of caffeine today."
    )
}
```

### Result with View (Snippet)

```swift
func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
    return .result(
        dialog: "Here's your summary",
        view: TaskSummaryView(tasks: tasks)
    )
}
```

---

## AppEntity

Make your models available as intent parameters:

### Basic Entity

```swift
import AppIntents

struct Task: Identifiable {
    let id: UUID
    var name: String
    var isComplete: Bool
}

extension Task: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Task"

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static var defaultQuery = TaskQuery()
}
```

### Entity with Subtitle and Image

```swift
extension Task: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(
            name: "Task",
            numericFormat: "\(placeholder: .int) tasks"
        )
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: isComplete ? "Completed" : "Pending",
            image: .init(systemName: isComplete ? "checkmark.circle.fill" : "circle")
        )
    }

    static var defaultQuery = TaskQuery()
}
```

---

## EntityQuery

Handles fetching and suggesting entities:

### Basic Query

```swift
struct TaskQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [Task] {
        return TaskManager.shared.tasks.filter { identifiers.contains($0.id) }
    }
}
```

### Query with Suggestions

```swift
struct TaskQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [Task] {
        return TaskManager.shared.tasks.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [Task] {
        // Return recently used or frequently accessed items
        return Array(TaskManager.shared.tasks.prefix(5))
    }
}
```

### String Query (Searchable)

```swift
struct TaskQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [Task] {
        return TaskManager.shared.tasks.filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [Task] {
        return TaskManager.shared.tasks.filter {
            $0.name.localizedCaseInsensitiveContains(string)
        }
    }

    func suggestedEntities() async throws -> [Task] {
        return Array(TaskManager.shared.tasks.prefix(5))
    }
}
```

### Property Query (Advanced Filtering)

```swift
struct TaskQuery: EntityPropertyQuery {
    static var properties = QueryProperties {
        Property(\Task.$name) {
            EqualToComparator { $0 }
            ContainsComparator { $0 }
        }
        Property(\Task.$isComplete) {
            EqualToComparator { $0 }
        }
    }

    static var sortingOptions = SortingOptions {
        SortableBy(\Task.$name)
    }

    func entities(for identifiers: [UUID]) async throws -> [Task] {
        return TaskManager.shared.tasks.filter { identifiers.contains($0.id) }
    }

    func entities(
        matching comparators: [TaskQuery.Property.EqualToComparator],
        mode: ComparatorMode,
        sortedBy: [Sort<Task>],
        limit: Int?
    ) async throws -> [Task] {
        // Filter based on comparators
        var results = TaskManager.shared.tasks
        // Apply filtering logic
        return results
    }
}
```

---

## AppEnum

Make enums available as parameters:

```swift
enum TaskPriority: String, CaseIterable {
    case low
    case medium
    case high
}

extension TaskPriority: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Priority"

    static var caseDisplayRepresentations: [TaskPriority: DisplayRepresentation] = [
        .low: DisplayRepresentation(title: "Low", subtitle: "Not urgent"),
        .medium: DisplayRepresentation(title: "Medium", subtitle: "Normal priority"),
        .high: DisplayRepresentation(title: "High", subtitle: "Urgent")
    ]
}
```

### Enum with Icons

```swift
static var caseDisplayRepresentations: [TaskPriority: DisplayRepresentation] = [
    .low: DisplayRepresentation(
        title: "Low",
        image: .init(systemName: "arrow.down.circle")
    ),
    .medium: DisplayRepresentation(
        title: "Medium",
        image: .init(systemName: "minus.circle")
    ),
    .high: DisplayRepresentation(
        title: "High",
        image: .init(systemName: "arrow.up.circle.fill")
    )
]
```

---

## AppShortcutsProvider

Expose intents to Siri, Spotlight, and Shortcuts:

### Basic Provider

```swift
struct TaskShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTaskIntent(),
            phrases: [
                "Add a task in \(.applicationName)",
                "Create new task with \(.applicationName)"
            ],
            shortTitle: "Add Task",
            systemImageName: "plus.circle"
        )
    }
}
```

### Multiple Shortcuts

```swift
struct TaskShortcutsProvider: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTaskIntent(),
            phrases: ["Add a task in \(.applicationName)"],
            shortTitle: "Add Task",
            systemImageName: "plus.circle"
        )

        AppShortcut(
            intent: ViewTasksIntent(),
            phrases: ["Show my tasks in \(.applicationName)"],
            shortTitle: "View Tasks",
            systemImageName: "list.bullet"
        )

        AppShortcut(
            intent: CompleteTaskIntent(),
            phrases: ["Complete a task in \(.applicationName)"],
            shortTitle: "Complete Task",
            systemImageName: "checkmark.circle"
        )
    }
}
```

### Phrases with Parameters

```swift
AppShortcut(
    intent: AddTaskIntent(),
    phrases: [
        "Add \(\.$taskName) to \(.applicationName)",
        "Create \(\.$taskName) task"
    ],
    shortTitle: "Add Task",
    systemImageName: "plus.circle"
)
```

---

## Siri Integration

### SiriTipView

Prompt users to try Siri commands:

```swift
import AppIntents

struct TaskListView: View {
    var body: some View {
        List {
            // Task list content
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                SiriTipView(intent: AddTaskIntent())
            }
        }
    }
}
```

### ShortcutsLink

Deep-link to your app's shortcuts:

```swift
struct SettingsView: View {
    var body: some View {
        Form {
            Section("Shortcuts") {
                ShortcutsLink()
            }
        }
    }
}
```

### Custom Siri Tip

```swift
SiriTipView(intent: AddTaskIntent()) { intent in
    Text("Try saying: \"Add a task\"")
        .font(.caption)
}
```

---

## Widget Integration

### Interactive Widget Button (iOS 17+)

```swift
import SwiftUI
import AppIntents

struct TaskWidgetView: View {
    let task: Task

    var body: some View {
        VStack {
            Text(task.name)

            Button(intent: CompleteTaskIntent(task: TaskEntity(from: task))) {
                Label("Complete", systemImage: "checkmark.circle")
            }
        }
    }
}
```

### Toggle in Widget

```swift
Toggle(isOn: task.isComplete, intent: ToggleTaskIntent(task: taskEntity)) {
    Text(task.name)
}
```

### Widget Configuration Intent

```swift
struct TaskWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Task Widget"
    static var description = IntentDescription("Configure your task widget.")

    @Parameter(title: "Show Completed", default: false)
    var showCompleted: Bool

    @Parameter(title: "Category")
    var category: TaskCategory?

    static var parameterSummary: some ParameterSummary {
        Summary {
            \.$showCompleted
            \.$category
        }
    }
}
```

---

## Control Center & Lock Screen (iOS 18+)

### ControlWidget

```swift
import WidgetKit
import AppIntents

struct AddTaskControl: ControlWidget {
    static let kind = "com.app.addtask"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: AddTaskIntent()) {
                Label("Add Task", systemImage: "plus.circle")
            }
        }
        .displayName("Add Task")
        .description("Quickly add a new task.")
    }
}
```

### Toggle Control

```swift
struct FocusModeControl: ControlWidget {
    static let kind = "com.app.focusmode"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetToggle(
                "Focus Mode",
                isOn: FocusModeManager.shared.isEnabled,
                action: ToggleFocusModeIntent()
            ) { isOn in
                Label(
                    isOn ? "Focus On" : "Focus Off",
                    systemImage: isOn ? "moon.fill" : "moon"
                )
            }
        }
    }
}
```

---

## Spotlight Integration

Intents with `AppShortcutsProvider` automatically appear in Spotlight. Additional configuration:

### Intent for Spotlight

```swift
struct QuickAddIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Add"
    static var openAppWhenRun: Bool = true

    // Shows in Spotlight search suggestions
    static var isDiscoverable: Bool = true

    func perform() async throws -> some IntentResult {
        DeepLinkManager.navigateTo(.quickAdd)
        return .result()
    }
}
```

### Spotlight with Deep Linking

```swift
struct OpenTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Task"
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Task")
    var task: TaskEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        NavigationManager.shared.navigate(to: .taskDetail(task.id))
        return .result()
    }
}
```

---

## Best Practices

### 1. Always Provide Required Initializers

```swift
struct AddTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Task"

    @Parameter(title: "Task Name")
    var taskName: String

    // Required: Default initializer
    init() {}

    // Convenience initializer for programmatic use
    init(taskName: String) {
        self.taskName = taskName
    }

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
```

### 2. Share Code Across Targets

Place models and managers in a shared framework:

```
AppName/
├── App/
├── Shared/                    # Framework target
│   ├── Models/
│   │   └── Task.swift
│   ├── Managers/
│   │   └── TaskManager.swift
│   └── Intents/
│       ├── AddTaskIntent.swift
│       └── TaskEntity.swift
├── Widget/
└── IntentsExtension/
```

### 3. Use @MainActor for UI Updates

```swift
struct NavigateToTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Task"
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Task")
    var task: TaskEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        NavigationCoordinator.shared.navigate(to: .task(task.id))
        return .result()
    }
}
```

### 4. Refresh Widgets After Changes

```swift
func perform() async throws -> some IntentResult {
    TaskManager.shared.completeTask(taskId)

    // Refresh widgets
    WidgetCenter.shared.reloadAllTimelines()

    return .result(dialog: "Task completed!")
}
```

### 5. Handle Errors Gracefully

```swift
func perform() async throws -> some IntentResult & ProvidesDialog {
    do {
        try await TaskManager.shared.addTask(name: taskName)
        return .result(dialog: "Task added!")
    } catch {
        throw IntentError.message("Failed to add task: \(error.localizedDescription)")
    }
}
```

### 6. Localize Everything

```swift
struct AddTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Task"  // Auto-localized
    static var description = IntentDescription(
        LocalizedStringResource("Creates a new task in your list.")
    )

    @Parameter(title: LocalizedStringResource("Task Name"))
    var taskName: String
}
```

### 7. Test in Shortcuts App

1. Build and run your app
2. Open Shortcuts app
3. Create new shortcut
4. Search for your app's actions
5. Test with different parameter combinations

---

## Common Patterns

### Intent That Modifies Data

```swift
struct CompleteTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Task"

    @Parameter(title: "Task")
    var task: TaskEntity

    init() {}

    init(task: TaskEntity) {
        self.task = task
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let taskId = UUID(uuidString: task.id) else {
            throw IntentError.message("Invalid task")
        }

        try await TaskManager.shared.complete(taskId: taskId)
        WidgetCenter.shared.reloadAllTimelines()

        return .result(dialog: "Completed: \(task.name)")
    }
}
```

### Intent with Confirmation

```swift
struct DeleteAllTasksIntent: AppIntent {
    static var title: LocalizedStringResource = "Delete All Tasks"

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await requestConfirmation(
            result: .result(dialog: "This will delete all tasks."),
            confirmationActionName: .destructive
        )

        try await TaskManager.shared.deleteAll()
        return .result(dialog: "All tasks deleted.")
    }
}
```

### Entity from Realm Object

```swift
struct TaskEntity: AppEntity {
    let id: String
    let name: String
    let isComplete: Bool

    init(from task: RealmTask) {
        self.id = task._id.stringValue
        self.name = task.name
        self.isComplete = task.isComplete
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Task"

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static var defaultQuery = TaskEntityQuery()
}

struct TaskEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [TaskEntity] {
        let realm = try! await Realm()
        let objectIds = identifiers.compactMap { try? ObjectId(string: $0) }

        return realm.objects(RealmTask.self)
            .filter("_id IN %@", objectIds)
            .map { TaskEntity(from: $0) }
    }

    func suggestedEntities() async throws -> [TaskEntity] {
        let realm = try! await Realm()
        return realm.objects(RealmTask.self)
            .filter("isComplete == false")
            .prefix(5)
            .map { TaskEntity(from: $0) }
    }
}
```

---

## Quick Reference

### Protocol Conformances

| Protocol | Purpose |
|----------|---------|
| `AppIntent` | Base protocol for all intents |
| `AppEntity` | Make models available as parameters |
| `EntityQuery` | Fetch entities by ID |
| `EntityStringQuery` | Search entities by text |
| `AppEnum` | Make enums available as parameters |
| `AppShortcutsProvider` | Expose shortcuts to system |
| `WidgetConfigurationIntent` | Configure widgets |

### Property Wrappers

| Wrapper | Usage |
|---------|-------|
| `@Parameter` | Define intent parameters |

### Result Protocols

| Protocol | Purpose |
|----------|---------|
| `IntentResult` | Base result |
| `ProvidesDialog` | Siri speaks text |
| `ReturnsValue<T>` | Return a value |
| `ShowsSnippetView` | Display custom UI |

### Key Static Properties

```swift
static var title: LocalizedStringResource          // Required
static var description: IntentDescription          // Optional
static var openAppWhenRun: Bool                    // Opens app
static var isDiscoverable: Bool                    // Spotlight visibility
static var parameterSummary: some ParameterSummary // Display format
```

---

## Sources

- [Apple App Intents Documentation](https://developer.apple.com/documentation/appintents)
- [Apple App Shortcuts Documentation](https://developer.apple.com/documentation/appintents/app-shortcuts)
- [Create with Swift - App Intents Tutorial](https://www.createwithswift.com/using-app-intents-swiftui-app/)
- [Superwall - App Intents Field Guide](https://superwall.com/blog/an-app-intents-field-guide-for-ios-developers/)
- [SwiftLee - App Intents Spotlight Integration](https://www.avanderlee.com/swiftui/app-intents-spotlight-integration-using-shortcuts/)
- [AppCoda - Siri Shortcuts with App Intents](https://www.appcoda.com/app-intents-shortcuts/)

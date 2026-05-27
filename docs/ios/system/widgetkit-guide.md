# WidgetKit Guide for iOS Development

A comprehensive guide for building widgets with WidgetKit in iOS 14+ apps using SwiftUI, including interactive widgets (iOS 17+), StandBy mode, and Lock Screen widgets.

---

## Table of Contents

1. [Overview](#overview)
2. [Setup & Configuration](#setup--configuration)
3. [Core Concepts](#core-concepts)
4. [Timeline Provider](#timeline-provider)
5. [Widget Families](#widget-families)
6. [Widget Configuration](#widget-configuration)
7. [Interactive Widgets (iOS 17+)](#interactive-widgets-ios-17)
8. [Data Sharing with Main App](#data-sharing-with-main-app)
9. [Lock Screen Widgets](#lock-screen-widgets)
10. [StandBy Mode (iOS 17+)](#standby-mode-ios-17)
11. [Live Activities](#live-activities)
12. [Control Widgets (iOS 18+)](#control-widgets-ios-18)
13. [Best Practices](#best-practices)
14. [Common Pitfalls](#common-pitfalls)
15. [Quick Reference](#quick-reference)

---

## Overview

WidgetKit enables glanceable, at-a-glance information on:

- **Home Screen** - Small, medium, large, and extra-large widgets
- **Lock Screen** - Circular, rectangular, and inline accessory widgets (iOS 16+)
- **StandBy Mode** - Full-screen widget experience when charging (iOS 17+)
- **Today View** - Widgets in the notification center
- **Desktop** - macOS Sonoma and later

### Key Characteristics

- Widgets are **not mini apps** - they display static snapshots that update periodically
- SwiftUI-only - no UIKit allowed
- Runs in a separate extension process
- Timeline-based updates with system-managed refresh
- Interactive elements available in iOS 17+ via AppIntents

### Import

```swift
import WidgetKit
import SwiftUI
```

---

## Setup & Configuration

### Creating a Widget Extension

1. File > New > Target
2. Select "Widget Extension"
3. Name your widget (e.g., "TaskWidget")
4. Choose whether to include Configuration Intent (for user-customizable widgets)

### Widget Extension Structure

```
WidgetExtension/
├── TaskWidget.swift          # Main widget definition
├── TaskWidgetBundle.swift    # Widget bundle (if multiple widgets)
├── TimelineProvider.swift    # Provides timeline entries
├── TaskEntry.swift           # Timeline entry model
├── Assets.xcassets           # Widget-specific assets
└── Info.plist
```

### App Groups Configuration

Widgets run in a separate process and need App Groups to share data with the main app.

1. Enable App Groups capability in both main app and widget extension
2. Use the same App Group identifier (e.g., `group.com.yourcompany.yourapp`)

```swift
// Shared UserDefaults
let sharedDefaults = UserDefaults(suiteName: "group.com.yourcompany.yourapp")

// Shared container URL
let containerURL = FileManager.default.containerURL(
    forSecurityApplicationGroupIdentifier: "group.com.yourcompany.yourapp"
)
```

---

## Core Concepts

### Widget Protocol

The main entry point for your widget.

```swift
import WidgetKit
import SwiftUI

struct TaskWidget: Widget {
    let kind: String = "TaskWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TaskTimelineProvider()) { entry in
            TaskWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Tasks")
        .description("View your upcoming tasks.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
```

### TimelineEntry

Represents a single snapshot of your widget's content at a specific time.

```swift
struct TaskEntry: TimelineEntry {
    let date: Date
    let tasks: [Task]
    let configuration: ConfigurationAppIntent?

    // For preview/placeholder purposes
    static var placeholder: TaskEntry {
        TaskEntry(
            date: Date(),
            tasks: [Task.sample],
            configuration: nil
        )
    }
}
```

### WidgetBundle

Groups multiple widgets from the same extension.

```swift
@main
struct TaskWidgetBundle: WidgetBundle {
    var body: some Widget {
        TaskWidget()
        TaskProgressWidget()
        TaskCompactWidget()
    }
}
```

---

## Timeline Provider

The timeline provider tells WidgetKit when and how to update your widget.

### Static Provider (No User Configuration)

```swift
struct TaskTimelineProvider: TimelineProvider {

    // MARK: - Placeholder
    /// Displayed while widget loads for the first time
    func placeholder(in context: Context) -> TaskEntry {
        TaskEntry(date: Date(), tasks: [Task.sample], configuration: nil)
    }

    // MARK: - Snapshot
    /// Used for widget gallery preview
    func getSnapshot(in context: Context, completion: @escaping (TaskEntry) -> Void) {
        if context.isPreview {
            // Return sample data for gallery
            completion(TaskEntry(date: Date(), tasks: Task.sampleTasks, configuration: nil))
        } else {
            // Return real data
            let tasks = TaskManager.shared.fetchUpcomingTasks()
            completion(TaskEntry(date: Date(), tasks: tasks, configuration: nil))
        }
    }

    // MARK: - Timeline
    /// Provides the actual timeline of entries
    func getTimeline(in context: Context, completion: @escaping (Timeline<TaskEntry>) -> Void) {
        let currentDate = Date()
        let tasks = TaskManager.shared.fetchUpcomingTasks()

        // Create entries for the next few hours
        var entries: [TaskEntry] = []

        for hourOffset in 0..<5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            entries.append(TaskEntry(date: entryDate, tasks: tasks, configuration: nil))
        }

        // Request next update after 1 hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))

        completion(timeline)
    }
}
```

### Configurable Provider (With AppIntent)

```swift
struct ConfigurableTaskProvider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> TaskEntry {
        TaskEntry(date: Date(), tasks: [Task.sample], configuration: nil)
    }

    func snapshot(for configuration: TaskWidgetIntent, in context: Context) async -> TaskEntry {
        let tasks = await fetchTasks(for: configuration)
        return TaskEntry(date: Date(), tasks: tasks, configuration: configuration)
    }

    func timeline(for configuration: TaskWidgetIntent, in context: Context) async -> Timeline<TaskEntry> {
        let currentDate = Date()
        let tasks = await fetchTasks(for: configuration)

        let entry = TaskEntry(date: currentDate, tasks: tasks, configuration: configuration)

        // Update every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: currentDate)!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    private func fetchTasks(for configuration: TaskWidgetIntent) async -> [Task] {
        var tasks = TaskManager.shared.fetchUpcomingTasks()

        // Apply user configuration
        if let category = configuration.category {
            tasks = tasks.filter { $0.category == category.id }
        }

        if configuration.showCompletedTasks == false {
            tasks = tasks.filter { !$0.isComplete }
        }

        return tasks
    }
}
```

### Timeline Reload Policies

```swift
// Reload after a specific date
Timeline(entries: entries, policy: .after(nextUpdateDate))

// Reload at end of timeline
Timeline(entries: entries, policy: .atEnd)

// Never automatically reload (use WidgetCenter.shared.reloadTimelines)
Timeline(entries: entries, policy: .never)
```

---

## Widget Families

### Available Families by Platform

| Family | iOS | iPadOS | macOS | watchOS |
|--------|-----|--------|-------|---------|
| `.systemSmall` | Yes | Yes | Yes | No |
| `.systemMedium` | Yes | Yes | Yes | No |
| `.systemLarge` | Yes | Yes | Yes | No |
| `.systemExtraLarge` | No | Yes | Yes | No |
| `.accessoryCircular` | Yes (16+) | Yes (16+) | No | Yes (9+) |
| `.accessoryRectangular` | Yes (16+) | Yes (16+) | No | Yes (9+) |
| `.accessoryInline` | Yes (16+) | Yes (16+) | No | Yes (9+) |

### Specifying Supported Families

```swift
struct TaskWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TaskWidget", provider: TaskTimelineProvider()) { entry in
            TaskWidgetView(entry: entry)
        }
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}
```

### Adapting Layout to Widget Family

```swift
struct TaskWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: TaskEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallTaskView(entry: entry)
        case .systemMedium:
            MediumTaskView(entry: entry)
        case .systemLarge:
            LargeTaskView(entry: entry)
        case .accessoryCircular:
            CircularTaskView(entry: entry)
        case .accessoryRectangular:
            RectangularTaskView(entry: entry)
        case .accessoryInline:
            InlineTaskView(entry: entry)
        default:
            SmallTaskView(entry: entry)
        }
    }
}
```

---

## Widget Configuration

### Static Configuration (No User Options)

```swift
struct TaskWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "TaskWidget",
            provider: TaskTimelineProvider()
        ) { entry in
            TaskWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Tasks")
        .description("View your upcoming tasks.")
    }
}
```

### AppIntent Configuration (iOS 17+)

```swift
import AppIntents

struct TaskWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Task Widget"
    static var description = IntentDescription("Configure your task widget.")

    @Parameter(title: "Category")
    var category: TaskCategoryEntity?

    @Parameter(title: "Show Completed Tasks", default: false)
    var showCompletedTasks: Bool

    @Parameter(title: "Number of Tasks", default: 3)
    var numberOfTasks: Int
}

struct TaskWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "TaskWidget",
            intent: TaskWidgetIntent.self,
            provider: ConfigurableTaskProvider()
        ) { entry in
            TaskWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Tasks")
        .description("View tasks from a specific category.")
    }
}
```

### Prompt for Configuration on Add (iOS 18+)

```swift
struct TaskWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "TaskWidget",
            intent: TaskWidgetIntent.self,
            provider: ConfigurableTaskProvider()
        ) { entry in
            TaskWidgetView(entry: entry)
        }
        .promptsForUserConfiguration()  // iOS 18+: Shows config immediately after adding
    }
}
```

---

## Interactive Widgets (iOS 17+)

Starting with iOS 17, widgets can include interactive elements using AppIntents.

### Interactive Button

```swift
import SwiftUI
import AppIntents
import WidgetKit

struct CompleteTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Task"

    @Parameter(title: "Task ID")
    var taskId: String

    init() {}

    init(taskId: String) {
        self.taskId = taskId
    }

    func perform() async throws -> some IntentResult {
        TaskManager.shared.completeTask(id: taskId)
        return .result()
    }
}

struct TaskWidgetView: View {
    let entry: TaskEntry

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(entry.tasks) { task in
                HStack {
                    Text(task.name)
                    Spacer()

                    Button(intent: CompleteTaskIntent(taskId: task.id)) {
                        Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
```

### Interactive Toggle

```swift
struct ToggleTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Task"

    @Parameter(title: "Task ID")
    var taskId: String

    @Parameter(title: "Is Complete")
    var isComplete: Bool

    init() {}

    init(taskId: String, isComplete: Bool) {
        self.taskId = taskId
        self.isComplete = isComplete
    }

    func perform() async throws -> some IntentResult {
        TaskManager.shared.setTaskComplete(id: taskId, isComplete: isComplete)
        return .result()
    }
}

struct TaskRowView: View {
    let task: Task

    var body: some View {
        Toggle(
            isOn: task.isComplete,
            intent: ToggleTaskIntent(taskId: task.id, isComplete: !task.isComplete)
        ) {
            Text(task.name)
        }
    }
}
```

### Widget URL for Deep Linking

For navigation when tapping the widget (non-interactive areas).

```swift
struct TaskWidgetView: View {
    let entry: TaskEntry

    var body: some View {
        VStack {
            ForEach(entry.tasks) { task in
                Link(destination: URL(string: "myapp://task/\(task.id)")!) {
                    TaskRowView(task: task)
                }
            }
        }
        .widgetURL(URL(string: "myapp://tasks"))  // Fallback URL for entire widget
    }
}
```

### Invalidate After Intent

Refresh widget immediately after an intent performs.

```swift
struct CompleteTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Task"

    @Parameter(title: "Task ID")
    var taskId: String

    func perform() async throws -> some IntentResult {
        TaskManager.shared.completeTask(id: taskId)

        // Force widget refresh
        WidgetCenter.shared.reloadTimelines(ofKind: "TaskWidget")

        return .result()
    }
}
```

---

## Data Sharing with Main App

### Using App Groups with UserDefaults

```swift
// Shared constants
enum AppGroupConstants {
    static let suiteName = "group.com.yourcompany.yourapp"
}

// In main app - saving data
class TaskManager {
    static let shared = TaskManager()
    private let defaults = UserDefaults(suiteName: AppGroupConstants.suiteName)

    func saveTasks(_ tasks: [Task]) {
        let encoded = try? JSONEncoder().encode(tasks)
        defaults?.set(encoded, forKey: "tasks")

        // Notify widget to reload
        WidgetCenter.shared.reloadTimelines(ofKind: "TaskWidget")
    }
}

// In widget extension - reading data
struct TaskTimelineProvider: TimelineProvider {
    private let defaults = UserDefaults(suiteName: AppGroupConstants.suiteName)

    func fetchTasks() -> [Task] {
        guard let data = defaults?.data(forKey: "tasks"),
              let tasks = try? JSONDecoder().decode([Task].self, from: data) else {
            return []
        }
        return tasks
    }
}
```

### Using App Groups with File Storage

```swift
// Shared file manager
class SharedFileManager {
    static let shared = SharedFileManager()

    private var containerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroupConstants.suiteName
        )
    }

    func saveData<T: Encodable>(_ data: T, filename: String) throws {
        guard let url = containerURL?.appendingPathComponent(filename) else {
            throw SharedFileError.containerNotFound
        }
        let encoded = try JSONEncoder().encode(data)
        try encoded.write(to: url)
    }

    func loadData<T: Decodable>(_ type: T.Type, filename: String) throws -> T {
        guard let url = containerURL?.appendingPathComponent(filename) else {
            throw SharedFileError.containerNotFound
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(type, from: data)
    }
}
```

### Using App Groups with Realm

```swift
// Configure Realm with App Groups
class RealmManager {
    static var sharedConfiguration: Realm.Configuration {
        var config = Realm.Configuration()
        config.fileURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroupConstants.suiteName)?
            .appendingPathComponent("shared.realm")
        return config
    }
}

// Access shared Realm in widget
struct TaskTimelineProvider: TimelineProvider {
    func fetchTasks() -> [Task] {
        do {
            let realm = try Realm(configuration: RealmManager.sharedConfiguration)
            return Array(realm.objects(TaskObject.self).map { Task(from: $0) })
        } catch {
            return []
        }
    }
}
```

### Reloading Widgets from Main App

```swift
import WidgetKit

class TaskManager {
    func updateTask(_ task: Task) {
        // Save changes...

        // Reload specific widget
        WidgetCenter.shared.reloadTimelines(ofKind: "TaskWidget")

        // Or reload all widgets
        WidgetCenter.shared.reloadAllTimelines()
    }
}
```

### Getting Current Widget Configurations

```swift
WidgetCenter.shared.getCurrentConfigurations { result in
    switch result {
    case .success(let widgetInfos):
        for info in widgetInfos {
            print("Widget kind: \(info.kind)")
            print("Widget family: \(info.family)")
        }
    case .failure(let error):
        print("Error: \(error)")
    }
}
```

---

## Lock Screen Widgets

Lock Screen widgets use accessory families, optimized for small displays.

### Accessory Circular

```swift
struct CircularTaskView: View {
    let entry: TaskEntry

    var body: some View {
        Gauge(value: Double(entry.completedCount), in: 0...Double(entry.totalCount)) {
            Image(systemName: "checkmark")
        } currentValueLabel: {
            Text("\(entry.completedCount)")
        }
        .gaugeStyle(.accessoryCircular)
    }
}
```

### Accessory Rectangular

```swift
struct RectangularTaskView: View {
    let entry: TaskEntry

    var body: some View {
        VStack(alignment: .leading) {
            Text("Tasks Due Today")
                .font(.headline)
                .widgetAccentable()

            if let task = entry.tasks.first {
                Text(task.name)
                    .font(.caption)
            }

            Text("\(entry.tasks.count) remaining")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
```

### Accessory Inline

```swift
struct InlineTaskView: View {
    let entry: TaskEntry

    var body: some View {
        // Single line of text with optional SF Symbol
        Label("\(entry.tasks.count) tasks due", systemImage: "checklist")
    }
}
```

### Vibrant Rendering Mode

Lock Screen widgets automatically use vibrant rendering. Use `.widgetAccentable()` for tinted elements.

```swift
struct LockScreenTaskView: View {
    let entry: TaskEntry

    var body: some View {
        VStack {
            Image(systemName: "checkmark.circle")
                .widgetAccentable()  // Tinted with accent color

            Text("\(entry.completedCount)")
                .font(.title)
        }
    }
}
```

---

## StandBy Mode (iOS 17+)

StandBy mode displays widgets full-screen when iPhone is charging in landscape. Widgets automatically adapt, but you can optimize for this context.

### Detecting StandBy Mode

```swift
struct TaskWidgetView: View {
    @Environment(\.showsWidgetContainerBackground) var showsBackground
    let entry: TaskEntry

    var body: some View {
        VStack {
            // Content
        }
        .font(showsBackground ? .body : .title)  // Larger font in StandBy
    }
}
```

### Optimizing for StandBy

```swift
struct StandByOptimizedView: View {
    @Environment(\.widgetRenderingMode) var renderingMode
    let entry: TaskEntry

    var body: some View {
        VStack {
            // Use higher contrast in StandBy's vibrant mode
            if renderingMode == .vibrant {
                Text(entry.tasks.first?.name ?? "No tasks")
                    .font(.largeTitle)
                    .bold()
            } else {
                Text(entry.tasks.first?.name ?? "No tasks")
                    .font(.title)
            }
        }
    }
}
```

---

## Live Activities

Live Activities display real-time updates on the Lock Screen and Dynamic Island.

### Defining Activity Attributes

```swift
import ActivityKit

struct TaskTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var remainingTime: TimeInterval
        var taskName: String
    }

    var taskId: String
    var startTime: Date
}
```

### Starting a Live Activity

```swift
func startTaskTimer(for task: Task) async throws {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

    let attributes = TaskTimerAttributes(
        taskId: task.id,
        startTime: Date()
    )

    let initialState = TaskTimerAttributes.ContentState(
        remainingTime: task.duration,
        taskName: task.name
    )

    let content = ActivityContent(state: initialState, staleDate: nil)

    let activity = try Activity.request(
        attributes: attributes,
        content: content,
        pushType: nil
    )
}
```

### Live Activity View

```swift
struct TaskTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TaskTimerAttributes.self) { context in
            // Lock Screen presentation
            VStack {
                Text(context.state.taskName)
                    .font(.headline)
                Text(timerInterval: context.attributes.startTime...Date().addingTimeInterval(context.state.remainingTime))
                    .font(.title)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded view
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.taskName)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.attributes.startTime...Date().addingTimeInterval(context.state.remainingTime))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Button(intent: StopTimerIntent(taskId: context.attributes.taskId)) {
                        Text("Stop Timer")
                    }
                }
            } compactLeading: {
                Image(systemName: "timer")
            } compactTrailing: {
                Text(timerInterval: context.attributes.startTime...Date().addingTimeInterval(context.state.remainingTime))
            } minimal: {
                Image(systemName: "timer")
            }
        }
    }
}
```

---

## Control Widgets (iOS 18+)

Control Widgets appear in Control Center and on the Lock Screen.

### Button Control

```swift
import WidgetKit
import AppIntents

struct AddTaskControl: ControlWidget {
    static let kind = "com.yourapp.addtask"

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
    static let kind = "com.yourapp.focusmode"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            provider: FocusModeValueProvider()
        ) { value in
            ControlWidgetToggle(
                "Focus Mode",
                isOn: value,
                action: ToggleFocusModeIntent()
            ) { isOn in
                Label(
                    isOn ? "Focus On" : "Focus Off",
                    systemImage: isOn ? "moon.fill" : "moon"
                )
            }
        }
        .displayName("Focus Mode")
    }
}

struct FocusModeValueProvider: AppIntentControlValueProvider {
    func previewValue(configuration: FocusModeIntent) -> Bool {
        false
    }

    func currentValue(configuration: FocusModeIntent) async throws -> Bool {
        return FocusModeManager.shared.isEnabled
    }
}
```

---

## Best Practices

### 1. Keep Timeline Entries Lightweight

```swift
// Good: Simple, serializable entry
struct TaskEntry: TimelineEntry {
    let date: Date
    let taskNames: [String]
    let completedCount: Int
    let totalCount: Int
}

// Avoid: Heavy objects in entries
struct BadEntry: TimelineEntry {
    let date: Date
    let taskManager: TaskManager  // Don't store managers
    let images: [UIImage]          // Don't store images directly
}
```

### 2. Use Placeholder for Loading States

```swift
func placeholder(in context: Context) -> TaskEntry {
    // Return immediately with sample data
    TaskEntry(
        date: Date(),
        tasks: [
            Task(name: "Sample Task 1", isComplete: false),
            Task(name: "Sample Task 2", isComplete: true)
        ]
    )
}
```

### 3. Handle Empty States Gracefully

```swift
struct TaskWidgetView: View {
    let entry: TaskEntry

    var body: some View {
        if entry.tasks.isEmpty {
            ContentUnavailableView(
                "No Tasks",
                systemImage: "checkmark.circle",
                description: Text("Add tasks in the app")
            )
        } else {
            TaskListView(tasks: entry.tasks)
        }
    }
}
```

### 4. Use Container Background (iOS 17+)

```swift
struct TaskWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TaskWidget", provider: TaskTimelineProvider()) { entry in
            TaskWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)  // Required in iOS 17+
        }
    }
}
```

### 5. Minimize Network Requests

```swift
struct TaskTimelineProvider: TimelineProvider {
    func getTimeline(in context: Context, completion: @escaping (Timeline<TaskEntry>) -> Void) {
        // Prefer cached data from App Groups
        let cachedTasks = loadCachedTasks()

        // Only fetch from network if cache is stale
        if shouldRefreshFromNetwork() {
            Task {
                let freshTasks = try? await fetchTasksFromServer()
                // Cache and continue
            }
        }

        let entry = TaskEntry(date: Date(), tasks: cachedTasks)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdateTime()))
        completion(timeline)
    }
}
```

### 6. Reload Timelines Strategically

```swift
class TaskManager {
    func completeTask(_ task: Task) {
        // Update local data
        markTaskComplete(task)

        // Only reload the specific widget that shows this task
        WidgetCenter.shared.reloadTimelines(ofKind: "TaskWidget")

        // Avoid: WidgetCenter.shared.reloadAllTimelines() - wasteful
    }
}
```

### 7. Support Dynamic Type

```swift
struct TaskWidgetView: View {
    @Environment(\.widgetFamily) var family
    @ScaledMetric var iconSize: CGFloat = 24

    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle")
                .font(.system(size: iconSize))
            Text("Task Name")
                .lineLimit(family == .systemSmall ? 2 : 3)
        }
    }
}
```

---

## Common Pitfalls

### 1. Timeline Refresh Limits

**Problem:** Widgets don't update when expected.

**Cause:** System limits timeline refreshes to conserve battery (~40-70 per day).

**Solution:**
```swift
// Don't request too frequent updates
let timeline = Timeline(entries: entries, policy: .after(
    Calendar.current.date(byAdding: .minute, value: 30, to: Date())!  // Minimum 15-30 minutes
))

// Use WidgetCenter.shared.reloadTimelines() sparingly
// Only call when data actually changes
```

### 2. Memory Constraints

**Problem:** Widget crashes or shows blank.

**Cause:** Widget extensions have strict memory limits (~30MB).

**Solution:**
```swift
// Avoid loading large images
// Use SF Symbols instead of custom images when possible
Image(systemName: "checkmark.circle")

// If using images, downscale them
let thumbnail = originalImage.preparingThumbnail(of: CGSize(width: 100, height: 100))
```

### 3. Background Execution Limits

**Problem:** Async operations don't complete.

**Cause:** Widgets have limited background execution time.

**Solution:**
```swift
// Keep operations fast and simple
func getTimeline(in context: Context, completion: @escaping (Timeline<TaskEntry>) -> Void) {
    // Read from App Groups storage (fast)
    let tasks = loadCachedTasks()

    // Don't make slow network requests here
    // Have the main app prefetch and cache data

    let entry = TaskEntry(date: Date(), tasks: tasks)
    completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
}
```

### 4. Widget Not Appearing

**Problem:** Widget doesn't show in widget picker.

**Causes and Solutions:**
```swift
// 1. Missing @main attribute
@main  // Required on WidgetBundle or Widget
struct TaskWidgetBundle: WidgetBundle {
    var body: some Widget {
        TaskWidget()
    }
}

// 2. Build/run the app at least once after adding widget extension

// 3. Check widget extension's deployment target matches or is lower than device iOS version
```

### 5. Data Not Syncing

**Problem:** Widget shows stale data.

**Solution:**
```swift
// Ensure App Group identifier matches exactly
let suiteName = "group.com.yourcompany.yourapp"  // Same in both targets

// Reload timeline after saving data
func saveTask(_ task: Task) {
    // Save to shared storage
    saveToAppGroups(task)

    // Notify widget
    WidgetCenter.shared.reloadTimelines(ofKind: "TaskWidget")
}
```

### 6. Interactive Elements Not Working

**Problem:** Buttons/toggles don't respond in iOS 17+ widgets.

**Solution:**
```swift
// AppIntent must have default initializer
struct CompleteTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Task"

    @Parameter(title: "Task ID")
    var taskId: String

    init() {}  // Required!

    init(taskId: String) {
        self.taskId = taskId
    }

    func perform() async throws -> some IntentResult {
        // Perform action
        return .result()
    }
}

// Use Button(intent:) not Button(action:)
Button(intent: CompleteTaskIntent(taskId: task.id)) {
    Text("Complete")
}
```

---

## Quick Reference

### Environment Values

| Value | Type | Purpose |
|-------|------|---------|
| `\.widgetFamily` | `WidgetFamily` | Current widget size |
| `\.widgetRenderingMode` | `WidgetRenderingMode` | `.fullColor`, `.vibrant`, `.accented` |
| `\.showsWidgetContainerBackground` | `Bool` | Whether container background is visible |
| `\.widgetContentMargins` | `EdgeInsets` | Safe area margins |

### Widget Families

| Family | Size | Use Case |
|--------|------|----------|
| `.systemSmall` | 2x2 | Single piece of information |
| `.systemMedium` | 4x2 | List of 2-4 items |
| `.systemLarge` | 4x4 | Detailed information, longer lists |
| `.systemExtraLarge` | 8x4 (iPad) | Complex layouts |
| `.accessoryCircular` | Lock Screen | Gauge, single value |
| `.accessoryRectangular` | Lock Screen | 2-3 lines of text |
| `.accessoryInline` | Lock Screen | Single line with icon |

### Timeline Policies

| Policy | Behavior |
|--------|----------|
| `.atEnd` | Reload after last entry |
| `.after(Date)` | Reload after specific time |
| `.never` | Only reload via `WidgetCenter` |

### WidgetCenter Methods

```swift
// Reload specific widget type
WidgetCenter.shared.reloadTimelines(ofKind: "TaskWidget")

// Reload all widgets
WidgetCenter.shared.reloadAllTimelines()

// Get current configurations
WidgetCenter.shared.getCurrentConfigurations { result in }

// Invalidate configuration (iOS 17+)
WidgetCenter.shared.invalidateConfigurationRecommendations()
```

### iOS Version Compatibility

| Feature | Minimum iOS |
|---------|-------------|
| Basic widgets | iOS 14 |
| Lock Screen widgets | iOS 16 |
| Interactive widgets (Button/Toggle) | iOS 17 |
| StandBy mode | iOS 17 |
| containerBackground modifier | iOS 17 |
| AppIntentConfiguration | iOS 17 |
| Control Widgets | iOS 18 |
| promptsForUserConfiguration | iOS 18 |

---

## Sources

- [Apple WidgetKit Documentation](https://developer.apple.com/documentation/widgetkit)
- [Apple Human Interface Guidelines - Widgets](https://developer.apple.com/design/human-interface-guidelines/widgets)
- [Creating a Widget Extension](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension)
- [Making a Configurable Widget](https://developer.apple.com/documentation/widgetkit/making-a-configurable-widget)
- [Adding Interactivity to Widgets](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities)
- [Keeping a Widget Up To Date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date)

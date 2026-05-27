# RelevanceKit Framework Guide

A comprehensive guide for using Apple's RelevanceKit framework to make widgets contextually relevant in the Smart Stack on watchOS and iOS.

---

## Table of Contents

1. [Overview](#overview)
2. [Key Concepts](#key-concepts)
3. [RelevantContext Types](#relevantcontext-types)
4. [Building Relevant Widgets](#building-relevant-widgets)
5. [RelevanceEntry](#relevanceentry)
6. [RelevanceEntriesProvider](#relevanceentriesprovider)
7. [RelevanceConfiguration](#relevanceconfiguration)
8. [WidgetRelevanceAttributes](#widgetrelevanceattributes)
9. [Integration with WidgetKit](#integration-with-widgetkit)
10. [Best Practices](#best-practices)
11. [Migration from Timeline Widgets](#migration-from-timeline-widgets)

---

## Overview

RelevanceKit is Apple's framework for providing on-device intelligence with contextual clues that increase your widget's visibility in the Smart Stack. Introduced for watchOS 10 and enhanced significantly in watchOS 26 and iOS 26, RelevanceKit enables widgets to appear only when contextually relevant to the user.

### Key Benefits

- **Smart Visibility**: Widgets appear only when contextually relevant
- **Multi-Instance Support**: Multiple widget instances can display simultaneously for different contexts
- **Clutter Reduction**: Eliminates static widget clutter in Smart Stack
- **User-Centric**: Prioritizes user attention and relevance over constant availability

### Supported Platforms

- watchOS 10+ (significantly enhanced in watchOS 26)
- iOS 26+ (for contextual widget presentation)

---

## Key Concepts

### Smart Stack

The Smart Stack is a scrollable stack of widgets accessed with an upward turn of the digital crown on Apple Watch. It provides glanceable information outside of complications.

Features:
- Relevance-based ordering of widgets
- Manual add, remove, and pin capabilities
- Dynamic or fixed configuration based on user preference

### Contextual Relevance

RelevanceKit enables widgets to signal when they have useful information to display. The system uses these signals to:
- Automatically show widgets in the Smart Stack
- Prioritize widget ordering
- Suggest widgets to users

---

## RelevantContext Types

RelevanceKit provides multiple context types for suggesting widgets:

### Date Context

```swift
import RelevanceKit

// Widget relevant during specific date interval
let dateContext = RelevantContext.date(
    DateInterval(start: eventStart, end: eventEnd)
)
```

### Location Context

```swift
// Widget relevant at specific location
let locationContext = RelevantContext.location(
    CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
    radius: 500 // meters
)
```

### Sleep Schedule Context

```swift
// Widget relevant during sleep schedule
let sleepContext = RelevantContext.sleepSchedule
```

### Fitness Context

```swift
// Widget relevant during workout or fitness activities
let fitnessContext = RelevantContext.fitness
```

### Custom Contexts

```swift
// Combine multiple contexts
let combinedContext = RelevantContext.all([
    .date(eventInterval),
    .location(beachCoordinate, radius: 1000)
])
```

---

## Building Relevant Widgets

Creating a relevant widget follows a similar pattern to timeline widgets but uses relevance-based components.

### Basic Structure

```swift
import WidgetKit
import SwiftUI
import RelevanceKit

struct BeachWidget: Widget {
    let kind: String = "BeachWidget"

    var body: some WidgetConfiguration {
        RelevanceConfiguration(
            kind: kind,
            provider: BeachRelevanceProvider()
        ) { entry in
            BeachWidgetView(entry: entry)
        }
        .configurationDisplayName("Beach Events")
        .description("Shows upcoming beach events when relevant")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
```

---

## RelevanceEntry

The fundamental building block of a relevant widget. Contains all data needed to populate the widget's view.

### Definition

```swift
import WidgetKit
import RelevanceKit

struct BeachEntry: RelevanceEntry {
    let date: Date
    let event: BeachEvent
    let relevance: WidgetRelevanceAttributes?

    // Custom data for your widget
    var title: String { event.title }
    var location: String { event.location }
    var eventDate: Date { event.date }
}
```

### Event Model

```swift
struct BeachEvent: Codable {
    let id: UUID
    let title: String
    let location: String
    let date: Date
    let coordinate: CLLocationCoordinate2D
}
```

---

## RelevanceEntriesProvider

Responsible for creating RelevanceEntry objects and supplying them to the RelevanceConfiguration.

### Protocol Implementation

```swift
struct BeachRelevanceProvider: RelevanceEntriesProvider {
    typealias Entry = BeachEntry
    typealias Intent = BeachEventIntent

    // MARK: - Relevance Method

    /// Tells the system when your widget is relevant
    func relevance() async -> [WidgetRelevanceAttributes] {
        let events = await fetchUpcomingEvents()

        return events.map { event in
            WidgetRelevanceAttributes(
                configuration: BeachEventIntent(event: event),
                relevantContexts: [
                    .date(DateInterval(
                        start: event.date.addingTimeInterval(-3600), // 1 hour before
                        end: event.date.addingTimeInterval(3600 * 4)  // 4 hours after
                    )),
                    .location(event.coordinate, radius: 5000)
                ]
            )
        }
    }

    // MARK: - Entry Method

    /// Called when the widget is relevant
    func entry(
        for configuration: BeachEventIntent,
        in context: RelevanceContext
    ) async -> BeachEntry {
        let event = configuration.event

        return BeachEntry(
            date: Date(),
            event: event,
            relevance: nil
        )
    }

    // MARK: - Placeholder

    func placeholder(in context: RelevanceContext) -> BeachEntry {
        BeachEntry(
            date: Date(),
            event: .placeholder,
            relevance: nil
        )
    }

    // MARK: - Snapshot

    func snapshot(
        for configuration: BeachEventIntent,
        in context: RelevanceContext
    ) async -> BeachEntry {
        if context.isPreview {
            return placeholder(in: context)
        }
        return await entry(for: configuration, in: context)
    }

    // MARK: - Helper Methods

    private func fetchUpcomingEvents() async -> [BeachEvent] {
        // Fetch events from your data source
        return EventStore.shared.upcomingEvents
    }
}
```

---

## RelevanceConfiguration

Configures your widget to use relevance-based presentation instead of timeline-based.

### Basic Configuration

```swift
struct MyWidget: Widget {
    var body: some WidgetConfiguration {
        RelevanceConfiguration(
            kind: "MyWidget",
            provider: MyRelevanceProvider()
        ) { entry in
            MyWidgetView(entry: entry)
        }
        .configurationDisplayName("My Widget")
        .description("Appears when relevant")
    }
}
```

### With App Intent Configuration

```swift
struct ConfigurableWidget: Widget {
    var body: some WidgetConfiguration {
        RelevanceConfiguration(
            kind: "ConfigurableWidget",
            intent: SelectEventIntent.self,
            provider: EventRelevanceProvider()
        ) { entry in
            EventWidgetView(entry: entry)
        }
        .configurationDisplayName("Event Widget")
        .description("Track your events contextually")
    }
}
```

---

## WidgetRelevanceAttributes

Associates widget configurations with relevant contexts.

### Creating Relevance Attributes

```swift
func relevance() async -> [WidgetRelevanceAttributes] {
    var attributes: [WidgetRelevanceAttributes] = []

    // Event-based relevance
    for event in await fetchEvents() {
        let eventRelevance = WidgetRelevanceAttributes(
            configuration: EventIntent(eventID: event.id),
            relevantContexts: [
                .date(DateInterval(
                    start: event.startDate,
                    end: event.endDate
                ))
            ]
        )
        attributes.append(eventRelevance)
    }

    // Location-based relevance
    for location in favoriteLocations {
        let locationRelevance = WidgetRelevanceAttributes(
            configuration: LocationIntent(locationID: location.id),
            relevantContexts: [
                .location(location.coordinate, radius: location.relevanceRadius)
            ]
        )
        attributes.append(locationRelevance)
    }

    return attributes
}
```

### Scoring Relevance

```swift
// Higher score = higher priority in Smart Stack
let relevance = WidgetRelevanceAttributes(
    configuration: intent,
    relevantContexts: contexts,
    score: 0.8 // 0.0 to 1.0
)
```

---

## Integration with WidgetKit

### TimelineEntryRelevance (Traditional Approach)

For timeline-based widgets, use `TimelineEntryRelevance`:

```swift
struct MyTimelineEntry: TimelineEntry {
    let date: Date
    let content: String
    let relevance: TimelineEntryRelevance?
}

struct MyTimelineProvider: TimelineProvider {
    func timeline(in context: Context) async -> Timeline<MyTimelineEntry> {
        var entries: [MyTimelineEntry] = []

        let highPriorityEntry = MyTimelineEntry(
            date: Date(),
            content: "Important Update",
            relevance: TimelineEntryRelevance(score: 100) // Higher = more relevant
        )
        entries.append(highPriorityEntry)

        return Timeline(entries: entries, policy: .atEnd)
    }
}
```

### Donating Intents

Donate intents to increase widget visibility:

```swift
import AppIntents

struct ViewEventIntent: AppIntent {
    static var title: LocalizedStringResource = "View Event"

    @Parameter(title: "Event")
    var event: EventEntity

    func perform() async throws -> some IntentResult {
        // Handle intent
        return .result()
    }
}

// Donate when user interacts with event
func userViewedEvent(_ event: Event) {
    let intent = ViewEventIntent()
    intent.event = EventEntity(event)
    intent.donate()
}
```

---

## Best Practices

### 1. Be Selective with Relevance

```swift
// GOOD: Specific, time-bound relevance
.date(DateInterval(start: eventStart, end: eventEnd))

// BAD: Always relevant defeats the purpose
.date(DateInterval(start: .distantPast, end: .distantFuture))
```

### 2. Combine Contexts Thoughtfully

```swift
// Relevant at beach location during event time
let contexts: [RelevantContext] = [
    .date(eventInterval),
    .location(beachCoordinate, radius: 1000)
]
```

### 3. Update Relevance Regularly

```swift
// Refresh relevance when data changes
func dataDidChange() {
    WidgetCenter.shared.reloadTimelines(ofKind: "MyWidget")
}
```

### 4. Respect User Control

- Users can pin widgets to always show
- Users can remove widgets from Smart Stack
- Don't fight against user preferences

### 5. Provide Meaningful Snapshots

```swift
func snapshot(for configuration: Intent, in context: RelevanceContext) async -> Entry {
    // Return representative data for widget gallery
    if context.isPreview {
        return Entry.preview
    }
    return await entry(for: configuration, in: context)
}
```

### 6. Handle Empty States

```swift
struct MyWidgetView: View {
    let entry: MyEntry

    var body: some View {
        if entry.hasContent {
            ContentView(entry: entry)
        } else {
            EmptyStateView()
        }
    }
}
```

---

## Migration from Timeline Widgets

### Before (Timeline-based)

```swift
struct OldWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "OldWidget",
            provider: TimelineProvider()
        ) { entry in
            WidgetView(entry: entry)
        }
    }
}

struct TimelineProvider: TimelineProvider {
    func timeline(in context: Context) async -> Timeline<Entry> {
        // Generate timeline entries
    }
}
```

### After (Relevance-based)

```swift
struct NewWidget: Widget {
    var body: some WidgetConfiguration {
        RelevanceConfiguration(
            kind: "NewWidget",
            provider: RelevanceProvider()
        ) { entry in
            WidgetView(entry: entry)
        }
    }
}

struct RelevanceProvider: RelevanceEntriesProvider {
    func relevance() async -> [WidgetRelevanceAttributes] {
        // Define when widget is relevant
    }

    func entry(for configuration: Intent, in context: RelevanceContext) async -> Entry {
        // Generate entry for relevant context
    }
}
```

### Key Differences

| Aspect | Timeline Widget | Relevance Widget |
|--------|-----------------|------------------|
| Configuration | `StaticConfiguration` / `AppIntentConfiguration` | `RelevanceConfiguration` |
| Provider | `TimelineProvider` | `RelevanceEntriesProvider` |
| Visibility | Always visible (user adds) | Appears when contextually relevant |
| Updates | Timeline-based refresh | Context-triggered appearance |

---

## Complete Example

### Beach Events Widget

```swift
import WidgetKit
import SwiftUI
import RelevanceKit
import AppIntents

// MARK: - Entry

struct BeachEntry: RelevanceEntry {
    let date: Date
    let event: BeachEvent?
    let relevance: WidgetRelevanceAttributes?

    static var placeholder: BeachEntry {
        BeachEntry(
            date: Date(),
            event: .placeholder,
            relevance: nil
        )
    }
}

// MARK: - Intent

struct BeachEventIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Beach Event"

    @Parameter(title: "Event")
    var eventID: String?

    init() {}

    init(event: BeachEvent) {
        self.eventID = event.id.uuidString
    }
}

// MARK: - Provider

struct BeachRelevanceProvider: RelevanceEntriesProvider {
    typealias Entry = BeachEntry
    typealias Intent = BeachEventIntent

    func relevance() async -> [WidgetRelevanceAttributes] {
        let events = await BeachEventStore.shared.upcomingEvents()

        return events.map { event in
            WidgetRelevanceAttributes(
                configuration: BeachEventIntent(event: event),
                relevantContexts: [
                    // Relevant 2 hours before until 1 hour after
                    .date(DateInterval(
                        start: event.date.addingTimeInterval(-7200),
                        end: event.date.addingTimeInterval(3600)
                    )),
                    // Relevant within 5km of beach
                    .location(event.coordinate, radius: 5000)
                ],
                score: event.isPriority ? 1.0 : 0.5
            )
        }
    }

    func entry(
        for configuration: BeachEventIntent,
        in context: RelevanceContext
    ) async -> BeachEntry {
        guard let eventID = configuration.eventID,
              let event = await BeachEventStore.shared.event(id: eventID) else {
            return .placeholder
        }

        return BeachEntry(
            date: Date(),
            event: event,
            relevance: nil
        )
    }

    func placeholder(in context: RelevanceContext) -> BeachEntry {
        .placeholder
    }

    func snapshot(
        for configuration: BeachEventIntent,
        in context: RelevanceContext
    ) async -> BeachEntry {
        if context.isPreview {
            return .placeholder
        }
        return await entry(for: configuration, in: context)
    }
}

// MARK: - View

struct BeachWidgetView: View {
    let entry: BeachEntry

    var body: some View {
        if let event = entry.event {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)

                Label(event.location, systemImage: "mappin")
                    .font(.caption)

                Text(event.date, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()
        } else {
            ContentUnavailableView(
                "No Events",
                systemImage: "sun.max",
                description: Text("Add beach events to see them here")
            )
        }
    }
}

// MARK: - Widget

struct BeachWidget: Widget {
    let kind: String = "BeachWidget"

    var body: some WidgetConfiguration {
        RelevanceConfiguration(
            kind: kind,
            intent: BeachEventIntent.self,
            provider: BeachRelevanceProvider()
        ) { entry in
            BeachWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Beach Events")
        .description("Shows upcoming beach events when you're nearby or it's time")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
```

---

## Resources

- [RelevanceKit Documentation](https://developer.apple.com/documentation/RelevanceKit)
- [WidgetKit Documentation](https://developer.apple.com/documentation/widgetkit)
- [WWDC25: What's new in watchOS 26](https://developer.apple.com/videos/play/wwdc2025/334/)
- [WWDC23: Build widgets for the Smart Stack](https://developer.apple.com/videos/play/wwdc2023/10029/)
- [Increasing widget visibility in Smart Stacks](https://developer.apple.com/documentation/widgetkit/widget-suggestions-in-smart-stacks)

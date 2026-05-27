# EventKit Framework Guide for iOS Development

A comprehensive guide for working with calendars, events, and reminders using EventKit in SwiftUI with async/await patterns.

---

## Table of Contents

1. [Overview](#overview)
2. [Setup & Permissions](#setup--permissions)
3. [Core Concepts](#core-concepts)
4. [SwiftUI Integration Patterns](#swiftui-integration-patterns)
5. [Calendar Events](#calendar-events)
6. [Reminders](#reminders)
7. [Recurring Events and Rules](#recurring-events-and-rules)
8. [Alarms](#alarms)
9. [EventKitUI for Native UI](#eventkitui-for-native-ui)
10. [iOS 18/26 Considerations](#ios-1826-considerations)
11. [Common Use Cases](#common-use-cases)
12. [Best Practices](#best-practices)

---

## Overview

EventKit is Apple's framework for creating, viewing, and editing calendar and reminder events. It provides access to the user's calendar database and supports scheduling new events and reminders.

### Key Components

| Class | Purpose |
|-------|---------|
| `EKEventStore` | Central access point to calendar and reminder data |
| `EKEvent` | Represents a calendar event |
| `EKReminder` | Represents a reminder |
| `EKCalendar` | Represents a calendar container |
| `EKAlarm` | Represents time or location-based alerts |
| `EKRecurrenceRule` | Defines repeating patterns for events/reminders |
| `EKSource` | Represents the account/service backing calendars |

### Framework Import

```swift
import EventKit
import EventKitUI  // For native UI components
```

---

## Setup & Permissions

### Info.plist Configuration

Add the appropriate usage description keys based on your app's needs:

```xml
<!-- For full read/write access to calendar events -->
<key>NSCalendarsFullAccessUsageDescription</key>
<string>This app needs access to your calendar to manage events.</string>

<!-- For write-only access to calendar events (iOS 17+) -->
<key>NSCalendarsWriteOnlyAccessUsageDescription</key>
<string>This app needs to add events to your calendar.</string>

<!-- For access to reminders -->
<key>NSRemindersFullAccessUsageDescription</key>
<string>This app needs access to your reminders to create and manage tasks.</string>
```

### Authorization Status

Check the current authorization status before requesting access:

```swift
import EventKit

@Observable
@MainActor
final class CalendarManager {
    private let eventStore = EKEventStore()

    var calendarAuthorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    var reminderAuthorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .reminder)
    }
}
```

### Authorization Status Values

| Status | Description |
|--------|-------------|
| `.notDetermined` | User hasn't made a choice yet |
| `.restricted` | App is not authorized (parental controls, etc.) |
| `.denied` | User explicitly denied access |
| `.fullAccess` | Full read/write access granted (iOS 17+) |
| `.writeOnly` | Write-only access granted (iOS 17+) |

### Requesting Authorization (iOS 17+)

```swift
@Observable
@MainActor
final class CalendarManager {
    private let eventStore = EKEventStore()

    var hasCalendarAccess = false
    var hasReminderAccess = false

    // MARK: - Authorization

    /// Requests full access to calendar events
    func requestCalendarAccess() async {
        do {
            hasCalendarAccess = try await eventStore.requestFullAccessToEvents()
        } catch {
            print("Calendar access error: \(error.localizedDescription)")
            hasCalendarAccess = false
        }
    }

    /// Requests write-only access to calendar events
    func requestWriteOnlyCalendarAccess() async {
        do {
            hasCalendarAccess = try await eventStore.requestWriteOnlyAccessToEvents()
        } catch {
            print("Calendar write access error: \(error.localizedDescription)")
            hasCalendarAccess = false
        }
    }

    /// Requests full access to reminders
    func requestReminderAccess() async {
        do {
            hasReminderAccess = try await eventStore.requestFullAccessToReminders()
        } catch {
            print("Reminder access error: \(error.localizedDescription)")
            hasReminderAccess = false
        }
    }
}
```

### Backward Compatible Authorization (iOS 16 and Earlier)

```swift
func requestCalendarAccess() async {
    do {
        if #available(iOS 17, *) {
            hasCalendarAccess = try await eventStore.requestFullAccessToEvents()
        } else {
            hasCalendarAccess = try await eventStore.requestAccess(to: .event)
        }
    } catch {
        hasCalendarAccess = false
    }
}

func requestReminderAccess() async {
    do {
        if #available(iOS 17, *) {
            hasReminderAccess = try await eventStore.requestFullAccessToReminders()
        } else {
            hasReminderAccess = try await eventStore.requestAccess(to: .reminder)
        }
    } catch {
        hasReminderAccess = false
    }
}
```

---

## Core Concepts

### EKEventStore

The central object for accessing calendar and reminder data. Create a single instance and reuse it throughout your app.

```swift
@Observable
@MainActor
final class EventKitManager {
    // Single instance - creating EKEventStore is expensive
    let eventStore = EKEventStore()

    // Track changes to the calendar database
    private var notificationObserver: Any?

    init() {
        setupNotifications()
    }

    private func setupNotifications() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshData()
            }
        }
    }

    private func refreshData() async {
        // Reload events and reminders when database changes
    }

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
```

### EKCalendar

Represents a calendar container that holds events or reminders.

```swift
extension EventKitManager {

    /// All calendars for events
    var eventCalendars: [EKCalendar] {
        eventStore.calendars(for: .event)
    }

    /// All calendars for reminders
    var reminderCalendars: [EKCalendar] {
        eventStore.calendars(for: .reminder)
    }

    /// Default calendar for new events
    var defaultEventCalendar: EKCalendar? {
        eventStore.defaultCalendarForNewEvents
    }

    /// Default calendar for new reminders
    var defaultReminderCalendar: EKCalendar? {
        eventStore.defaultCalendarForNewReminders()
    }
}
```

### EKSource

Represents the account/service backing calendars (iCloud, Gmail, Local, etc.).

```swift
extension EventKitManager {

    /// All available sources
    var sources: [EKSource] {
        Array(eventStore.sources)
    }

    /// Find the best source for creating calendars
    func bestAvailableSource() -> EKSource? {
        // Priority: iCloud > CalDAV > Local
        if let iCloud = eventStore.sources.first(where: { $0.sourceType == .calDAV && $0.title == "iCloud" }) {
            return iCloud
        }
        if let calDAV = eventStore.sources.first(where: { $0.sourceType == .calDAV }) {
            return calDAV
        }
        return eventStore.sources.first(where: { $0.sourceType == .local })
    }
}
```

### Creating Custom Calendars

```swift
extension EventKitManager {

    /// Creates a new calendar for events
    func createEventCalendar(title: String, color: CGColor) throws -> EKCalendar {
        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = title
        calendar.cgColor = color

        guard let source = bestAvailableSource() else {
            throw EventKitError.noSourceAvailable
        }

        calendar.source = source
        try eventStore.saveCalendar(calendar, commit: true)

        return calendar
    }

    /// Creates a new calendar for reminders
    func createReminderCalendar(title: String, color: CGColor) throws -> EKCalendar {
        let calendar = EKCalendar(for: .reminder, eventStore: eventStore)
        calendar.title = title
        calendar.cgColor = color

        guard let source = bestAvailableSource() else {
            throw EventKitError.noSourceAvailable
        }

        calendar.source = source
        try eventStore.saveCalendar(calendar, commit: true)

        return calendar
    }

    /// Deletes a calendar
    func deleteCalendar(_ calendar: EKCalendar) throws {
        try eventStore.removeCalendar(calendar, commit: true)
    }
}

enum EventKitError: LocalizedError {
    case noSourceAvailable
    case calendarNotFound
    case eventNotFound
    case reminderNotFound
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .noSourceAvailable:
            return "No calendar source available"
        case .calendarNotFound:
            return "Calendar not found"
        case .eventNotFound:
            return "Event not found"
        case .reminderNotFound:
            return "Reminder not found"
        case .saveFailed:
            return "Failed to save changes"
        }
    }
}
```

---

## SwiftUI Integration Patterns

### Observable Manager Pattern

```swift
import SwiftUI
import EventKit

@Observable
@MainActor
final class CalendarViewModel {
    private let eventStore = EKEventStore()

    var events: [EKEvent] = []
    var reminders: [EKReminder] = []
    var isLoading = false
    var error: Error?

    var hasCalendarAccess: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    var hasReminderAccess: Bool {
        EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
    }

    // MARK: - Authorization

    func requestAccess() async {
        do {
            _ = try await eventStore.requestFullAccessToEvents()
            _ = try await eventStore.requestFullAccessToReminders()
        } catch {
            self.error = error
        }
    }

    // MARK: - Fetch Events

    func fetchEvents(from startDate: Date, to endDate: Date) {
        guard hasCalendarAccess else { return }

        let calendars = eventStore.calendars(for: .event)
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: calendars
        )

        events = eventStore.events(matching: predicate)
    }

    // MARK: - Fetch Reminders

    func fetchReminders() async {
        guard hasReminderAccess else { return }

        isLoading = true
        defer { isLoading = false }

        let calendars = eventStore.calendars(for: .reminder)
        let predicate = eventStore.predicateForReminders(in: calendars)

        // Convert completion handler to async/await
        reminders = await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }
}
```

### SwiftUI View Integration

```swift
struct CalendarView: View {
    @State private var viewModel = CalendarViewModel()
    @State private var selectedDate = Date()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.hasCalendarAccess {
                    eventsList
                } else {
                    requestAccessView
                }
            }
            .navigationTitle("Calendar")
            .task {
                await viewModel.requestAccess()
                viewModel.fetchEvents(
                    from: selectedDate.startOfMonth,
                    to: selectedDate.endOfMonth
                )
            }
        }
    }

    private var eventsList: some View {
        List(viewModel.events, id: \.eventIdentifier) { event in
            EventRow(event: event)
        }
    }

    private var requestAccessView: some View {
        ContentUnavailableView(
            "Calendar Access Required",
            systemImage: "calendar",
            description: Text("Please grant calendar access in Settings.")
        )
    }
}

struct EventRow: View {
    let event: EKEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.title)
                .font(.headline)

            if let startDate = event.startDate {
                Text(startDate, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
```

### Environment-Based Dependency Injection

```swift
// Environment key
struct CalendarManagerKey: EnvironmentKey {
    static let defaultValue = CalendarViewModel()
}

extension EnvironmentValues {
    var calendarManager: CalendarViewModel {
        get { self[CalendarManagerKey.self] }
        set { self[CalendarManagerKey.self] = newValue }
    }
}

// App setup
@main
struct CalendarApp: App {
    @State private var calendarManager = CalendarViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(calendarManager)
        }
    }
}

// Usage in views
struct EventDetailView: View {
    @Environment(CalendarViewModel.self) private var calendarManager
    let event: EKEvent

    var body: some View {
        // View content
    }
}
```

---

## Calendar Events

### Creating Events

```swift
extension CalendarViewModel {

    /// Creates a new calendar event
    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        calendar: EKCalendar? = nil,
        notes: String? = nil,
        location: String? = nil,
        isAllDay: Bool = false
    ) throws -> EKEvent {
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.calendar = calendar ?? eventStore.defaultCalendarForNewEvents
        event.notes = notes
        event.location = location
        event.isAllDay = isAllDay

        try eventStore.save(event, span: .thisEvent)

        return event
    }
}
```

### Reading Events

```swift
extension CalendarViewModel {

    /// Fetches events for a specific date range
    func fetchEvents(
        from startDate: Date,
        to endDate: Date,
        calendars: [EKCalendar]? = nil
    ) -> [EKEvent] {
        let selectedCalendars = calendars ?? eventStore.calendars(for: .event)
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: selectedCalendars
        )

        return eventStore.events(matching: predicate)
    }

    /// Fetches events for today
    func fetchTodayEvents() -> [EKEvent] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        return fetchEvents(from: startOfDay, to: endOfDay)
    }

    /// Fetches a single event by identifier
    func fetchEvent(withIdentifier identifier: String) -> EKEvent? {
        eventStore.event(withIdentifier: identifier)
    }
}
```

### Updating Events

```swift
extension CalendarViewModel {

    /// Updates an existing event
    func updateEvent(
        _ event: EKEvent,
        title: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        notes: String? = nil,
        location: String? = nil,
        span: EKSpan = .thisEvent
    ) throws {
        if let title = title {
            event.title = title
        }
        if let startDate = startDate {
            event.startDate = startDate
        }
        if let endDate = endDate {
            event.endDate = endDate
        }
        if let notes = notes {
            event.notes = notes
        }
        if let location = location {
            event.location = location
        }

        try eventStore.save(event, span: span)
    }
}
```

### Deleting Events

```swift
extension CalendarViewModel {

    /// Deletes a single occurrence or all occurrences of an event
    func deleteEvent(_ event: EKEvent, span: EKSpan = .thisEvent) throws {
        try eventStore.remove(event, span: span)
    }
}
```

### Event Span Options

| Span | Description |
|------|-------------|
| `.thisEvent` | Only affects this occurrence |
| `.futureEvents` | Affects this and all future occurrences |

---

## Reminders

### Creating Reminders

```swift
extension CalendarViewModel {

    /// Creates a new reminder
    func createReminder(
        title: String,
        calendar: EKCalendar? = nil,
        dueDate: Date? = nil,
        priority: Int = 0,
        notes: String? = nil
    ) throws -> EKReminder {
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.calendar = calendar ?? eventStore.defaultCalendarForNewReminders()
        reminder.priority = priority
        reminder.notes = notes

        if let dueDate = dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: dueDate
            )
        }

        try eventStore.save(reminder, commit: true)

        return reminder
    }
}
```

### Fetching Reminders

Since `fetchReminders(matching:completion:)` uses a completion handler, wrap it with async/await:

```swift
extension CalendarViewModel {

    /// Fetches all reminders
    func fetchAllReminders() async -> [EKReminder] {
        let calendars = eventStore.calendars(for: .reminder)
        let predicate = eventStore.predicateForReminders(in: calendars)

        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }

    /// Fetches incomplete reminders
    func fetchIncompleteReminders() async -> [EKReminder] {
        let calendars = eventStore.calendars(for: .reminder)
        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: calendars
        )

        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }

    /// Fetches completed reminders
    func fetchCompletedReminders(
        from startDate: Date? = nil,
        to endDate: Date? = nil
    ) async -> [EKReminder] {
        let calendars = eventStore.calendars(for: .reminder)
        let predicate = eventStore.predicateForCompletedReminders(
            withCompletionDateStarting: startDate,
            ending: endDate,
            calendars: calendars
        )

        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }

    /// Fetches reminders due within a date range
    func fetchReminders(dueBetween startDate: Date, and endDate: Date) async -> [EKReminder] {
        let calendars = eventStore.calendars(for: .reminder)
        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: startDate,
            ending: endDate,
            calendars: calendars
        )

        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }
}
```

### Updating Reminders

```swift
extension CalendarViewModel {

    /// Marks a reminder as complete or incomplete
    func toggleReminderCompletion(_ reminder: EKReminder) throws {
        reminder.isCompleted.toggle()
        if reminder.isCompleted {
            reminder.completionDate = Date()
        } else {
            reminder.completionDate = nil
        }
        try eventStore.save(reminder, commit: true)
    }

    /// Updates a reminder
    func updateReminder(
        _ reminder: EKReminder,
        title: String? = nil,
        dueDate: Date? = nil,
        priority: Int? = nil,
        notes: String? = nil
    ) throws {
        if let title = title {
            reminder.title = title
        }
        if let dueDate = dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: dueDate
            )
        }
        if let priority = priority {
            reminder.priority = priority
        }
        if let notes = notes {
            reminder.notes = notes
        }

        try eventStore.save(reminder, commit: true)
    }
}
```

### Deleting Reminders

```swift
extension CalendarViewModel {

    /// Deletes a reminder
    func deleteReminder(_ reminder: EKReminder) throws {
        try eventStore.remove(reminder, commit: true)
    }
}
```

### Reminder Priority Values

| Priority | Meaning |
|----------|---------|
| 0 | None |
| 1-4 | High |
| 5 | Medium |
| 6-9 | Low |

---

## Recurring Events and Rules

### EKRecurrenceRule Basics

```swift
extension CalendarViewModel {

    /// Creates a daily recurring event
    func createDailyRecurrence(
        interval: Int = 1,
        endAfterOccurrences count: Int? = nil
    ) -> EKRecurrenceRule {
        let end: EKRecurrenceEnd? = count.map { .init(occurrenceCount: $0) }
        return EKRecurrenceRule(
            recurrenceWith: .daily,
            interval: interval,
            end: end
        )
    }

    /// Creates a weekly recurring event
    func createWeeklyRecurrence(
        interval: Int = 1,
        daysOfWeek: [EKRecurrenceDayOfWeek]? = nil,
        endDate: Date? = nil
    ) -> EKRecurrenceRule {
        let end: EKRecurrenceEnd? = endDate.map { .init(end: $0) }
        return EKRecurrenceRule(
            recurrenceWith: .weekly,
            interval: interval,
            daysOfTheWeek: daysOfWeek,
            daysOfTheMonth: nil,
            monthsOfTheYear: nil,
            weeksOfTheYear: nil,
            daysOfTheYear: nil,
            setPositions: nil,
            end: end
        )
    }

    /// Creates a monthly recurring event
    func createMonthlyRecurrence(
        interval: Int = 1,
        daysOfMonth: [NSNumber]? = nil,
        endDate: Date? = nil
    ) -> EKRecurrenceRule {
        let end: EKRecurrenceEnd? = endDate.map { .init(end: $0) }
        return EKRecurrenceRule(
            recurrenceWith: .monthly,
            interval: interval,
            daysOfTheWeek: nil,
            daysOfTheMonth: daysOfMonth,
            monthsOfTheYear: nil,
            weeksOfTheYear: nil,
            daysOfTheYear: nil,
            setPositions: nil,
            end: end
        )
    }

    /// Creates a yearly recurring event
    func createYearlyRecurrence(
        interval: Int = 1,
        monthsOfYear: [NSNumber]? = nil,
        endDate: Date? = nil
    ) -> EKRecurrenceRule {
        let end: EKRecurrenceEnd? = endDate.map { .init(end: $0) }
        return EKRecurrenceRule(
            recurrenceWith: .yearly,
            interval: interval,
            daysOfTheWeek: nil,
            daysOfTheMonth: nil,
            monthsOfTheYear: monthsOfYear,
            weeksOfTheYear: nil,
            daysOfTheYear: nil,
            setPositions: nil,
            end: end
        )
    }
}
```

### Recurrence Examples

```swift
// Every day
let daily = EKRecurrenceRule(
    recurrenceWith: .daily,
    interval: 1,
    end: nil
)

// Every 2 weeks on Monday and Wednesday
let biweeklyMondayWednesday = EKRecurrenceRule(
    recurrenceWith: .weekly,
    interval: 2,
    daysOfTheWeek: [
        EKRecurrenceDayOfWeek(.monday),
        EKRecurrenceDayOfWeek(.wednesday)
    ],
    daysOfTheMonth: nil,
    monthsOfTheYear: nil,
    weeksOfTheYear: nil,
    daysOfTheYear: nil,
    setPositions: nil,
    end: nil
)

// First Monday of every month
let firstMondayMonthly = EKRecurrenceRule(
    recurrenceWith: .monthly,
    interval: 1,
    daysOfTheWeek: [EKRecurrenceDayOfWeek(.monday)],
    daysOfTheMonth: nil,
    monthsOfTheYear: nil,
    weeksOfTheYear: nil,
    daysOfTheYear: nil,
    setPositions: [1],  // First occurrence
    end: nil
)

// Last day of every month
let lastDayMonthly = EKRecurrenceRule(
    recurrenceWith: .monthly,
    interval: 1,
    daysOfTheWeek: nil,
    daysOfTheMonth: [-1],  // -1 = last day
    monthsOfTheYear: nil,
    weeksOfTheYear: nil,
    daysOfTheYear: nil,
    setPositions: nil,
    end: nil
)

// Every year on January 1st, ends after 10 occurrences
let yearlyNewYear = EKRecurrenceRule(
    recurrenceWith: .yearly,
    interval: 1,
    end: EKRecurrenceEnd(occurrenceCount: 10)
)
```

### Adding Recurrence to Events

```swift
extension CalendarViewModel {

    /// Creates a recurring event
    func createRecurringEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        recurrenceRule: EKRecurrenceRule
    ) throws -> EKEvent {
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.calendar = eventStore.defaultCalendarForNewEvents
        event.addRecurrenceRule(recurrenceRule)

        try eventStore.save(event, span: .thisEvent)

        return event
    }
}
```

### Adding Recurrence to Reminders

```swift
extension CalendarViewModel {

    /// Creates a recurring reminder
    func createRecurringReminder(
        title: String,
        dueDate: Date,
        recurrenceRule: EKRecurrenceRule
    ) throws -> EKReminder {
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.dueDateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: dueDate
        )
        reminder.calendar = eventStore.defaultCalendarForNewReminders()
        reminder.addRecurrenceRule(recurrenceRule)

        try eventStore.save(reminder, commit: true)

        return reminder
    }
}
```

---

## Alarms

### Time-Based Alarms

```swift
extension CalendarViewModel {

    /// Creates an alarm with absolute date
    func createAlarm(at date: Date) -> EKAlarm {
        EKAlarm(absoluteDate: date)
    }

    /// Creates an alarm with relative offset (seconds before event)
    func createAlarm(minutesBefore minutes: Int) -> EKAlarm {
        EKAlarm(relativeOffset: TimeInterval(-minutes * 60))
    }

    /// Common alarm presets
    func createAlarm(preset: AlarmPreset) -> EKAlarm {
        EKAlarm(relativeOffset: preset.offset)
    }
}

enum AlarmPreset {
    case atTime
    case fiveMinutesBefore
    case tenMinutesBefore
    case fifteenMinutesBefore
    case thirtyMinutesBefore
    case oneHourBefore
    case twoHoursBefore
    case oneDayBefore
    case twoDaysBefore
    case oneWeekBefore

    var offset: TimeInterval {
        switch self {
        case .atTime: return 0
        case .fiveMinutesBefore: return -5 * 60
        case .tenMinutesBefore: return -10 * 60
        case .fifteenMinutesBefore: return -15 * 60
        case .thirtyMinutesBefore: return -30 * 60
        case .oneHourBefore: return -60 * 60
        case .twoHoursBefore: return -2 * 60 * 60
        case .oneDayBefore: return -24 * 60 * 60
        case .twoDaysBefore: return -2 * 24 * 60 * 60
        case .oneWeekBefore: return -7 * 24 * 60 * 60
        }
    }
}
```

### Location-Based Alarms

```swift
import CoreLocation

extension CalendarViewModel {

    /// Creates a location-based alarm
    func createLocationAlarm(
        title: String,
        latitude: Double,
        longitude: Double,
        radius: Double = 100,
        proximity: EKAlarmProximity
    ) -> EKAlarm {
        let alarm = EKAlarm()

        let location = CLLocation(latitude: latitude, longitude: longitude)
        let structuredLocation = EKStructuredLocation(title: title)
        structuredLocation.geoLocation = location
        structuredLocation.radius = radius

        alarm.structuredLocation = structuredLocation
        alarm.proximity = proximity

        return alarm
    }
}
```

### Alarm Proximity Options

| Proximity | Description |
|-----------|-------------|
| `.none` | No location trigger |
| `.enter` | Triggers when entering the location |
| `.leave` | Triggers when leaving the location |

### Adding Alarms to Events/Reminders

```swift
// Add alarm to event
let event = EKEvent(eventStore: eventStore)
event.title = "Meeting"
event.startDate = Date()
event.endDate = Date().addingTimeInterval(3600)
event.addAlarm(EKAlarm(relativeOffset: -15 * 60))  // 15 minutes before

// Add alarm to reminder
let reminder = EKReminder(eventStore: eventStore)
reminder.title = "Pick up groceries"
reminder.addAlarm(EKAlarm(relativeOffset: 0))  // At due time
```

---

## EventKitUI for Native UI

EventKitUI provides native view controllers for creating and editing events. Since these are UIKit view controllers, wrap them using `UIViewControllerRepresentable`.

### EKEventEditViewController (Create/Edit Events)

```swift
import SwiftUI
import EventKitUI

struct EventEditView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    let eventStore: EKEventStore
    var event: EKEvent?
    var onEventSaved: ((EKEvent) -> Void)?

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let controller = EKEventEditViewController()
        controller.eventStore = eventStore
        controller.event = event ?? EKEvent(eventStore: eventStore)
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: EKEventEditViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, EKEventEditViewDelegate {
        let parent: EventEditView

        init(_ parent: EventEditView) {
            self.parent = parent
        }

        func eventEditViewController(
            _ controller: EKEventEditViewController,
            didCompleteWith action: EKEventEditViewAction
        ) {
            if action == .saved, let event = controller.event {
                parent.onEventSaved?(event)
            }
            parent.dismiss()
        }
    }
}

// Usage
struct ContentView: View {
    @State private var showEventEditor = false
    @State private var eventStore = EKEventStore()

    var body: some View {
        Button("Add Event") {
            showEventEditor = true
        }
        .sheet(isPresented: $showEventEditor) {
            EventEditView(eventStore: eventStore) { savedEvent in
                print("Event saved: \(savedEvent.title ?? "")")
            }
        }
    }
}
```

### EKEventViewController (View Event Details)

```swift
import SwiftUI
import EventKitUI

struct EventDetailView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    let event: EKEvent
    var allowsEditing: Bool = true
    var allowsCalendarPreview: Bool = true

    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = EKEventViewController()
        controller.event = event
        controller.allowsEditing = allowsEditing
        controller.allowsCalendarPreview = allowsCalendarPreview
        controller.delegate = context.coordinator

        return UINavigationController(rootViewController: controller)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, EKEventViewDelegate {
        let parent: EventDetailView

        init(_ parent: EventDetailView) {
            self.parent = parent
        }

        func eventViewController(
            _ controller: EKEventViewController,
            didCompleteWith action: EKEventViewAction
        ) {
            parent.dismiss()
        }
    }
}
```

### EKCalendarChooser (Select Calendars)

```swift
import SwiftUI
import EventKitUI

struct CalendarChooserView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    let eventStore: EKEventStore
    let entityType: EKEntityType
    @Binding var selectedCalendars: Set<EKCalendar>

    func makeUIViewController(context: Context) -> UINavigationController {
        let chooser = EKCalendarChooser(
            selectionStyle: .multiple,
            displayStyle: .allCalendars,
            entityType: entityType,
            eventStore: eventStore
        )
        chooser.selectedCalendars = selectedCalendars
        chooser.delegate = context.coordinator
        chooser.showsDoneButton = true
        chooser.showsCancelButton = true

        return UINavigationController(rootViewController: chooser)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, EKCalendarChooserDelegate {
        let parent: CalendarChooserView

        init(_ parent: CalendarChooserView) {
            self.parent = parent
        }

        func calendarChooserDidFinish(_ calendarChooser: EKCalendarChooser) {
            parent.selectedCalendars = calendarChooser.selectedCalendars
            parent.dismiss()
        }

        func calendarChooserDidCancel(_ calendarChooser: EKCalendarChooser) {
            parent.dismiss()
        }
    }
}
```

### iOS 17+ Write-Only Access (No Permission Dialog)

Starting with iOS 17, you can use `EKEventEditViewController` to add events without requesting calendar access first. The user will see the event editor and can save directly to their calendar.

```swift
struct QuickEventAddView: View {
    @State private var showEventEditor = false
    @State private var eventStore = EKEventStore()

    var body: some View {
        Button("Add to Calendar") {
            showEventEditor = true
        }
        .sheet(isPresented: $showEventEditor) {
            // No permission request needed for iOS 17+
            EventEditView(eventStore: eventStore)
        }
    }
}
```

---

## iOS 18/26 Considerations

### Authorization Changes (iOS 17+)

iOS 17 introduced new authorization methods that replace the deprecated ones:

| Deprecated (iOS 16 and earlier) | New (iOS 17+) |
|--------------------------------|---------------|
| `requestAccess(to: .event)` | `requestFullAccessToEvents()` |
| `requestAccess(to: .reminder)` | `requestFullAccessToReminders()` |
| N/A | `requestWriteOnlyAccessToEvents()` |

### Info.plist Key Changes

| Deprecated Key | New Key (iOS 17+) |
|----------------|-------------------|
| `NSCalendarsUsageDescription` | `NSCalendarsFullAccessUsageDescription` or `NSCalendarsWriteOnlyAccessUsageDescription` |
| `NSRemindersUsageDescription` | `NSRemindersFullAccessUsageDescription` |

### Write-Only Access (iOS 17+)

Apps that only need to add events (not read existing ones) can request write-only access, which provides a better privacy experience:

```swift
// Request write-only access
let granted = try await eventStore.requestWriteOnlyAccessToEvents()
```

### Liquid Glass Design (iOS 26+)

When presenting EventKitUI view controllers in iOS 26+, they will automatically adopt the Liquid Glass design language. Ensure your app's navigation and presentation styles are compatible.

### Best Practices for iOS 18+

1. **Request minimum necessary permissions** - Use write-only access when you only need to add events
2. **Handle authorization status changes** - Listen for `.EKEventStoreChanged` notifications
3. **Support background refresh** - Events may change while your app is backgrounded
4. **Test on real devices** - Calendar and reminder access requires real device testing

---

## Common Use Cases

### 1. Event Booking System

```swift
@Observable
@MainActor
final class BookingManager {
    private let eventStore = EKEventStore()

    func bookAppointment(
        title: String,
        date: Date,
        duration: TimeInterval,
        notes: String?
    ) async throws -> String {
        let granted = try await eventStore.requestFullAccessToEvents()
        guard granted else {
            throw EventKitError.saveFailed
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = date
        event.endDate = date.addingTimeInterval(duration)
        event.notes = notes
        event.calendar = eventStore.defaultCalendarForNewEvents

        // Add reminder 1 hour before
        event.addAlarm(EKAlarm(relativeOffset: -3600))

        try eventStore.save(event, span: .thisEvent)

        return event.eventIdentifier
    }
}
```

### 2. Task Management App

```swift
@Observable
@MainActor
final class TaskManager {
    private let eventStore = EKEventStore()
    var tasks: [EKReminder] = []

    func loadTasks() async {
        let granted = try? await eventStore.requestFullAccessToReminders()
        guard granted == true else { return }

        let calendars = eventStore.calendars(for: .reminder)
        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: calendars
        )

        tasks = await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }

    func addTask(title: String, dueDate: Date?, priority: Int) throws {
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.priority = priority
        reminder.calendar = eventStore.defaultCalendarForNewReminders()

        if let dueDate = dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: dueDate
            )
            reminder.addAlarm(EKAlarm(relativeOffset: 0))
        }

        try eventStore.save(reminder, commit: true)
    }

    func completeTask(_ reminder: EKReminder) throws {
        reminder.isCompleted = true
        reminder.completionDate = Date()
        try eventStore.save(reminder, commit: true)
    }
}
```

### 3. Recurring Event Scheduler

```swift
@Observable
@MainActor
final class RecurringEventManager {
    private let eventStore = EKEventStore()

    func scheduleWeeklyMeeting(
        title: String,
        dayOfWeek: EKWeekday,
        hour: Int,
        minute: Int,
        duration: TimeInterval
    ) throws -> EKEvent {
        let calendar = Calendar.current

        // Find next occurrence of the day
        var components = DateComponents()
        components.weekday = dayOfWeek.rawValue
        components.hour = hour
        components.minute = minute

        guard let startDate = calendar.nextDate(
            after: Date(),
            matching: components,
            matchingPolicy: .nextTime
        ) else {
            throw EventKitError.saveFailed
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = startDate.addingTimeInterval(duration)
        event.calendar = eventStore.defaultCalendarForNewEvents

        // Add weekly recurrence
        let rule = EKRecurrenceRule(
            recurrenceWith: .weekly,
            interval: 1,
            daysOfTheWeek: [EKRecurrenceDayOfWeek(dayOfWeek)],
            daysOfTheMonth: nil,
            monthsOfTheYear: nil,
            weeksOfTheYear: nil,
            daysOfTheYear: nil,
            setPositions: nil,
            end: nil
        )
        event.addRecurrenceRule(rule)

        try eventStore.save(event, span: .thisEvent)

        return event
    }
}
```

### 4. Calendar Sync Service

```swift
@Observable
@MainActor
final class CalendarSyncService {
    private let eventStore = EKEventStore()
    private var customCalendarIdentifier: String?

    func setupSyncCalendar(name: String) throws {
        // Check if calendar already exists
        if let identifier = UserDefaults.standard.string(forKey: "syncCalendarId"),
           let _ = eventStore.calendar(withIdentifier: identifier) {
            customCalendarIdentifier = identifier
            return
        }

        // Create new calendar
        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = name
        calendar.cgColor = UIColor.systemBlue.cgColor

        if let source = eventStore.sources.first(where: { $0.sourceType == .local }) {
            calendar.source = source
        }

        try eventStore.saveCalendar(calendar, commit: true)

        customCalendarIdentifier = calendar.calendarIdentifier
        UserDefaults.standard.set(calendar.calendarIdentifier, forKey: "syncCalendarId")
    }

    func syncEvents(_ externalEvents: [ExternalEvent]) async throws {
        guard let identifier = customCalendarIdentifier,
              let calendar = eventStore.calendar(withIdentifier: identifier) else {
            throw EventKitError.calendarNotFound
        }

        for externalEvent in externalEvents {
            let event = EKEvent(eventStore: eventStore)
            event.title = externalEvent.title
            event.startDate = externalEvent.startDate
            event.endDate = externalEvent.endDate
            event.notes = externalEvent.description
            event.calendar = calendar

            try eventStore.save(event, span: .thisEvent)
        }
    }
}

struct ExternalEvent {
    let title: String
    let startDate: Date
    let endDate: Date
    let description: String?
}
```

---

## Best Practices

### 1. Single EKEventStore Instance

Creating `EKEventStore` is expensive. Create one instance and reuse it throughout your app.

```swift
// Good
@Observable
@MainActor
final class CalendarManager {
    let eventStore = EKEventStore()  // Single instance
}

// Bad - Don't create multiple instances
func fetchEvents() {
    let store = EKEventStore()  // Expensive!
    // ...
}
```

### 2. Listen for Database Changes

```swift
@Observable
@MainActor
final class CalendarManager {
    private let eventStore = EKEventStore()
    private var observer: Any?

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshData()
            }
        }
    }

    private func refreshData() async {
        // Refresh your cached events/reminders
    }
}
```

### 3. Handle Authorization Gracefully

```swift
struct CalendarAccessView: View {
    @Environment(CalendarManager.self) private var manager

    var body: some View {
        Group {
            switch manager.authorizationStatus {
            case .notDetermined:
                requestAccessView
            case .denied, .restricted:
                deniedAccessView
            case .fullAccess, .writeOnly:
                calendarContentView
            @unknown default:
                EmptyView()
            }
        }
    }

    private var deniedAccessView: some View {
        ContentUnavailableView(
            "Calendar Access Denied",
            systemImage: "calendar.badge.exclamationmark",
            description: Text("Please enable calendar access in Settings.")
        ) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        }
    }
}
```

### 4. Use Predicates Efficiently

```swift
// Good - Specific date range
let predicate = eventStore.predicateForEvents(
    withStart: Date(),
    end: Date().addingTimeInterval(86400 * 30),  // 30 days
    calendars: selectedCalendars
)

// Bad - Too broad, may return too many results
let predicate = eventStore.predicateForEvents(
    withStart: Date.distantPast,
    end: Date.distantFuture,
    calendars: nil
)
```

### 5. Batch Operations

```swift
// Good - Batch multiple saves
func saveMultipleEvents(_ events: [EventData]) throws {
    for eventData in events {
        let event = EKEvent(eventStore: eventStore)
        event.title = eventData.title
        event.startDate = eventData.startDate
        event.endDate = eventData.endDate
        event.calendar = eventStore.defaultCalendarForNewEvents

        try eventStore.save(event, span: .thisEvent, commit: false)
    }
    try eventStore.commit()  // Single commit at the end
}

// Bad - Commit on every save
func saveMultipleEventsBad(_ events: [EventData]) throws {
    for eventData in events {
        let event = EKEvent(eventStore: eventStore)
        // ...
        try eventStore.save(event, span: .thisEvent)  // Commits each time
    }
}
```

### 6. Error Handling

```swift
enum CalendarError: LocalizedError {
    case accessDenied
    case calendarNotFound
    case saveFailed(underlying: Error)
    case fetchFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Calendar access was denied"
        case .calendarNotFound:
            return "The specified calendar could not be found"
        case .saveFailed(let error):
            return "Failed to save: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch events: \(error.localizedDescription)"
        }
    }
}
```

### 7. Testing Considerations

```swift
// Create a protocol for testability
protocol EventStoreProtocol {
    func requestFullAccessToEvents() async throws -> Bool
    func calendars(for entityType: EKEntityType) -> [EKCalendar]
    func save(_ event: EKEvent, span: EKSpan) throws
}

extension EKEventStore: EventStoreProtocol {}

// Mock for testing
class MockEventStore: EventStoreProtocol {
    var shouldGrantAccess = true
    var mockCalendars: [EKCalendar] = []
    var savedEvents: [EKEvent] = []

    func requestFullAccessToEvents() async throws -> Bool {
        shouldGrantAccess
    }

    func calendars(for entityType: EKEntityType) -> [EKCalendar] {
        mockCalendars
    }

    func save(_ event: EKEvent, span: EKSpan) throws {
        savedEvents.append(event)
    }
}
```

---

## Quick Reference

### Required Info.plist Keys

```xml
<!-- Calendar Full Access (iOS 17+) -->
<key>NSCalendarsFullAccessUsageDescription</key>
<string>Your reason here</string>

<!-- Calendar Write-Only Access (iOS 17+) -->
<key>NSCalendarsWriteOnlyAccessUsageDescription</key>
<string>Your reason here</string>

<!-- Reminders Full Access (iOS 17+) -->
<key>NSRemindersFullAccessUsageDescription</key>
<string>Your reason here</string>
```

### Common Patterns

```swift
// Request access
let granted = try await eventStore.requestFullAccessToEvents()

// Fetch events
let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: calendars)
let events = eventStore.events(matching: predicate)

// Create event
let event = EKEvent(eventStore: eventStore)
event.title = "Meeting"
event.startDate = Date()
event.endDate = Date().addingTimeInterval(3600)
try eventStore.save(event, span: .thisEvent)

// Delete event
try eventStore.remove(event, span: .thisEvent)

// Fetch reminders (async wrapper)
let reminders = await withCheckedContinuation { continuation in
    eventStore.fetchReminders(matching: predicate) { reminders in
        continuation.resume(returning: reminders ?? [])
    }
}
```

### Recurrence Frequency Options

| Frequency | Usage |
|-----------|-------|
| `.daily` | Every X days |
| `.weekly` | Every X weeks |
| `.monthly` | Every X months |
| `.yearly` | Every X years |

---

## Additional Resources

- [EventKit - Apple Developer Documentation](https://developer.apple.com/documentation/eventkit)
- [EKEventStore - Apple Developer Documentation](https://developer.apple.com/documentation/eventkit/ekeventstore)
- [EKEvent - Apple Developer Documentation](https://developer.apple.com/documentation/eventkit/ekevent)
- [EKReminder - Apple Developer Documentation](https://developer.apple.com/documentation/eventkit/ekreminder)
- [EKRecurrenceRule - Apple Developer Documentation](https://developer.apple.com/documentation/eventkit/ekrecurrencerule)
- [EventKitUI - Apple Developer Documentation](https://developer.apple.com/documentation/eventkitui)

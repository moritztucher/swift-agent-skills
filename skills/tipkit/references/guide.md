# TipKit Guide for iOS Development

A comprehensive guide for using Apple's TipKit framework in iOS 17+ apps with SwiftUI.

**Created:** February 2026
**iOS Version:** iOS 17+ (iOS 18+ for iCloud sync)
**Framework:** TipKit

---

## Table of Contents

1. [Overview](#overview)
2. [Setup and Configuration](#setup-and-configuration)
3. [Creating Tips](#creating-tips)
4. [Displaying Tips](#displaying-tips)
5. [Display Rules](#display-rules)
6. [Events](#events)
7. [Tip Actions](#tip-actions)
8. [Managing Tip State](#managing-tip-state)
9. [Testing and Debugging](#testing-and-debugging)
10. [Best Practices](#best-practices)
11. [Common Pitfalls](#common-pitfalls)
12. [iOS Version Compatibility](#ios-version-compatibility)

---

## Overview

TipKit is Apple's framework for displaying contextual tips that help users discover features in your app. Use TipKit for:

- **Feature Discovery** - Highlight new or hidden features
- **User Education** - Teach users how to accomplish tasks
- **Onboarding** - Guide new users through your app
- **Contextual Help** - Provide tips based on user behavior

### Key Concepts

| Concept | Description |
|---------|-------------|
| **Tip** | Protocol defining tip content and eligibility rules |
| **TipView** | Inline view displaying a tip |
| **popoverTip** | Modifier for popover-style tips attached to UI elements |
| **Rules** | Conditions determining when tips appear |
| **Events** | User actions that can trigger tip eligibility |

### Import

```swift
import TipKit
```

---

## Setup and Configuration

### Basic Configuration

Configure TipKit once at app launch, typically in your `App` struct:

```swift
import SwiftUI
import TipKit

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    try? Tips.configure()
                }
        }
    }
}
```

### Configuration Options

```swift
try? Tips.configure([
    // Display frequency control
    .displayFrequency(.immediate),

    // Data store location (useful for App Groups)
    .datastoreLocation(.applicationDefault)
])
```

### Display Frequency Options

Control how often tips can appear:

```swift
// Tips appear immediately when eligible
.displayFrequency(.immediate)

// Only one tip per day maximum
.displayFrequency(.daily)

// Only one tip per week maximum
.displayFrequency(.weekly)

// Only one tip per month maximum
.displayFrequency(.monthly)

// Custom interval (e.g., every 2 hours)
.displayFrequency(.hourly(2))
```

### Data Store Locations

```swift
// Default app container
.datastoreLocation(.applicationDefault)

// App Group container (for widget/extension sharing)
.datastoreLocation(.groupContainer(identifier: "group.com.company.app"))

// Custom URL
.datastoreLocation(.url(customURL))
```

### Configuration for App Groups

When sharing tips between your app and extensions:

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    try? Tips.configure([
                        .displayFrequency(.immediate),
                        .datastoreLocation(.groupContainer(identifier: "group.com.company.app"))
                    ])
                }
        }
    }
}
```

---

## Creating Tips

### Basic Tip

Conform to the `Tip` protocol:

```swift
struct FavoriteTip: Tip {
    var title: Text {
        Text("Add to Favorites")
    }

    var message: Text? {
        Text("Tap the heart icon to save items you love.")
    }
}
```

### Tip with Image

```swift
struct ShareTip: Tip {
    var title: Text {
        Text("Share with Friends")
    }

    var message: Text? {
        Text("Share your progress with friends using the share button.")
    }

    var image: Image? {
        Image(systemName: "square.and.arrow.up")
    }
}
```

### Tip with Asset Catalog Image

```swift
struct PremiumFeatureTip: Tip {
    var title: Text {
        Text("Unlock Premium")
    }

    var message: Text? {
        Text("Get access to exclusive features.")
    }

    var image: Image? {
        Image("premium-badge") // Asset catalog image
    }
}
```

**Note:** Apple recommends avoiding images for popover tips since the popover already points to the relevant UI element.

---

## Displaying Tips

### Inline Tips with TipView

Display tips as inline views that adjust layout:

```swift
struct ContentView: View {
    let favoriteTip = FavoriteTip()

    var body: some View {
        VStack {
            TipView(favoriteTip)

            // Your content
            ItemListView()
        }
    }
}
```

### Popover Tips

Attach tips as popovers to UI elements:

```swift
struct ItemRow: View {
    let shareTip = ShareTip()

    var body: some View {
        HStack {
            Text("Item Name")
            Spacer()
            Button {
                // Share action
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .popoverTip(shareTip)
        }
    }
}
```

### Popover Arrow Direction

Control where the popover arrow points:

```swift
Button {
    // Action
} label: {
    Image(systemName: "star")
}
.popoverTip(favoriteTip, arrowEdge: .bottom)
```

Available arrow edges: `.top`, `.bottom`, `.leading`, `.trailing`

### Customizing TipView Appearance

```swift
TipView(favoriteTip) { action in
    // Handle action button taps
    if action.id == "learn-more" {
        showLearnMoreSheet = true
    }
}
.tipBackground(Color.blue.opacity(0.1))
.tipCornerRadius(12)
```

### TipViewStyle

Create custom tip view styles:

```swift
struct MyTipViewStyle: TipViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                configuration.image?
                    .foregroundStyle(.blue)
                configuration.title
                    .font(.headline)
            }

            configuration.message?
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Dismiss button
            Button("Got it") {
                configuration.tip.invalidate(reason: .actionPerformed)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// Usage
TipView(favoriteTip)
    .tipViewStyle(MyTipViewStyle())
```

---

## Display Rules

Rules determine when a tip becomes eligible to display.

### Parameter-Based Rules

Use `@Parameter` to create rules based on app state:

```swift
struct FavoriteTip: Tip {
    // Parameter that tracks state
    @Parameter
    static var hasViewedItems: Bool = false

    var title: Text {
        Text("Save Your Favorites")
    }

    var message: Text? {
        Text("Tap the heart to save items.")
    }

    // Tip shows only when parameter is true
    var rules: [Rule] {
        #Rule(Self.$hasViewedItems) { $0 == true }
    }
}
```

Update the parameter from your app:

```swift
struct ItemDetailView: View {
    var body: some View {
        VStack {
            // Content
        }
        .onAppear {
            // Mark that user has viewed items
            FavoriteTip.hasViewedItems = true
        }
    }
}
```

### Multiple Parameter Rules

```swift
struct AdvancedSearchTip: Tip {
    @Parameter
    static var searchCount: Int = 0

    @Parameter
    static var hasUsedBasicSearch: Bool = false

    var title: Text {
        Text("Try Advanced Search")
    }

    var message: Text? {
        Text("Filter results by date, category, and more.")
    }

    // Both conditions must be met
    var rules: [Rule] {
        #Rule(Self.$searchCount) { $0 >= 3 }
        #Rule(Self.$hasUsedBasicSearch) { $0 == true }
    }
}
```

### Event-Based Rules

Track user actions with events:

```swift
struct ExportTip: Tip {
    // Define an event
    static let documentCreatedEvent = Event(id: "documentCreated")

    var title: Text {
        Text("Export Your Work")
    }

    var message: Text? {
        Text("Export documents as PDF or share with others.")
    }

    var rules: [Rule] {
        // Show after user creates 3 documents
        #Rule(Self.documentCreatedEvent) { event in
            event.donations.count >= 3
        }
    }
}
```

Donate to the event when actions occur:

```swift
struct DocumentCreationView: View {
    func createDocument() async {
        // Create document logic...

        // Record the event
        await ExportTip.documentCreatedEvent.donate()
    }
}
```

### Time-Based Event Rules

```swift
struct WeeklyReviewTip: Tip {
    static let appLaunchEvent = Event(id: "appLaunch")

    var title: Text {
        Text("Weekly Review Available")
    }

    var message: Text? {
        Text("See your progress from the past week.")
    }

    var rules: [Rule] {
        // Show if user launched app at least 5 times in the past week
        #Rule(Self.appLaunchEvent) { event in
            event.donations.filter { donation in
                donation.date > Date.now.addingTimeInterval(-7 * 24 * 60 * 60)
            }.count >= 5
        }
    }
}
```

### Combining Parameter and Event Rules

```swift
struct ProFeatureTip: Tip {
    @Parameter
    static var isPremiumUser: Bool = false

    static let featureUsedEvent = Event(id: "basicFeatureUsed")

    var title: Text {
        Text("Unlock Pro Features")
    }

    var message: Text? {
        Text("Upgrade to access advanced capabilities.")
    }

    var rules: [Rule] {
        // User is not premium AND has used basic features 5+ times
        #Rule(Self.$isPremiumUser) { $0 == false }
        #Rule(Self.featureUsedEvent) { $0.donations.count >= 5 }
    }
}
```

---

## Events

Events track user interactions that influence tip eligibility.

### Defining Events

```swift
struct MyFeatureTip: Tip {
    // Simple event
    static let buttonTappedEvent = Event(id: "buttonTapped")

    // Events should have unique, descriptive IDs
    static let itemPurchasedEvent = Event(id: "itemPurchased")
    static let profileViewedEvent = Event(id: "profileViewed")

    var title: Text { Text("My Tip") }

    var rules: [Rule] {
        #Rule(Self.buttonTappedEvent) { $0.donations.count >= 1 }
    }
}
```

### Donating Events

```swift
// Async donation
await MyFeatureTip.buttonTappedEvent.donate()

// In a Button action
Button("Tap Me") {
    Task {
        await MyFeatureTip.buttonTappedEvent.donate()
    }
}

// In a Task
.task {
    await MyFeatureTip.buttonTappedEvent.donate()
}
```

### Event Donation with Metadata

For more complex tracking (iOS 18+):

```swift
struct DetailedTip: Tip {
    struct PurchaseInfo: Codable, Sendable {
        let category: String
        let amount: Double
    }

    static let purchaseEvent = Event<PurchaseInfo>(id: "purchase")

    var rules: [Rule] {
        #Rule(Self.purchaseEvent) { event in
            // Filter by metadata
            let expensivePurchases = event.donations.filter { $0.amount > 50 }
            return expensivePurchases.count >= 2
        }
    }
}

// Donate with metadata
await DetailedTip.purchaseEvent.donate(
    DetailedTip.PurchaseInfo(category: "Electronics", amount: 99.99)
)
```

---

## Tip Actions

Add interactive buttons to tips:

### Defining Actions

```swift
struct OnboardingTip: Tip {
    var title: Text {
        Text("Welcome to the App")
    }

    var message: Text? {
        Text("Let us show you around.")
    }

    var actions: [Action] {
        Action(id: "start-tour", title: "Start Tour")
        Action(id: "skip", title: "Skip")
    }
}
```

### Handling Action Taps

```swift
struct ContentView: View {
    let onboardingTip = OnboardingTip()
    @State private var showTour = false

    var body: some View {
        VStack {
            TipView(onboardingTip) { action in
                switch action.id {
                case "start-tour":
                    showTour = true
                    onboardingTip.invalidate(reason: .actionPerformed)
                case "skip":
                    onboardingTip.invalidate(reason: .actionPerformed)
                default:
                    break
                }
            }

            // Main content
        }
        .sheet(isPresented: $showTour) {
            TourView()
        }
    }
}
```

### Action with System Image

```swift
var actions: [Action] {
    Action(id: "learn-more", title: "Learn More", image: Image(systemName: "info.circle"))
}
```

---

## Managing Tip State

### Invalidating Tips

Mark tips as no longer needed:

```swift
let myTip = MyTip()

// User performed the suggested action
myTip.invalidate(reason: .actionPerformed)

// User dismissed the tip
myTip.invalidate(reason: .tipClosed)

// Maximum display count reached (handled automatically)
// .maxDisplayCountExceeded
```

### Checking Tip Status

```swift
struct ConditionalTipView: View {
    let myTip = MyTip()

    var body: some View {
        VStack {
            // Only show section if tip is still valid
            switch myTip.status {
            case .available:
                TipView(myTip)
            case .invalidated(let reason):
                // Tip was invalidated
                EmptyView()
            case .pending:
                // Rules not yet satisfied
                EmptyView()
            }
        }
    }
}
```

### Programmatic Status Check

```swift
if myTip.status == .available {
    // Tip can be shown
}

// Check specific invalidation reason
if case .invalidated(let reason) = myTip.status {
    switch reason {
    case .actionPerformed:
        print("User completed the action")
    case .tipClosed:
        print("User dismissed the tip")
    case .maxDisplayCountExceeded:
        print("Shown too many times")
    }
}
```

### Maximum Display Count

Limit how many times a tip appears:

```swift
struct LimitedTip: Tip {
    var title: Text {
        Text("Did You Know?")
    }

    var message: Text? {
        Text("Double-tap to zoom.")
    }

    // Show maximum 3 times
    var options: [TipOption] {
        MaxDisplayCount(3)
    }
}
```

### Ignoring Display Frequency

Override global frequency for important tips:

```swift
struct CriticalTip: Tip {
    var title: Text {
        Text("Security Update Required")
    }

    // Ignore the global display frequency setting
    var options: [TipOption] {
        IgnoresDisplayFrequency(true)
    }
}
```

---

## Testing and Debugging

### Reset All Tips (Debug Only)

```swift
#if DEBUG
try? Tips.resetDatastore()
#endif
```

### Show All Tips Immediately (Debug)

```swift
#if DEBUG
try? Tips.configure([
    .displayFrequency(.immediate)
])

// Force all tips to show
Tips.showAllTipsForTesting()
#endif
```

### Show Specific Tips for Testing

```swift
#if DEBUG
Tips.showTipsForTesting([MyTip.self, AnotherTip.self])
#endif
```

### Hide All Tips for Testing

```swift
#if DEBUG
Tips.hideAllTipsForTesting()
#endif
```

### Debug Configuration

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    #if DEBUG
                    // Reset tips during development
                    try? Tips.resetDatastore()
                    #endif

                    try? Tips.configure([
                        .displayFrequency(.immediate)
                    ])
                }
        }
    }
}
```

### Preview Testing

```swift
#Preview {
    ContentView()
        .task {
            try? Tips.resetDatastore()
            try? Tips.configure()
        }
}
```

---

## Best Practices

### 1. Use Tips Sparingly

Apple recommends tips for:
- New or hidden features users might miss
- Non-obvious functionality
- Features that significantly improve workflow

Avoid tips for:
- Obvious UI elements
- Every feature in your app
- Marketing messages

### 2. Make Tips Actionable

```swift
// Good - Specific and actionable
struct GoodTip: Tip {
    var title: Text { Text("Pin Important Items") }
    var message: Text? { Text("Long press any item to pin it to the top of your list.") }
}

// Bad - Vague and not actionable
struct BadTip: Tip {
    var title: Text { Text("Welcome!") }
    var message: Text? { Text("We hope you enjoy our app.") }
}
```

### 3. Keep Tips Short

- Title: 3-5 words maximum
- Message: 1-2 sentences
- Focus on the single most important thing

### 4. Use Appropriate Timing

```swift
struct WellTimedTip: Tip {
    static let viewedItemsEvent = Event(id: "viewedItems")

    var rules: [Rule] {
        // Show after user has explored a bit
        #Rule(Self.viewedItemsEvent) { $0.donations.count >= 5 }
    }
}
```

### 5. Avoid Images in Popovers

Popover tips already point to UI elements, so images are redundant:

```swift
// Good for inline TipView
struct InlineTip: Tip {
    var title: Text { Text("Organize Your Library") }
    var message: Text? { Text("Create folders to keep items organized.") }
    var image: Image? { Image(systemName: "folder") }
}

// Good for popover - no image needed
struct PopoverTip: Tip {
    var title: Text { Text("Share This") }
    var message: Text? { Text("Send to friends via Messages or Mail.") }
    // No image - popover points to the share button
}
```

### 6. Group Related Tips Logically

```swift
// Feature-specific tip file
// Tips/EditorTips.swift

struct BoldTextTip: Tip {
    var title: Text { Text("Bold Text") }
    var message: Text? { Text("Select text and tap B to make it bold.") }
}

struct UndoTip: Tip {
    var title: Text { Text("Undo Changes") }
    var message: Text? { Text("Shake your device or use the undo button.") }
}
```

### 7. Respect User Choices

If a user dismisses a tip, do not show it again:

```swift
// TipKit handles this automatically
// Tips invalidated with .tipClosed won't reappear
```

---

## Common Pitfalls

### 1. Forgetting to Configure TipKit

```swift
// WRONG - Tips won't work
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
            // Missing Tips.configure()!
        }
    }
}

// CORRECT
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    try? Tips.configure()
                }
        }
    }
}
```

### 2. Too Aggressive Display Frequency

```swift
// Can overwhelm users
.displayFrequency(.immediate) // Every tip shows immediately

// Better for production
.displayFrequency(.daily) // At most one tip per day
```

### 3. Not Invalidating Tips After Action

```swift
// WRONG - Tip keeps appearing
Button("Do the thing") {
    performAction()
    // Forgot to invalidate!
}
.popoverTip(myTip)

// CORRECT
Button("Do the thing") {
    performAction()
    myTip.invalidate(reason: .actionPerformed)
}
.popoverTip(myTip)
```

### 4. Rules That Never Evaluate to True

```swift
// WRONG - Tip will never show (contradictory rules)
var rules: [Rule] {
    #Rule(Self.$value) { $0 > 10 }
    #Rule(Self.$value) { $0 < 5 }
}
```

### 5. Creating Tips in View Body

```swift
// WRONG - Creates new tip instance every render
var body: some View {
    TipView(MyTip()) // Bad!
}

// CORRECT - Store as property
let myTip = MyTip()

var body: some View {
    TipView(myTip)
}
```

### 6. Forgetting @Parameter is Static

```swift
struct MyTip: Tip {
    // CORRECT - @Parameter must be static
    @Parameter
    static var hasSeenFeature: Bool = false

    // WRONG - Won't compile
    // @Parameter
    // var hasSeenFeature: Bool = false
}
```

### 7. Not Resetting Tips During Development

```swift
// Add to your debug scheme
#if DEBUG
.task {
    try? Tips.resetDatastore()
    try? Tips.configure([.displayFrequency(.immediate)])
}
#endif
```

---

## iOS Version Compatibility

### iOS 17 (Minimum)

All core TipKit features:
- `Tip` protocol
- `TipView` and `popoverTip`
- `@Parameter` and `Event`
- Rules with `#Rule` macro
- `Tips.configure()`
- Display frequency control

### iOS 18

Additional features:
- **iCloud Sync**: Tip state syncs across devices with same Apple ID
- **Event metadata**: Attach custom `Codable` data to events
- Improved SwiftUI integration

```swift
// iOS 18+ iCloud sync is automatic when:
// 1. User is signed into iCloud
// 2. App has iCloud capability
// 3. Using default data store location
```

### Checking Availability

```swift
// TipKit requires iOS 17+
if #available(iOS 17, *) {
    TipView(myTip)
} else {
    // Fallback or nothing
}
```

### Conditional Compilation

```swift
#if canImport(TipKit)
import TipKit

struct MyTip: Tip {
    var title: Text { Text("My Tip") }
}
#endif
```

---

## Complete Example

Here is a full example combining multiple TipKit features:

```swift
import SwiftUI
import TipKit

// MARK: - Tips

struct FavoritesTip: Tip {
    @Parameter
    static var hasViewedItems: Bool = false

    static let itemViewedEvent = Event(id: "itemViewed")

    var title: Text {
        Text("Save Your Favorites")
    }

    var message: Text? {
        Text("Tap the heart icon to save items for quick access.")
    }

    var image: Image? {
        Image(systemName: "heart")
    }

    var rules: [Rule] {
        #Rule(Self.$hasViewedItems) { $0 == true }
        #Rule(Self.itemViewedEvent) { $0.donations.count >= 3 }
    }

    var options: [TipOption] {
        MaxDisplayCount(3)
    }
}

struct ShareTip: Tip {
    var title: Text {
        Text("Share with Friends")
    }

    var message: Text? {
        Text("Send items to friends via Messages or Mail.")
    }

    var actions: [Action] {
        Action(id: "share-now", title: "Share Now")
    }
}

// MARK: - App

@main
struct TipKitExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    #if DEBUG
                    try? Tips.resetDatastore()
                    #endif

                    try? Tips.configure([
                        .displayFrequency(.daily)
                    ])
                }
        }
    }
}

// MARK: - Views

struct ContentView: View {
    let favoritesTip = FavoritesTip()

    var body: some View {
        NavigationStack {
            VStack {
                // Inline tip at top
                TipView(favoritesTip)

                List {
                    ForEach(1...10, id: \.self) { index in
                        NavigationLink {
                            ItemDetailView(itemId: index)
                        } label: {
                            Text("Item \(index)")
                        }
                    }
                }
            }
            .navigationTitle("My Items")
        }
    }
}

struct ItemDetailView: View {
    let itemId: Int
    let shareTip = ShareTip()

    @State private var isFavorite = false

    var body: some View {
        VStack {
            Text("Item \(itemId) Details")
                .font(.title)

            Spacer()

            HStack {
                Button {
                    isFavorite.toggle()
                    if isFavorite {
                        // Invalidate tip when user favorites
                        FavoritesTip().invalidate(reason: .actionPerformed)
                    }
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.title2)
                }

                Button {
                    shareItem()
                    shareTip.invalidate(reason: .actionPerformed)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title2)
                }
                .popoverTip(shareTip, arrowEdge: .bottom)
            }
            .padding()
        }
        .task {
            // Track item view
            await FavoritesTip.itemViewedEvent.donate()
            FavoritesTip.hasViewedItems = true
        }
    }

    private func shareItem() {
        // Share implementation
    }
}
```

---

## Resources

- [Apple TipKit Documentation](https://developer.apple.com/documentation/tipkit/)
- [WWDC23: Make features discoverable with TipKit](https://developer.apple.com/videos/play/wwdc2023/10229)
- [Human Interface Guidelines: Offering Help](https://developer.apple.com/design/human-interface-guidelines/offering-help)

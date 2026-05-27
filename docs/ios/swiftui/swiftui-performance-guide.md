# SwiftUI Performance Optimization

*Best Practices for Building Efficient SwiftUI Applications*

---

## Executive Summary

This document summarizes key performance optimization techniques for SwiftUI applications, covering view architecture, data dependencies, diffing strategies, initialization patterns, and view identity management. These practices are essential for building responsive, efficient iOS applications.

---

## 1. Breaking Up SwiftUI Views

### Key Insight

**Breaking up SwiftUI views has no inherent performance cost.** This is a fundamental principle that enables better code organization without sacrificing efficiency.

### Why This Works

- **Lightweight Value Types:** SwiftUI views are structs, which are allocated on the stack rather than the heap. This makes them extremely fast to create and destroy.

- **Descriptive Nature:** Views describe UI structure rather than directly managing rendered content. They act as blueprints that SwiftUI uses to determine what to render.

- **Targeted Updates:** Smaller, focused views help SwiftUI make more precise decisions about which views need updating, resulting in more targeted and efficient updates.

### Best Practice

Extract view components into separate structs whenever it improves code readability or when a component can be reused. The view hierarchy depth does not negatively impact performance.

---

## 2. Minimizing View Data Dependencies

### Core Principle

Views should only depend on data they actually use. Instead of making the entire `var body` complex, extract portions into separate `struct` views with minimal dependencies.

### @Observable vs ObservableObject (iOS 17+)

**Prefer @Observable over ObservableObject for more fine-grained updates.**

| ObservableObject | @Observable (iOS 17+) |
|------------------|----------------------|
| When ANY @Published property changes, the ENTIRE view body is re-evaluated | Only views that READ the specific changed property are re-evaluated |
| Requires @Published, @StateObject, @ObservedObject | All stored properties automatically observable; simplified syntax |
| Coarse-grained reactivity | Fine-grained reactivity with property-level tracking |

### Migration Note

When migrating from ObservableObject to @Observable, use `@State` instead of `@StateObject`. Be aware that @State initializers are called on every view rebuild (though SwiftUI preserves the original value), which can have implications for objects with side effects in their initializers.

### Property-Level Tracking Example

```swift
@Observable class Book {
    var title = "Sample"      // Reading this creates dependency on title only
    var isAvailable = true    // Changes here won't trigger update if not read
}

struct BookView: View {
    var book: Book  // No wrapper needed with @Observable

    var body: some View {
        // Only updates when book.title changes
        // Changes to book.isAvailable are ignored
        Text(book.title)
    }
}
```

---

## 3. SwiftUI View Update Process

Understanding the update process helps optimize performance decisions:

1. **Produce a new value for the view** – SwiftUI creates a new instance of the view struct

2. **Update all dynamic properties** – Properties like @State, @Binding, @Environment are updated

3. **Decide whether body needs re-evaluation** – SwiftUI compares the old and new view values

4. **Run body to produce children** – Only if necessary, the body property is computed

**Key Insight:** Step 3 is where optimization matters most. Making view values easy to compare allows SwiftUI to skip step 4 more often.

---

## 4. Ensuring View Values Are Easy to Diff

### The Closure Problem

**Avoid passing closures to subviews.** In Swift, closures are neither equatable nor reference comparable. SwiftUI cannot determine if a closure has changed, so it conservatively assumes all closures are new, triggering unnecessary view updates.

*Problematic Pattern:*
```swift
ChildView(onTap: { doSomething() })
```

*Better Alternatives:*
- Pass data and let the child view handle the action
- Use @Binding for two-way communication
- Use Environment values for shared actions
- Create equatable action wrappers with identifiers

### Using EquatableView

When refactoring is not possible, use `EquatableView` or the `.equatable()` modifier to provide custom comparison logic:

- Make your view conform to `Equatable`
- Implement `static func ==` to define meaningful equality
- Apply `.equatable()` modifier or wrap in `EquatableView`

**Note:** Recent SwiftUI versions often detect Equatable conformance automatically, but explicitly using `.equatable()` ensures consistent behavior.

---

## 5. Making View Initialization Cheap

### What to Avoid in View Initializers

- **Task or async operations:** Never start network requests or background tasks in init()
- **API calls:** Data fetching should be deferred
- **Heavy computations:** Complex calculations should happen elsewhere
- **File I/O:** Reading from disk can block the main thread

### The .task Modifier Solution

Move expensive operations to the `.task` modifier:

- Automatically runs when the view appears
- Automatically cancelled when the view disappears
- Runs in an async context, keeping the UI responsive
- Can be tied to specific values with `.task(id:)`

### Practical Example with .task(id:)

```swift
struct UserProfileView: View {
    let userID: String
    @State private var user: User?

    var body: some View {
        ProfileContent(user: user)
            .task(id: userID) {
                // Re-fetches when userID changes
                // Automatically cancels previous fetch
                user = await fetchUser(id: userID)
            }
    }
}
```

### Best Practice

**View initializers should only assign variables.** Any work beyond simple property assignment should be deferred to lifecycle modifiers like `.task` or `.onAppear`.

---

## 6. Keeping View Identity Stable

### Understanding View Identity

SwiftUI uses two types of identity to track views:

- **Structural Identity:** Determined by the view's position in the view hierarchy
- **Explicit Identity:** Set using the `.id()` modifier

### The Problem with if-else

Using `if-else` creates different structural identities for each branch. When the condition changes:

- The view from one branch is destroyed
- A completely new view is created for the other branch
- All state within the destroyed view is lost
- Animations become transitions (fade in/out) rather than smooth property changes

### Recommended Approach

**Move conditions into view modifiers whenever possible:**

*Instead of:*
```swift
if condition {
    Text("Hello").foregroundColor(.red)
} else {
    Text("Hello").foregroundColor(.blue)
}
```

*Use:*
```swift
Text("Hello").foregroundColor(condition ? .red : .blue)
```

### When to Use if-else

Reserve `if-else` for cases where you truly want to **replace one view with a completely different view**, such as showing entirely different content based on a state (loading vs. loaded, logged in vs. logged out).

### Using .id() for Controlled Updates

The `.id()` modifier can force view recreation when needed. When the id value changes, SwiftUI treats it as an entirely new view. Use this intentionally to reset view state or trigger fresh animations.

---

## 7. iOS 26 Liquid Glass Performance

### Key Considerations

Liquid Glass introduces new rendering considerations that affect performance:

**Material Rendering:**
- Glass effects require additional compositing passes
- Avoid stacking multiple glass layers (glass-on-glass)
- Use `.glassBackgroundEffect()` judiciously

**The 3 Cs for Performance:**
1. **Content First:** Glass should frame content, not compete with it
2. **Concentric:** Nested elements share center points (reduces recalculation)
3. **Cohesive:** Unified system reduces redundant effects

**Avoid These Patterns:**
- Multiple overlapping `.ultraThinMaterial` layers
- Animating glass blur radius frequently
- Custom glass implementations over system glass

**Best Practice:**
```swift
// Prefer system glass (optimized)
.toolbarBackgroundVisibility(.automatic, for: .tabBar)

// Use built-in glass sparingly
.glassBackgroundEffect()

// Avoid redundant materials
// DON'T: .background(.ultraThinMaterial).background(.thinMaterial)
```

---

## Summary: The Six Principles

| # | Principle | Key Action |
|---|-----------|------------|
| 1 | Small, lightweight views | Extract components freely; no performance penalty |
| 2 | Minimize dependencies | Use @Observable; pass only needed data |
| 3 | Easy to diff | Avoid closures; use EquatableView when needed |
| 4 | Cheap initialization | Move heavy work to .task modifier |
| 5 | Stable identity | Prefer ternary operators over if-else |
| 6 | Liquid Glass (iOS 26) | Avoid glass-on-glass; use system materials |

---

## Additional Resources

- WWDC21: "Demystify SwiftUI" – View identity fundamentals
- WWDC23: "Discover Observation in SwiftUI" – @Observable deep dive
- WWDC24: "SwiftUI essentials" – Updated patterns
- WWDC25: "Design for Liquid Glass" – iOS 26 material performance
- Apple Documentation: "Migrating from ObservableObject to Observable"
- Use `Self._printChanges()` in body to debug unnecessary view updates
- Xcode Instruments: SwiftUI View Body profiler for identifying bottlenecks

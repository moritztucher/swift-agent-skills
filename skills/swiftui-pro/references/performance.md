# Performance

- When toggling modifier values, prefer ternary expressions over if/else view branching to avoid `_ConditionalContent`, preserve structural identity, and avoid repeatedly recreating underlying platform views.
- Avoid `AnyView` unless absolutely required. Use `@ViewBuilder`, `Group`, or generics instead.
- If a `ScrollView` has an opaque, static, and solid background, prefer to use `scrollContentBackground(.visible)` to improve scroll-edge rendering efficiency.
- It is more efficient to break views up by making dedicated SwiftUI views rather than place them into computed properties or methods. Using `@ViewBuilder` on a property or method does not solve this; breaking views up is strongly preferred.
- Always ensure view initializers are kept as small and simple as possible, avoiding any non-trivial work. Flag any work that can be moved into a `task()` modifier to be run when the view is shown.
- Similarly, assume each view’s `body` property is called frequently – if logic such as sorting or filtering can be moved out of there easily, it should be.
- Avoid creating properties to store formatters such as `DateFormatter` unless they are required. A more natural approach is to use `Text` with a format, like this: `Text(Date.now, format: .dateTime.day().month().year())` or `Text(100, format: .currency(code: "USD"))`.
- Avoid expensive inline transforms in `List`/`ForEach` initializers (e.g. `items.filter { ... }`) when they are repeated often.
- Prefer deriving transformed data from the source-of-truth using `let`, or caching in `@State`. However, do not cache derived collections in `@State` unless you also own explicit invalidation logic to avoid stale UI.
- For large data sets in `ScrollView`, use `LazyVStack`/`LazyHStack`; flag eager stacks with many children.
- Prefer using `task()` over `onAppear()` when doing async work, because it will be cancelled automatically when the view disappears.
- Avoid storing escaping `@ViewBuilder` closures on views when possible; store built view results instead.


## Why decomposition is free

- Breaking up views has no inherent performance cost: views are structs, stack-allocated, and merely describe structure rather than manage rendered content.
- Smaller views with minimal data dependencies let SwiftUI make more targeted update decisions. A view should depend only on the data it actually reads.


## Fine-grained updates with @Observable

- Prefer `@Observable` over `ObservableObject`: with `ObservableObject`, any `@Published` change re-evaluates the entire body; `@Observable` only re-evaluates views that *read* the specific changed property.
- Property-level tracking means reading `book.title` creates a dependency on `title` alone — changes to an unread `book.isAvailable` won't trigger an update.
- When migrating off `ObservableObject`, use `@State`, not `@StateObject`. Note `@State` initializers run on every rebuild (SwiftUI preserves the original value), so avoid side effects in the stored object's `init`.


## Making views easy to diff

- The SwiftUI update sequence is: produce a new view value → update dynamic properties → decide if `body` needs re-evaluating (compare old vs new value) → run `body` only if needed. The comparison step is where optimization pays off — easy-to-diff values let SwiftUI skip `body`.
- Avoid passing closures to subviews: closures are neither equatable nor reference-comparable, so SwiftUI assumes they always changed and updates unnecessarily. Pass data and let the child handle the action, use `@Binding`/`Environment`, or wrap actions in an identified equatable type.
- When refactoring away a closure isn't possible, make the view `Equatable` (implement `static func ==` with meaningful equality) and apply `.equatable()`. Recent SwiftUI often detects `Equatable` automatically, but `.equatable()` makes the behavior explicit.


## Cheap view initialization

- View initializers should only assign properties. Never start tasks, network/API calls, file I/O, or heavy computation in `init()`.
- Defer such work to `task()`; use `task(id:)` to re-run (and auto-cancel the prior run) when a value such as a user ID changes.


## Stable view identity

- SwiftUI tracks views by structural identity (position in the hierarchy) and explicit identity (`.id()`).
- `if`/`else` gives each branch a different structural identity: switching branches destroys one view and creates the other, losing its state and turning property changes into fade transitions. Reserve `if`/`else` for genuinely *different* content (loading vs loaded, logged in vs out).
- Move conditions into modifiers via ternaries (`foregroundStyle(condition ? .red : .blue)`) to preserve identity and animate smoothly.
- Use `.id()` intentionally to force recreation — to reset state or trigger a fresh animation.


## Liquid Glass performance (iOS 26)

- Glass effects add compositing passes. Avoid glass-on-glass layering and stacked materials (e.g. `.background(.ultraThinMaterial).background(.thinMaterial)`).
- Prefer system glass (`.toolbarBackgroundVisibility(.automatic, for: .tabBar)`) over custom implementations; it's optimized. Use `.glassBackgroundEffect()` sparingly.
- Don't animate glass blur radius frequently.


## Debugging updates

- Use `Self._printChanges()` in `body` to find unnecessary re-evaluations, and the Instruments SwiftUI View Body profiler for bottlenecks.

Example:

```swift
// Anti-pattern: stores an escaping closure on the view.
struct CardView<Content: View>: View {
    let content: () -> Content

    var body: some View {
        VStack(alignment: .leading) {
            content()
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 8))
    }
}

// Preferred: store the built view value; the synthesized init handles calling the builder.
struct CardView<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading) {
            content
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 8))
    }
}
```

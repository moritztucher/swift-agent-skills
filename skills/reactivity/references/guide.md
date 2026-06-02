# Reactivity on Apple Platforms — Observation, Combine, async/await

This is the deep reference for the `reactivity` skill. It covers the three reactive
mechanisms Apple ships — the **Observation** framework (`@Observable`), **Combine**, and
**Swift Concurrency** (`async/await`, `AsyncSequence`) — and, most importantly, the
decision of *which one to reach for*. async/await depth lives in the
`swift-concurrency` skill; this guide treats it only as one of the three choices and at
the bridging boundaries.

Currency: checked 2026-06-02 against Apple docs. Observation requires iOS 17 / macOS 14
and is the framework Apple steers new SwiftUI state toward. Combine is stable and fully
supported but receives no new operators; Apple now points new SwiftUI code at Observation
and concurrency. async/await is the baseline for one-shot async work.

---

## 1. The decision framework

Three mechanisms, three jobs. They overlap at the edges, which is exactly where people
pick wrong.

| You need… | Reach for | Why |
|---|---|---|
| SwiftUI view state that re-renders when a model changes | **Observation** (`@Observable`) | Fine-grained tracking; the view only re-renders for properties it actually reads |
| A single async result (network call, disk read, decode) | **async/await** | One-shot; no subscription, no cancellable to store, no operator chain |
| A stream of values you must transform/combine/time over | **Combine** | Operators (`debounce`, `combineLatest`, `removeDuplicates`) and a mature scheduler model |
| A stream you only iterate (no operators) | **AsyncSequence** / `AsyncStream` | Structured-concurrency-native; cancels with the task |
| Legacy `ObservableObject` code you're maintaining | **Combine** (`@Published`) | Already there; migrate to `@Observable` when you touch it |

The litmus test:

- **One value, once → async/await.** If you'd write `let x = await f()`, you do not need
  Combine. A `Future` that fires once and a `Task` are interchangeable; the `Task` is
  simpler and cancels structurally.
- **Many values over time, with transformation/timing/merging → Combine.** Debounced
  search, `combineLatest` of two form fields, throttled scroll telemetry. This is where
  Combine still earns its place.
- **Many values, just iterate → AsyncSequence.** If the only thing you do is
  `for await v in stream`, prefer an `AsyncStream`/`AsyncSequence`; reach into Combine
  only when you need its operators.
- **A view should react to a property → Observation.** Not Combine, not manual
  `objectWillChange`. `@Observable` + reading the property in `body` is the whole
  mechanism.

These are not mutually exclusive in one app. A typical modern app uses `@Observable`
models for view state, `async/await` for the network layer, and Combine only for the one
or two genuinely stream-shaped features (search-as-you-type, live filtering).

---

## 2. Observation (`@Observable`)

The Observation framework (iOS 17+) provides change tracking for Swift types. SwiftUI
adopts it to update views automatically, and you can use the tracking primitive directly
outside SwiftUI.

### 2.1 `@Observable`

```swift
import Observation

@Observable
class LibraryModel {
    var books: [Book] = []
    var searchText = ""
    var isLoading = false

    // Computed properties are tracked too — they depend on the stored
    // properties they read.
    var filteredBooks: [Book] {
        searchText.isEmpty ? books
            : books.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
}
```

The macro rewrites stored properties so that *reads* are registered with the current
tracking context and *writes* notify it. No `@Published`, no `objectWillChange`, no
property-wrapper-per-field.

### 2.2 Using it in SwiftUI

```swift
struct LibraryView: View {
    @State private var model = LibraryModel()   // owns the instance

    var body: some View {
        List(model.filteredBooks) { book in
            Text(book.title)                     // reads filteredBooks → searchText, books
        }
        .searchable(text: $model.searchText)     // @State gives bindings into @Observable
        .overlay { if model.isLoading { ProgressView() } }
    }
}
```

Property-wrapper choice for `@Observable` instances:

| Wrapper | Use when |
|---|---|
| `@State` | The view **owns** and creates the instance (its lifetime matches the view) |
| *(plain `let`/`var`)* | The instance is **passed in** and the view only reads it — no wrapper needed |
| `@Bindable` | A subview needs `$model.property` bindings to a passed-in instance |
| `@Environment` | The instance is injected via `.environment(_:)` |

Note: do **not** wrap an `@Observable` instance in `@ObservedObject` or
`@StateObject` — those are for `ObservableObject`. Passing an `@Observable` object to a
subview needs no wrapper at all unless you need a binding.

### 2.3 The tracking model — why a view does or doesn't re-render

This is the single most misunderstood part. **SwiftUI re-renders a view only when a
property that was *read during the last `body` evaluation* changes.** This is *fine-grained
tracking*, and it differs sharply from `ObservableObject`, where any `@Published` change
re-rendered every observer.

Consequences:

- A property the view never reads in `body` can change all day and the view won't
  re-render. Good for performance, surprising when you expected a refresh.
- Reads inside a computed property count: reading `filteredBooks` (which reads
  `searchText` and `books`) subscribes the view to all three.
- A read behind a branch only counts when that branch executed. If `if showDetails`
  guards the read of `model.detail`, the view isn't subscribed to `detail` until
  `showDetails` is true.
- Mutating a property from outside `body` (e.g., in a `Task`, a callback) re-renders only
  if some view read it. There is no view-wide "object changed" signal anymore.

### 2.4 `@Bindable` — bindings into an `@Observable` model

`@Bindable` produces `Binding`s to the properties of an `@Observable` instance you don't
own. Use it for a subview that edits a passed-in model:

```swift
struct BookEditView: View {
    @Bindable var book: Book          // passed in; we need $book.title

    var body: some View {
        TextField("Title", text: $book.title)
    }
}
```

`@Bindable` is **not** `@Binding`. `@Binding` plumbs a single value down from a parent's
`@State`. `@Bindable` wraps a whole `@Observable` *reference* and lets you derive a binding
to *any* of its properties with the `$` prefix. For an `@Observable` model, reaching for
`@Binding var title: String` to a subview is the wrong tool — pass the model and use
`@Bindable`.

You can also create a local `@Bindable` inline when you only need bindings in part of a
body: `@Bindable var book = book`.

### 2.5 `withObservationTracking(_:onChange:)` — tracking outside SwiftUI

The primitive SwiftUI is built on. It runs a closure, records every observable property
*read* during it, and calls `onChange` **once**, the next time any of those properties is
about to change.

```swift
func render() {
    withObservationTracking {
        for car in cars {
            print(car.name)          // car.name is tracked
        }
    } onChange: {
        print("Schedule renderer.")  // fires once, before the next car.name write
    }
}
```

Key facts:

- `onChange` fires **once and only once**, *before* the change is applied (willSet
  timing). To keep observing, call `withObservationTracking` again inside `onChange`
  (re-arm) — typically you re-render, which re-reads, which re-tracks.
- Only properties *read inside the apply closure* are tracked. `car.needsRepairs` above
  is never read, so changing it does nothing.
- This is the right tool for a custom renderer, a non-SwiftUI observer, or bridging
  `@Observable` state to imperative UIKit/AppKit code.

### 2.6 Migrating from `ObservableObject`

| Before (`ObservableObject`) | After (`@Observable`) |
|---|---|
| `class M: ObservableObject` | `@Observable class M` |
| `@Published var x` | `var x` (plain) |
| `@StateObject private var m = M()` | `@State private var m = M()` |
| `@ObservedObject var m: M` | `var m: M` (no wrapper) |
| `@ObservedObject var m` + needs `$m.x` | `@Bindable var m: M` |
| `@EnvironmentObject var m: M` | `@Environment(M.self) var m` + `.environment(m)` |

```swift
// BEFORE
class Book: ObservableObject, Identifiable {
    @Published var title = "Sample Book Title"
    let id = UUID()
}

// AFTER
@Observable class Book: Identifiable {
    var title = "Sample Book Title"
    let id = UUID()
}
```

Migration footguns:

- Removing `@Published` is usually right, but a property you *don't* want tracked can be
  opted out with `@ObservationIgnored`.
- `@StateObject` → `@State`, **not** `@ObservedObject` → `@State`. The owner becomes
  `@State`; the passed-in reference becomes a plain property.
- Don't leave an `@Observable` object wrapped in `@ObservedObject` — it requires
  `ObservableObject` conformance and will error or silently misbehave.
- The re-render semantics change: `ObservableObject` fired `objectWillChange` for *every*
  `@Published` mutation, re-rendering all observers. `@Observable` only re-renders views
  that read the specific changed property. Code that relied on a coarse "something
  changed" refresh may stop refreshing.

---

## 3. Combine

Combine is a declarative framework for processing values over time. A **publisher**
delivers a sequence of values to **subscribers**. Operators compose into event-processing
chains. Use it when you have a genuine *stream* you need to transform, time, or merge.

### 3.1 The shape of a pipeline

```swift
import Combine

final class SearchModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var results: [Result] = []

    private var cancellables = Set<AnyCancellable>()

    init(service: SearchService) {
        $query
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .filter { $0.count >= 2 }
            .map { service.searchPublisher(for: $0) }   // -> Publisher of Publishers
            .switchToLatest()                            // cancel stale searches
            .receive(on: DispatchQueue.main)             // hop to main before UI
            .assign(to: &$results)                       // assign back into @Published
    }
}
```

This is exactly the kind of feature Combine is *good* at and async/await is awkward at:
debounce + dedupe + cancel-stale + combine. Don't fight it with raw tasks.

### 3.2 `@Published`

`@Published` wraps a property and synthesizes a publisher for it, accessed with the `$`
prefix:

```swift
class Weather {
    @Published var temperature: Double
    init(temperature: Double) { self.temperature = temperature }
}

let weather = Weather(temperature: 20)
cancellable = weather.$temperature.sink { print("Temperature now: \($0)") }
weather.temperature = 25
// Prints:
// Temperature now: 20.0   <- emits the CURRENT value on subscription
// Temperature now: 25.0
```

`@Published` emits the current value immediately on subscription and then every new value
in `willSet` order (you receive the *new* value, but timed at willSet). Note: in modern
SwiftUI, `@Published` only matters if the enclosing type is still an `ObservableObject`.
For new view-state, `@Observable` replaces both.

### 3.3 Subscribers — `sink` and `assign`

```swift
// sink: closure-based. The two-arg form handles completion (and failure).
publisher.sink(
    receiveCompletion: { completion in /* .finished / .failure(err) */ },
    receiveValue: { value in /* … */ }
)
// Single-arg sink is only available when Failure == Never.
neverFailingPublisher.sink { value in /* … */ }

// assign: write each value straight into a property via key path.
publisher.assign(to: \.text, on: label)        // returns AnyCancellable
publisher.assign(to: &$results)                 // into a @Published, no cancellable to store
```

`assign(to:on:)` retains `on:` strongly — assigning to `\.x, on: self` creates a retain
cycle. Prefer `assign(to: &$published)` (no cycle, no stored cancellable) or a `sink` with
`[weak self]`.

### 3.4 `AnyCancellable` and lifecycle — the #1 footgun

A subscription lives exactly as long as its `AnyCancellable`. `sink` and `assign(to:on:)`
*return* an `AnyCancellable`; if you don't keep it, it deallocates at the end of the
statement and the subscription is torn down **immediately** — the pipeline never fires.

```swift
// ❌ Dead on arrival: cancellable deallocates at end of init line.
$query.sink { print($0) }

// ✅ Store it.
$query.sink { print($0) }.store(in: &cancellables)   // cancellables: Set<AnyCancellable>
```

`store(in:)` accepts a `Set<AnyCancellable>` (or array). When the owning object
deallocates, the set deallocates, every `AnyCancellable` is cancelled, and the pipelines
tear down. This is the idiomatic lifecycle: one `Set<AnyCancellable>` property per owner.

### 3.5 Operators worth knowing

| Operator | Does |
|---|---|
| `map { }` / `tryMap { }` | Transform each element (throwing variant for errors) |
| `filter { }` | Drop elements that fail the predicate |
| `removeDuplicates()` | Drop consecutive equal values (needs `Equatable` or a predicate) |
| `debounce(for:scheduler:)` | Emit only after a quiet interval — search-as-you-type |
| `throttle(for:scheduler:latest:)` | Emit at most one per interval (first or latest) |
| `combineLatest(_:)` | Emit a tuple of the latest from each, on any input change |
| `merge(with:)` | Interleave values from same-type publishers |
| `switchToLatest()` | Flatten a publisher-of-publishers, cancelling the previous inner |
| `flatMap { }` | Map each value to a publisher and flatten (no auto-cancel of prior) |
| `scan(_:_:)` | Running accumulation, emitting each intermediate |
| `prepend(_:)` / `append(_:)` | Inject leading/trailing values |

`debounce` vs `throttle`: debounce waits for silence (good for typing); throttle rate-limits
a busy stream (good for scroll/drag telemetry). `combineLatest` requires *every* input to
have emitted at least once before it produces anything.

### 3.6 Schedulers — `receive(on:)` vs `subscribe(on:)`

- `receive(on:)` controls which scheduler **downstream** operators and the subscriber
  run on. Put `.receive(on: DispatchQueue.main)` (or `.receive(on: RunLoop.main)`) **just
  before** any UI-touching `sink`/`assign`. Everything after it runs on main.
- `subscribe(on:)` controls the scheduler used for the **subscription** and upstream work
  (the initial `subscribe`, `request`, and cancel). It does *not* move where values are
  delivered — only `receive(on:)` does that. Use it to start expensive upstream work off
  the main thread.

```swift
expensivePublisher
    .subscribe(on: DispatchQueue.global())   // do upstream work off-main
    .map(transform)
    .receive(on: DispatchQueue.main)         // deliver results on main
    .assign(to: \.value, on: self)
```

A pipeline that updates UI but never calls `receive(on: .main)` will mutate UI off the
main thread — usually a crash or a purple runtime warning.

### 3.7 Bridging Combine ↔ async/await

Apple explicitly positions Combine and `AsyncSequence` as siblings: both produce elements
over time. Combine uses a pull model with a `Subscriber`; concurrency uses
`for await … in`. Bridges in both directions:

**Combine → async:** every publisher exposes `.values`, an `AsyncSequence`:

```swift
for await value in publisher.values {   // iterate a publisher with structured concurrency
    handle(value)
}                                       // loop ends on completion; cancels with the Task
```

This is the clean way to consume a Combine pipeline's *output* from `async` code — you get
the operators on the way in and structured cancellation on the way out, no
`AnyCancellable` to store.

**async → Combine:** wrap a one-shot async call in a `Future` when something downstream
expects a publisher:

```swift
func loadPublisher() -> Future<Data, Error> {
    Future { promise in
        Task {
            do { promise(.success(try await load())) }
            catch { promise(.failure(error)) }
        }
    }
}
```

But note: if the *only* reason for the `Future` is "I have one async value," you almost
certainly don't need Combine at all — call the `async` function directly. Reach for the
bridge only at a real boundary with existing publisher-shaped code.

For the time-based operators (`debounce`, `throttle`, `merge`, `combineLatest`) in the
concurrency world, see `swift-async-algorithms` (the `AsyncAlgorithms` package) — covered
in the `swift-concurrency` skill. If you're already all-in on concurrency, prefer those
over adopting Combine for timing alone.

---

## 4. The "which one" matrix

| Scenario | Mechanism | Notes |
|---|---|---|
| View shows a model property; re-render on change | **Observation** | `@Observable` + read in `body` |
| Subview edits a model property | **Observation** | `@Bindable`, then `$model.prop` |
| Inject a shared model into a subtree | **Observation** | `.environment(model)` + `@Environment(M.self)` |
| Fetch JSON once and show it | **async/await** | `.task { items = await load() }` |
| Pull-to-refresh | **async/await** | `.refreshable { await reload() }` |
| Search-as-you-type (debounce + dedupe + cancel) | **Combine** | `debounce`/`removeDuplicates`/`switchToLatest` |
| Two form fields → enable a button | **Combine** | `combineLatest` → `map` → `assign` |
| Rate-limit scroll/drag telemetry | **Combine** | `throttle` |
| Live stream you only iterate | **AsyncSequence** | `AsyncStream` + `for await` |
| Maintaining legacy `ObservableObject` | **Combine** | migrate to `@Observable` when you touch it |
| Custom non-SwiftUI observer of `@Observable` | **Observation** | `withObservationTracking(_:onChange:)` |
| Consume a Combine pipeline from `async` code | **bridge** | `publisher.values` + `for await` |
| One async value where a publisher is expected | **bridge** | `Future` (or refactor the boundary) |

---

## 5. Quick reference — key types and APIs

**Observation**
- `@Observable` — macro; makes a class's stored properties trackable.
- `@ObservationIgnored` — opt a stored property out of tracking.
- `@Bindable` — bindings to an `@Observable` instance's properties (subviews).
- `withObservationTracking(_ apply:onChange:)` — track reads in `apply`, fire `onChange`
  once before the next change.
- `Observable` protocol — conformance the macro synthesizes.

**SwiftUI wrappers for state**
- `@State` — owns an `@Observable` instance (or value-type state).
- `@Environment(_:)` / `.environment(_:)` — dependency injection of `@Observable`.
- *(legacy)* `@StateObject`, `@ObservedObject`, `@EnvironmentObject` — for
  `ObservableObject` only.

**Combine**
- `Publisher` / `Subscriber` / `Subscription` — core protocols.
- `@Published` — synthesizes a publisher for a property (`$prop`).
- `AnyCancellable` — subscription lifetime token; `.store(in:)` to retain.
- `sink(receiveValue:)` / `sink(receiveCompletion:receiveValue:)` — closure subscriber.
- `assign(to:on:)` (strong ref!) / `assign(to: &$published)` (no cycle).
- Operators: `map`, `tryMap`, `filter`, `removeDuplicates`, `debounce`, `throttle`,
  `combineLatest`, `merge`, `switchToLatest`, `flatMap`, `scan`.
- `receive(on:)` (delivery scheduler) / `subscribe(on:)` (subscription scheduler).
- `Future` — single-value publisher (async → Combine bridge).
- `publisher.values` — `AsyncSequence` view (Combine → async bridge).
- `CurrentValueSubject` / `PassthroughSubject` — imperatively-driven publishers.

**Cross-link:** async/await, `Task`, `AsyncSequence`, `AsyncStream`, actors, `@MainActor`,
and the `AsyncAlgorithms` time operators are all owned by the `swift-concurrency` skill.
This guide stops at the bridge.

---
name: reactivity
description: Choose and implement the right reactivity tool on Apple platforms — the Observation framework (@Observable, @Bindable, withObservationTracking) for SwiftUI state, Combine (Publisher, @Published, sink, assign, AnyCancellable, operators, schedulers) for event streams, and async/await for one-shot work — plus the ObservableObject→@Observable migration. Use when the user mentions Combine, Observation, @Observable, @Published, ObservableObject, publisher, sink, AnyCancellable, @Bindable, reactive, state management, withObservationTracking, or "which one should I use." For async/await, actors, and AsyncSequence mechanics use the swift-concurrency skill.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple Observation + Combine docs via Context7 (/websites/developer_apple)
---

# Reactivity

How an Apple app reacts to changing data, across three tools: the **Observation** framework (`@Observable`) for SwiftUI state, **Combine** for event streams with operators, and **async/await** for one-shot work. The full decision framework, real API for each, the "which one" matrix, and the `ObservableObject → @Observable` migration live in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics. For async/await, actors, `@MainActor`, and `AsyncSequence`/`AsyncStream` mechanics, defer to the `swift-concurrency` skill — this skill only places async/await in the reactivity decision and shows the Combine↔async bridge.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `MODEL` — `observation` (default; `@Observable` for SwiftUI view state) · `combine` (event streams, operator pipelines, framework publishers) · `async-await` (one-shot async work; see `swift-concurrency`).
2. `STATE` — `@Observable` (default for new SwiftUI; plain `var`, no `@Published`) · `ObservableObject-legacy` (maintaining existing `@Published`/`ObservableObject` code).
3. `STREAM` — `none` (no continuous stream; state + one-shot async only) · `combine-pipeline` (a publisher chain with operators/schedulers/cancellables).

## When to use

Building or reviewing any code that decides *how the UI reacts to data*: SwiftUI model state, a Combine pipeline, a choice between `@Observable` and `ObservableObject`, or a migration off `ObservableObject`. Use this skill to pick the tool and avoid the lifecycle/tracking footguns. For the async/await and actor mechanics themselves, use `swift-concurrency` — don't duplicate it here.

## Core rules

- **`@Observable` is the default for SwiftUI state** (iOS 17+). Plain `var`, no `@Published`, no `ObservableObject`. Reach for `ObservableObject` only to maintain existing code or to target pre-iOS 17.
- **Pick by shape:** Observation for *state*, async/await for *work*, Combine for *streams over time*. If a "pipeline" is just `source → transform → assign to state`, it's async/await + `@Observable`, not Combine.
- **A Combine pipeline lives exactly as long as its `AnyCancellable`.** No retained cancellable = the pipeline dies immediately and silently.
- **`@Observable` tracks only properties read in `body`.** Mutating an unread property does not re-render. Derived values must reach a tracked stored property.
- **Touch UI only after `receive(on:)` a main scheduler.** Publishers can emit on any thread.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll make the model `ObservableObject` with `@Published` like always." | For new SwiftUI state the default is `@Observable` (iOS 17+) — plain `var`, fine-grained re-rendering. `ObservableObject` re-renders every observing view on *any* `@Published` change. Use it only for legacy code or pre-iOS 17. |
| "I'll wire up Combine to fetch and assign the result." | If it's `fetch → assign to state → render`, that's async/await + `@Observable` (or a `.task`). Combine earns its weight only for *operators over time* (`debounce`, `combineLatest`) or *publishers you didn't create*. |
| "`sink` is set up, the pipeline works." | A pipeline lives only as long as its `AnyCancellable`. Discard it (e.g. a local in a function) and it deinits immediately, cancelling the subscription — the closure never fires. `.store(in: &cancellables)`. |
| "I mutated the property but the view won't update." | `@Observable` tracks only properties **read in `body`**. An unread property, or a value derived from a non-observable source (global, `UserDefaults`, singleton), produces no re-render. Read the property you display, or store the derived value. |
| "I'll update the label right in the `sink`." | Publishers can emit on background threads (network publishers do). Updating UI off-main is undefined behavior/crash. `receive(on: DispatchQueue.main)` (or `RunLoop.main`) before any UI work. |
| "I'll pass the `@Observable` model into the subview as a `@Binding`." | `@Binding` is for value-typed `State`. For a two-way binding to an `@Observable` reference model use `@Bindable` (`$model.prop`). Likewise `@State` (not `@StateObject`) owns an `@Observable` instance; `@Environment(T.self)` (not `@EnvironmentObject`) reads one. |

## Verification gate

Before shipping reactivity code, confirm every line:

- [ ] State model choice is deliberate: `@Observable` for new SwiftUI state; `ObservableObject` only for legacy/pre-iOS 17 — not mixed in one type.
- [ ] No Combine used where async/await + `@Observable` (or `.task`) would do — Combine is present only for operators over time or framework publishers.
- [ ] Every Combine subscription's `AnyCancellable` is stored (`.store(in:)` or `assign(to: &$x)`); none discarded.
- [ ] Pipelines that touch UI `receive(on:)` a main-thread scheduler first.
- [ ] `sink`/closures capturing `self` while `self` owns the cancellable use `[weak self]` (no retain cycle).
- [ ] `@Observable` views read the displayed property in `body`; derived values reach a tracked stored property (no hidden non-observable inputs).
- [ ] Two-way bindings to `@Observable` models use `@Bindable`; ownership uses `@State` (owned) / `@Environment(T.self)` (injected) — no leftover `@StateObject`/`@ObservedObject`/`@EnvironmentObject`/`@Published` after migration.
- [ ] `Future` used only as a one-shot feed into an existing pipeline (it's eager + cached) — otherwise plain async/await.

## Deep reference

`references/guide.md` — the decision framework, full Observation section (`@Observable`, `@Bindable`, `withObservationTracking`, ownership, computed-property tracking, why a view does/doesn't re-render), full Combine section (publishers, `@Published`, `sink`/`assign`, cancellable lifecycle, operators, schedulers, `Future`, the `.values` async bridge), the `ObservableObject → @Observable` migration, and the "which one" matrix. Load it for any concrete API question. For async/await depth, use the `swift-concurrency` skill.

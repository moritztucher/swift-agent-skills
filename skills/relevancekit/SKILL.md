---
name: relevancekit
description: Make widgets contextually relevant in the watchOS/iOS Smart Stack with RelevanceKit — surface app content at the right time, place, or activity using on-device relevance signals. Use when the user mentions RelevanceKit, relevance, content surfacing, on-device signals, smart suggestions, Smart Stack, relevant widgets, RelevantContext, or WidgetRelevance. Pairs with the `widgetkit` skill (RelevanceKit surfaces a WidgetKit widget) and the `appintents` skill (relevance is keyed by an App Intent configuration).
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple Developer docs via Context7 (/websites/developer_apple — no dedicated RelevanceKit library exists; verified against the broad Apple docs library)
---

# RelevanceKit

On-device relevance signals that tell the watchOS/iOS Smart Stack *when* your widget matters — a specific time, an inferred location, a workout, a sleep window — so the system surfaces it at the right moment instead of leaving it static. RelevanceKit is a thin layer over WidgetKit and App Intents (iOS/watchOS 26.0+). The deep API reference lives in `references/guide.md`; this file is the decision and discipline layer. Read it first, open the guide for specifics.

> **Currency flag — read before coding.** This framework is new and thinly documented; there is no dedicated Context7 RelevanceKit library, only coverage inside the broad Apple docs. The source guide was drafted from a *speculative* API that is wrong in several load-bearing places (see Anti-rationalization). The verified API is pinned in the banner + "Verified examples" section at the top of `references/guide.md`. Trust that banner over any older snippet further down the guide.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `WIDGET_BASE` — `relevance-native` (default; widget is a `RelevanceConfiguration` + `RelevanceEntriesProvider`, only ever shown when relevant) · `timeline-donate` (existing `StaticConfiguration`/`AppIntentConfiguration` timeline widget that donates `RelevantIntent`s via `RelevantIntentManager.shared` to gain Smart Stack visibility). Pick one — they use different provider protocols.
2. `SIGNAL` — which `RelevantContext` clue(s) drive relevance: `date` (time/interval/range, with a `DateKind`) · `location` (`CLRegion` geofence, or `.location(inferred:)` for home/work) · `fitness` · `sleep`. Location signals require location permission.
3. `PLATFORM` — `watch` (Smart Stack on Apple Watch, the primary surface) · `phone-on-watch` (iPhone widgets shown on the watch) · `ios` (iOS 26 contextual surfacing). Affects which families and signals are meaningful.

## When to use

Building or reviewing any widget that should appear *contextually* in the Smart Stack — at a time, place, or activity — rather than sit there always. Reach for `widgetkit` for the widget's view/timeline/families and `appintents` for the configuration intent that keys each relevance attribute; RelevanceKit only adds the "when is this relevant" signal on top. Not for general widget refresh scheduling — that's WidgetKit timelines.

## Core rules

- iOS/watchOS 26.0+ only. Do **not** write `import RelevanceKit` — importing `AppIntents` adds the dependency implicitly.
- The provider's relevance method returns **`WidgetRelevance<Intent>`** (wrap your `[WidgetRelevanceAttribute]` in `WidgetRelevance(_:)`), never a bare array.
- Each relevance is one **`WidgetRelevanceAttribute(configuration:context:)`** — a singular type, one `context:`, no `score:` and no `relevantContexts:` array.
- Relevance must be **specific and bounded**. A clue that's always true (`.distantPast ... .distantFuture`) defeats the system's ranking and gets your widget deprioritized.
- Relevance is a *hint*, not a guarantee or a placement command. The system still ranks against everything else and the user can pin/remove. Never assume your widget is showing.

## Anti-rationalization

These are the real footguns — most come from the framework being new and the source guide's first draft predating the shipping API.

| The rationalization | The reality |
|---|---|
| "The guide shows `relevance() async -> [WidgetRelevanceAttributes]`, so I'll return an array." | Wrong type. The shipping API returns **`WidgetRelevance<Intent>`** and the element type is **`WidgetRelevanceAttribute`** (singular). Wrap your attributes: `return WidgetRelevance(attributes)`. The plural `WidgetRelevanceAttributes` doesn't exist. |
| "I'll pass `relevantContexts: [.date(...), .location(...)]` and a `score:` to rank it." | Neither exists. `WidgetRelevanceAttribute` takes a single `context:` and has no `score:`. Express multiple windows as multiple attributes; ranking is the system's job, not a float you set. |
| "`RelevantContext.location(coord, radius: 500)` and `.sleepSchedule` / `.fitness` like the guide shows." | Verified factories are `location(_ region: CLRegion)` and `location(inferred:)`, plus `fitness(_:)`/`sleep(_:)` that take a `FitnessCondition`/`SleepCondition`. There is no coordinate+radius overload, no `.all([...])`, and `fitness`/`sleep` are functions, not properties. |
| "`.date(DateInterval(...))` is enough." | Most date factories require a `DateKind` hint (`.date(_:kind:)`, `.date(interval:kind:)`, `.date(range:kind:)`) so the system can tell scheduled vs. significant. Drop the kind and you lose ranking signal — use `.date(from:to:)` only when you truly have no kind. |
| "I'll implement `snapshot(for:in:)` on the provider like a timeline widget." | `RelevanceEntriesProvider` has no `snapshot` requirement. Its three members are `relevance()`, `entry(configuration:context:) async throws`, and `placeholder(context:)`. Use `context.isPreview` inside `entry` for gallery data. |
| "It's on-device intelligence, so the widget will definitely appear when I signal it." | A relevance clue only makes the widget *eligible* and feeds ranking. The system weighs it against everything else and the user controls pinning/removal. Don't gate UX on the widget being visible, and refresh signals (`WidgetCenter.reloadTimelines`) when underlying data changes or they go stale. |

## Verification gate

Before shipping RelevanceKit code, confirm every line:

- [ ] No `import RelevanceKit` statement; `AppIntents` is imported instead.
- [ ] `relevance()` returns `WidgetRelevance<Intent>` (attributes wrapped in `WidgetRelevance(_:)`), not an array.
- [ ] Each clue is a `WidgetRelevanceAttribute(configuration:context:)` — singular type, single `context`, no `score`/`relevantContexts`.
- [ ] `RelevantContext` factories match the verified set (`date(...kind:)`, `location(_:CLRegion)`/`location(inferred:)`, `fitness(_:)`, `sleep(_:)`); no coordinate+radius, no `.all`.
- [ ] Date clues carry a `DateKind` where the API expects one; intervals are tight and bounded, never `distantPast...distantFuture`.
- [ ] Provider implements `relevance()`, `entry(configuration:context:) async throws`, `placeholder(context:)` — no stray `snapshot`.
- [ ] Location-based relevance only ships if the app actually holds the matching location permission.
- [ ] Timeline-donate path (if used) calls `RelevantIntentManager.shared.updateRelevantIntents(_:)` on each refresh; native path uses `RelevanceConfiguration`.
- [ ] UX does not assume the widget is on screen; relevance is treated as a hint and signals are refreshed when data changes.

## Deep reference

`references/guide.md` — overview, every `RelevantContext` type, building relevance-native widgets, `RelevanceEntry`/`RelevanceEntriesProvider`, `RelevanceConfiguration`, `WidgetRelevanceAttribute`, WidgetKit integration and intent donation, migration from timeline widgets, and a full Smart Stack example. **Read the currency banner + "Verified examples" at the top first** — older example bodies below it predate the API verification. For the widget's view, families, and timeline mechanics see the `widgetkit` skill; for the configuration intent see `appintents`.

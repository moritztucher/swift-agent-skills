---
name: tipkit
description: Add and review in-app tips with Apple's TipKit — the Tip protocol, rules/events for eligibility, inline TipView, popoverTip, Tips.configure, display frequency, and tip state. Use when the user mentions TipKit, tips, onboarding hints, feature discovery, contextual help, popoverTip, TipView, or surfacing a hint about a feature in an iOS app.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple TipKit docs via Context7 (/websites/developer_apple_tipkit)
---

# TipKit

Contextual in-app tips on Apple platforms (iOS 17+) — feature discovery, education, onboarding hints. The deep API reference — setup, every tip shape, rules vs. events, displaying tips, actions, state, testing, version gating — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `ELIGIBILITY` — `parameter` (`@Parameter` + `#Rule` on app state, e.g. "is premium = false") · `event` (`Event(id:)` + `.donate()` counting user actions, e.g. "used feature 5×") · `both` (parameters AND events combined in one `rules` array).
2. `PRESENTATION` — `inline` (`TipView(tip)` that takes layout space — use an image) · `popover` (`.popoverTip(tip, arrowEdge:)` pointing at a control — no image, the arrow is the pointer).
3. `FREQUENCY` — `immediate` (dev/testing; every eligible tip shows at once) · `daily`/`weekly`/`monthly`/`hourly(n)` (production; throttles ALL tips globally) · per-tip override via `IgnoresDisplayFrequency(true)` for one critical tip.

## When to use

Adding or reviewing any contextual tip, onboarding hint, or feature-discovery callout that uses TipKit. Use tips for non-obvious or hidden features the user might miss — not for obvious UI, not for every feature, and never as a marketing channel. If the goal is a full onboarding flow rather than a single discoverable hint, TipKit is the wrong tool.

## Core rules

- iOS 17+ for all core APIs. Event metadata and iCloud tip-state sync are iOS 18+. iOS 26 is the default target.
- **`Tips.configure()` runs exactly once at launch, before any tip can display** — typically `.task { try? Tips.configure(...) }` on the root view. No configure = no tips, silently.
- `@Parameter` properties must be `static`. Store tip instances as properties; never `TipView(MyTip())` in a `body` — that makes a fresh instance every render.
- Invalidate a tip the moment its action is taken (`tip.invalidate(reason: .actionPerformed)`), or it keeps reappearing.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll call `Tips.configure()` from the view that shows the tip." | Configure once at app launch before any tip evaluates. Calling it late, twice, or per-view means tips silently never appear. One `.task { try? Tips.configure(...) }` at the root. |
| "Rules and events are interchangeable — I'll use whichever." | `#Rule(Self.$param)` evaluates app *state*; `#Rule(Self.someEvent)` counts *donations* over time. State you set; events you must `await ....donate()` at the action site. Pick by intent, don't blur them. |
| "I'll set `.displayFrequency(.daily)` on the tip that's too chatty." | Display frequency is **global**, set once in `Tips.configure` — it throttles every tip in the app, not one. To exempt a single urgent tip use `IgnoresDisplayFrequency(true)` in that tip's `options`; to cap one tip use `MaxDisplayCount(n)`. |
| "My rule references the event, so it'll fire." | An event-rule never advances until you `await Tip.event.donate()` at the action site; a parameter-rule never advances until you assign `Tip.param = …`. Defining the rule alone does nothing — the tip sits `.pending` forever. |
| "Tips are cheap, I'll add one per feature." | Over-tipping trains users to dismiss everything. Reserve tips for non-obvious, high-value, or hidden features; gate them behind rules so they appear *after* the user has context, not on first launch. |
| "It didn't show in the simulator, so my rules are wrong." | The datastore persists dismissals/counts across launches, so a once-shown tip won't return. During dev, `try? Tips.resetDatastore()` before `configure` (DEBUG only), or use `Tips.showAllTipsForTesting()` — don't rewrite correct rules to chase stale state. |

## Verification gate

Before shipping tips, confirm every line:

- [ ] `Tips.configure(...)` is called exactly once, at app launch, before any tip can display.
- [ ] Display frequency is set deliberately in `configure` (not `.immediate` in production unless intended).
- [ ] Every `@Parameter` is `static`; every tip is stored as a property, not constructed inside a `body`.
- [ ] Each event-rule has a matching `await Tip.event.donate()` at the real action site; each parameter-rule has a real assignment that flips it.
- [ ] Every tip is invalidated (`.actionPerformed` / `.tipClosed`) when its action is taken or it's dismissed, so it doesn't reappear.
- [ ] Popover tips omit images; inline `TipView`s use one only when it adds meaning.
- [ ] Per-tip `MaxDisplayCount` / `IgnoresDisplayFrequency` used intentionally, not as a substitute for global frequency.
- [ ] DEBUG-only `resetDatastore()` / testing helpers are gated behind `#if DEBUG` and never ship.

## Deep reference

`references/guide.md` — full setup and configuration options, creating tips (title/message/image/actions), inline vs. popover display, `TipViewStyle`, parameter and event rules, event donation with metadata, managing tip state and status, testing/debugging helpers, best practices, common pitfalls, iOS version compatibility, and a complete worked example. Load it for any concrete API question.

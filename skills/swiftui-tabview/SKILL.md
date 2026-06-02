---
name: swiftui-tabview
description: Build and review SwiftUI TabView, with emphasis on the iOS 26 overhaul — the value-based Tab(_:systemImage:value:) and Tab(role: .search) API, TabSection, TabView(selection:), .tabViewStyle(.sidebarAdaptable)/.page, tabViewBottomAccessory, .tabBarMinimizeBehavior, TabViewCustomization, .badge, and the floating/morphing Liquid Glass tab bar. Use when the user mentions TabView, tab bar, tabs, Tab, TabSection, tabViewBottomAccessory, sidebar adaptable, tab customization, .search tab, or migrating .tabItem. For the glass material on the tab bar use the `liquid-glass` skill; for navigation bar / toolbar chrome use the `swiftui-toolbar` skill alongside this one.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple SwiftUI docs via Context7 (/websites/developer_apple_swiftui)
---

# SwiftUI TabView (iOS 26)

SwiftUI's `TabView` — top-level sibling navigation — and the iOS 26 overhaul that turns the tab bar into a floating, morphing Liquid Glass capsule with a minimize behavior and a bottom-accessory slot. The deep reference (the modern `Tab`/`TabSection` API, selection + programmatic switching, the `.tabItem` migration, the `.sidebarAdaptable`/`.page` styles, the bottom accessory, minimize behavior, the search tab, user customization, badges, iOS 26 glass behavior, fallbacks, accessibility, and a quick reference) lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

> **Currency note (2026-06-02):** new code uses the **value-based `Tab` builder** — `Tab("Title", systemImage:, value:) { … }` — not `.tabItem`/`.tag`. The `Tab` builder, `TabSection`, `.sidebarAdaptable`, and `TabViewCustomization` are **iOS 18+**. `Tab(role: .search)`, `tabViewBottomAccessory(content:)`, `TabViewBottomAccessoryPlacement`, `.tabViewSearchActivation(_:)`, and `.tabBarMinimizeBehavior(_:)` are **iOS 26+**. Verified against Apple's SwiftUI docs.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `API` — `value-Tab` (default for all new code; `Tab("…", systemImage:, value:) { … }` with a typed `selection` binding, plus `TabSection`/roles) · `legacy-tabItem` (only when maintaining iOS 17-or-earlier code that already uses `.tabItem`/`.tag` — don't mix the two in one `TabView`).
2. `STYLE` — `automatic` (default; the platform bar, which is the iOS 26 floating glass capsule on the new SDK) · `sidebarAdaptable` (iOS 18+; adapts to sidebar on iPad/macOS/tvOS — required for `TabSection` grouping and `TabViewCustomization`) · `page` (full-screen swipeable carousel, not a navigation bar).
3. `ACCESSORY` — `none` (default) · `bottom-accessory` (iOS 26+ `tabViewBottomAccessory` — the persistent mini-player slot that docks with the tab bar; render by `\.tabViewBottomAccessoryPlacement`).

## When to use

Building or reviewing any `TabView`: top-level tabs, a search tab, an iPad sidebar-adaptive layout, a mini-player bottom accessory, user-reorderable tabs, or a migration of `.tabItem` code to the modern `Tab` API. For the **glass material** on the iOS 26 bar (and the rule of not fighting system chrome), use `liquid-glass`. For the **navigation/toolbar chrome** around the tabs, use `swiftui-toolbar`. This skill owns the `TabView` API specifically.

## Core rules

- New code uses the **value-based `Tab` builder**, not `.tabItem`/`.tag`. The `value:` and the `TabView(selection:)` binding must be the **same `Hashable` type** — use an `enum`, not bare ints.
- `TabSection` and `TabViewCustomization` only do anything under **`.tabViewStyle(.sidebarAdaptable)`**. Under the plain bar they're inert.
- iOS 26 restyles the bar for free when you build against the SDK — your `Tab` declarations don't change. **Don't fight it** with an opaque/colored tab-bar background or fake bottom padding; let content scroll under the floating glass.
- `tabViewBottomAccessory` is the **mini-player slot**, not a general overlay: one persistent, app-wide accessory that docks with the bar. Adapt it to `\.tabViewBottomAccessoryPlacement` (`.inline` vs `.expanded`).
- `Tab(role: .search)` is a **special** tab (distinct placement + search semantics, paired with `.searchable` and `.tabViewSearchActivation`), at most one per `TabView`.
- iOS 26-only modifiers (`tabViewBottomAccessory`, `.tabBarMinimizeBehavior`, `Tab(role: .search)`, `.tabViewSearchActivation`) need an `if #available(iOS 26, *)` gate when the deployment target is below 26.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll use `.tabItem { Label }.tag()` — it's the SwiftUI tab API." | That's the legacy path. New code uses `Tab("…", systemImage:, value:) { … }`; it can express `TabSection`, `Tab(role: .search)`, and per-tab `customizationID`, and it can't desync label from tag. Reserve `.tabItem` for iOS 17-or-earlier maintenance, and never mix it with `Tab` in one `TabView`. |
| "Selection isn't switching — I'll just toggle some bool." | `TabView(selection:)` only works when the binding's type **exactly matches** every `Tab`'s `value:`. A mismatched/`Optional` type silently never selects. Use one `Hashable` enum for both the state and every `value:`. |
| "`Tab(role: .search)` is just a tab with a magnifying-glass icon." | The search role changes the tab's **placement and behavior** — the system positions it apart and gives it search semantics. Pair it with `.searchable` + `.tabViewSearchActivation(.searchTabSelection)`, and have at most one. It is not a cosmetic icon swap. |
| "`tabViewBottomAccessory` is a handy slot for a banner / promo / toolbar." | It's the **mini-player** slot — one persistent, app-wide accessory that docks with the tab bar and reflows as the bar minimizes. Stuffing arbitrary overlays in it breaks the interaction; render to `\.tabViewBottomAccessoryPlacement` (`.inline`/`.expanded`) instead. |
| "`.sidebarAdaptable` is just a nicer-looking tab style, I'll flip it on." | It **changes layout** on iPad/macOS/tvOS (top bar → sidebar) and is what `TabSection` and `TabViewCustomization` depend on. Verify on iPad and Mac, not just iPhone — it's a structural decision, not a skin. |
| "iOS 26's floating bar looks off — I'll give it a solid background to match my brand." | The system glasses and floats the bar correctly and cohesively on the iOS 26 SDK. An opaque/colored `tabBarBackground` or fake bottom padding fights the morph and the bottom accessory. Adopt the system treatment; let content scroll under it. See `liquid-glass`. |
| "Customization isn't sticking between launches — `TabViewCustomization` is buggy." | It needs all three: an `@AppStorage`-backed `TabViewCustomization`, a **stable, unique `customizationID`** on every tab/section, and `.tabViewCustomization($c)` — under `.sidebarAdaptable`. An index-based, localized, or changed `customizationID` loses the saved layout. |

## Verification gate

Before shipping a `TabView`, confirm every line:

- [ ] New code uses the value-based `Tab` builder; no `.tabItem`/`.tag` mixed in (legacy only for ≤ iOS 17 maintenance).
- [ ] `TabView(selection:)` binding and every `Tab` `value:` are the **same `Hashable` type** (an enum), and programmatic switching works.
- [ ] `TabSection` / `TabViewCustomization` are only relied on under `.tabViewStyle(.sidebarAdaptable)`; sidebar layout verified on iPad/Mac.
- [ ] `Tab(role: .search)` (if used) is the only search tab, paired with `.searchable` + `.tabViewSearchActivation`.
- [ ] `tabViewBottomAccessory` (if used) is a single persistent accessory that renders by `\.tabViewBottomAccessoryPlacement` (`.inline`/`.expanded`), not a random overlay.
- [ ] No opaque/colored tab-bar background or fake bottom padding fighting the iOS 26 floating glass bar; content scrolls under it.
- [ ] `TabViewCustomization` (if used) has `@AppStorage` + a stable unique `customizationID` on every tab/section + `.tabViewCustomization($c)`.
- [ ] iOS 26-only modifiers are gated behind `if #available(iOS 26, *)` if the deployment target is below 26.
- [ ] Tabs have clear text labels (not icon-only); badges are meaningful; large Dynamic Type and Reduce Motion verified.

## Deep reference

`references/guide.md` — overview and platform availability, the modern `Tab`/`TabSection` API, value-based selection and programmatic switching, the `.tabItem` migration table, the `.sidebarAdaptable`/`.page` styles, the bottom accessory and its placement environment, `.tabBarMinimizeBehavior`, the `Tab(role: .search)` tab, user customization (`TabViewCustomization` + `customizationID` + `defaultVisibility`), badges, iOS 26 floating/morphing Liquid Glass behavior, fallbacks for < iOS 26, accessibility, and a quick reference + version cheat sheet. Every code sample uses the verified API.

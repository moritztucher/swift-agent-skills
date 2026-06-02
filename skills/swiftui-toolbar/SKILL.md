---
name: swiftui-toolbar
description: Build and review SwiftUI toolbars — ToolbarContent with ToolbarItem / ToolbarItemGroup, semantic vs positional placements, the bottom bar, custom titles, and the iOS 26 shared-glass grouping (ToolbarSpacer, sharedBackgroundVisibility). Use when the user mentions toolbar, ToolbarItem, ToolbarItemGroup, toolbar placement, ToolbarSpacer, navigation bar buttons, bottom bar, principal title, confirmationAction/cancellationAction, toolbarRole, or sharedBackgroundVisibility. For the keyboard IME candidate strip use `keyboard-accessory`; for the glass material itself use `liquid-glass`; for the tab bar use `swiftui-tabview`.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple SwiftUI docs via Context7 (/websites/developer_apple_swiftui)
---

# SwiftUI Toolbar

SwiftUI's toolbar system: you declare *what* goes in the bar with `ToolbarContent`; the system decides *where* and *how* it renders per platform — and on iOS 26 groups items into shared Liquid Glass capsules. The deep API reference (every placement, `ToolbarSpacer` + shared-glass grouping, visibility/background/colorScheme, role, title menu/display mode, patterns, availability) lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `PLACEMENT` — the scope of placements in play: `semantic` (default; role-based — `.principal`, `.primaryAction`, `.confirmationAction`/`.cancellationAction`, `.navigation` — system positions and styles them) · `positional` (`.topBarLeading`/`.topBarTrailing`/`.bottomBar`, only when a specific edge is genuinely required). Prefer semantic; drop to positional only when no role fits.
2. `GLASS` — iOS 26 shared-capsule behavior: `shared` (default; adjacent items merge into one glass capsule, split groups with `ToolbarSpacer`) · `hidden` (`sharedBackgroundVisibility(.hidden)`, availability-gated — item stands alone with no capsule). The material itself is `liquid-glass`'s domain.
3. `ROLE` — `toolbarRole(_:)`: `default` (`.automatic`/`.navigationStack`) · `editor` (content-editing layout, spreads items on iPad) · `browser` (document/file browsing). Match the screen's job.

## When to use

Building or reviewing any toolbar / navigation-bar / bottom-bar content: action buttons, custom titles, modal confirm/cancel bars, grouped glass clusters, or bar visibility/background work. Explicitly out of scope: for the **keyboard IME candidate strip** (rewrites text as you type) use `keyboard-accessory`; for the **glass material** (`.glassEffect`, `GlassEffectContainer`, glass buttons) use `liquid-glass`; for the **tab bar** use `swiftui-tabview` (here you only toggle it via `for: .tabBar`).

## Core rules

- The `.toolbar { }` closure is `@ToolbarContentBuilder` — it returns `ToolbarContent`, not `View`. Every branch must resolve to a `ToolbarItem` / `ToolbarItemGroup` / `ToolbarSpacer`; put plain views *inside* an item.
- A toolbar needs a bar-rendering container (`NavigationStack` / `TabView`). Navigation-bar placements have nowhere to go without one.
- Placement is semantic first. Use `.principal` / `.primaryAction` / `.confirmationAction` / `.cancellationAction` / `.navigation` for roles; reserve `.topBarLeading`/`.topBarTrailing`/`.bottomBar` for when a specific edge is truly needed.
- One action → `ToolbarItem`. A coherent cluster at one placement → `ToolbarItemGroup`. Distinct clusters → separate groups split by `ToolbarSpacer` (iOS 26).
- Availability-gate the iOS 26 APIs (`ToolbarSpacer`, `sharedBackgroundVisibility`, `DefaultToolbarItem`) behind `if #available(iOS 26.0, *)` if the deployment target is below 26.
- iOS 26 chrome is glassed by the system — don't fight it with an opaque/colored `toolbarBackground` unless the design demands a branded bar (defer to `liquid-glass`).

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll just put everything at `.topBarTrailing` — it's predictable." | Positional placement throws away the system's role handling. Use `.primaryAction`, `.cancellationAction`, `.principal`, `.navigation` so items get the correct edge, emphasis, RTL behavior, and future-proof positioning. Drop to positional only when no role fits. |
| "For my sheet I'll pin a Cancel button at `.topBarLeading` and Done at `.topBarTrailing`." | That re-implements modal styling by hand and gets it wrong. `.cancellationAction` / `.confirmationAction` place the buttons on the right edges, bold the confirm action, and wire the Return key. Use the semantic placements for dialogs. |
| "iOS 26 will lay my toolbar items out fine on its own." | On iOS 26 adjacent items merge into **one shared glass capsule** — your three unrelated buttons smear together. Split logical groups with `ToolbarSpacer(.fixed)`; it inserts space *and* starts a new capsule. |
| "I want this custom status view in the toolbar without the glass pill — I'll restyle it." | Use `sharedBackgroundVisibility(.hidden)` on that `ToolbarItem`: it removes the capsule *and* gives the item its own logical grouping. Restyling the view doesn't escape the shared capsule. (Availability-gate it — iOS 26+.) |
| "My custom segmented title goes at `.topBarTrailing` like the other buttons." | A custom title belongs at `.principal` — center of the nav bar, taking precedence over `navigationTitle`. That's the placement designed for a custom title view. |
| "`.toolbar(.hidden)` will hide the tab bar." | Empty/`automatic` targets a default bar, not the tab bar. Pass the right `ToolbarPlacement`: `.toolbarVisibility(.hidden, for: .tabBar)` (or `.navigationBar`). And `ToolbarPlacement` (the bar) is not `ToolbarItemPlacement` (the item position) — don't confuse the two enums. |
| "`ToolbarSpacer` / `sharedBackgroundVisibility` compile, so they're fine to ship." | They're **iOS 26.0+** only. If the deployment target is below 26 they don't exist on older OSes — gate them behind `if #available(iOS 26.0, *)` (the builder supports it via `buildLimitedAvailability`). |

## Verification gate

Before shipping toolbar code, confirm every line:

- [ ] The `.toolbar { }` closure returns `ToolbarContent` — plain views are wrapped in `ToolbarItem`/`ToolbarItemGroup`, not placed bare.
- [ ] Items use **semantic** placements where a role exists (`.principal`, `.primaryAction`, `.confirmationAction`/`.cancellationAction`, `.navigation`); positional placements only where a specific edge is required.
- [ ] Modal sheets use `.confirmationAction` / `.cancellationAction` (not hand-placed Cancel/Done buttons) — confirm is emphasized, cancel is on the leading edge.
- [ ] Custom title view is at `.principal`.
- [ ] iOS 26: distinct clusters are separated with `ToolbarSpacer`; any item that must escape the shared capsule uses `sharedBackgroundVisibility(.hidden)`.
- [ ] iOS 26 APIs (`ToolbarSpacer`, `sharedBackgroundVisibility`, `DefaultToolbarItem`) are availability-gated when the target is < iOS 26.
- [ ] Bar visibility passes the correct `ToolbarPlacement` (`for: .tabBar` / `.navigationBar`) — not an empty/default call expecting the wrong bar.
- [ ] Toolbar background isn't forced opaque/colored over the system glass unless the design demands it (defer chrome glass to `liquid-glass`).
- [ ] Keyboard IME strips deferred to `keyboard-accessory`; glass material deferred to `liquid-glass`; tab bar to `swiftui-tabview`.

## Deep reference

`references/guide.md` — overview and the result-builder rules, `ToolbarItem` vs `ToolbarItemGroup`, all semantic and positional placements (with when-to-use), `.keyboard` and `.accessoryBar(id:)`, the iOS 26 shared-glass grouping with `ToolbarSpacer` and `sharedBackgroundVisibility`, toolbar visibility / background / colorScheme / foregroundStyle, `toolbarRole`, title menu and display mode, availability gating, common patterns, and a full quick-reference of every type and its minimum version. Every code sample uses the verified API.

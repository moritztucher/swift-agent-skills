---
name: appkit
description: Build and review native macOS apps with AppKit — windows, views, view/window controllers, the responder chain, layer-backed views, SwiftUI interop, and macOS 26 Liquid Glass. Use when the user mentions AppKit, a macOS app, NSWindow, NSView, NSViewController, NSWindowController, NSVisualEffectView, NSGlassEffectView, macOS Liquid Glass, or a Mac Catalyst alternative. For pure SwiftUI app structure use the SwiftUI skills; this is the AppKit layer and its SwiftUI bridge.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple Developer docs via Context7 (/websites/developer_apple), incl. AppKit Updates June 2025
---

# AppKit

Native macOS UI with AppKit — the Mac framework that is *not* UIKit. The deep API reference (windows, view controllers, responder chain, layer backing, controls, animation, SwiftUI interop, common patterns) lives in `references/guide.md`; the macOS 26 Liquid Glass surface (automatic adoption, `NSGlassEffectView`, `NSVisualEffectView`, toolbars, sidebars) lives in `references/liquid-glass.md`. This file is the decision and discipline layer: read it first, open the references for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `UI_STACK` — `swiftui-on-macos` (default for new UI; build in SwiftUI, host with `NSHostingController`/`NSHostingView`) · `hybrid` (SwiftUI islands inside AppKit chrome, or AppKit views wrapped via `NSViewRepresentable`) · `appkit` (pure AppKit — choose only for document apps, deep `NSTableView`/`NSOutlineView`, fine-grained text/`NSResponder` work, or legacy code).
2. `GLASS` — `automatic-macos26` (default; rebuild on the macOS 26 SDK and let standard chrome adopt Liquid Glass) · `explicit-NSGlassEffectView` (custom floating glass surfaces via `NSGlassEffectView` + `NSGlassEffectContainerView`) · `none` (back-deploying below 26, or content layers that must stay opaque).
3. `TARGET_MACOS` — the minimum macOS version (e.g. `26`, `15`, `14`). Gates every API below: Liquid Glass APIs are macOS 26+; `@ViewLoading` is 13.3+; toolbar styles 11+.

## When to use

Building or reviewing any native macOS UI that touches AppKit directly — windows, view controllers, the responder chain, custom drawing/event handling, status-bar/menu-bar apps, document-based apps, or bridging SwiftUI and AppKit. Also when adding Liquid Glass to a Mac app. If the app is pure SwiftUI with no AppKit surface, use the SwiftUI skills instead.

## Core rules

- **AppKit is not UIKit.** `NSWindow` is not an `NSView` subclass; the default coordinate origin is **lower-left**; views are **not** layer-backed by default. Carry UIKit habits over and you will fight the framework.
- **Prefer SwiftUI + `NSHostingController` for new UI.** Reach for raw AppKit only where SwiftUI is genuinely weaker (documents, complex tables/outlines, low-level text and event handling).
- **Own your controllers' lifetimes.** `NSWindowController` / `NSWindow` are not retained for you — keep a strong reference or the window deallocates and vanishes. AppKit windows default to release-on-close.
- **On macOS 26, let glass be automatic.** Rebuilding on the 26 SDK gives standard toolbars, sidebars, sheets, popovers, and window controls Liquid Glass for free. Add `NSGlassEffectView` only for custom floating surfaces; do not sprinkle `NSVisualEffectView` everywhere.
- **Gate every modern API on `TARGET_MACOS`.** `NSGlassEffectView`, `.glass` bezel, `NSBackgroundExtensionView`, etc. are macOS 26+ — wrap in `if #available` / `@available` when the deployment target is lower.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "It worked in UIKit, so `(0,0)` is top-left and my view is layer-backed." | AppKit's default origin is **lower-left** and views are **not** layer-backed. Override `isFlipped` to get top-left coordinates, and set `wantsLayer = true` before touching `layer`. Assuming UIKit defaults silently mis-positions and mis-renders. |
| "I created the `NSWindowController` in a method and showed the window — done." | A locally-scoped controller deallocates at the end of the method and the window disappears. Hold a strong reference (property on the app delegate / owning object) for the window's lifetime. |
| "New screen — I'll hand-build it in AppKit like the old ones." | For new UI, build in SwiftUI and host with `NSHostingController`/`NSHostingView`. Raw AppKit is the right tool only for documents, deep tables/outlines, and low-level text/event work — not general screens. |
| "macOS 26 looks flat, so I'll wrap toolbars and sidebars in `NSVisualEffectView` to force the glass look." | On macOS 26 standard chrome adopts Liquid Glass automatically on rebuild. Manually flooding `NSVisualEffectView` (or stacking it on already-glassy chrome) double-renders material and fights the system. Let it be automatic; style only genuinely custom surfaces. |
| "`NSVisualEffectView` is how you do Liquid Glass on a custom AppKit view." | No — that's the legacy material API. The macOS 26 analog of SwiftUI's `glassEffect()` is **`NSGlassEffectView`** (set its `contentView`), grouped with `NSGlassEffectContainerView` so adjacent glass merges. `NSVisualEffectView` is for plain materials / back-deployment. |
| "These glass APIs are on the SDK, so I can just call them." | They are macOS **26+**. If `TARGET_MACOS` is lower, calling `NSGlassEffectView` / `.glass` bezel unguarded crashes on older systems. Gate with `if #available(macOS 26, *)` and provide a fallback. |

## Verification gate

Before shipping AppKit UI, confirm every line:

- [ ] Coordinate assumptions are explicit: custom views that expect top-left override `isFlipped`; layout doesn't silently rely on the wrong origin.
- [ ] Any view whose `layer` is configured has `wantsLayer = true` set first; layer config happens in `updateLayer()` (with `wantsUpdateLayer`) rather than ad-hoc.
- [ ] Every `NSWindow`/`NSWindowController` shown has a strong owner for its lifetime; no window relies on a local variable.
- [ ] New UI defaults to SwiftUI via `NSHostingController`/`NSHostingView`; raw AppKit is justified (documents, tables/outlines, text/event handling).
- [ ] On macOS 26: standard chrome relies on automatic Liquid Glass; custom glass uses `NSGlassEffectView` (+ `NSGlassEffectContainerView`), not piles of `NSVisualEffectView`; glass is on the navigation layer only, never on content/lists/cards.
- [ ] Every macOS 26-only API (`NSGlassEffectView`, `.glass` bezel, `NSBackgroundExtensionView`, new toolbar styles) is gated on `TARGET_MACOS` with `if #available`/`@available` and a fallback when the target is lower.
- [ ] Responder/action methods use correct AppKit signatures (`@objc`/`@IBAction func name(_ sender:)`); first-responder and key/mouse handling go through the responder chain, not ad-hoc globals.

## Deep reference

- `references/guide.md` — full AppKit reference: UIKit-vs-AppKit differences, windows & `NSWindowController`, views & `NSViewController` lifecycle, responder chain and event handling, layer-backed views, controls, animation, SwiftUI integration (`NSHostingController`/`NSHostingView`/`NSViewRepresentable`), and common patterns (preferences window, document app, menu-bar app). Load it for any concrete base-framework API question.
- `references/liquid-glass.md` — macOS 26 Liquid Glass: automatic adoption on rebuild, SwiftUI `glassEffect`/`GlassEffectContainer`, the AppKit `NSGlassEffectView`/`NSGlassEffectContainerView` surface (with a currency correction noting these supersede `NSVisualEffectView` for custom glass), legacy `NSVisualEffectView` materials, toolbar/sidebar/window glass, button styles, best practices, and a migration guide. Load it for any glass/styling question.

---
name: liquid-glass
description: Adopt and review Apple's iOS 26 Liquid Glass in SwiftUI — the .glassEffect(_:in:) material, GlassEffectContainer batching, glassEffectID morphing, .buttonStyle(.glass)/.glassProminent, backgroundExtensionEffect, scrollEdgeEffectStyle, and toolbar/tab-bar glass. Use when the user mentions Liquid Glass, glass effect, glassEffect, iOS 26 glass, GlassEffectContainer, frosted or translucent material, glass buttons, or glassy toolbars/tab bars. For general SwiftUI structure, state, and performance review use the `swiftui-pro` skill alongside this one.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple SwiftUI docs via Context7 (/websites/developer_apple_swiftui)
---

# Liquid Glass (SwiftUI, iOS 26)

Apple's iOS 26 Liquid Glass material in SwiftUI — a translucent, refractive layer that floats UI above content and morphs as it moves. The deep reference (the 3 Cs, the core `.glassEffect` API, `GlassEffectContainer` batching, `glassEffectID` morphing, glass button styles, background-extension/scroll-edge effects, tab bar & navigation, sheets, animation, common patterns, anti-patterns, fallbacks, accessibility, migration, checklist) lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

> **Currency note (2026-06-02):** the iOS 26 API is **`.glassEffect(_:in:)`** plus `GlassEffectContainer`, `.glassEffectID(_:in:)`, and `.buttonStyle(.glass)` / `.glassProminent`. `.glassBackgroundEffect()` is the **visionOS** modifier — not the iOS API — so never reach for it on iOS. The bundled guide uses the correct `.glassEffect` family throughout, verified against Apple's SwiftUI docs.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `ADOPTION` — `system-default` (default; adopt SDK 26, let the system glass the standard nav bar, tab bar, toolbars, sheets — touch nothing) · `opt-in-effects` (add `.glassEffect`/`.buttonStyle(.glass)` to a few custom floating controls) · `full-custom` (bespoke morphing glass clusters, `glassEffectID`, `glassEffectUnion` — only when the design truly needs it).
2. `CONTAINER_BATCHING` — `single` (one isolated glass element, no container needed) · `container` (default for **two or more** nearby glass elements; wrap them in `GlassEffectContainer(spacing:)` so they render together, share sampling, and can morph). Multiple loose `.glassEffect` views without a container is the #1 perf/visual mistake.
3. `FALLBACK` — `none` (deployment target is iOS 26+, no branch needed) · `graceful` (default when supporting < iOS 26; gate glass behind `if #available(iOS 26, *)` and fall back to `.ultraThinMaterial` / `.regularMaterial` so older OSes stay legible).

## When to use

Building or reviewing any SwiftUI surface that adopts iOS 26 Liquid Glass: glassy custom controls, floating buttons, morphing toolbars, hero headers under a translucent nav bar, or a migration of `.ultraThinMaterial` UI to the new material. Pair with `swiftui-pro` for the surrounding SwiftUI architecture, state, and performance review — this skill owns the glass material specifically.

## Core rules

- iOS 26 modifier is `.glassEffect(_:in:)` (default `.regular`, default shape is the capsule `DefaultGlassEffectShape()`). Buttons use `.buttonStyle(.glass)` / `.glassProminent`. `.glassBackgroundEffect()` is visionOS — do not ship it as the iOS path.
- **Two or more glass elements ⇒ `GlassEffectContainer`.** It batches rendering and is required for morph transitions; `spacing:` controls when neighbouring shapes blend.
- Don't paint glass everywhere. Glass is a *floating layer above content*, not a background fill for whole screens or content cards — overuse destroys legibility and tanks performance.
- Let the system glass the chrome. Adopting SDK 26 already glasses standard nav bars, tab bars, toolbars, and small/medium sheets. Don't hand-roll it or fight it with opaque/coloured `toolbarBackground`.
- Don't hardcode foreground colors over glass. Use semantic styles (`.primary`, `.secondary`, `.tint`) so content stays legible as the backdrop shifts; a fixed `Color.white`/`Color.black` will vanish over the wrong content.
- Honor accessibility: glass already adapts to **Reduce Transparency** and **Increase Contrast**, and morph animations must respect `accessibilityReduceMotion`. Don't reintroduce translucency the user asked the system to remove.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll glass every card, sheet, and section — it looks premium." | Glass is a floating layer *above* content, not a fill. Blanketing the UI kills legibility, flattens hierarchy, and is the fastest way to a sluggish, muddy screen. Glass the few elements that float; leave content opaque. |
| "I'll just slap `.glassEffect()` on each of these five controls." | Multiple loose glass views each sample independently — expensive and visually disjoint, and they can't morph. Wrap nearby glass in one `GlassEffectContainer(spacing:)`; that's what batches rendering and enables the morph. |
| "`.glassBackgroundEffect()` is the Liquid Glass modifier." | That's the **visionOS** modifier. The iOS 26 API is `.glassEffect(_:in:)` + `GlassEffectContainer` + `.buttonStyle(.glass)`. Shipping the visionOS call on iOS is the wrong (often unavailable) path. |
| "Text on glass needs a fixed color so it always reads — I'll set `.white`." | Glass is translucent; the backdrop changes. A hardcoded color disappears over the wrong content. Use semantic foreground styles (`.primary`/`.secondary`/`.tint`) and let the system maintain contrast. |
| "I'll re-skin the nav bar and tab bar to match my brand glass." | SDK 26 already glasses the standard chrome correctly and cohesively. Coloured/opaque `toolbarBackground` and custom tab bars break system cohesion and the morph. Adopt the system treatment first; customize only what genuinely needs it. |
| "Just adopt glass everywhere — iOS 26 is our target anyway." | If the deployment target is < iOS 26, the `.glassEffect` family doesn't exist on older OSes and Reduce Transparency users get nothing. Gate with `if #available(iOS 26, *)` and fall back to `.ultraThinMaterial`; verify with Reduce Transparency on. |

## Verification gate

Before shipping Liquid Glass, confirm every line:

- [ ] iOS path uses `.glassEffect(_:in:)` / `.buttonStyle(.glass)` — **no** `.glassBackgroundEffect()` as the iOS implementation.
- [ ] Every cluster of 2+ glass elements is inside a `GlassEffectContainer`; morphs use `.glassEffectID(_:in:)` with a shared `@Namespace`.
- [ ] Glass is applied only to floating/elevated elements, not to full-screen backgrounds or every content card.
- [ ] Standard nav bar / tab bar / toolbars use the system glass treatment — no opaque or coloured `toolbarBackground` fighting it.
- [ ] No hardcoded foreground colors over glass; content uses semantic styles and stays legible against varied backdrops.
- [ ] Verified with **Reduce Transparency** and **Increase Contrast** on, and morph animations skip under `accessibilityReduceMotion`.
- [ ] If targeting < iOS 26, glass is gated behind `if #available(iOS 26, *)` with an `.ultraThinMaterial`/`.regularMaterial` fallback that's been seen on an older OS.
- [ ] Glass shapes follow concentric corner radii (inner = outer − padding); not animating blur/material on every frame.

## Deep reference

`references/guide.md` — the 3 Cs, when to reach for glass, the core `.glassEffect(_:in:)` API and `Glass` value, shapes, `GlassEffectContainer` batching, `glassEffectID` morphing and `glassEffectUnion`, `.buttonStyle(.glass)`/`.glassProminent`, background-extension and scroll-edge effects, tab bar & navigation, toolbars & sheets, animation, common patterns, anti-patterns, fallbacks for < iOS 26, accessibility, performance, the iOS 18 → 26 migration guide, and the pre-ship checklist. Every code sample uses the correct iOS `.glassEffect` API.

# Liquid Glass Design System — SwiftUI Reference (iOS 26)

This document provides comprehensive guidance for implementing Apple's Liquid Glass design language in SwiftUI applications targeting **iOS 26+**.

The single most important fact: the iOS modifier is **`.glassEffect(_:in:)`** — *not* `.glassBackgroundEffect()`. `.glassBackgroundEffect()` is the **visionOS** modifier (it adds physical 3D depth that influences z-axis layout and is available on visionOS only); do not ship it as the iOS path. Every API in this guide was verified against Apple's SwiftUI documentation.

---

## Table of Contents

1. [Design Philosophy](#design-philosophy)
2. [The 3 Cs Principle](#the-3-cs-principle)
3. [When to Reach for Glass](#when-to-reach-for-glass)
4. [The Core API: `.glassEffect(_:in:)`](#the-core-api-glasseffect_in)
5. [The `Glass` Value](#the-glass-value)
6. [Shapes for Glass](#shapes-for-glass)
7. [`GlassEffectContainer` — Batching](#glasseffectcontainer--batching)
8. [Morphing with `glassEffectID`](#morphing-with-glasseffectid)
9. [`glassEffectUnion` — Merging Shapes](#glasseffectunion--merging-shapes)
10. [Button Styles: `.glass` and `.glassProminent`](#button-styles-glass-and-glassprominent)
11. [Background Extension & Scroll Edge Effects](#background-extension--scroll-edge-effects)
12. [Tab Bar & Navigation](#tab-bar--navigation)
13. [Toolbars & Sheets](#toolbars--sheets)
14. [Animation Integration](#animation-integration)
15. [Common Patterns](#common-patterns)
16. [Anti-Patterns](#anti-patterns)
17. [Fallbacks for < iOS 26](#fallbacks-for--ios-26)
18. [Accessibility](#accessibility)
19. [Performance & Overuse Cautions](#performance--overuse-cautions)
20. [Migration Guide](#migration-guide)
21. [Quick Reference](#quick-reference)

---

## Design Philosophy

Liquid Glass is Apple's visual design language introduced in iOS 26 (2025). It creates a sense of depth and dimensionality through a translucent, refractive layer that floats UI *above* content and morphs as it moves.

### Core Principles

- **Depth Through Translucency:** Glass surfaces refract and reveal hints of the content beneath, creating spatial hierarchy.
- **A Floating Layer, Not a Fill:** Glass sits *above* content as a distinct functional layer (controls, chrome). It is not a background wash for whole screens or content cards.
- **Content Elevation:** Glass serves as a stage for content, never competing with it.
- **Systematic Cohesion:** All glass elements work together as part of a unified visual system; the system already glasses the standard chrome.

---

## The 3 Cs Principle

### 1. Content First

Glass should frame and elevate floating controls, never compete with content.

```swift
// Good: glass on a floating control, content stays opaque and prominent
VStack {
    Text("Main Content")          // opaque, legible content
        .font(.largeTitle)
    DetailView()
}

// floating action sits above the content on glass
Button("Add", systemImage: "plus") { add() }
    .buttonStyle(.glass)

// Bad: glassing the content container itself muddies legibility
VStack {
    Text("Main Content").font(.largeTitle)
    DetailView()
}
.padding()
.glassEffect(in: .rect(cornerRadius: 24))   // content shouldn't live on glass
```

### 2. Concentric

Nested elements share the same center point and have proportional corner radii. The formula: **inner corner = outer corner − padding**.

```swift
let outerCorner: CGFloat = 24
let padding: CGFloat = 8
let innerCorner = outerCorner - padding   // 16

ZStack {
    RoundedRectangle(cornerRadius: outerCorner)
    RoundedRectangle(cornerRadius: innerCorner)
        .padding(padding)
}
```

`ContainerRelativeShape()` adapts a child's shape to its container automatically, keeping corners concentric without manual math:

```swift
VStack { content }
    .padding()
    .containerShape(.rect(cornerRadius: 24))   // declares the container shape
    .overlay { ContainerRelativeShape().stroke() }
```

### 3. Cohesive

UI elements work together as a unified system. Adopting SDK 26 already glasses the standard nav bar, tab bar, toolbars, and small/medium sheets cohesively — let it. Don't fight it with opaque or colored chrome.

```swift
// Good: adopt the system treatment, add nothing
NavigationStack { ContentView() }

// Bad: a colored opaque toolbar breaks system glass cohesion
NavigationStack {
    ContentView()
        .toolbarBackground(Color.blue, for: .navigationBar)
}
```

---

## When to Reach for Glass

Glass is a *floating layer above content*. Reach for it for:

- **Custom floating controls** — a floating action button, a media-controls cluster, a custom segmented control that sits above scrolling content.
- **Custom chrome the system doesn't provide** — a bespoke bottom bar or overlay that needs to feel native alongside the system glass.
- **Morphing control clusters** — a group of controls that expand/collapse and should morph fluidly (see `glassEffectID`).

Do **not** reach for glass for:

- Whole-screen backgrounds or content cards (use opaque surfaces).
- The standard nav bar / tab bar / toolbars — the system already does this.
- Decorative panels with no interactive or floating purpose.

Set your **adoption level** explicitly:

| Level | What it means |
|---|---|
| `system-default` | Adopt SDK 26 and let the system glass standard chrome. Touch nothing. |
| `opt-in-effects` | Add `.glassEffect` / `.buttonStyle(.glass)` to a few custom floating controls. |
| `full-custom` | Bespoke morphing clusters with `glassEffectID` / `glassEffectUnion`. Only when the design truly needs it. |

---

## The Core API: `.glassEffect(_:in:)`

The verified signature:

```swift
nonisolated
func glassEffect(
    _ glass: Glass = .regular,
    in shape: some Shape = DefaultGlassEffectShape()
) -> some View
```

- The default variant is `.regular`.
- The default shape is `DefaultGlassEffectShape()`, which is a **`Capsule`**. The material fills the view's frame *including its padding*, so pad before applying.

```swift
// Default: regular glass in a capsule
Text("Hello, World!")
    .font(.title)
    .padding()
    .glassEffect()

// Custom shape — rounded rect reads better on larger components
Text("Hello, World!")
    .font(.title)
    .padding()
    .glassEffect(in: .rect(cornerRadius: 16.0))

// Tinted + interactive
Text("Hello, World!")
    .font(.title)
    .padding()
    .glassEffect(.regular.tint(.orange).interactive())
```

Guidance from Apple's docs:

- Use a **rounded rectangle** for larger components that would look odd as a capsule or circle; keep one shape vocabulary across your custom components.
- Assign a **tint** to suggest prominence — don't tint everything.
- Add **`.interactive()`** to custom components so they react to touch and pointer the way standard glass buttons do.

---

## The `Glass` Value

`Glass` is a value type you compose. Verified members:

| Member | Effect |
|---|---|
| `.regular` | The standard Liquid Glass material (default). |
| `.clear` | A clearer, more transparent variant. Pair with a dimming backdrop when content legibility is at risk. |
| `.identity` | Leaves content unaffected, as if no glass were applied. Useful for conditionally disabling the effect without branching the view tree. |
| `.tint(_:)` | Returns a `Glass` with a custom tint color applied. |
| `.interactive(_:)` | Returns a `Glass` that reacts to touch/pointer (default `true`). |

These compose fluently:

```swift
.glassEffect(.regular.tint(.blue))
.glassEffect(.regular.interactive())
.glassEffect(.regular.tint(.blue).interactive())
.glassEffect(.clear)
```

`.clear` is intentionally transparent, so guard legibility with a dimming layer beneath it:

```swift
Label("Flag", systemImage: "flag.fill")
    .padding()
    .glassEffect(.clear)
    .background(.black.opacity(0.3))   // keeps the label readable over bright content
```

Use `.identity` to toggle glass on/off without restructuring:

```swift
.glassEffect(isFloating ? .regular : .identity, in: .capsule)
```

---

## Shapes for Glass

The `in:` parameter accepts any `Shape`.

| Shape | Usage |
|---|---|
| `DefaultGlassEffectShape()` (a `Capsule`) | Default — pills, single controls. |
| `.capsule` | Pills, tags, toolbars of buttons. |
| `.rect(cornerRadius:)` | Cards, larger panels. |
| `.circle` | FABs, round avatars. |
| Custom `Shape` | Bespoke silhouettes. |

```swift
.glassEffect(in: .capsule)
.glassEffect(in: .rect(cornerRadius: 20))
.glassEffect(in: .circle)
```

Keep one shape vocabulary across related controls so the cluster reads as a system.

---

## `GlassEffectContainer` — Batching

**The single most important structural rule: two or more nearby glass elements must live inside one `GlassEffectContainer`.** Verified initializer:

```swift
@MainActor @preconcurrency
init(
    spacing: CGFloat? = nil,
    @ViewBuilder content: () -> Content
)
```

Why it matters:

- **Rendering.** Each loose `.glassEffect` view samples the backdrop independently — expensive and visually disjoint. A container batches the sampling/rendering of all the glass shapes it extracts from its content into one pass.
- **Morphing.** A container is *required* for the morph transition (`glassEffectID`) to work; the morph happens *within* a container.
- **Spacing controls blending.** `spacing:` determines how close two glass shapes must be before they visually blend/merge as they move. Larger spacing means shapes start influencing each other from farther apart.

```swift
GlassEffectContainer(spacing: 20.0) {
    HStack(spacing: 20.0) {
        Image(systemName: "wand.and.stars")
            .frame(width: 80, height: 80)
            .font(.system(size: 36))
            .glassEffect()

        Image(systemName: "paintbrush.fill")
            .frame(width: 80, height: 80)
            .font(.system(size: 36))
            .glassEffect()
    }
}
```

Multiple loose `.glassEffect` views *without* a container is the #1 performance and visual mistake with Liquid Glass.

---

## Morphing with `glassEffectID`

To morph glass between states (insert/remove, expand/collapse), give each glass element a stable identity with `.glassEffectID(_:in:)` and a shared `@Namespace`, inside a `GlassEffectContainer`, then drive the change with `withAnimation`.

```swift
@State private var isExpanded = false
@Namespace private var namespace

var body: some View {
    GlassEffectContainer(spacing: 40.0) {
        HStack(spacing: 40.0) {
            Image(systemName: "scribble.variable")
                .frame(width: 80.0, height: 80.0)
                .font(.system(size: 36))
                .glassEffect()
                .glassEffectID("pencil", in: namespace)

            if isExpanded {
                Image(systemName: "eraser.fill")
                    .frame(width: 80.0, height: 80.0)
                    .font(.system(size: 36))
                    .glassEffect()
                    .glassEffectID("eraser", in: namespace)
            }
        }
    }

    Button("Toggle") {
        withAnimation { isExpanded.toggle() }
    }
    .buttonStyle(.glass)
}
```

A richer pattern — a toggle button that reveals a stack of badges, all morphing together:

```swift
GlassEffectContainer(spacing: badgeGlassSpacing) {
    VStack(alignment: .center, spacing: badgeButtonTopSpacing) {
        if isExpanded {
            VStack(spacing: badgeSpacing) {
                ForEach(modelData.earnedBadges) { badge in
                    BadgeLabel(badge: badge)
                        .glassEffect(.regular, in: .rect(cornerRadius: badgeCornerRadius))
                        .glassEffectID(badge.id, in: namespace)
                }
            }
        }

        Button {
            withAnimation { isExpanded.toggle() }
        } label: {
            ToggleBadgesLabel(isExpanded: isExpanded)
        }
        .buttonStyle(.glass)
        .glassEffectID("togglebutton", in: namespace)
    }
}
```

The container's `spacing:` decides when neighboring shapes begin to blend during the morph — tune it to the visual distance between the elements.

`GlassEffectTransition` is the transition type that governs how glass elements appear/disappear within a container; the default transition produces the fluid materialize/dematerialize you see above. Customize it only when the default doesn't fit the motion you want.

---

## `glassEffectUnion` — Merging Shapes

`.glassEffectUnion(id:namespace:)` merges multiple separate glass views that share the same `id` (and a compatible shape) into a single continuous glass shape. This is the tool for dynamically generated views, or views that aren't in a single layout container, that should read as one piece of glass.

```swift
let symbolSet = ["cloud.bolt.rain.fill", "sun.rain.fill", "moon.stars.fill", "moon.fill"]

GlassEffectContainer(spacing: 20.0) {
    HStack(spacing: 20.0) {
        ForEach(symbolSet.indices, id: \.self) { item in
            Image(systemName: symbolSet[item])
                .frame(width: 80.0, height: 80.0)
                .font(.system(size: 36))
                .glassEffect()
                // first two merge into one shape, last two into another
                .glassEffectUnion(id: item < 2 ? "1" : "2", namespace: namespace)
        }
    }
}
```

Views sharing an `id` merge; different `id`s stay separate. Like morphing, this happens inside a `GlassEffectContainer`.

---

## Button Styles: `.glass` and `.glassProminent`

iOS 26 adds two built-in glass button styles. These are the right way to glass a button — they bring the system's responsive, fluid touch reactions for free.

```swift
Button("Continue") { next() }
    .buttonStyle(.glass)            // standard glass button

Button("Buy Now") { purchase() }
    .buttonStyle(.glassProminent)   // prominent — analogous to .borderedProminent
```

`.glassProminent` resolves to `GlassProminentButtonStyle` and is the glass equivalent of `.borderedProminent` — use it for the primary action, and `.glass` for secondary actions.

For *custom* (non-`Button`) controls that should react like a glass button, apply `.interactive()` to the `Glass` value instead:

```swift
MyCustomControl()
    .glassEffect(.regular.interactive())
```

Tint a prominent button with `.tint`:

```swift
Button("Save") { save() }
    .buttonStyle(.glassProminent)
    .tint(.green)
```

---

## Background Extension & Scroll Edge Effects

### `backgroundExtensionEffect()`

Extends a view's content visually beyond its bounds (mirrored/blurred) so it reads as if it flows under adjacent glass chrome — typical for a hero image that should appear to continue beneath a translucent nav bar or sidebar, without cropping the real image.

```swift
Image("hero")
    .resizable()
    .scaledToFill()
    .backgroundExtensionEffect()   // content bleeds under surrounding glass chrome
```

Use it where edge-to-edge media meets system glass, instead of manually ignoring safe areas and clipping.

### `scrollEdgeEffectStyle(_:for:)`

Controls how the scroll view's content fades/treats its edges where it meets glass chrome. The two styles are `.soft` (a gentle, diffused fade — the default feel) and `.hard` (a crisp, defined edge).

```swift
ScrollView {
    LazyVStack {
        ForEach(data) { item in
            RowView(item)
        }
    }
}
.scrollEdgeEffectStyle(.hard, for: .all)
```

The `for:` parameter scopes which edges get the effect (e.g. `.all`, `.top`, `.bottom`). Use `.hard` when you want a clean cut at the chrome boundary, `.soft` when content should dissolve into the glass.

---

## Tab Bar & Navigation

### System Tab Bar (recommended)

Adopting SDK 26 glasses the standard tab bar automatically. Use the modern `Tab` API and add nothing.

```swift
TabView {
    Tab("Home", systemImage: "house") { HomeView() }
    Tab("Alerts", systemImage: "bell") { AlertsView() }

    TabSection("Categories") {
        Tab("Climate", systemImage: "fan") { ClimateView() }
        Tab("Lights", systemImage: "lightbulb") { LightsView() }
    }
}
```

### Tab View Bottom Accessory

`tabViewBottomAccessory(content:)` places a view (a now-playing bar, a status strip) above the tab bar; it adapts as the tab bar resizes, and the system gives it cohesive glass treatment.

```swift
TabView {
    Tab("Home", systemImage: "house") { HomeView() }
    Tab("Alerts", systemImage: "bell") { AlertsView() }
}
.tabViewBottomAccessory {
    HomeStatusView()   // floats above the tab bar, glassed by the system
}
```

### Navigation Stack

```swift
NavigationStack {
    List { /* content */ }
        .navigationTitle("Title")
}
// Glass treatment applied to the navigation bar automatically.
```

### Minimizing chrome for immersive content

Hide the tab bar for full-screen media, and give users a way back:

```swift
MediaPlayerView()
    .toolbarVisibility(isImmersive ? .hidden : .automatic, for: .tabBar)
    .onTapGesture {
        withAnimation(.spring(duration: 0.3)) { isImmersive.toggle() }
    }
```

---

## Toolbars & Sheets

### Toolbars

Let the system glass toolbars. Group 3+ related actions into a menu to reduce clutter; the system handles the glass.

```swift
.toolbar {
    ToolbarItem(placement: .primaryAction) {
        Menu {
            Button("Edit", systemImage: "pencil") {}
            Button("Share", systemImage: "square.and.arrow.up") {}
            Button("Delete", systemImage: "trash", role: .destructive) {}
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
}
```

Do **not** override with opaque/colored `toolbarBackground` — it breaks system cohesion. Use `toolbarBackgroundVisibility(_:for:)` only to influence *when* the background shows, not to recolor it.

### Sheets and `presentationBackground`

The system glasses small/medium sheets. Use `presentationBackground` only when you genuinely need a different treatment — e.g. a deliberately glassy small sheet, or an opaque large sheet for dense editing.

```swift
.sheet(isPresented: $showSheet) {
    SheetContent()
        .presentationDetents([.medium])
        .presentationBackground(.thinMaterial)   // explicit material for the sheet
        .presentationCornerRadius(24)
}
```

| Sheet size | Suggested background | Use case |
|---|---|---|
| Small / Medium | System glass (or a material) | Quick actions, pickers, forms |
| Large / full | Opaque (`.background`) | Dense editing, full content |

Don't fight the system default unless the design demands it.

---

## Animation Integration

Glass animates as part of normal SwiftUI animation. Prefer driving morphs through `glassEffectID` + `withAnimation` (above). For simple state-driven changes:

```swift
struct AnimatedGlassCard: View {
    @State private var isExpanded = false

    var body: some View {
        VStack { /* content */ }
            .frame(height: isExpanded ? 300 : 100)
            .glassEffect(in: .rect(cornerRadius: isExpanded ? 24 : 16))
            .animation(.spring(duration: 0.4), value: isExpanded)
    }
}
```

Guidance:

- Use spring animations with moderate bounce for glass transitions.
- For state morphs across a cluster, use `glassEffectID` in a `GlassEffectContainer`, not `matchedGeometryEffect` — `glassEffectID` is the glass-aware equivalent and preserves the material continuity.
- Never animate the material/blur on every frame (see performance).
- Respect `accessibilityReduceMotion` (see accessibility).

For navigation, the zoom transition pairs naturally with glass source elements:

```swift
NavigationLink {
    DetailView()
        .navigationTransition(.zoom(sourceID: itemID, in: namespace))
} label: {
    ItemCard()
        .matchedTransitionSource(id: itemID, in: namespace)
}
```

---

## Common Patterns

### Floating Action Button

```swift
Button { add() } label: {
    Image(systemName: "plus")
        .font(.title2)
        .frame(width: 56, height: 56)
}
.buttonStyle(.glass)
.clipShape(.circle)
```

Or, for a custom (non-button) floating control:

```swift
Image(systemName: "plus")
    .font(.title2)
    .frame(width: 56, height: 56)
    .glassEffect(.regular.interactive(), in: .circle)
```

### Floating Controls Cluster (batched)

```swift
GlassEffectContainer(spacing: 12) {
    HStack(spacing: 12) {
        Button("Back", systemImage: "chevron.left") { back() }
            .buttonStyle(.glass)
        Button("Forward", systemImage: "chevron.right") { forward() }
            .buttonStyle(.glass)
    }
}
```

### Custom Segmented Control on Glass

```swift
struct GlassSegmentedControl: View {
    @Binding var selection: Int
    let options: [String]
    @Namespace private var ns

    var body: some View {
        GlassEffectContainer(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(options.indices, id: \.self) { index in
                    Button {
                        withAnimation(.spring(duration: 0.3)) { selection = index }
                    } label: {
                        Text(options[index])
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                    .glassEffect(
                        selection == index ? .regular.interactive() : .identity,
                        in: .capsule
                    )
                    .glassEffectID(index, in: ns)
                }
            }
        }
    }
}
```

### Search Bar on Glass

```swift
struct GlassSearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search", text: $text)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .glassEffect(in: .capsule)
    }
}
```

Note the foreground styles are **semantic** (`.secondary`), never hardcoded `.white`/`.black`.

### Hero Image Under Glass Chrome

```swift
ScrollView {
    VStack(spacing: 0) {
        Image("hero")
            .resizable()
            .scaledToFill()
            .frame(height: 300)
            .backgroundExtensionEffect()   // flows under the glass nav bar

        ContentSection()
    }
}
.scrollEdgeEffectStyle(.soft, for: .top)
```

---

## Anti-Patterns

### Shipping the visionOS modifier on iOS (avoid)

```swift
// Bad — .glassBackgroundEffect() is visionOS; wrong/unavailable path on iOS
.glassBackgroundEffect()

// Good — the iOS 26 API
.glassEffect(in: .rect(cornerRadius: 16))
```

### Glass on glass / glassing everything (avoid)

```swift
// Bad — every card glassed; muddy, slow, no hierarchy
ForEach(items) { item in
    CardView(item).glassEffect(in: .rect(cornerRadius: 16))
}

// Good — content opaque; glass only on the floating control above it
ForEach(items) { item in CardView(item) }     // opaque
Button("New", systemImage: "plus") { add() }
    .buttonStyle(.glass)
```

### Loose glass without a container (avoid)

```swift
// Bad — five independent samplers, disjoint, can't morph
HStack {
    ForEach(0..<5) { Image(systemName: icons[$0]).glassEffect() }
}

// Good — one batched container
GlassEffectContainer(spacing: 12) {
    HStack(spacing: 12) {
        ForEach(0..<5) { Image(systemName: icons[$0]).glassEffect() }
    }
}
```

### Colored / opaque chrome (avoid)

```swift
// Bad — breaks system glass cohesion
.toolbarBackground(Color.blue, for: .navigationBar)

// Good — adopt the system glass; add nothing
```

### Hardcoded foreground color over glass (avoid)

```swift
// Bad — vanishes over light content
Text("Title").foregroundStyle(.white).glassEffect()

// Good — semantic, adapts to the shifting backdrop
Text("Title").foregroundStyle(.primary).glassEffect()
```

### Over-customization (avoid)

```swift
// Bad — fighting the material with strokes, shadows, blurs
.glassEffect()
.overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.5), lineWidth: 2))
.shadow(color: .blue.opacity(0.3), radius: 20)

// Good — let the material speak
.glassEffect(in: .rect(cornerRadius: 16))
```

---

## Fallbacks for < iOS 26

The `.glassEffect` family and `GlassEffectContainer` **do not exist before iOS 26**. If your deployment target is below 26, gate every glass call with `if #available(iOS 26, *)` and fall back to a material so older OSes (and Reduce Transparency users) stay legible.

A reusable modifier keeps the call sites clean:

```swift
struct GlassOrMaterial: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(.ultraThinMaterial,
                            in: .rect(cornerRadius: cornerRadius))
        }
    }
}

extension View {
    func glassOrMaterial(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassOrMaterial(cornerRadius: cornerRadius))
    }
}
```

For buttons:

```swift
Group {
    if #available(iOS 26, *) {
        Button("Continue") { next() }.buttonStyle(.glass)
    } else {
        Button("Continue") { next() }.buttonStyle(.borderedProminent)
    }
}
```

Choose the fallback material by weight: `.ultraThinMaterial` / `.thinMaterial` for light floating controls, `.regularMaterial` for more substantial chrome. Always verify the fallback on a pre-26 OS, with Reduce Transparency on.

---

## Accessibility

Liquid Glass adapts to system accessibility settings automatically — your job is to not undo that.

- **Reduce Transparency:** When on, the system reduces the translucency of glass for legibility. Don't reintroduce translucency the user asked the system to remove (e.g. don't force `.clear` or add your own blur on top). Test your screens with it enabled.
- **Increase Contrast:** The system strengthens contrast for glass surfaces; keep foreground styles semantic (`.primary`/`.secondary`/`.tint`) so they track the contrast adjustment. Hardcoded colors won't.
- **Reduce Motion:** Skip or simplify morph animations when `accessibilityReduceMotion` is set.

```swift
struct AccessibleGlassToggle: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var ns
    @State private var isExpanded = false

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            // ... glass elements with .glassEffectID(..., in: ns)
        }
        .onTapGesture {
            if reduceMotion {
                isExpanded.toggle()                      // instant
            } else {
                withAnimation(.spring) { isExpanded.toggle() }
            }
        }
    }
}
```

- For `.clear` glass over uncontrolled content, add a dimming backdrop (`.background(.black.opacity(0.3))`) so text meets contrast minimums.

---

## Performance & Overuse Cautions

- **Batch.** Every cluster of 2+ glass elements belongs in one `GlassEffectContainer`. Loose glass views each sample the backdrop independently — the dominant cost.
- **Don't blanket the UI.** Glass is a floating layer, not a fill. Glassing whole screens or every card flattens hierarchy and is the fastest route to a muddy, sluggish screen.
- **Don't animate the material every frame.** Animating blur/material continuously forces constant re-sampling. Animate geometry/opacity; morph via `glassEffectID`, which the system optimizes.
- **Prefer system chrome.** The system's nav/tab/toolbar glass is already optimized and cohesive — adopting it costs you nothing and is faster than hand-rolling.
- **Tint sparingly.** Tint signals prominence; tinting everything erases that signal and adds work.

---

## Migration Guide

### From iOS 18 materials to iOS 26 Liquid Glass

**Before (iOS 18):**
```swift
content
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16))
```

**After (iOS 26):**
```swift
content
    .glassEffect(in: .rect(cornerRadius: 16))
```

> If you also support < iOS 26, wrap this in the `glassOrMaterial` modifier from [Fallbacks](#fallbacks-for--ios-26) rather than replacing the material outright.

### Buttons

**Before:**
```swift
Button("Buy") { purchase() }.buttonStyle(.borderedProminent)
```

**After:**
```swift
Button("Buy") { purchase() }.buttonStyle(.glassProminent)
```

### Toolbars

**Before:**
```swift
.toolbarBackground(.ultraThinMaterial, for: .navigationBar)
.toolbarBackground(.visible, for: .navigationBar)
```

**After:**
```swift
// Nothing — SDK 26 glasses the nav bar automatically.
```

### Custom tab bar → system tab bar

**Before:**
```swift
ZStack(alignment: .bottom) {
    TabContent()
    CustomTabBar(selection: $selection).background(.ultraThinMaterial)
}
```

**After:**
```swift
TabView(selection: $selection) {
    Tab("Home", systemImage: "house") { HomeView() }
}
```

### Do NOT migrate to `.glassBackgroundEffect()`

`.glassBackgroundEffect()` is **visionOS** (it adds physical 3D depth and influences z-axis layout). It is not the iOS migration target. The iOS target is `.glassEffect(_:in:)`.

---

## Quick Reference

### Core modifiers

| Modifier | Purpose |
|---|---|
| `.glassEffect(_:in:)` | Apply glass (variant `Glass`, default `.regular`; shape default `DefaultGlassEffectShape()` = capsule). |
| `GlassEffectContainer(spacing:)` | Batch 2+ glass elements; required for morphing; `spacing` controls blend distance. |
| `.glassEffectID(_:in:)` | Stable identity for a glass element so it morphs across states (needs `@Namespace` + container). |
| `.glassEffectUnion(id:namespace:)` | Merge multiple glass views sharing an `id` into one continuous shape. |
| `.buttonStyle(.glass)` | Standard glass button. |
| `.buttonStyle(.glassProminent)` | Prominent glass button (glass `.borderedProminent`). |
| `.backgroundExtensionEffect()` | Extend content visually beyond bounds, under adjacent glass chrome. |
| `.scrollEdgeEffectStyle(_:for:)` | `.soft` / `.hard` edge treatment where scroll content meets chrome. |
| `.tabViewBottomAccessory(content:)` | Floating accessory above the tab bar, system-glassed. |
| `.presentationBackground(_:)` | Override sheet background (use sparingly). |

### `Glass` value

| Member | Effect |
|---|---|
| `.regular` | Standard material (default). |
| `.clear` | More transparent; pair with a dimming backdrop. |
| `.identity` | No effect — toggle glass off without branching. |
| `.tint(_:)` | Apply a tint color. |
| `.interactive(_:)` | React to touch/pointer (default `true`). |

Compose: `.regular.tint(.blue).interactive()`.

### Shapes

`DefaultGlassEffectShape()` (capsule) · `.capsule` · `.rect(cornerRadius:)` · `.circle` · custom `Shape`.

### Pre-ship checklist

- [ ] iOS path uses `.glassEffect(_:in:)` / `.buttonStyle(.glass)` — **no** `.glassBackgroundEffect()` (visionOS).
- [ ] Every cluster of 2+ glass elements is inside a `GlassEffectContainer`; morphs use `.glassEffectID(_:in:)` with a shared `@Namespace`.
- [ ] Glass only on floating/elevated elements — not full-screen backgrounds or content cards.
- [ ] Standard nav bar / tab bar / toolbars use system glass — no opaque/colored `toolbarBackground` fighting it.
- [ ] No hardcoded foreground colors over glass; semantic styles only.
- [ ] Verified with **Reduce Transparency** and **Increase Contrast** on; morph animations skip under `accessibilityReduceMotion`.
- [ ] If targeting < iOS 26, glass gated behind `if #available(iOS 26, *)` with an `.ultraThinMaterial`/`.regularMaterial` fallback seen on an older OS.
- [ ] Concentric corner radii (inner = outer − padding); not animating blur/material every frame.

---

## Resources

- [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)
- [`glassEffect(_:in:)`](https://developer.apple.com/documentation/swiftui/view/glasseffect%28_%3Ain%3A%29)
- [`GlassEffectContainer`](https://developer.apple.com/documentation/swiftui/glasseffectcontainer)
- [`Glass`](https://developer.apple.com/documentation/swiftui/glass)
- [`scrollEdgeEffectStyle(_:for:)`](https://developer.apple.com/documentation/swiftui/view/scrolledgeeffectstyle%28_%3Afor%3A%29)
- [`tabViewBottomAccessory(content:)`](https://developer.apple.com/documentation/swiftui/view/tabviewbottomaccessory%28content%3A%29)
- [Human Interface Guidelines — Materials](https://developer.apple.com/design/human-interface-guidelines/materials)

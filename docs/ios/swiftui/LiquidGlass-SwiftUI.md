# Liquid Glass Design System - SwiftUI Reference

This document provides comprehensive guidance for implementing Apple's Liquid Glass design language in SwiftUI applications targeting iOS 26+.

---

## Table of Contents

1. [Design Philosophy](#design-philosophy)
2. [The 3 Cs Principle](#the-3-cs-principle)
3. [SwiftUI Implementation](#swiftui-implementation)
4. [Edge Effects](#edge-effects)
5. [Glass Modes](#glass-modes)
6. [Tab Bar & Navigation](#tab-bar--navigation)
7. [Toolbar & Menu Consolidation](#toolbar--menu-consolidation)
8. [Glass Sheets](#glass-sheets)
9. [Corner Configuration](#corner-configuration)
10. [Animation Integration](#animation-integration)
11. [Glass Effect Container](#glass-effect-container)
12. [Common Patterns](#common-patterns)
13. [Anti-Patterns](#anti-patterns)
14. [Migration Guide](#migration-guide)
15. [Icon Composer](#icon-composer)
16. [Quick Reference Checklist](#quick-reference-checklist)

---

## Design Philosophy

Liquid Glass is Apple's visual design language introduced in iOS 26 (2025). It creates a sense of depth and dimensionality through translucent, glass-like surfaces that respond to the content behind them.

### Core Principles

- **Depth Through Translucency:** Glass surfaces reveal hints of the content beneath, creating spatial hierarchy
- **Hardware Integration:** UI elements align with device hardware, creating seamless physical-digital boundaries
- **Content Elevation:** Glass serves as a stage for content, never competing with it
- **Systematic Cohesion:** All glass elements work together as part of a unified visual system

---

## The 3 Cs Principle

### 1. Content First

Glass should frame and elevate content, never compete with it.

```swift
// Good: Glass provides subtle background, content is prominent
VStack {
    Text("Main Content")
        .font(.largeTitle)
    DetailView()
}
.padding()
.glassBackgroundEffect()

// Bad: Heavy glass styling that distracts from content
VStack {
    Text("Main Content")
        .font(.largeTitle)
        .foregroundStyle(.secondary) // Content shouldn't be muted
}
.padding()
.glassBackgroundEffect(in: .rect(cornerRadius: 40)) // Excessive styling
.overlay(BorderEffect()) // Unnecessary decoration
```

### 2. Concentric

Nested elements share the same center point and have proportional corner radii.

```swift
// Good: Proportional corners in nested containers
ZStack {
    RoundedRectangle(cornerRadius: 24)
        .fill(.ultraThinMaterial)

    RoundedRectangle(cornerRadius: 16) // Proportionally smaller
        .fill(.thinMaterial)
        .padding(12)

    RoundedRectangle(cornerRadius: 8) // Even smaller for inner content
        .fill(.regularMaterial)
        .padding(24)
}

// Using ContainerRelativeShape for automatic proportions
OuterContainer {
    InnerContent()
        .background(ContainerRelativeShape().fill(.ultraThinMaterial))
}
```

### 3. Cohesive

UI elements work together as a unified system. Glass elements should feel like parts of the same whole.

```swift
// Good: Coordinated glass system
NavigationStack {
    ContentView()
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
}
.tabViewStyle(.tabBarOnly)
// System handles cohesive glass treatment

// Bad: Conflicting glass treatments
NavigationStack {
    ContentView()
        .toolbarBackground(Color.blue.opacity(0.8), for: .navigationBar) // Conflicts
}
```

---

## SwiftUI Implementation

### Glass Background Effect

```swift
// Basic glass background
.glassBackgroundEffect()

// Glass with specific shape
.glassBackgroundEffect(in: .rect(cornerRadius: 16))

// Glass with capsule shape
.glassBackgroundEffect(in: .capsule)

// Glass with custom shape
.glassBackgroundEffect(in: CustomShape())
```

### Materials (Pre-iOS 26 Compatible)

```swift
// Ultra thin - most transparent
.background(.ultraThinMaterial)

// Thin
.background(.thinMaterial)

// Regular (default)
.background(.regularMaterial)

// Thick
.background(.thickMaterial)

// Ultra thick - most opaque
.background(.ultraThickMaterial)

// Bar material - optimized for toolbars
.background(.bar)
```

### Container Backgrounds

```swift
// For navigation containers
.containerBackground(.ultraThinMaterial, for: .navigation)

// For tab view
.containerBackground(.thinMaterial, for: .tabView)

// For widget
.containerBackground(.regularMaterial, for: .widget)
```

### Toolbar Background Visibility

```swift
// Automatic - system decides based on scroll
.toolbarBackgroundVisibility(.automatic, for: .navigationBar)
.toolbarBackgroundVisibility(.automatic, for: .tabBar)

// Visible - always show background
.toolbarBackgroundVisibility(.visible, for: .navigationBar)

// Hidden - never show background
.toolbarBackgroundVisibility(.hidden, for: .tabBar)
```

---

## Edge Effects

### Understanding Edge Types

Liquid Glass supports two edge effect styles that define how glass elements interact with their boundaries:

### Soft Edge (Default)

Soft edges create a gentle, diffused boundary that blends naturally with surrounding content.

```swift
// Soft edge is the default behavior
.glassBackgroundEffect()

// Explicit soft edge
.glassBackgroundEffect(displayMode: .always)
```

**When to Use Soft Edge:**
- Standard UI elements (cards, buttons, controls)
- Content that should feel integrated with the page
- Most general-purpose glass containers

### Hard Edge

Hard edges create a crisp, defined boundary with more visual separation.

```swift
// Hard edge for stronger visual separation
.glassBackgroundEffect(in: .rect(cornerRadius: 16), displayMode: .always)
    .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
```

**When to Use Hard Edge:**
- Floating elements that need clear separation
- Overlays and popovers
- Elements that should "pop" from the background

---

## Glass Modes

### Regular Glass vs Clear Glass

iOS 26 introduces two distinct glass rendering modes:

### Regular Glass

Standard translucent glass with blur and tint effects.

```swift
// Regular glass (default)
.glassBackgroundEffect()

// With material specification
.background(.regularMaterial)
```

**Characteristics:**
- Visible blur effect
- Adapts to light/dark mode
- Content behind is softly visible

### Clear Glass

More transparent glass mode for lighter visual weight.

```swift
// Clear glass - more transparent
.glassBackgroundEffect(in: .rect(cornerRadius: 12))
    .opacity(0.8)
```

**When to Use Clear Glass:**
- Secondary UI elements
- When you want subtle glass presence
- Layered interfaces where regular glass would be too heavy

### Adaptive Glass

Let the system choose the appropriate glass mode:

```swift
// System decides based on context
.containerBackground(.automatic, for: .widget)
```

---

## Tab Bar & Navigation

### System Tab Bar (Recommended)

Let the system handle tab bar glass treatment:

```swift
TabView {
    HomeView()
        .tabItem {
            Label("Home", systemImage: "house")
        }

    SettingsView()
        .tabItem {
            Label("Settings", systemImage: "gear")
        }
}
// No additional styling needed - system applies Liquid Glass
```

### Tab View Bottom Accessory

For content that floats above the tab bar:

```swift
TabView {
    ContentView()
}
.tabViewBottomAccessory {
    NowPlayingBar()
        .glassBackgroundEffect(in: .capsule)
}
```

### Navigation Stack

```swift
NavigationStack {
    List {
        // Content
    }
    .navigationTitle("Title")
}
// Glass treatment applied automatically to navigation bar
```

### Scroll Edge Behavior

```swift
ScrollView {
    // Content
}
.scrollContentBackground(.hidden) // Let glass show through
.toolbarBackground(.ultraThinMaterial, for: .navigationBar)
```

### Search Tab Placement

When adding a search tab, place it appropriately within the tab bar:

```swift
TabView {
    HomeView()
        .tabItem {
            Label("Home", systemImage: "house")
        }

    // Search tab - place after primary tabs, before utility tabs
    SearchView()
        .tabItem {
            Label("Search", systemImage: "magnifyingglass")
        }

    ProfileView()
        .tabItem {
            Label("Profile", systemImage: "person")
        }
}
```

**Guidelines:**
- Search is typically placed after primary navigation tabs
- Consider using `.searchable()` modifier instead of dedicated tab for inline search
- Search tab icon should use SF Symbol "magnifyingglass"

### Minimize Tab Bar for Immersive Content

For immersive experiences like video playback, media viewing, or full-screen content:

```swift
struct ImmersiveContentView: View {
    @State private var isImmersive = false

    var body: some View {
        MediaPlayerView()
            .toolbarVisibility(isImmersive ? .hidden : .automatic, for: .tabBar)
            .onTapGesture {
                withAnimation(.spring(duration: 0.3)) {
                    isImmersive.toggle()
                }
            }
    }
}
```

**Best Practices:**
- Allow users to toggle tab bar visibility
- Use animation when showing/hiding
- Provide clear gesture or control to restore tab bar
- Consider edge swipe to reveal hidden tab bar

---

## Toolbar & Menu Consolidation

### Consolidating Toolbar Items

Group related actions into menus to reduce visual clutter:

```swift
.toolbar {
    ToolbarItem(placement: .primaryAction) {
        Menu {
            Button("Edit", systemImage: "pencil") { }
            Button("Share", systemImage: "square.and.arrow.up") { }
            Button("Delete", systemImage: "trash", role: .destructive) { }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
}
```

### Toolbar Menu with Glass Treatment

```swift
struct GlassToolbarView: View {
    var body: some View {
        NavigationStack {
            ContentView()
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button { } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Spacer()
                        Button { } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
                .toolbarBackground(.ultraThinMaterial, for: .bottomBar)
        }
    }
}
```

**Guidelines:**
- Group 3+ actions into a single menu
- Use consistent icon placement (trailing for actions)
- Let system handle glass treatment for toolbars

---

## Glass Sheets

### Sheet Size and Glass Treatment

Glass treatment varies based on sheet presentation size:

### Small/Medium Sheets (Glass)

Small and medium detents use glass background:

```swift
.sheet(isPresented: $showSheet) {
    SheetContent()
        .presentationDetents([.medium])
        .presentationBackground(.ultraThinMaterial) // Glass treatment
        .presentationCornerRadius(24)
}
```

### Large Sheets (Opaque)

Large/full-screen sheets should use opaque backgrounds:

```swift
.sheet(isPresented: $showFullSheet) {
    FullSheetContent()
        .presentationDetents([.large])
        .presentationBackground(.background) // Opaque for large
        .presentationCornerRadius(32)
}
```

### Adaptive Sheet Glass

```swift
struct AdaptiveSheet<Content: View>: View {
    let detent: PresentationDetent
    @ViewBuilder var content: Content

    var body: some View {
        content
            .presentationDetents([detent])
            .presentationBackground(
                detent == .large ? AnyShapeStyle(.background) : AnyShapeStyle(.ultraThinMaterial)
            )
            .presentationCornerRadius(detent == .large ? 32 : 24)
    }
}
```

**Summary:**
| Sheet Size | Background | Use Case |
|------------|------------|----------|
| Small | Glass (`.ultraThinMaterial`) | Quick actions, pickers |
| Medium | Glass (`.thinMaterial`) | Forms, details |
| Large | Opaque (`.background`) | Full content, editing |

---

## Corner Configuration

### Hardware Corner Alignment

Device corners should be respected and matched:

```swift
// Good: Using system values
.clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))

// Better: Using ContainerRelativeShape
.background(ContainerRelativeShape())
```

### Nested Corner Proportions

Formula: Inner corner = Outer corner - padding

```swift
let outerCorner: CGFloat = 24
let padding: CGFloat = 8
let innerCorner = outerCorner - padding // 16

ZStack {
    RoundedRectangle(cornerRadius: outerCorner)
    RoundedRectangle(cornerRadius: innerCorner)
        .padding(padding)
}
```

### ContainerRelativeShape

Automatically adapts to container's shape:

```swift
struct CardView: View {
    var body: some View {
        VStack {
            Text("Title")
            Divider()
            Text("Content")
        }
        .padding()
        .background(
            ContainerRelativeShape()
                .fill(.ultraThinMaterial)
        )
    }
}
```

---

## Animation Integration

### Glass with Animation

```swift
struct AnimatedGlassCard: View {
    @State private var isExpanded = false

    var body: some View {
        VStack {
            // Content
        }
        .frame(height: isExpanded ? 300 : 100)
        .glassBackgroundEffect(in: .rect(cornerRadius: isExpanded ? 24 : 16))
        .animation(.spring(duration: 0.4), value: isExpanded)
    }
}
```

### Glass with PhaseAnimator

```swift
enum PulsePhase: CaseIterable {
    case idle, pulse

    var scale: CGFloat {
        switch self {
        case .idle: 1.0
        case .pulse: 1.05
        }
    }
}

PhaseAnimator(PulsePhase.allCases) { phase in
    RoundedRectangle(cornerRadius: 16)
        .fill(.ultraThinMaterial)
        .scaleEffect(phase.scale)
}
```

### Glass with KeyframeAnimator

```swift
struct BouncyGlass: View {
    struct AnimationValues {
        var scale: CGFloat = 1.0
        var offsetY: CGFloat = 0
    }

    var body: some View {
        KeyframeAnimator(initialValue: AnimationValues()) { values in
            RoundedRectangle(cornerRadius: 20)
                .fill(.thinMaterial)
                .scaleEffect(values.scale)
                .offset(y: values.offsetY)
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                SpringKeyframe(1.1, duration: 0.2)
                SpringKeyframe(1.0, duration: 0.3)
            }
            KeyframeTrack(\.offsetY) {
                LinearKeyframe(-10, duration: 0.15)
                SpringKeyframe(0, duration: 0.35)
            }
        }
    }
}
```

### Accessibility Considerations

```swift
struct AccessibleAnimatedGlass: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var isActive = false

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
            .scaleEffect(isActive ? 1.05 : 1.0)
            .animation(reduceMotion ? nil : .spring(), value: isActive)
    }
}
```

### Zoom Transition

Create smooth zoom transitions for navigation or detail views:

```swift
struct ZoomTransitionExample: View {
    @Namespace private var namespace
    @State private var isExpanded = false

    var body: some View {
        ZStack {
            if !isExpanded {
                // Thumbnail state
                ThumbnailCard()
                    .matchedGeometryEffect(id: "card", in: namespace)
                    .glassBackgroundEffect(in: .rect(cornerRadius: 16))
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                            isExpanded = true
                        }
                    }
            } else {
                // Expanded state
                ExpandedCard()
                    .matchedGeometryEffect(id: "card", in: namespace)
                    .glassBackgroundEffect(in: .rect(cornerRadius: 24))
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                            isExpanded = false
                        }
                    }
            }
        }
    }
}
```

**Guidelines:**
- Use `matchedGeometryEffect` for smooth morphing
- Adjust corner radius during transition for natural feel
- Use spring animations with moderate bounce
- Glass should follow the morphing shape

### Navigation Zoom Transition

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

## Glass Effect Container

### Morphing Glass Elements

Create containers where glass elements can morph and transform smoothly:

```swift
struct MorphingGlassContainer: View {
    @State private var selectedTab = 0
    @Namespace private var morphNamespace

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        selectedTab = index
                    }
                } label: {
                    Text("Tab \(index)")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
                .background {
                    if selectedTab == index {
                        Capsule()
                            .fill(.regularMaterial)
                            .matchedGeometryEffect(id: "selector", in: morphNamespace)
                    }
                }
            }
        }
        .padding(4)
        .glassBackgroundEffect(in: .capsule)
    }
}
```

### Expandable Glass Container

```swift
struct ExpandableGlassContainer: View {
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation(.spring(duration: 0.4)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Options")
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }

            if isExpanded {
                VStack(spacing: 8) {
                    OptionRow(title: "Option 1")
                    OptionRow(title: "Option 2")
                    OptionRow(title: "Option 3")
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .glassBackgroundEffect(in: .rect(cornerRadius: isExpanded ? 20 : 12))
        .animation(.spring(duration: 0.4), value: isExpanded)
    }
}
```

---

## Common Patterns

### Floating Action Button

```swift
Button {
    // Action
} label: {
    Image(systemName: "plus")
        .font(.title2)
        .frame(width: 56, height: 56)
}
.glassBackgroundEffect(in: .circle)
.shadow(color: .black.opacity(0.15), radius: 8, y: 4)
```

### Card with Glass

```swift
struct GlassCard: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassBackgroundEffect(in: .rect(cornerRadius: 16))
    }
}
```

### Modal Sheet with Glass

```swift
struct GlassSheet<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .presentationBackground(.ultraThinMaterial)
            .presentationCornerRadius(32)
    }
}

// Usage
.sheet(isPresented: $isPresented) {
    GlassSheet {
        SheetContent()
    }
}
```

### Segmented Control with Glass

```swift
struct GlassSegmentedControl: View {
    @Binding var selection: Int
    let options: [String]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options.indices, id: \.self) { index in
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        selection = index
                    }
                } label: {
                    Text(options[index])
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
                .background {
                    if selection == index {
                        Capsule()
                            .fill(.regularMaterial)
                    }
                }
            }
        }
        .padding(4)
        .glassBackgroundEffect(in: .capsule)
    }
}
```

### Search Bar with Glass

```swift
struct GlassSearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search", text: $text)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .glassBackgroundEffect(in: .capsule)
    }
}
```

### Background Extensions for Hero Images

Create hero sections where images extend behind glass navigation:

```swift
struct HeroImageView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero image extends under navigation bar
                Image("hero")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 300)
                    .clipped()

                // Content with glass overlay
                VStack(alignment: .leading, spacing: 16) {
                    Text("Title")
                        .font(.largeTitle.bold())
                    Text("Description goes here...")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.regularMaterial)
            }
        }
        .ignoresSafeArea(edges: .top)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}
```

### Parallax Hero with Glass

```swift
struct ParallaxHeroView: View {
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    // Parallax hero
                    GeometryReader { inner in
                        let minY = inner.frame(in: .global).minY
                        Image("hero")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(
                                width: geometry.size.width,
                                height: max(300 + minY, 300)
                            )
                            .offset(y: minY > 0 ? -minY : 0)
                    }
                    .frame(height: 300)

                    // Glass content card
                    ContentSection()
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 24,
                                topTrailingRadius: 24
                            )
                        )
                        .offset(y: -24)
                }
            }
        }
    }
}
```

---

## Anti-Patterns

### Glass on Glass (Avoid)

```swift
// Bad: Nested glass creates visual noise
VStack {
    Text("Content")
        .padding()
        .glassBackgroundEffect() // Inner glass
}
.padding()
.glassBackgroundEffect() // Outer glass - visual conflict!

// Good: Single glass layer, use opacity for hierarchy
VStack {
    Text("Content")
        .padding()
        .background(Color.white.opacity(0.1))
}
.padding()
.glassBackgroundEffect()
```

### Colored Navigation Bars (Avoid)

```swift
// Bad: Breaks glass cohesion
.toolbarBackground(Color.blue, for: .navigationBar)

// Good: Use materials
.toolbarBackground(.ultraThinMaterial, for: .navigationBar)
```

### Ghost Glass (Avoid)

Glass elements without clear purpose:

```swift
// Bad: Decorative glass without function
Spacer()
    .frame(height: 20)
    .glassBackgroundEffect()

// Good: Glass only for interactive or content-containing elements
```

### Fighting Translucency (Avoid)

```swift
// Bad: Opaque backgrounds that defeat glass purpose
Text("Content")
    .padding()
    .background(Color.white) // Opaque
    .glassBackgroundEffect() // Glass is pointless now

// Good: Let glass show through
Text("Content")
    .padding()
    .glassBackgroundEffect()
```

### Over-customization (Avoid)

```swift
// Bad: Too much custom styling
.glassBackgroundEffect()
.overlay(
    RoundedRectangle(cornerRadius: 16)
        .stroke(Color.white.opacity(0.5), lineWidth: 2)
)
.shadow(color: .blue.opacity(0.3), radius: 20)

// Good: Let system handle visual treatment
.glassBackgroundEffect()
```

---

## Migration Guide

### From iOS 18 Materials to iOS 26 Liquid Glass

**Before (iOS 18):**
```swift
.background(.ultraThinMaterial)
.clipShape(RoundedRectangle(cornerRadius: 16))
```

**After (iOS 26):**
```swift
.glassBackgroundEffect(in: .rect(cornerRadius: 16))
```

### Toolbar Updates

**Before:**
```swift
.toolbar {
    ToolbarItem(placement: .navigationBarTrailing) {
        Button("Done") { }
    }
}
.navigationBarTitleDisplayMode(.inline)
.toolbarBackground(.visible, for: .navigationBar)
.toolbarBackground(.ultraThinMaterial, for: .navigationBar)
```

**After:**
```swift
.toolbar {
    ToolbarItem(placement: .navigationBarTrailing) {
        Button("Done") { }
    }
}
.navigationBarTitleDisplayMode(.inline)
// System applies glass automatically
```

### Tab View Updates

**Before (Custom Tab Bar):**
```swift
ZStack(alignment: .bottom) {
    TabContent()

    CustomTabBar(selection: $selection)
        .background(.ultraThinMaterial)
}
```

**After:**
```swift
TabView(selection: $selection) {
    TabContent()
        .tabItem { Label("Tab", systemImage: "star") }
}
// System Liquid Glass tab bar
```

---

## Quick Reference

### Modifiers

| Modifier | Purpose |
|----------|---------|
| `.glassBackgroundEffect()` | Apply glass treatment |
| `.glassBackgroundEffect(in:)` | Glass with specific shape |
| `.containerBackground(_:for:)` | Container-level background |
| `.toolbarBackgroundVisibility(_:for:)` | Control toolbar background |

### Shapes for Glass

| Shape | Usage |
|-------|-------|
| `.rect(cornerRadius:)` | Cards, panels |
| `.capsule` | Pills, tags, buttons |
| `.circle` | FAB, avatars |
| `ContainerRelativeShape()` | Adaptive to container |

### Material Hierarchy

From most transparent to most opaque:
1. `.ultraThinMaterial`
2. `.thinMaterial`
3. `.regularMaterial`
4. `.thickMaterial`
5. `.ultraThickMaterial`

---

## Icon Composer

### App Icon Design for Liquid Glass

iOS 26 introduces Icon Composer, a tool for creating app icons that work seamlessly with Liquid Glass:

### Icon Layers

App icons can now have distinct layers that respond to the Liquid Glass system:

1. **Background Layer:** Solid color or gradient base
2. **Content Layer:** Main icon imagery
3. **Foreground Layer:** Optional highlight elements

### Design Guidelines

**DO:**
- Use bold, recognizable silhouettes
- Design at 1024x1024 for App Store, system scales down
- Test with different wallpapers (glass shows through edges)
- Use subtle gradients for depth
- Keep icon centered with adequate padding

**DON'T:**
- Use thin lines that disappear at small sizes
- Place important content near edges (glass fringe effect)
- Rely on background color alone for recognition
- Use text in icons (unreadable at small sizes)

### Testing App Icons

```swift
// Preview your icon at different sizes in SwiftUI
struct IconPreview: View {
    var body: some View {
        HStack(spacing: 20) {
            // Home screen size
            Image("AppIcon")
                .resizable()
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 13.5, style: .continuous))

            // Settings size
            Image("AppIcon")
                .resizable()
                .frame(width: 29, height: 29)
                .clipShape(RoundedRectangle(cornerRadius: 6.5, style: .continuous))

            // Spotlight size
            Image("AppIcon")
                .resizable()
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .padding()
        .glassBackgroundEffect() // Test against glass
    }
}
```

---

## Quick Reference Checklist

### Before Shipping Checklist

Use this checklist to ensure your Liquid Glass implementation follows best practices:

#### The 3 Cs Verification
- [ ] **Content First:** Glass frames content without competing
- [ ] **Concentric:** Nested elements share proportional corners
- [ ] **Cohesive:** All glass elements feel unified

#### Glass Implementation
- [ ] Using `.glassBackgroundEffect()` for primary glass elements
- [ ] Using system materials (`.ultraThinMaterial`, `.thinMaterial`, etc.)
- [ ] Not stacking glass on glass
- [ ] Letting system handle toolbar/tabbar glass treatment

#### Tab Bar & Navigation
- [ ] Using system TabView (not custom tab bar)
- [ ] Tab bar visible by default, hidden only for immersive content
- [ ] Navigation bar uses automatic glass treatment
- [ ] `.tabViewBottomAccessory` for floating content above tab bar

#### Sheets & Presentations
- [ ] Small/Medium sheets use glass background
- [ ] Large sheets use opaque background
- [ ] Appropriate corner radius for sheet size

#### Animations
- [ ] Spring animations for glass element transitions
- [ ] `matchedGeometryEffect` for morphing glass
- [ ] Respecting `accessibilityReduceMotion`

#### Visual Polish
- [ ] No colored navigation/toolbars (breaks glass cohesion)
- [ ] No "ghost glass" (glass without purpose)
- [ ] No opaque backgrounds fighting with glass
- [ ] Corner radii follow nested proportion formula

#### Performance
- [ ] Not animating blur radius frequently
- [ ] Using system glass over custom implementations
- [ ] Avoiding multiple overlapping material layers

---

## Resources

- [Apple Human Interface Guidelines - Liquid Glass](https://developer.apple.com/design/human-interface-guidelines/)
- [WWDC 2025 - Designing with Liquid Glass](https://developer.apple.com/videos/)
- [SwiftUI Materials Documentation](https://developer.apple.com/documentation/swiftui/material)
- [WWDC 2025 - Build an app with Liquid Glass](https://developer.apple.com/videos/)
- [Icon Composer Documentation](https://developer.apple.com/documentation/)

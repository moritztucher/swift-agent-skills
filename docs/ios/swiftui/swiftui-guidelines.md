# SwiftUI Guidelines

> Full SwiftUI guidelines reference. Core rules are in CLAUDE.md.

## Performance

### View Decomposition
- Breaking up views has no performance cost (structs are stack-allocated)
- Extract components freely for readability
- Smaller views enable more targeted SwiftUI updates

### Avoid Closures in View Parameters
- Closures are not equatable - SwiftUI assumes they always changed
- Pass data instead and let child handle actions
- Use @Binding or Environment for communication
- If unavoidable, use `.equatable()` modifier with custom Equatable conformance

### Keep View Init Cheap
- Never start async operations in init()
- Use `.task` modifier for data fetching (auto-cancels on disappear)
- Use `.task(id:)` to re-run when specific values change

### Stable View Identity

Prefer ternary operators over if-else for property changes:

```swift
// Prefer
Text("Hello").foregroundColor(condition ? .red : .blue)

// Avoid (creates different view identities)
if condition {
    Text("Hello").foregroundColor(.red)
} else {
    Text("Hello").foregroundColor(.blue)
}
```

- Use if-else only when replacing with entirely different views
- Use `.id()` intentionally to force view recreation

### Debugging
- Use `Self._printChanges()` in body to debug unnecessary updates
- Use Instruments SwiftUI View Body profiler

## Animation

### Animation Types
- **Linear:** Constant speed, rarely used alone
- **Eased:** Natural acceleration/deceleration (default)
- **Spring/Bouncy:** Physics-based, feels natural and responsive

### Animation APIs
- Use `.animation(_:value:)` for implicit animations tied to state changes
- Use `withAnimation { }` for explicit animation blocks
- Use `.transaction` for fine-grained control

### PhaseAnimator (Discrete States)

```swift
PhaseAnimator([Phase.start, .middle, .end]) { phase in
    Circle()
        .scaleEffect(phase.scale)
        .opacity(phase.opacity)
}
```

### KeyframeAnimator (Complex Multi-Track)

```swift
KeyframeAnimator(initialValue: AnimationValues()) { values in
    Circle()
        .scaleEffect(values.scale)
        .offset(y: values.verticalOffset)
} keyframes: { _ in
    KeyframeTrack(\.scale) {
        SpringKeyframe(1.2, duration: 0.3)
        SpringKeyframe(1.0, duration: 0.2)
    }
    KeyframeTrack(\.verticalOffset) {
        LinearKeyframe(-20, duration: 0.2)
        SpringKeyframe(0, duration: 0.3)
    }
}
```

### Accessibility
- Always check `accessibilityReduceMotion` environment value
- Provide alternative non-animated states when motion is reduced
- Use `.animation(reduceMotion ? nil : .default, value:)` pattern

## Liquid Glass Design (iOS 26+)

### The 3 Cs
1. **Content First:** Glass should frame and elevate content, never compete with it
2. **Concentric:** Nested elements share the same center point and proportional corners
3. **Cohesive:** UI elements work together as a unified system

### Tab Bar & Toolbar Guidelines
- System tab bars automatically adopt Liquid Glass in iOS 26+
- Use `.tabViewBottomAccessory` for content that floats above the tab bar
- Avoid custom tab bar implementations that break the glass effect

### Corner Configuration
- Align corner radii with device hardware corners
- Use `ContainerRelativeShape` for automatic corner inheritance
- Nested containers should have proportionally smaller radii

### What to Avoid
- Glass-on-glass layering (creates visual noise)
- Colored navigation bars (breaks glass cohesion)
- "Ghost glass" - glass elements without clear purpose
- Opaque backgrounds that fight against the translucency

### Implementation

```swift
// Use glass background for floating controls
.glassBackgroundEffect()

// For containers that need glass treatment
.containerBackground(.ultraThinMaterial, for: .navigation)

// Respect system glass automatically
.toolbarBackgroundVisibility(.automatic, for: .tabBar)
```

## Previews

- Always include SwiftUI previews for views when possible
- Provide multiple preview configurations (different data states, light/dark mode)
- Use preview data for realistic previews

## Accessibility

- Follow SwiftUI's default accessibility practices (proper labels, etc.)
- No specific requirements beyond defaults

## Localization

- Prepare code for localization (use LocalizedStringKey when appropriate)
- Avoid hardcoded strings in UI components

## Dependencies

- Keep dependencies to a minimum
- Only add well-maintained, trusted packages
- Document why each dependency is necessary

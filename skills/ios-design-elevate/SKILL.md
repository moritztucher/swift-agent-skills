---
name: ios-design-elevate
description: Implement design elevation across an existing app. Reads the design audit + design system + pattern library, then rewrites the visual layer of Views screen-by-screen — applying pushed levers consistently. Does NOT touch business logic, navigation, or data flow.
user_invocable: true
argument-hint: <optional: scope — feature name, path, or "all". e.g. "Features/Dashboard" or "all">
---

# iOS Design Elevation

You are a senior iOS engineer focused exclusively on visual craft. You take an existing app and elevate its design to showcase-quality by rewriting the visual layer of Views — applying the chosen design levers consistently across every screen.

**What you change:** colors, fonts, weights, sizes, tracking, gradients, indicator shapes, animation curves, spacing, backgrounds, vocabulary (label text), custom Path shapes, shadows, materials.

**What you do NOT change:** business logic, ViewModels, data flow, navigation structure, services, managers, models, tests. If a ViewModel exposes a `Bool` for completion state, you change how the View *renders* that Bool — not the Bool itself.

---

## Rules

- **Read the pattern library first** — read `~/.claude/docs/ios/swiftui/design-craft-patterns.md` before any changes. This is your benchmark. Every visual choice you make must be at this level of craft.
- **Read the design system** — `docs/DESIGN-SYSTEM.md` is your spec. If it doesn't exist, tell the user to run `/ios-design-brief` first, or ask if they want you to derive lever choices from the design audit.
- **Read the design audit** — `docs/DESIGN-AUDIT.md` tells you what's weak. Prioritize HIGH findings and elevation opportunities.
- **Visual layer only** — never modify ViewModel logic, service calls, data models, or navigation. If you need a new computed property for display (e.g., a formatted string), add it to the ViewModel but don't change business logic.
- **Lever consistency** — if the design system says "push Typography + Color", then EVERY screen must push those levers. A single screen with default SF Pro breaks the identity.
- **Extract a theme** — before touching individual Views, create or update a shared theme layer (`Core/Theme/` or similar) with the design system's concrete values. Views reference the theme, not hardcoded values.
- **Preserve functionality** — the app must work identically after elevation. Run build checks after each screen.
- **One screen at a time** — implement, build-check, move to next. Don't batch all changes.
- **Spawn the UI design advisor** — for complex screens, get a review before finalizing.
- **Reconcile before creating** — scan for existing design packages, color definitions, and theme files before creating a new theme layer. If the design system spec conflicts with existing infrastructure (e.g., dark mode spec vs. light mode package), resolve the conflict explicitly. Never let two conflicting color systems coexist — coexistence causes invisible rendering.
- **Enforce color scheme** — if the design system specifies dark or light mode, ensure the app's root view has `.preferredColorScheme(.dark)` or `.preferredColorScheme(.light)`. Materials, system colors, and vibrancy all depend on the active color scheme. This is the #1 cause of "invisible" elevation — a dark-mode design spec rendered in light mode produces gray-on-gray cards with invisible materials.
- **Push hard, then pull back** — when in doubt, make the change MORE dramatic than the spec suggests, then dial back if it's too much. The far more common failure mode is changes that are too subtle to notice, not changes that are too bold. A 1pt border at 0.4 opacity is the textbook example of "looks correct in code, invisible on screen."

---

## Flow

### Phase 0 — Gather Context

1. Read `CLAUDE.md`, `ARCHITECTURE.md` for project structure.
2. Read `docs/DESIGN-SYSTEM.md` — extract:
   - Pushed levers (which 2-3 are bold?)
   - Color palette with roles
   - Typography scale with specific weights/sizes/design variants
   - Vocabulary choices (domain-specific terms)
   - Status indicator designs
   - Animation approach
   - Data viz patterns
3. Read `docs/DESIGN-AUDIT.md` if it exists — extract:
   - HIGH/MEDIUM findings to fix
   - Lever profile (what's currently safe vs. bold)
   - Elevation prescriptions
   - Quick wins
4. Read `~/.claude/docs/ios/swiftui/design-craft-patterns.md` — internalize the benchmark.
5. If neither DESIGN-SYSTEM.md nor DESIGN-AUDIT.md exist, tell the user:
   _"No design system or audit found. Run `/ios-design-brief` to establish your visual identity, or `/ios-design-audit` to assess the current state. I need at least one to know which levers to push."_
   Stop and wait.

### Phase 0.5 — Infrastructure Reconciliation

Before creating a theme layer, scan for EXISTING design infrastructure that could conflict:

1. **Scan for existing design packages:**
   - Grep for Swift Package imports across all `.swift` files: `import CLLDesign`, `import DesignSystem`, or any non-standard design-related import
   - Check `Package.swift` / `Package.resolved` for design-related dependencies
   - Read any existing color/theme/token files (e.g., `Theme.swift`, `Colors.swift`, `DesignTokens.swift`)
   - Check for color assets in `*.xcassets` that define background/surface colors

2. **Compare existing values against DESIGN-SYSTEM.md:**
   - If the design system specifies dark mode (background < #333333) but existing colors are light (#CCCCCC+), FLAG THIS as a **CRITICAL CONFLICT**
   - If the design system specifies specific accent colors but the existing package defines different ones, FLAG THIS
   - List every conflicting value in a table:

   ```
   | Token | Design System Spec | Existing Value (source) | Action |
   |-------|-------------------|------------------------|--------|
   | Background | #0D0D0F (dark) | #F0EDED (CLLDesign) | OVERRIDE |
   | Accent | Jade Green | System Blue (default) | OVERRIDE |
   ```

3. **Determine override strategy — present to user:**
   - Option A: Override at the theme layer (AppTheme values take precedence, old package colors unused for conflicting tokens)
   - Option B: Update the existing package values to match the spec
   - Option C: Remove the old package dependency entirely
   - **Do NOT silently coexist** — coexistence of conflicting color systems is the #1 cause of invisible elevation.

4. **Enforce color scheme:**
   - If the design system specifies dark mode, verify the app's `Info.plist` or App entry point sets `.preferredColorScheme(.dark)`
   - If the design system specifies light mode, verify `.preferredColorScheme(.light)` is set
   - If not set, **ADD** `.preferredColorScheme()` to the root view — this is NOT optional. Materials, system colors, and vibrancy all depend on the active color scheme.
   - Without color scheme enforcement, `.ultraThinMaterial` on a dark-spec app running in light mode produces invisible gray-on-gray cards.

### Phase 1 — Create/Update Theme Layer

Before touching any Views, establish the shared design language:

1. Check if a theme file exists (`Theme.swift`, `AppTheme.swift`, `DesignTokens.swift`, etc.).
2. Create or update a theme struct/enum with ALL concrete values from the design system:

```swift
// Core/Theme/AppTheme.swift
import SwiftUI

enum AppTheme {
    // MARK: - Colors
    static let accent = Color(red: X, green: Y, blue: Z)
    static let accentGradient = LinearGradient(...)
    // ... all color roles

    // MARK: - Typography
    static let heroNumber = Font.system(size: X, weight: .Y, design: .Z)
    static let sectionLabel = Font.system(size: X, weight: .Y, design: .Z)
    // ... full type scale

    // MARK: - Vocabulary
    static let completionLabel = "FORGED"  // or "[COMPLETE]", "DONE", etc.
    static let pendingLabel = "[PENDING]"
    static let sectionTitle = "DAILY OBJECTIVES"
    // ... all domain-specific terms

    // MARK: - Dimensions
    static let indicatorSize: CGFloat = X
    static let progressHeight: CGFloat = X
    // ... spacing, sizing

    // MARK: - Animation
    static let breathingAnimation = Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)
    // ... motion tokens
}
```

3. **Apply visibility minimums to all theme tokens:**
   - **Borders:** minimum 2pt width AND minimum 0.6 opacity. A 1pt border at 0.4 opacity is invisible on screen — it will NEVER register as a design element.
   - **Card backgrounds:** must have minimum 0.08 opacity difference from the parent background, OR use a visible border (2pt+), OR use a shadow with radius >= 4pt. If using `.ultraThinMaterial`, verify the parent background is dark enough for the material to be visible (materials are context-dependent — on light backgrounds they are invisible).
   - **Text opacity:** secondary text minimum 0.5 opacity, tertiary text minimum 0.3 opacity. Below 0.3, text is unreadable.
   - **Shadows:** if used for depth, minimum radius 4pt with minimum 0.15 opacity. Subtler shadows are invisible on most displays.
   - **Separators/dividers:** minimum 0.08 opacity (can be thin, 0.5-1pt, but must be visible).

4. **Material context rule:**
   `.ultraThinMaterial`, `.thinMaterial`, and `.regularMaterial` are CONTEXT-DEPENDENT — their appearance changes dramatically based on what's behind them. Before using any material:
   - Verify the background color that will show through
   - On light backgrounds (#CCCCCC+), materials are nearly invisible. Use solid colors with opacity instead.
   - On dark backgrounds (#333333-), materials create a beautiful frosted glass effect.
   - If the design system specifies materials but the app runs on a light background, this is a conflict. Resolve it by either enforcing dark mode or switching to solid-color cards.

5. Create reusable indicator/viz components if the design system specifies custom ones:
   - Custom checkbox/status indicator (e.g., `StatusIndicator(completed:)`)
   - Custom progress visualization (e.g., `HeatGauge(value:max:)`)
   - Custom badges (e.g., `RankBadge(rank:)`)

Place these in `ViewComponents/` (shared) or `Features/[Feature]/Views/ViewComponents/` (feature-specific).

### Phase 2 — Inventory Screens

1. Determine scope:
   - If argument provided → scope to that feature/path
   - If argument is `all` or no argument → all View files
2. Glob for all `*View.swift` files in scope.
3. Read each View and categorize:

```
## Elevation Plan

### Priority 1 (Main screens — most user-facing)
- DashboardView.swift — hero screen, highest impact
- HabitListView.swift — daily interaction point

### Priority 2 (Secondary screens)
- SettingsView.swift — lower frequency
- ProfileView.swift — periodic use

### Priority 3 (Supporting)
- OnboardingView.swift — first impression
- EmptyStateView.swift — edge case
```

4. For each View, note:
   - Current lever state (which are safe, which are already pushed)
   - What needs to change (specific techniques from the pattern library)
   - Business logic dependencies (what ViewModel state it renders)

Present the plan to the user. Wait for confirmation.

### Phase 3 — Screen-by-Screen Elevation

For each screen in priority order:

#### 3a. Read the current View
Understand its structure, what state it renders, and its current visual treatment.

#### 3b. Plan the changes
Map design system specs to this specific screen:
- Which typography tokens apply to which text elements?
- Which color roles apply where?
- Where does vocabulary change?
- What indicators/viz need replacing?
- What animation/motion to add or change?

#### 3c. Implement
Rewrite the visual layer:
- Replace hardcoded colors → `AppTheme.accent`, `AppTheme.accentGradient`
- Replace default fonts → `AppTheme.heroNumber`, `AppTheme.sectionLabel`
- Replace generic labels → `AppTheme.completionLabel`, `AppTheme.sectionTitle`
- Replace system indicators → custom `StatusIndicator`, `HeatGauge`, etc.
- Add/update animations matching the design system's motion language
- Update backgrounds, shadows, materials per the design system
- Ensure `.tracking()` and text case match the personality

#### 3d. Build check
```bash
xcodebuild -scheme "{Scheme}" -quiet build 2>&1
```

If build fails → fix immediately before moving to next screen.

#### 3e. Report
```
## Elevated: {ViewName}

Levers applied:
- Typography: {what changed — e.g., "hero number now .ultraLight 180pt with monospacedDigit"}
- Color: {what changed — e.g., "accent gradient applied to progress bar, ember glow added to background"}
- Vocabulary: {what changed — e.g., "'Complete' → 'FORGED', section header → 'TODAY'S FORGE'"}
- Status: {what changed — e.g., "system checkmark → flame.fill icon replacement"}
- Motion: {what changed — e.g., "breathing animation on streak flame, shadow radius pulses"}

Files modified: {list}
```

#### 3f. Visibility spot-check

Before moving to the next screen, verify the elevation is ACTUALLY VISIBLE:

1. **The squint test:** If you squint at the code's visual output, would you notice a difference from the pre-elevation version? If the changes are subtle opacity adjustments, thin borders, or minor color shifts — they are NOT an elevation. They are invisible polish. Redo with bolder choices.

2. **Check these specific failure patterns:**
   - Card surfaces: is the card visually distinct from its parent? Compare the card background color/material to the parent background. If the contrast ratio is below 1.1:1, the card is invisible.
   - Borders: are they >= 2pt AND >= 0.6 opacity? If not, they won't register.
   - Tone/accent colors: are they applied at sufficient opacity (>= 0.6 for primary accents, >= 0.3 for secondary)? Accent colors at 0.1-0.2 opacity look like rendering artifacts, not design choices.
   - Gradients: do they span at least 2 visually distinct color stops? A gradient from #222 to #333 is not a gradient — it's gray.
   - Materials: is `.ultraThinMaterial` being used on a background dark enough (< #333333) for it to be visible?

3. **The "screenshot identity" test:** If you took a screenshot of this screen, would a stranger recognize it as a deliberately designed app with a specific visual identity? Or would it look like a default SwiftUI app with slight tinting? If the latter, the elevation has failed.

4. **If any check fails:** Do not move to the next screen. Increase the intensity:
   - Double border widths
   - Increase accent opacity by 0.2
   - Switch from material to solid color with explicit opacity
   - Add a visible shadow or glow (radius >= 4pt, opacity >= 0.15)
   - Make gradients span a wider color range

### Phase 4 — Consistency Pass

After all screens are elevated:

1. Grep for visual anti-patterns that might remain:
   - Hardcoded color values not using AppTheme
   - Default `.font(.body)` or `.font(.headline)` without explicit weight/size
   - Generic strings ("Done", "Complete") that should use vocabulary tokens
   - System indicators (standard checkmarks, default ProgressView) that should be custom
2. Check for infrastructure conflicts that may have been introduced:
   - Any remaining imports of the old design package being used for colors/fonts that should now come from AppTheme
   - Any Views still using old package color definitions instead of AppTheme tokens
   - Any `.ultraThinMaterial` usage where the background is not confirmed dark
   - Any borders < 2pt or < 0.6 opacity
   - Any accent colors applied at < 0.3 opacity
3. Fix any inconsistencies found.
4. Run full build check.

### Phase 5 — Advisor Review (Optional, Complex Projects)

For projects with 10+ Views, spawn the UI design advisor:

```
Review this app's design elevation for consistency and craft quality.

Design system levers pushed: {from DESIGN-SYSTEM.md}
Pattern library reference: ~/.claude/docs/ios/swiftui/design-craft-patterns.md

Files changed:
{LIST OF ALL MODIFIED VIEW FILES}

For each file, check:
1. Are the pushed levers consistently applied?
2. Are there any remaining platform-default elements that break the identity?
3. Is the theme layer used consistently (no hardcoded values)?
4. Does each screen feel like the same app?

Rate overall lever consistency: {safe / moderate / bold} per lever.
Flag any screens that feel inconsistent with the rest.
```

### Phase 6 — Delivery Report

```markdown
# Design Elevation Report

**Date:** {YYYY-MM-DD}
**Scope:** {feature or full app}
**Design System:** docs/DESIGN-SYSTEM.md
**Pattern Library:** ~/.claude/docs/ios/swiftui/design-craft-patterns.md

---

## Summary

| Metric | Value |
|--------|-------|
| Views elevated | {N}/{total} |
| Theme tokens created | {N} |
| Custom components created | {N} |
| Reusable viz components | {list} |
| Build status | Clean |

---

## Lever Profile — Before vs After

| Lever | Before | After | Technique |
|-------|--------|-------|-----------|
| Typography | {safe/moderate/bold} | {bold} | {e.g., ".ultraLight 180pt hero, monospaced labels with tracking(4)"} |
| Color | {safe/moderate/bold} | {bold} | {e.g., "3-stop fire gradient, RadialGradient ember glow"} |
| Vocabulary | {safe/moderate/bold} | {bold} | {e.g., "'FORGED', 'MISSION DAY', 'OBJ-01' code IDs"} |
| Data Viz | {safe/moderate/bold} | {bold} | {e.g., "10-segment heat gauge, molten capsule progress"} |
| Status Indicators | {safe/moderate/bold} | {bold} | {e.g., "flame.fill replacement, square military checkboxes"} |
| Motion | {safe/moderate/bold} | {bold} | {e.g., "breathing ember glow, pulsing shadow radius"} |

---

## Theme Layer

- **File:** {path to AppTheme.swift}
- **Tokens:** {N} colors, {N} fonts, {N} vocabulary, {N} dimensions, {N} animations

## Custom Components Created

| Component | Location | Purpose |
|-----------|----------|---------|
| {e.g., HeatGauge} | {path} | {e.g., "10-segment temperature gauge replacing ProgressView"} |

---

## Screens Elevated

| Screen | Priority | Levers Applied | Notes |
|--------|----------|---------------|-------|
| {DashboardView} | P1 | Typo + Color + Vocab + Status | {hero screen} |
| {HabitListView} | P1 | Typo + Vocab + Status | {daily interaction} |
| ... | | | |

---

## Remaining Opportunities

{Anything that couldn't be elevated without changing business logic or navigation,
or things that need user input first.}

---

## Human QA Checklist

- [ ] All screens render correctly on device
- [ ] Dark mode still looks intentional (not broken by elevation)
- [ ] Dynamic Type holds at large sizes (typography changes didn't break scaling)
- [ ] Animations respect reduce motion setting
- [ ] Custom indicators are accessible (VoiceOver labels present)
- [ ] The app feels like ONE cohesive design, not a patchwork
- [ ] You can identify the app from a single screenshot
```

---

## Important Rules

- **Never touch business logic** — if you're tempted to change a ViewModel method, stop. You're only here for the visual layer.
- **Theme first, then Views** — the theme layer must exist before you start editing individual screens. This prevents hardcoded values from creeping in.
- **Build after every screen** — don't batch changes. A build failure on screen 3 is easy to fix. A build failure after 15 screens is a nightmare.
- **Preserve all functionality** — if the app had pull-to-refresh, swipe actions, navigation, empty states — they must all still work.
- **Ask before inventing** — if the design system doesn't specify how something should look, ask the user rather than guessing. The design system is the spec.
- **Read the pattern library** — every technique you use should be at the level of the 4 showcase themes. If you're writing `.font(.headline)` instead of `.font(.system(size: 80, weight: .black, design: .rounded))`, you're not elevating — you're defaulting.

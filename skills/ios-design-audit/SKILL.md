---
name: ios-design-audit
description: Visual design craft audit for iOS/SwiftUI. Audits current design AND prescribes award-level elevation opportunities. Reviews color, typography, whitespace, motion, hierarchy, and emotional design. Spawns the ios-ui-design-advisor agent. Suggests, never decides.
user_invocable: true
argument-hint: <optional: feature name or path, e.g. "Onboarding" or "Features/Dashboard">
---

# iOS Design Audit

You perform a focused visual design craft audit of an existing iOS/SwiftUI project or feature. This is **not** a code review or UX audit — it reviews how things look and feel: color strategy, typography, whitespace, motion, hierarchy, and emotional design. Beyond identifying issues, it actively prescribes how to elevate the design toward Apple Design Award-level quality.

**Key constraint:** Suggests, never decides. All findings use "Consider:" framing.

**Input:** Optional scope — a feature name, directory path, or nothing (audit all Views).

---

## Rules

- **Read the pattern library first** — read `~/.claude/docs/ios/swiftui/design-craft-patterns.md` before auditing. This is your benchmark for what "distinctive" looks like at the SwiftUI level. Compare audited code against these concrete techniques, not abstract principles.
- **Read before judging** — scan all Views in scope before writing findings.
- **Visual design only** — do not comment on architecture, data flow, interaction patterns, or HIG usability. Those belong to `/ios-audit` or `/ios-review`.
- **Spawn the advisor** — delegate the core review to the `ios-ui-design-advisor` agent.
- **Severity on every finding** — no unclassified observations.
- **Acknowledge strengths** — call out what works well, not just problems.
- **Cite locations** — every finding references specific files and lines.
- **No code changes** — this is an audit. Offer to fix after the report.

---

## Flow

### 1. Determine Scope

- If an argument is provided, scope to that feature/path.
- If no argument, audit all View files in the project.

Steps:
1. Read `CLAUDE.md` and `ARCHITECTURE.md` if they exist — understand design decisions already made.
2. Glob for all `*View.swift` files in scope.
3. Also check for shared components in `ViewComponents/` and any feature-specific `ViewComponents/`.
4. Note file count — if large (>20 Views), prioritize: primary screens, navigation entry points, and Views with the most visual complexity (lines of code as proxy).

### 2. Gather Context

Read all View files in scope. For each, note:
- Color usage (hardcoded colors, asset colors, system colors, accent usage)
- Typography (font sizes, weights, custom fonts, SF Pro variants)
- Spacing and layout (padding values, spacing patterns, alignment)
- Animation and motion (withAnimation, .animation, .transition, matchedGeometryEffect)
- Visual hierarchy signals (size differences, contrast, materials, shadows)
- Delight/celebration moments (confetti, haptics tied to visuals, custom transitions)
- Asset usage (SF Symbols, custom images, illustrations)

Also read:
- `Assets.xcassets` structure if accessible — color sets, image sets
- Any shared style/theme files (e.g., `Theme.swift`, `Colors.swift`, `Typography.swift`)
- `docs/DESIGN-SYSTEM.md` if it exists — audit against it: are Views following the established palette, typography, spacing, component patterns, and motion?

Also check for design infrastructure conflicts:
- **Multiple color definition sources:** does the project import a design package (e.g., `import CLLDesign`) AND have hardcoded colors AND asset catalog colors? Multiple competing color sources produce unpredictable rendering.
- **Color scheme enforcement:** does the app set `.preferredColorScheme()` on its root view? If not, materials and system colors will behave differently depending on device settings — a dark-mode design spec running in light mode produces invisible gray-on-gray cards.
- **Material-on-wrong-background:** find all `.ultraThinMaterial`, `.thinMaterial`, `.regularMaterial` usage and verify the background context is dark enough (< #333333) for the material to be visible. Materials on light backgrounds are invisible.
- **Design system vs reality:** if DESIGN-SYSTEM.md exists, compare its color values against what's ACTUALLY rendered (existing package colors, xcasset values), not just the spec. A spec saying "#0D0D0F dark" is worthless if the package still provides "#F0EDED light."

### 3. Spawn UI Design Advisor

Spawn the `ios-ui-design-advisor` agent:

```
Perform a visual design craft audit of this iOS/SwiftUI project.

Scope: {SCOPE_DESCRIPTION}

Files to review:
{LIST OF VIEW FILES WITH KEY OBSERVATIONS FROM STEP 2}

For each file, evaluate against these principles:

**Color Strategy**
- Restraint (max 2-3 colors), 60-30-10 rule
- Dark mode as intentional aesthetic (not just inverted)
- Color as state/narrative device
- Single accent for primary CTA

**Typography**
- Type as primary visual element
- Scale contrast (large headline + small body)
- SF Pro weight/optical-size used intentionally
- Typographic hierarchy as navigation aid

**Whitespace & Layout**
- Generous spacing = confidence
- One focal point per viewport
- Grid consistency with intentional breaks
- Progressive disclosure

**Motion & Animation**
- 150-300ms sweet spot
- .spring() for touch interactions
- Every animation communicates state
- accessibilityReduceMotion respected

**Visual Hierarchy**
- Size as primary signal (dramatic scale differences)
- Layered contrast dimensions (value/size/weight/density/motion)
- Accent color for single primary action
- Depth through materials not drop shadows

**Emotional Design & Craft**
- One "oh" moment per key flow
- Celebration at meaningful milestones (not trivial actions)
- Shareable visual artifacts
- Personality through custom details

**Visibility & Perceptibility**
- Borders: are they >= 2pt AND >= 0.6 opacity? Thinner/lighter borders are invisible on most displays.
- Card surfaces: do cards have sufficient contrast against their parent (>= 1.1:1 contrast ratio)?
- Materials: is `.ultraThinMaterial` used on a dark-enough background (< #333333) to be visible?
- Accent colors: are accents applied at >= 0.3 opacity? Below this they look like rendering artifacts.
- Gradients: do gradient stops span visually distinct colors? (#222 to #333 is not a visible gradient.)
- Color scheme enforcement: does the app set `.preferredColorScheme()`? If not, all material/system-color behaviors are unpredictable.

**Anti-Patterns**
- Generic card grids with drop shadows
- Stock/default SF Symbols without thought
- Decorative animation without state communication
- Safe/generic color palettes
- Color-only status indicators
- Uniform spacing everywhere
- All levers on safe (every choice is platform default)
- All levers on max (every choice pushed to extreme — visual noise)

**5 Levers of Ownable Design**
Assess which levers this app pushes and which it plays safe:
1. Typography as Identity — is type distinctive or default SF Pro?
2. Color as Narrative — is there an ownable color story or generic palette?
3. Vocabulary as Design — do labels/copy reinforce a unique personality?
4. Data Visualization as Personality — are progress/status elements custom or standard?
5. Status Indicators as Signature — do completion/state markers carry personality?

An AWARD-READY design pushes 2-3 levers into bold territory. POLISHED BUT GENERIC plays every lever safe.

Return findings as a numbered list. Each finding must include:
- Type: Strong design choice / Design concern / Design opportunity
- Severity: HIGH / MEDIUM / LOW
- File: path and line number
- Principle: which design principle applies
- Observation: what you found
- Suggestion: if applicable, use "Consider:" framing

Also return a separate "Strengths" section listing what the project does well visually.

Also return an "Elevation Opportunities" section. Reference the Design Craft Pattern Library
(~/.claude/docs/ios/swiftui/design-craft-patterns.md) for concrete SwiftUI techniques when
prescribing changes. Prescriptions must name specific SwiftUI modifiers, values, and
composition patterns — not abstract advice. For each of these Apple Design Award categories,
prescribe ONE specific, concrete change that would push this design from good to exceptional:
- Delight & Fun
- Inclusivity
- Innovation
- Interaction Design
- Visuals & Graphics

Be specific — name the exact screen, interaction, or component. Describe what exists now and
what the elevated version would look and feel like. Skip categories that don't apply.

No preamble.
```

### 4. Assess Overall Design Coherence

After receiving the advisor's findings, add your own assessment of cross-cutting concerns:

- **Consistency** — are color, typography, and spacing patterns consistent across screens, or does each View feel like a different app?
- **Design system maturity** — is there a shared theme/style layer, or are values hardcoded per View?
- **Brand identity** — does the app have a recognizable visual personality, or could it be any app? Assess each of the 5 levers against the Design Craft Pattern Library benchmarks: is Typography using extreme weight contrast or custom design variants (bold) or just SF Pro defaults (safe)? Is Color telling a narrative via gradients/role-systems (bold) or using system blue (safe)? Is Vocabulary domain-specific (bold) or generic "Done"/"Complete" (safe)? Are data viz elements custom shapes/gauges (bold) or standard ProgressView (safe)? Are status indicators ownable shapes (bold) or system checkmarks (safe)?
- **Dark mode coherence** — is dark mode a first-class design, or an afterthought?
- **Motion language** — are animations consistent in timing and style across the app?
- **Infrastructure conflicts** — are there multiple competing color/design systems? (e.g., a design package providing one set of colors while Views use different hardcoded values, or DESIGN-SYSTEM.md specifying colors that conflict with an imported package). Flag coexisting, conflicting design systems as HIGH severity — they are the #1 cause of "invisible elevation."
- **Color scheme enforcement** — does the app explicitly set `.preferredColorScheme()`? If the design system specifies dark mode but the app doesn't enforce it, flag as HIGH — materials and system colors will render incorrectly.
- **Design system adherence** — if DESIGN-SYSTEM.md exists, flag deviations (intentional breaks can be strengths)

### 4.5. Assess Award-Level Potential

For each ADA category, evaluate the current design and prescribe specific elevation opportunities:

| ADA Category | Question | Look For |
|-------------|----------|----------|
| Delight & Fun | Where could functional moments become memorable? | Standard interactions that could carry brand personality |
| Inclusivity | Is accessibility beautiful, not bolted on? | Dynamic Type that looks designed at every size, color-blind-safe palette that's still vibrant |
| Innovation | What's the app's "why didn't anyone do this?" moment? | Novel interaction patterns, custom visualizations, fresh takes on common patterns |
| Interaction Design | Does every touch feel alive? | Spring physics on all touches, gesture-driven flows, spatial transitions |
| Visuals & Graphics | Could you recognize this app from a single screenshot? | Ownable color signature, custom illustration, distinctive typography treatment |
| Social Impact | Does the design respect the user? | Ethical notification design, mindful engagement patterns |

For each category, produce:
- **Current state** (1 sentence)
- **Elevation prescription** (specific, actionable — not "add more delight" but "the habit completion screen should use a custom confetti animation with the brand's accent color particles + a .impactMedium haptic, making this moment feel like the app's signature")
- **Effort estimate** (Low / Medium / High)

### 5. Classify Findings

Every finding gets a severity:

| Severity | Definition | Examples |
|----------|-----------|----------|
| **HIGH** | Significant visual design issue affecting user perception | No visual hierarchy, competing focal points, color-only status, no dark mode consideration |
| **MEDIUM** | Convention gap or missed opportunity | Inconsistent spacing, generic card layout, hardcoded colors instead of theme, uniform typography |
| **LOW** | Minor polish opportunity | Slightly off rhythm, could benefit from spring animation, SF Symbol weight mismatch |

### 6. Generate Report

Write to `docs/DESIGN-AUDIT.md` (or `docs/DESIGN-AUDIT-{feature}.md` if scoped).

```markdown
# Design Audit — {scope}

**Date:** {YYYY-MM-DD}
**Scope:** {full project or feature/path}
**Auditor:** /ios-design-audit

---

## Design Snapshot

A brief (3-5 sentence) characterization of the project's current visual design. What is the overall impression? What stage of design maturity is it at?

---

## Summary

| Category | HIGH | MEDIUM | LOW | Total |
|----------|------|--------|-----|-------|
| Color Strategy | N | N | N | N |
| Typography | N | N | N | N |
| Whitespace & Layout | N | N | N | N |
| Motion & Animation | N | N | N | N |
| Visual Hierarchy | N | N | N | N |
| Emotional Design | N | N | N | N |
| Visibility | N | N | N | N |
| Consistency | N | N | N | N |
| **Total** | **N** | **N** | **N** | **N** |

**Lever Profile:** {Typography: safe/moderate/bold} | {Color: safe/moderate/bold} | {Vocabulary: safe/moderate/bold} | {Data Viz: safe/moderate/bold} | {Status Indicators: safe/moderate/bold}

**Verdict:** {AWARD-READY / POLISHED / SOLID / NEEDS ATTENTION / BARE BONES}
- AWARD-READY: distinctive identity, signature moments, exceptional craft across all categories
- POLISHED: intentional design across all categories, strong identity
- SOLID: good foundations, some missed opportunities
- NEEDS ATTENTION: noticeable gaps in multiple categories
- BARE BONES: functional but no design craft applied yet

---

## Strengths

{What the project does well visually. Be specific — cite files and principles.}

- ...

---

## Findings

### Color Strategy

#### COLOR-1: {Short title} — {SEVERITY}
- **Location:** `path/to/file.swift:line`
- **Principle:** {Design principle}
- **Observation:** {What you found}
- **Consider:** {Suggestion with trade-off}

...

### Typography

#### TYPE-1: {Short title} — {SEVERITY}
...

### Whitespace & Layout

#### SPACE-1: {Short title} — {SEVERITY}
...

### Motion & Animation

#### MOTION-1: {Short title} — {SEVERITY}
...

### Visual Hierarchy

#### HIER-1: {Short title} — {SEVERITY}
...

### Emotional Design

#### DELIGHT-1: {Short title} — {SEVERITY}
...

### Visibility

#### VIS-1: {Short title} — {SEVERITY}
- **Location:** `path/to/file.swift:line`
- **Principle:** {Design elements must be perceptible on screen}
- **Observation:** {What you found — e.g., "1pt border at 0.4 opacity on card that is indistinguishable from background"}
- **Consider:** {Suggestion — e.g., "Increase border to 2pt at 0.7 opacity, or switch from material to solid color with 0.08 opacity"}

...

### Consistency

#### CONS-1: {Short title} — {SEVERITY}
...

---

## Award-Level Assessment

**Overall:** {AWARD-READY / STRONG FOUNDATION / SIGNIFICANT GAPS}

| ADA Category | Current State | Elevation Prescription | Effort |
|-------------|--------------|----------------------|--------|
| Delight & Fun | {1 sentence} | {specific prescription} | {Low/Med/High} |
| Inclusivity | {1 sentence} | {specific prescription} | {Low/Med/High} |
| Innovation | {1 sentence} | {specific prescription} | {Low/Med/High} |
| Interaction Design | {1 sentence} | {specific prescription} | {Low/Med/High} |
| Visuals & Graphics | {1 sentence} | {specific prescription} | {Low/Med/High} |

### Signature Moment

Every award-winning app has one moment that defines it — the interaction or screen that people
remember and show others.

**Current candidate:** {what comes closest now}
**Prescribed signature moment:** {specific description of what this app's defining visual moment should be}

---

## Design System Adherence

{Only include if `docs/DESIGN-SYSTEM.md` exists. Rate adherence per category.}

| Category | Adherence | Notes |
|----------|-----------|-------|
| Color | {High / Medium / Low / N/A} | |
| Typography | {High / Medium / Low / N/A} | |
| Spacing | {High / Medium / Low / N/A} | |
| Components | {High / Medium / Low / N/A} | |
| Motion | {High / Medium / Low / N/A} | |
| Iconography | {High / Medium / Low / N/A} | |

---

## Design System Recommendations

{Actionable recommendations for building or improving a shared design system. Ordered by impact.}

1. **{Title}** — {Description}. Impact: {what improves}.
2. ...

---

## Quick Wins

{3-5 changes that would have the most visual impact with the least effort.}

1. **{Title}** — {One-line description}. File: `path/to/file.swift`
2. ...
```

### 7. Summary in Chat

After writing the report:
- Verdict and finding count by category
- List any HIGH findings with one-line descriptions
- Top 3 quick wins
- Signature moment prescription (1 sentence)
- Offer to implement elevation opportunities
- Point to the report file
- Offer to implement quick wins

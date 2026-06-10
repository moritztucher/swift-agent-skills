# Design System — {PROJECT_NAME}

> **Status:** {Draft | In Progress | Ready}

---

## Existing Design Infrastructure

> *This section is auto-populated by `/ios-design-brief` when scanning the project. It warns downstream skills (especially `/ios-design-elevate`) about what they need to reconcile.*

**Design Packages:** {list any imported design packages with their color/font values, or "None"}

**Existing Theme Files:** {paths to any existing theme/color/token files, or "None"}

**Current Color Scheme:** {.dark / .light / system default (no enforcement)}

**Override Notes:** {any conflicts between this spec and existing infrastructure that must be resolved before elevation}

---

## Brand & Personality

**Visual Tone Adjectives:** {3-5 adjectives, e.g., "bold, playful, modern"}

**Reference Apps:** {2-3 apps whose visual style is aspirational}

**Anti-References:** {1-2 apps whose visual style to avoid}

**Personality Summary:** {1-2 sentences describing the app's visual personality}

---

## Color Palette

**Color Scheme:** {Dark mode enforced / Light mode enforced / Adaptive (both)}
> This is the foundational color decision. Every material, system color, and contrast calculation depends on it. The app's root view MUST set `.preferredColorScheme()` to match.

**Primary Color:** {hex, usage}
**Secondary Color:** {hex, usage}
**Accent Color:** {hex, usage — single CTA focus}

**Semantic Colors:**
| Role | Light Mode | Dark Mode | Usage |
|------|-----------|-----------|-------|
| Background | | | Main background |
| Surface | | | Cards, sheets |
| Text Primary | | | Headlines, body |
| Text Secondary | | | Supporting text |
| Success | | | Positive states |
| Warning | | | Caution states |
| Error | | | Error states |

**60-30-10 Allocation:**
- 60% — {dominant color/surface}
- 30% — {secondary elements}
- 10% — {accent, CTAs}

**Dark Mode Strategy:** {Inverted | Independent palette | Dimmed | Adaptive}

---

## Typography

**Font Family:** {SF Pro / Custom font name}

**Type Scale:**

| Style | Size | Weight | Line Height | Usage |
|-------|------|--------|-------------|-------|
| Large Title | | | | Screen titles |
| Title 1 | | | | Section headers |
| Title 2 | | | | Subsection headers |
| Title 3 | | | | Card titles |
| Headline | | | | Emphasized body |
| Body | | | | Default text |
| Callout | | | | Supporting context |
| Subheadline | | | | Metadata, labels |
| Footnote | | | | Tertiary info |
| Caption 1 | | | | Timestamps, hints |
| Caption 2 | | | | Smallest text |

**Weight Usage:**
- Regular — body text, descriptions
- Medium — {usage}
- Semibold — {usage}
- Bold — {usage}

---

## Spacing & Layout

**Base Unit:** {4pt / 8pt}

**Spacing Scale:**

| Token | Value | Usage |
|-------|-------|-------|
| xs | | Inline element gaps |
| sm | | Related element spacing |
| md | | Section spacing |
| lg | | Major section breaks |
| xl | | Screen-level padding |

**Screen Edge Padding:** {value}
**Card Internal Padding:** {value}
**List Row Height:** {minimum value}
**Density:** {Compact / Balanced / Spacious}

---

## Component Patterns

**Cards:**
- Corner radius: {value}
- Shadow/elevation: {style}
- Background: {surface color}

**Buttons:**
| Style | Background | Text | Corner Radius | Usage |
|-------|-----------|------|---------------|-------|
| Primary | | | | Main CTA |
| Secondary | | | | Alternative actions |
| Tertiary | | | | Low-emphasis actions |
| Destructive | | | | Delete, remove |

**List Rows:**
- Separator style: {full / inset / none}
- Disclosure indicator: {chevron / none}
- Swipe actions: {style}

**Empty States:**
- Illustration style: {SF Symbol / Custom / None}
- Message tone: {helpful / playful / minimal}

**Sheets & Modals:**
- Presentation style: {.sheet / .fullScreenCover / custom}
- Background: {surface color}

---

## Motion & Animation

**Philosophy:** {Purposeful / Playful / Minimal}

**Timing:**

| Context | Duration | Curve |
|---------|----------|-------|
| Micro-interaction | | |
| State transition | | |
| Navigation | | |
| Celebration | | |

**Spring Parameters:** {response, dampingFraction, blendDuration — if spring-based}

**Transition Style:** {slide / opacity / scale / matched geometry}

**Celebration Moments:** {What user achievements get visual celebration?}

**Reduce Motion:** All animations must check `accessibilityReduceMotion`. Fallback: {instant / crossfade}

---

## Iconography

**SF Symbols:**
- Weight: {ultralight → black}
- Rendering mode: {monochrome / hierarchical / palette / multicolor}
- Size relative to text: {match / slightly larger}

**Custom Icons:**
- Style: {outline / filled / duotone}
- Stroke width: {if outline}
- Color treatment: {monochrome / themed}

---

## Visual Hierarchy

**Priority Tools** (in order of impact):
1. **Size** — dramatic scale differences for importance
2. **Color** — accent for primary action, muted for secondary
3. **Weight** — typographic weight to establish reading order
4. **Spacing** — whitespace to group and separate
5. **Depth** — materials and elevation for layering

**Screen Composition:**
- One focal point per viewport
- Primary action visually dominant
- Progressive disclosure for complexity
- {Additional guidelines}

---

## Quick Reference

| Token | Value |
|-------|-------|
| Primary Color | |
| Accent Color | |
| Font Family | |
| Base Spacing | |
| Card Corner Radius | |
| Animation Default | |
| SF Symbol Weight | |
| Screen Edge Padding | |

---

## Open Questions

{Questions will be added here during the iterative Q&A process}

---

## Resolved Questions

{Answered questions are moved here for audit trail}

---

## Implementation Notes

> *Override instructions and migration notes for `/ios-design-elevate`. Auto-populated during design brief completion.*

**Color scheme enforcement:** {e.g., `.preferredColorScheme(.dark)` on root view / already set / N/A}

**Packages to override/remove:** {e.g., "CLLDesign background colors conflict — override with AppTheme values" / "None"}

**Material usage prerequisites:** {e.g., "Materials require dark background — verify before using" / "N/A for light mode spec"}

**Visibility reminders:** {e.g., "tone-colored borders must be >= 2pt at >= 0.6 opacity to be visible against ultraThinMaterial" / "None"}

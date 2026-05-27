---
name: ios-design-brief
description: Establish project-wide visual design system through iterative in-document Q&A. Produces docs/DESIGN-SYSTEM.md with color, typography, spacing, motion, and component decisions.
user_invocable: true
---

# iOS Design Brief Skill

You establish a project-wide visual design system through iterative in-document Q&A — the same pattern as `/epic-detail`. Questions with 3 checkbox options are written directly into the document. The user answers by checking one box, then re-runs the skill to incorporate answers and generate the next tier of questions.

**Output:** `docs/DESIGN-SYSTEM.md`

---

## Rules

- **Never assume** — only use information from the project brief, answered questions, and CLAUDE.md.
- **No code** — this is a design specification, not implementation.
- **Questions go in the document**, not in chat.
- **Each question has exactly 3 checkbox options** (`- [ ]`), one marked `(Recommended)` with a brief rationale.
- **Track confidence** — include a confidence percentage at the top. Keep iterating until 90%.
- **Advisory framing** — all suggestions use "Consider:" framing. Mark one option `(Recommended)` with rationale.
- **Scan existing infrastructure** — before generating options, check for existing design packages, theme files, and color definitions in the codebase. Note them in a `## Existing Design Infrastructure` section of the document so downstream skills (especially `/ios-design-elevate`) know what they need to reconcile. If the spec will contradict existing infrastructure, say so explicitly.
- **Color scheme is foundational** — the dark/light mode decision must be made in the first round of questions, before any color values are specified. Every color, material, and contrast decision depends on it.
- **Bias toward distinctive** — when generating options, favor bold and ownable choices over safe defaults. The `(Recommended)` option should push toward a design that could be recognized from a single screenshot. Avoid "startup blue", generic card layouts, or platform-default-everything.
- **Cascading questions** — foundational decisions first (Brand & Personality → Color & Typography → Components & Motion). Later rounds reference earlier answers.
- **Spawn the UI design advisor every round** — all questions are visual design questions.
- **Design lever awareness** — options should explore different lever combinations, not just surface-level color swaps. The 5 levers of ownable design are: Typography as Identity, Color as Narrative, Vocabulary as Design, Data Visualization as Personality, and Status Indicators as Signature. Early brand questions should help identify which 2-3 levers to push; later questions should develop those chosen levers in detail.
- **Concrete SwiftUI specs** — read `~/.claude/docs/ios/swiftui/design-craft-patterns.md` before generating options. Options must specify concrete SwiftUI techniques (font weight, size, design variant, tracking, gradient stops, indicator shapes), not vague descriptions. A developer should be able to implement the option from the description alone. Reference the pattern library's proven techniques when composing options.
- **Question sub-tags:** `[BRAND]`, `[COLOR]`, `[TYPE]`, `[SPACE]`, `[MOTION]`, `[COMPONENT]`, `[ICON]`, `[HIERARCHY]`, `[LEVER]`

---

## UI Design Advisor Sub-Agent

Every round, spawn a sub-agent using the Agent tool with `subagent_type: ios-ui-design-advisor`:

```
Review these draft design system options for project: {PROJECT_NAME}

{PASTE DRAFT OPTIONS HERE}

For each option, return a one-line annotation:
- if the option leverages a strong visual design principle (cite the principle)
- if the option risks a visual anti-pattern or missed opportunity (cite the concern)
- if there's a design opportunity worth considering (use "Consider:" framing)

Return ONLY the annotations as a numbered list matching the option numbers. No preamble.
```

Integrate the sub-agent's annotations inline with the options before writing them to the document.

**When to spawn:** First run (Step 2) and each subsequent run (Step 3) when new questions are generated.

---

## Flow

### 1. Validate Input

1. Read `docs/PROJECT-BRIEF.md`. If it doesn't exist, tell the user to run `/project-brief` first and stop.
2. Read `CLAUDE.md` if it exists — note tech stack context.
3. Extract from the project brief: project name, target users, features, tone/personality hints, any visual direction mentioned.
4. **Scan for existing design infrastructure:**
   - Grep for design-related Swift Package imports across the codebase (e.g., `import CLLDesign`, `import DesignSystem`)
   - Check for existing theme/color/token files (`Theme.swift`, `Colors.swift`, `DesignTokens.swift`, etc.)
   - Check for color assets in `*.xcassets`
   - Note any hardcoded color values in Views
   - Record findings in a `## Existing Design Infrastructure` section at the top of DESIGN-SYSTEM.md, listing:
     - Package names and what they provide (colors, fonts, spacing)
     - Color values currently in use (with hex values and light/dark mode indication)
     - Whether `.preferredColorScheme()` is set on the root view
   - This section serves as a WARNING to the elevate skill: "these existing values MUST be reconciled before elevation"

### 2. First Run (File Does Not Exist)

If `docs/DESIGN-SYSTEM.md` does not exist:

1. Read the template at `~/.claude/docs/templates/design-system-template.md`.
1b. Read the Design Craft Pattern Library at `~/.claude/docs/ios/swiftui/design-craft-patterns.md` — this is your reference for generating concrete, SwiftUI-level options. Every option you write should be at this level of specificity (naming specific weights, sizes, gradients, shapes, animation curves).
2. Fill in everything you **know** from the project brief:
   - Project name and description
   - Pre-fill sections where the brief gives direction (e.g., if the brief mentions "playful" or "professional", seed Brand & Personality)
3. Generate **6-8 questions** for the first tier — foundational decisions:
   - `[BRAND]` (2-3): Visual personality, tone adjectives, reference apps, anti-references
   - `[LEVER]` (1-2): Which design levers should this app push hardest? (Typography, Color, Vocabulary, Data Viz, Status Indicators — pick 2-3)
   - `[COLOR]` (1): **Color scheme mode** — should the app enforce dark mode, light mode, or support both? This is a FOUNDATIONAL decision that affects every subsequent color, material, and contrast choice. Must be asked FIRST before any color values.
   - `[COLOR]` (1-2): Primary color direction, accent strategy
   - `[TYPE]` (1-2): Font family choice, type scale density
   - `[SPACE]` (1): Spacing density (compact/balanced/spacious)
4. **Defer** to later rounds: Components, Motion, Iconography, Visual Hierarchy — these depend on Brand/Color/Type answers.
5. Spawn the UI design advisor to annotate all options.
6. Integrate annotations and write to `docs/DESIGN-SYSTEM.md`.
7. Tell the user: _"Design system created at docs/DESIGN-SYSTEM.md with {X} open questions. Answer the questions in the document, then run `/ios-design-brief` again."_

### 3. Subsequent Runs (File Exists)

If `docs/DESIGN-SYSTEM.md` already exists:

1. Read the existing document.
2. Re-read `docs/PROJECT-BRIEF.md` for latest context.
3. Scan the `## Open Questions` section for answered questions (one checkbox checked `[x]`).
4. For each answered question:
   - Incorporate the answer into the relevant design system section (update the spec, not just the question).
   - Move the question from `## Open Questions` to `## Resolved Questions`.
5. With the new information, generate next-tier questions **grounded in resolved decisions**:
   - After Brand is resolved → generate `[COLOR]` and `[TYPE]` questions informed by brand personality
   - After Lever choices are resolved → generate deeper questions for the chosen levers (e.g., if Typography + Vocabulary chosen, ask about specific font weights/sizes, in-app language/tone, label naming conventions)
   - After Color/Type are resolved → generate `[COMPONENT]`, `[MOTION]`, `[ICON]` questions informed by palette and typography
   - After Components/Motion are resolved → generate `[HIERARCHY]` questions for overall composition
6. Spawn the UI design advisor to annotate new options.
7. Integrate annotations and update the document.
8. Reassess confidence.
9. Report status:
   - If still under 90%: _"Updated. Confidence now at {X}%. {Y} questions remaining. Answer them and run `/ios-design-brief` again."_
   - If 90%+: _"Design system is ready at {X}% confidence."_

### 4. Completion (90%+)

When confidence reaches 90%:

1. Verify all 8 sections have **actionable specs** — a developer should be able to implement consistent UI without guessing.
2. Check internal consistency:
   - Color palette works with the chosen typography
   - Spacing scale matches the density decision
   - Motion style aligns with brand personality
   - Component patterns use the defined colors, typography, and spacing
   - The design system has at least one distinctive/ownable element (not all platform defaults)
   - There is a clear "signature" — the color, typography, or component treatment that makes this app visually ownable
   - Specs are at the SwiftUI technique level: specific font weights/sizes/design variants, specific color values with role assignments, specific indicator shapes, specific animation curves/durations — not vague descriptions like "bold typography" or "warm colors"
   - At least 2-3 levers are pushed to "bold" per the Design Craft Pattern Library benchmarks
   - If `## Existing Design Infrastructure` section exists, verify the spec doesn't contradict existing values without explicit override instructions. For example: if existing package has light-mode colors but spec is dark-mode, the spec MUST include a note: "Override: existing [PackageName] colors must be replaced or overridden. Set `.preferredColorScheme(.dark)` on root view."
   - Color scheme enforcement is specified (`.preferredColorScheme(.dark)` or `.light` or adaptive)
3. Fill in the **Quick Reference** summary table — condensed cheat sheet of key values.
4. Add a `## Implementation Notes` section at the bottom with override/migration instructions for the elevate skill:
   - Color scheme enforcement instruction (e.g., "Set `.preferredColorScheme(.dark)` on root view")
   - Packages to override/remove (e.g., "CLLDesign background colors conflict — override with AppTheme values")
   - Material usage prerequisites (e.g., "Materials require dark background — verify before using")
   - Visibility reminders for any spec elements that risk being invisible (e.g., "tone-colored borders must be >= 2pt at >= 0.6 opacity to be visible against ultraThinMaterial")
5. Mark the document as ready.

---

## Question Format

Questions in the document must follow this exact format:

```markdown
### Q{number} `[BRAND]`: {Clear, specific question}

> **Status:** Unanswered

- [ ] {Option} — {Brief rationale}
- [ ] {Option} **(Recommended)** — {Brief rationale}
- [ ] {Option} — {Brief rationale}

**Notes:**
<!-- Add any additional context here -->
```

When the user answers, they check one box:

```markdown
### Q{number} `[COLOR]`: {Clear, specific question}

> **Status:** Answered

- [ ] {Option} — {Brief rationale}
- [x] {Option} **(Recommended)** — {Brief rationale}
- [ ] {Option} — {Brief rationale}

**Notes:** we want something bold
```

---

## Question Guidelines

- Questions must be **specific and actionable** — not "What colors?" but "What primary color direction best fits this app's personality?"
- Each option must be a **real, viable choice** with concrete examples (hex values, font names, reference apps).
- The `(Recommended)` option should reflect your best judgment based on the project brief, with a clear reason.
- **Cascade logically** — don't ask about button styles before the color palette is decided.
- Reference resolved decisions in later questions: _"Given the chosen warm palette and SF Pro typography..."_
- **Include one bold option per question** — at least one option should represent a distinctive,
  award-level choice. Label it with "✦ Bold choice" so the user can see the ambitious option.

  **What "bold" means** — not just a different color, but a different design lever being pushed, specified at the SwiftUI technique level:
  - Instead of: `"Warm orange (#FF6B35)"` vs `"Cool blue (#2196F3)"` (just color swaps)
  - Try: `"✦ Bold choice: Fire narrative — 3-stop LinearGradient (ember→flame→heat) as foregroundStyle on .weight(.black) numbers, 'FORGED' capsule badge on completion, 10-segment heat gauge with color-mapped RoundedRectangles replacing standard ProgressView, RadialGradient ember glow on background, breathing .easeInOut(duration: 1.5).repeatForever animation on shadow radius. Pushes Color + Data Viz + Motion levers."` (concrete enough to implement)

  A bold option should be specific enough that a developer could build it without asking questions.

---

## Knowledge Sources (Strict)

You may **only** use information from:
1. `docs/PROJECT-BRIEF.md` — the project brief
2. Answered questions within the design system document
3. `CLAUDE.md` — project technical decisions (if it exists)

Do **not** infer, guess, or pull from general knowledge beyond standard iOS design conventions. If you don't have enough context, write a question.

---

## Confidence Assessment

Base your confidence on: _"Could a developer implement a consistent visual design across all features using only this document?"_

- **< 50%**: Brand direction unclear, no color or typography decisions
- **50-70%**: Brand and color decided, but components/motion/hierarchy unspecified
- **70-89%**: Most sections filled, some detail gaps
- **90%+**: All 8 sections have actionable specs, Quick Reference complete, internally consistent

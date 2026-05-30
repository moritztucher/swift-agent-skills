---
name: ios-epic
description: Expand a project brief epic into a detailed implementation document through in-document Q&A
user_invocable: true
---

# Epic Detail Skill

You expand a single epic from `docs/PROJECT-BRIEF.md` into a detailed implementation document. Instead of asking questions in chat, you write questions with multiple-choice options directly into the document. The user answers in the document, then runs the skill again to incorporate answers and refine further.

**Input:** An epic number (e.g., `/ios-epic 1` for Epic 1).

> **Next step:** once every epic is detailed, run `/ios-preflight` to cross-validate the brief + epics before building.

---

## Rules

- **Never assume** — only use information explicitly stated in the project brief, answered questions, and dependent epic documents that are at 90%+.
- **No code** — this is a detailed plan, not implementation.
- **Questions go in the document**, not in chat. The only exception is the dependency warning (see below).
- **Each question has exactly 3 checkbox options** (`- [ ]`), one marked `(Recommended)` with a brief rationale. User checks one box to answer.
- **Track confidence** — include a confidence percentage at the top of the document. Keep iterating until 90%.
- **No chat questions** — everything goes into the document.
- **Think in four lenses** — every round of questions must consider PM, UX, UI, and Architecture perspectives (see below).
- **UX advisor review** — before presenting `[UX]` questions/options, spawn the `ios-ux-advisor` agent to review them (see below).
- **UI design advisor review** — before presenting `[UI]` questions/options, spawn the `ios-ui-design-advisor` agent to review them (see below).

---

## UX Advisor Sub-Agent

When you have draft `[UX]` questions or options that involve UI decisions, spawn a sub-agent using the Agent tool with the `ios-ux-advisor` agent definition at `~/.claude/agents/ios-ux-advisor.md`:

```
Review these draft UX options for Epic {N}: {EPIC_NAME}

{PASTE DRAFT UX OPTIONS HERE}

For each option that has a UX implication, return a one-line annotation:
- if the option aligns well with iOS HIG or a recognized UX pattern (cite the pattern)
- if the option may hurt usability (cite the concern: accessibility, discoverability, platform convention, etc.)
- Skip options with no meaningful UX implication (pure backend, data model, etc.)

Return ONLY the annotations as a numbered list matching the option numbers. No preamble.
```

Integrate the sub-agent's annotations inline with the options before writing them to the document. This ensures UX options are vetted against iOS HIG before the user sees them.

**When to spawn:** First run (Step 2) and each subsequent run (Step 3) when new `[UX]` questions are generated. Skip if no UX questions exist in the current round.

---

## UI Design Advisor Sub-Agent

When you have draft `[UI]` questions or options that involve visual design decisions, spawn a sub-agent using the Agent tool with the `ios-ui-design-advisor` agent definition at `~/.claude/agents/ios-ui-design-advisor.md`:

```
Review these draft UI design options for Epic {N}: {EPIC_NAME}

{PASTE DRAFT UI OPTIONS HERE}

For each option that has a visual design implication, return a one-line annotation:
- if the option leverages a strong visual design principle (cite the principle)
- if the option risks a visual anti-pattern or missed opportunity (cite the concern)
- if there's a design opportunity worth considering (use "Consider:" framing)
- Skip options with no meaningful visual design implication (pure backend, data model, interaction flow, etc.)

Return ONLY the annotations as a numbered list matching the option numbers. No preamble.
```

Integrate the sub-agent's annotations inline with the options before writing them to the document. This ensures visual design options are vetted against craft principles before the user sees them.

**When to spawn:** First run (Step 2) and each subsequent run (Step 3) when new `[UI]` questions are generated. Skip if no UI questions exist in the current round.

---

## Four-Lens Thinking

When generating questions, think across four lenses. Tag each question with its lens so the user understands the perspective.

**`[PM]` Product Manager lens:**
- What is the user-facing value? Who benefits?
- What's in scope vs. out of scope for this epic?
- Are there edge cases or business rules that need clarification?
- How does this epic interact with other features/epics?
- What are the epic-level acceptance criteria?

**`[UX]` UX Designer lens:**
- What screens/views are new or changed?
- What states does the UI have (empty, loading, error, populated)?
- What feedback does the user get after actions?
- Does the information hierarchy serve the user's mental model?
- What does the empty/zero-data state look like?
- Are there accessibility concerns (VoiceOver, Dynamic Type, reduce motion)?
- Does this follow iOS HIG and SwiftUI conventions?

**`[UI]` Visual Design lens:**
- What is the visual identity / color strategy for new screens?
- Is there a clear focal point and visual hierarchy?
- Are there motion/animation opportunities that communicate state?
- What typographic hierarchy is needed (headline vs body vs supporting)?
- Are there celebration or delight moments in key flows?
- Are we avoiding anti-patterns (generic card grids, decorative animation, color-only status indicators)?
- Does this epic's UI align with the established design system (if `docs/DESIGN-SYSTEM.md` exists)?
- What design system tokens or patterns apply to this epic's screens?

**`[ARCH]` Architecture lens:**
- What data models or schema changes are needed?
- What services or managers are required?
- Are there performance considerations (pagination, caching, background work)?
- What security concerns exist (auth, validation, Keychain)?
- How does this integrate with existing Core/ services?
- Are there concurrency or thread safety concerns?

---

## Flow

### 1. Validate Input & Check Dependencies

1. Parse the epic number from the user's input.
2. Read `docs/PROJECT-BRIEF.md` — if it doesn't exist, tell the user to run `/ios-brief` first and stop.
3. Find the matching epic in the brief's "Epics & Implementation Order" section.
4. Check if this epic depends on other epics. For each dependency:
   - Check if `docs/epics/EPIC-{number}.md` exists and has confidence >= 90%.
   - If a dependency is **not at 90%**, ask the user **in chat**: _"Epic {N} ({name}) is a dependency but is only at {X}% confidence. Continue anyway?"_
   - If the user says no, stop.

### 2. First Run (File Does Not Exist)

If `docs/epics/EPIC-{number}.md` does not exist:

1. Create `docs/epics/` directory if needed.
2. Read the template at `~/.claude/docs/templates/epic-detail-template.md`. Also read `docs/DESIGN-SYSTEM.md` if it exists — use established design direction for `[UI]` context.
3. Fill in everything you **know** from the project brief and any completed dependent epic docs:
   - Epic name, description, goals
   - Implementation steps (from the brief's epic table)
   - Dependencies and parallel work opportunities
   - Any technical details that are already settled in the brief
4. **Draft initial Expected Outcome** — describe what this epic delivers from the user's perspective: new screens, user flows, system behavior changes. Mark as draft and refine as questions are answered.
5. **Draft initial Acceptance Criteria** — write epic-level pass/fail criteria based on what's known. Each criterion must be a binary testable statement starting with a verb. Include the test type (`unit` / `integration` / `ui`) for each. Mark as draft.
6. **Draft Human QA Checklist** — populate the checklist with things a human tester must verify on a real device that automated tests cannot cover. Focus on: visual fidelity, animation feel, haptics, dark mode, empty/error states, accessibility (VoiceOver, Dynamic Type, reduce motion), gestures, interruptions, and device-specific behavior. Replace template placeholders with epic-specific items. Refine as questions are answered.
7. For everything you **don't know**, write questions in the `## Open Questions` section using the question format below. **Use all four lenses** — ensure at least one question from each applicable lens.
8. Assess your confidence level and write it at the top.
9. Write the file to `docs/epics/EPIC-{number}.md`.
10. Tell the user: _"Epic {N} document created at docs/epics/EPIC-{number}.md with {X} open questions. Answer the questions in the document, then run `/ios-epic {N}` again."_

### 3. Subsequent Runs (File Exists)

If `docs/epics/EPIC-{number}.md` already exists:

1. Read the existing document.
2. Re-read `docs/PROJECT-BRIEF.md` and any dependent epic docs for latest context.
3. Scan the `## Open Questions` section for answered questions (status changed to `Answered` — i.e., one checkbox is checked `[x]`).
4. For each answered question:
   - Incorporate the answer into the relevant section of the document (update the detail sections, not just the question).
   - Move the question from `## Open Questions` to `## Resolved Questions` (keep it for audit trail).
5. With the new information:
   - Add more detail to the implementation sections.
   - **Update Expected Outcome** — refine based on newly resolved decisions.
   - **Update Acceptance Criteria** — add new criteria surfaced by answers, refine existing ones, ensure each has a test type.
   - **Update Human QA Checklist** — add new items surfaced by UX/UI answers, remove items that became irrelevant, make items more specific as the epic's design solidifies.
6. Reassess confidence:
   - If **below 90%** and there are **no unanswered questions left**: generate new questions (using all four lenses) to close remaining gaps. Add them to `## Open Questions`.
   - If **below 90%** and there are **still unanswered questions**: keep them, optionally add more if new gaps emerged.
   - If **90% or above**: finalize the document (see Completion below).
7. Update the confidence percentage at the top.
8. Write the updated file.
9. Report status:
   - If still under 90%: _"Updated. Confidence now at {X}%. {Y} questions remaining. Answer them and run `/ios-epic {N}` again."_
   - If 90%+: _"Epic {N} is ready for implementation at {X}% confidence."_

### 4. Completion (90%+)

When confidence reaches 90%:

1. Verify **Expected Outcome** is filled — if empty or vague, generate it from resolved decisions and ask user to confirm.
2. Verify **Acceptance Criteria** table is complete:
   - Every major requirement has a testable criterion.
   - Each criterion has a test type (`unit` / `integration` / `ui`).
   - Criteria cover: happy path, key error states, empty states, and edge cases.
   - Aim for zero criteria without a test type.
3. Verify **Human QA Checklist** is populated with epic-specific items (not template placeholders). All five categories should have at least one relevant item. Remove items that don't apply to this epic.
4. Mark the document as ready.

---

## Question Format

Questions in the document must follow this exact format:

```markdown
### Q{number} `[PM]`: {Clear, specific question}

> **Status:** Unanswered

- [ ] {Option} — {Brief rationale}
- [ ] {Option} **(Recommended)** — {Brief rationale}
- [ ] {Option} — {Brief rationale}

**Notes:**
<!-- Add any additional context here -->
```

The lens tag (`[PM]`, `[UX]`, `[UI]`, or `[ARCH]`) goes after the question number.

When the user answers, they check one box:

```markdown
### Q{number} `[UX]`: {Clear, specific question}

> **Status:** Answered

- [ ] {Option} — {Brief rationale}
- [x] {Option} **(Recommended)** — {Brief rationale}
- [ ] {Option} — {Brief rationale}

**Notes:** we also want to support X
```

---

## Question Guidelines

- Questions must be **specific and actionable** — not vague ("How should auth work?") but precise ("Which authentication flow should the login screen use?").
- Each option must be a **real, viable choice** — no throwaway options.
- The `(Recommended)` option should be your best judgment based on the project brief and technical context, with a clear reason why.
- Group questions by lens when there are many.
- Don't repeat questions that are already answered in the project brief or dependent epics.
- **Ensure coverage across lenses** — if all questions are `[ARCH]`, add at least one `[PM]`, `[UX]`, or `[UI]` question to ensure product and design gaps are addressed.

---

## Knowledge Sources (Strict)

You may **only** use information from:
1. `docs/PROJECT-BRIEF.md` — the project brief
2. `docs/epics/EPIC-{N}.md` — dependent epic documents that are at 90%+ confidence
3. Answered questions within the current epic document
4. `CLAUDE.md` — project technical decisions (if it exists, for tech stack context)
5. `docs/DESIGN-SYSTEM.md` — project-wide design system (if it exists). Reference established design direction for `[UI]` questions rather than re-asking. If absent, note: "Consider running `/ios-design-brief` first to establish project-wide visual direction."

Do **not** infer, guess, or pull from general knowledge. If you don't have enough context for a section, write a question instead.

---

## Confidence Assessment

Base your confidence on: _"Could a developer implement this epic using only this document and the project brief, without needing to ask any clarifying questions?"_

- **< 50%**: Major gaps — goals or approach unclear, many unknowns
- **50-70%**: Direction is clear but key decisions unmade
- **70-89%**: Most decisions made, some details to nail down
- **90%+**: Ready for implementation — all decisions made, steps are clear and actionable, Expected Outcome is concrete, Acceptance Criteria are testable

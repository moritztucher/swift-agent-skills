---
name: ios-onboarding-audit
description: Audit an existing onboarding flow or design one from scratch. Analyzes activation psychology, permission timing, progressive disclosure, visual identity, and time-to-value. Spawns onboarding, UX, and UI design advisors. Produces docs/ONBOARDING-AUDIT.md.
user_invocable: true
argument-hint: <optional: "new" for greenfield design, or feature path e.g. "Features/Onboarding">
---

# iOS Onboarding Audit

You audit an existing onboarding flow or design one from scratch for an iOS/SwiftUI project. This skill operates in two modes:

- **Audit mode** (default) — scan existing onboarding code, evaluate against best practices, produce findings + elevation opportunities.
- **Greenfield mode** (argument: `new`) — no onboarding exists yet. Read project context, then produce a recommended onboarding blueprint.

**Key constraint:** Suggests, never decides. All recommendations use "Consider:" framing.

**Output:** `docs/ONBOARDING-AUDIT.md`

---

## Rules

- **Read before judging** — scan all onboarding-related Views and flows before writing findings.
- **Three advisors** — spawn the onboarding advisor (strategy), UX advisor (interaction/HIG), and UI design advisor (visual craft) for a complete review.
- **Severity on every finding** — no unclassified observations.
- **Acknowledge strengths** — call out what works, not just problems.
- **Cite locations** — every finding references specific files and lines (audit mode) or project brief sections (greenfield mode).
- **No code changes** — this is an audit/blueprint. Offer to implement after the report.
- **Match the app's identity** — recommendations must reference the project's design system and brand personality, not generic advice.

---

## Flow

### 1. Determine Mode

- If argument is `new` or no onboarding Views exist → **Greenfield mode** (Step 2B)
- If onboarding Views exist → **Audit mode** (Step 2A)

**Context gathering (both modes):**
1. Read `CLAUDE.md` — tech stack, architecture decisions.
2. Read `docs/PROJECT-BRIEF.md` — target users, app purpose, features, tone.
3. Read `docs/DESIGN-SYSTEM.md` — established visual identity, design levers being pushed.
4. Read `ARCHITECTURE.md` — navigation approach, data flow.
5. Note which permissions the app uses (grep for `NSHealthShareUsageDescription`, `NSLocationWhenInUseUsageDescription`, `NSCameraUsageDescription`, `NSUserTrackingUsageDescription`, etc. in Info.plist or target settings).

---

### 2A. Audit Mode (Existing Onboarding)

#### Scan

1. Glob for onboarding-related files: `*Onboarding*`, `*Welcome*`, `*Intro*`, `*Walkthrough*`, `*Tutorial*`, `*GetStarted*`, `*FirstLaunch*`, `*Setup*`.
2. Read all matched View files. For each, note:
   - Screen purpose (value prop, personalization, permission ask, setup, tutorial)
   - Whether it's skippable
   - What user action advances to the next screen
   - Permissions requested (if any)
   - Personalization questions (if any)
   - Time estimate per screen (text density, required actions)
   - Visual craft (animations, custom elements, design lever usage)
3. Identify the activation moment — what's the first real action the user takes after onboarding?
4. Check for re-entry paths — can the user revisit tips/tutorials later? (grep for TipKit usage, "Getting Started" sections)
5. Check for conditional flows — does the onboarding differ based on context (new vs. returning user, sign-up vs. sign-in)?

#### Spawn Advisors

Spawn all three advisors in parallel:

**Onboarding Advisor** (`ios-onboarding-advisor`):
```
Audit this iOS app's onboarding flow.

App context:
- Purpose: {FROM PROJECT BRIEF}
- Target users: {FROM PROJECT BRIEF}
- Permissions needed: {LIST}

Onboarding screens in order:
{SCREEN-BY-SCREEN SUMMARY WITH FILE PATHS}

Post-onboarding first screen: {WHAT THE USER SEES AFTER ONBOARDING}

Evaluate against:
1. Time-to-value — how many taps/seconds to activation moment?
2. Permission timing — are asks just-in-time with value explanation, or cold/upfront?
3. Progressive disclosure — teach by doing or explain then use?
4. Personalization — does the onboarding adapt the experience?
5. Flow pattern — which pattern is used (none/welcome/walkthrough/interactive/gated)?
6. Drop-off risks — which screens are likely to lose users and why?
7. Emotional first impression — does the onboarding match the app's personality?
8. Anti-patterns — any present?
9. Metrics — what should be measured?

Return findings as numbered list with: Type (Strong/Concern/Opportunity/Measurement),
Severity (HIGH/MEDIUM/LOW), Screen reference, Principle, Observation, Suggestion.

Also return a recommended flow revision if significant improvements are possible.
```

**UX Advisor** (`ios-ux-advisor`):
```
Review these onboarding screens for UX and HIG compliance:

{SCREEN LIST WITH KEY OBSERVATIONS}

Check: skip button presence, back navigation, progress indicators, tap targets,
Dynamic Type, VoiceOver labels, keyboard handling on input screens,
loading states during account creation, error handling on permission denial.

Return only numbered annotations. No preamble.
```

**UI Design Advisor** (`ios-ui-design-advisor`):
```
Review these onboarding screens for visual design craft:

{SCREEN LIST WITH KEY OBSERVATIONS}

Design system context: {FROM DESIGN-SYSTEM.md — pushed levers, palette, typography}

Evaluate: Does the onboarding set the app's visual tone from screen 1?
Are the app's pushed design levers (Typography, Color, Vocabulary, Data Viz,
Status Indicators) active in the onboarding or does it feel like a generic template?
Is there a micro-delight moment?

Return only numbered annotations. No preamble.
```

---

### 2B. Greenfield Mode (No Onboarding Exists)

#### Analyze Requirements

From project context, determine:
1. **Activation moment** — what's the core value action? (from project brief features/epics)
2. **Required setup** — what MUST happen before the user can reach the activation moment? (account? permissions? data entry?)
3. **Permissions needed** — list all, categorize by sensitivity (low: notifications, medium: location, high: health/camera/tracking)
4. **Personalization potential** — are there user personas or use-case branches?
5. **App personality** — what are the pushed design levers? (from design system)
6. **Complexity level** — is the app's core action self-evident or does it need teaching?

#### Spawn Advisors

Spawn the onboarding advisor:

```
Design an onboarding flow for a new iOS app.

App context:
- Purpose: {FROM PROJECT BRIEF}
- Target users: {FROM PROJECT BRIEF}
- Core value action (activation moment): {IDENTIFIED ABOVE}
- Required setup before activation: {LIST}
- Permissions needed: {LIST WITH SENSITIVITY}
- Personalization potential: {PERSONAS/BRANCHES}
- App personality: {FROM DESIGN SYSTEM — pushed levers, tone}
- Complexity: {SELF-EVIDENT / NEEDS TEACHING / NOVEL INTERACTION}

Recommend:
1. Flow pattern (none/welcome/walkthrough/interactive/gated) with rationale
2. Screen-by-screen sequence — for each screen: purpose, content, user action, estimated time
3. Permission timing — when each permission is asked and the value explanation
4. Personalization approach (if applicable)
5. Activation moment placement — which screen/action
6. Micro-delight moment — one specific suggestion matching the app's design levers
7. What to defer to contextual tips (TipKit) vs. include in onboarding
8. Metrics to track

For each recommendation, explain the trade-off and expected impact.
```

Also spawn the UI design advisor for visual direction:

```
Recommend visual direction for this app's onboarding.

App design system: {FROM DESIGN-SYSTEM.md}
Pushed levers: {WHICH 2-3 LEVERS}
App personality: {TONE/ADJECTIVES}

For each onboarding screen in this sequence:
{PROPOSED SCREEN SEQUENCE FROM ONBOARDING ADVISOR}

Suggest how the app's pushed design levers should manifest. The onboarding should
feel like the app from screen 1, not a generic template that gives way to the real app.

Return screen-by-screen visual direction annotations. No preamble.
```

---

### 3. Generate Report

Write to `docs/ONBOARDING-AUDIT.md`.

```markdown
# Onboarding Audit — {Project Name}

**Date:** {YYYY-MM-DD}
**Mode:** {Audit / Greenfield}
**Auditor:** /ios-onboarding-audit

---

## Executive Summary

{3-5 sentences: current state (or absence) of onboarding, biggest opportunity,
recommended flow pattern, estimated time-to-activation.}

---

## App Context

| Aspect | Value |
|--------|-------|
| **Core value action** | {What the user came to do} |
| **Activation moment** | {First time user experiences core value} |
| **Required permissions** | {List with sensitivity levels} |
| **Pushed design levers** | {From design system} |
| **App personality** | {Tone adjectives} |

---

## Current Flow Assessment

{Audit mode: screen-by-screen breakdown of existing flow.
Greenfield mode: "No onboarding exists. Recommendation follows."}

### Screen-by-Screen

| # | Screen | Purpose | Skippable | Est. Time | Risk |
|---|--------|---------|-----------|-----------|------|
| 1 | {Name} | {Purpose} | {Yes/No} | {Xs} | {Drop-off risk} |
| ... | | | | | |

**Estimated time-to-activation:** {total seconds/taps from launch to activation moment}

---

## Findings

{Audit mode only — skip in greenfield mode}

### ONBOARD-1: {Title} — {SEVERITY}
- **Screen:** {Which screen or flow point}
- **Principle:** {Onboarding principle}
- **Observation:** {What was found}
- **Consider:** {Suggestion with expected impact}

...

---

## Strengths

{What works well in the current onboarding — or in greenfield mode,
what project context gives the onboarding a head start (strong design system,
clear activation moment, etc.)}

---

## Recommended Flow

{Both modes — the recommended onboarding sequence.}

### Flow Pattern: {Pattern name}

**Rationale:** {Why this pattern fits this app}

### Screen Sequence

#### Screen 1: {Name}
- **Purpose:** {What this screen achieves}
- **Content:** {What the user sees — specific, not vague}
- **User action:** {What advances to next screen}
- **Visual direction:** {How the app's design levers manifest here}
- **Estimated time:** {Seconds}

#### Screen 2: {Name}
...

#### Activation: {First Real Action}
- **What happens:** {The user does the core thing for the first time}
- **Celebration:** {How the app acknowledges this moment — specific to design levers}

### Permission Strategy

| Permission | When | Pre-Permission Value Explanation | Fallback if Denied |
|------------|------|--------------------------------|---------------------|
| {e.g., Notifications} | {Screen # or trigger} | {One-line value pitch} | {What happens without it} |
| ... | | | |

### Personalization

{Personalization approach, or "Not recommended for this app — [reason]"}

### Deferred to Contextual Tips

{What should NOT be in onboarding but taught later via TipKit or coach marks}

- {Feature/gesture} — surface when: {trigger condition}
- ...

---

## Micro-Delight Moment

{One specific, concrete suggestion for a moment of craft/surprise in the onboarding
that matches the app's pushed design levers. Specific enough to implement from
this description alone.}

---

## Metrics Plan

| Metric | Target | How to Measure |
|--------|--------|---------------|
| Completion rate | > 80% | {Implementation note} |
| Drop-off per screen | < 15% each | {Implementation note} |
| Time-to-activation | < {X}s | {Implementation note} |
| Permission grant rate | > 60% | {Implementation note} |
| Day 1 retention | > 40% | {Implementation note} |
| Day 7 retention | > 20% | {Implementation note} |

---

## Implementation Notes

{Practical notes for the developer implementing this onboarding}

- **Navigation:** {Sheet flow? NavigationStack? Paging TabView?}
- **State tracking:** {How to track onboarding completion — UserDefaults key, @AppStorage}
- **Conditional paths:** {Different flows for different user states}
- **TipKit setup:** {Tips to configure for post-onboarding education}
- **Analytics events:** {Key events to log}

---

## Quick Wins

{3-5 highest-impact, lowest-effort improvements — audit mode only}

1. **{Title}** — {Description}. Expected impact: {what improves}.
2. ...
```

### 4. Summary in Chat

After writing the report:
- Mode and verdict (one sentence)
- Time-to-activation: current vs. recommended
- List any HIGH findings
- Recommended flow pattern + screen count
- The micro-delight suggestion (one sentence)
- Point to the report file
- Offer to create an onboarding epic (greenfield) or implement improvements (audit)

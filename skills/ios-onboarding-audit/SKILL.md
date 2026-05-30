---
name: ios-onboarding-audit
description: Audit an existing onboarding flow or design one from scratch. In audit mode it walks the real flow in the simulator (reset → screenshot each step → judge the lived sequence), evaluating time-to-value, permission timing, progressive disclosure, and first-impression craft. Spawns onboarding, UX, and UI advisors. Produces docs/ONBOARDING-AUDIT.md.
user_invocable: true
argument-hint: <optional: "new" for greenfield design, or feature path e.g. "Features/Onboarding">
---

# /ios-onboarding-audit — Onboarding Audit

Audit an existing onboarding flow, or design one from scratch. Two modes:

- **Audit mode** (default) — onboarding exists. **Walk it in the simulator and judge the lived sequence**, then produce findings + improvements.
- **Greenfield mode** (`new`, or no onboarding found) — nothing to run. Produce a recommended blueprint from project context, marked **unvalidated**.

**Suggests, never decides** — recommendations use "Consider:" framing. **No code changes** — offer to implement after the report. **Output:** `docs/ONBOARDING-AUDIT.md`.

## Principles

- **Walk it, don't infer it.** Onboarding is a timed sequence experienced over several screens — pacing, friction, and the screen-1 emotional hit can't be judged from source. In audit mode, step through the real flow and judge the screenshots; count actual taps/seconds to the activation moment rather than estimating from code.
- **Judge the experience, not a rulebook.** Severity reflects real friction/drop-off risk on screen, not deviation from a "best practice" checklist. A short, fast onboarding that works is a *strength*, not an opportunity to add screens. Don't manufacture findings.
- **Fit this app.** Recommendations reference the project's own personality and design system, never generic onboarding advice. The onboarding should feel like *this* app from screen 1.
- **Metrics are what to measure, not targets to hit.** Suggest the events worth instrumenting; don't invent pass/fail thresholds for a specific app.

## Visual Loop (audit mode — required)

Onboarding only shows on first launch, so **reset first-launch state before each run**:
1. `axe list-simulators` for a booted UDID (boot one if needed).
2. **Reset:** `xcrun simctl uninstall <UDID> <bundleID>` then reinstall — clears `UserDefaults`/`@AppStorage` so onboarding shows. (Or find the completion flag — grep `@AppStorage`/`hasCompletedOnboarding`/`hasLaunched` — and clear just that key.)
3. Build & install & launch (`xcodebuild … build` → `simctl install` → `simctl launch`).
4. **Walk it:** at each step, `axe screenshot --output .design/onboard-NN.png`, **Read the PNG**, then advance with AXe (`axe tap --label "Continue"/"Get Started"/"Skip" --udid <UDID>`; see `/ios-automate`). Capture every screen through to the **activation moment** (the first real use of the app).
5. Note the actual tap/second count to activation, which screens are skippable, and where a real user would hesitate or bail.

## Flow

### 1. Mode & context
- `new` argument, or no onboarding Views found (glob `*Onboarding*`, `*Welcome*`, `*Intro*`, `*Walkthrough*`, `*GetStarted*`, `*FirstLaunch*`, `*Setup*`) → **Greenfield**. Else → **Audit**.
- Read for context: `CLAUDE.md`, `docs/PROJECT-BRIEF.md` (users, purpose, tone), `docs/DESIGN-SYSTEM.md` (identity, pushed levers) if present, `ARCHITECTURE.md` (navigation). Note permissions the app declares (grep Info.plist / target settings for `NS*UsageDescription`).

### 2A. Audit mode
Run the **Visual Loop** to walk and capture the real flow. Pair each screenshot with its View code to note: purpose (value prop / personalization / permission / setup / tutorial), skippable?, the action that advances, permissions asked (cold vs. just-in-time with value), and the visual craft on screen. Identify the **activation moment** and any re-entry path (TipKit / "Getting Started").

**Spawn the three advisors with the screenshots** (pass the `.design/onboard-*.png` paths + brief context; tell them to Read the images and judge the rendered flow):
- **`ios-onboarding-advisor`** — strategy: time-to-value, permission timing, progressive disclosure, personalization, flow pattern, drop-off risks, emotional first impression, what to measure.
- **`ios-ux-advisor`** — interaction/HIG: skip & back affordances, progress indication, tap targets, Dynamic Type, VoiceOver, keyboard handling on input screens, loading/error states (incl. permission denial).
- **`ios-ui-design-advisor`** — visual craft: does screen 1 set the app's identity, are its pushed levers active, is there a genuine micro-delight moment.

Integrate their annotations; you own the final findings.

### 2B. Greenfield mode (blueprint — unvalidated)
From context, determine the activation moment, the minimum setup required before it, permissions (by sensitivity), personalization potential, and the app's personality. Spawn `ios-onboarding-advisor` (recommend flow pattern + screen-by-screen sequence + permission timing + activation placement + one micro-delight + what to defer to TipKit + metrics) and `ios-ui-design-advisor` (how the app's levers should manifest per screen so it feels like the app, not a template). Mark the blueprint **unvalidated — verify by walking it once built**.

### 3. Report → `docs/ONBOARDING-AUDIT.md`

```markdown
# Onboarding Audit — {Project}

**Date:** {YYYY-MM-DD} · **Mode:** {Audit / Greenfield} · **Walked in simulator:** {yes / no — greenfield}

## Summary
{3–5 sentences: current state (or absence), the lived first impression, biggest opportunity, recommended pattern, actual time-to-activation.}

## App Context
Core value action · activation moment · required permissions (+ sensitivity) · pushed design levers · personality.

## Current Flow {audit mode}
Screen-by-screen, from the walk:
| # | Screen | Purpose | Skippable | Taps in | Friction observed (from screenshot) |
**Measured time-to-activation:** {actual taps/seconds from launch to activation}

## Findings {audit mode}
#### ONBOARD-N: {title} — {HIGH/MEDIUM/LOW}
- **Screen:** {which screenshot/step} · `path/to/View.swift:line`
- **Observation:** {what's true in the lived flow}
- **Consider:** {suggestion + expected impact}

## Strengths
{What works in the flow — cite screens. A fast, clean flow is a strength.}

## Recommended Flow {both modes}
Pattern + rationale, then screen-by-screen (purpose · content · advancing action · visual direction · est. time), the activation moment + how it's acknowledged, a permission strategy table (permission · when · pre-permission value · fallback if denied), personalization (or "not recommended — why"), and what to defer to contextual tips.

## Micro-Delight Moment
One concrete moment of craft matching the app's levers — specific enough to implement.

## Metrics to Instrument
The events worth tracking (completion, per-screen drop-off, time-to-activation, permission grant, D1/D7 retention) — *what* to measure and how; set targets per the team's own benchmarks, not invented ones.

## Implementation Notes
Navigation (sheet / NavigationStack / paged TabView), completion-state storage, conditional paths, TipKit setup, analytics events.

## Quick Wins {audit mode}
3–5 highest-impact, lowest-effort improvements with file paths.
```

Severity is judged by real friction/drop-off impact seen in the walk — never by distance from a generic checklist.

### 4. Summary in chat
Mode + one-sentence verdict, measured vs. recommended time-to-activation, any HIGH findings, recommended pattern + screen count, the micro-delight (one line), pointer to the report, and an offer to implement (audit) or scaffold the flow (greenfield).

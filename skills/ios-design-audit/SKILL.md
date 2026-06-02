---
name: ios-design-audit
description: Visual design craft audit for iOS/SwiftUI. Builds and screenshots the running app, judges the real rendered screens against design-craft principles, and writes docs/DESIGN-AUDIT.md with severity-rated findings + concrete elevation opportunities. Reviews look-and-feel only (color, type, spacing, motion, hierarchy, emotional design) — suggests, never decides.
user_invocable: true
argument-hint: <optional: feature name or path, e.g. "Onboarding" or "Features/Dashboard">
---

# /ios-design-audit — Visual Design Audit

Audit the **rendered** visual craft of an iOS/SwiftUI app or feature — how it actually looks and feels — and prescribe concrete ways to elevate it. This is not a code review or UX/HIG audit (that's `/ios-review` and `/ios-audit`); it's about color, typography, whitespace, motion, hierarchy, and emotional design.

**Suggests, never decides** — findings use "Consider:" framing. **No code changes** — offer `/ios-design-elevate` to act on the report.

**Input:** optional scope — a feature name, path, or nothing (audit the whole app).

## Principles

- **Judge pixels, not code.** Build and screenshot the running app and assess the real screens. Code is secondary evidence (it tells you *why* a screen looks the way it does and gives you line citations) — but a finding must be grounded in what's actually on screen.
- **The rendered result is the truth — the doc is not.** `DESIGN-SYSTEM.md` is a reference, not the arbiter. A finding must be a real problem *on screen*, judged on its own merits — never "this deviates from the doc." When the rendering and the doc disagree, the implementation is often the deliberate, better choice (e.g. a 28pt hero that reads better than the doc's 44pt). Treat drift as a **question** ("code uses X, doc says Y — confirm which is intended; the doc may need updating"), not a defect. Severity reflects actual visual impact, never distance from the spec.
- **Don't manufacture findings.** If a screen looks good, say so. A short audit on a strong app is the right outcome — don't pad it with conformance nitpicks.
- **Fit this app.** Assess against the app's own domain and personality, not a house aesthetic. "Generic" is a finding; so is "distinctive but wrong for this app."
- **Acknowledge strengths**, not just problems. Cite specific screens/files.
- **Severity on every finding.** No unclassified observations.

## Visual Loop (primary evidence)

1. Booted simulator UDID: `axe list-simulators` (boot with `xcrun simctl boot <UDID>` if needed).
2. Build & run: `xcodebuild -scheme "<Scheme>" -destination 'platform=iOS Simulator,name=<device>' -derivedDataPath .build build`, then `xcrun simctl install booted <App.app>` + `xcrun simctl launch booted <bundleID>`.
3. Navigate the key screens with AXe (`axe tap --label … --udid <UDID>`; see `/ios-automate`), capturing each: `axe screenshot --udid <UDID> --output .design/audit-<screen>.png`.
4. **Read each PNG** and assess the real rendering.

If the app can't be built/run, say so, fall back to a code-only read, and mark the audit **unverified — not validated against rendered screens** (lower-confidence findings).

## Flow

### 1. Scope & context
- Argument → that feature/path; none → whole app. Glob `*View.swift` in scope + shared `ViewComponents/`. If >20 Views, prioritize main screens, navigation entry points, and the most visually complex.
- Read `CLAUDE.md`, `ARCHITECTURE.md`, `docs/DESIGN-SYSTEM.md` (if present — audit adherence to it), and `~/.claude/skills/ios-design-brief/references/design-craft-patterns.md` (the lever framework + concrete technique benchmark).

### 2. Capture & read the screens
Run the Visual Loop on the in-scope screens. For each screen, pair the screenshot with its code to note: color usage (hardcoded/asset/system), typography (sizes/weights/`design:`), spacing rhythm, motion, hierarchy signals, custom vs default indicators, and delight moments.

**Infrastructure checks** (verify against the rendered result, not just code):
- **Color scheme:** is `.preferredColorScheme()` set? Unenforced scheme + a dark spec = invisible gray-on-gray (you'll see it in the screenshot).
- **Competing color systems:** a design package + hardcoded colors + asset colors fighting each other → unpredictable rendering.
- **Materials on wrong backgrounds:** `.ultraThinMaterial` etc. over light backgrounds render invisible — confirm in the screenshot.
- **Spec vs reality:** if `DESIGN-SYSTEM.md` exists, note where the rendering differs from it — but record these as *drift to reconcile* (which is right, code or doc?), not as defects. The on-screen result decides; the doc may be the thing that needs updating.

### 3. Advisor review (optional, larger projects)
For substantial scopes, spawn `ios-ui-design-advisor` with the **screenshots + key code observations** and the lever framework, asking for: per-screen strong choices / concerns / opportunities (with "Consider:" framing), a strengths list, and concrete elevation opportunities citing pattern-library techniques. Integrate its annotations; you own the final findings.

### 4. Assess levers & coherence
Rate each of the levers **safe / moderate / bold** from the rendered screens:
Typography as identity · Color as narrative · Vocabulary as design · Data viz as personality · Status indicators as signature · Motion as personality. An award-ready app pushes 2–3 levers bold; a generic one plays them all safe. Also assess cross-screen consistency (does every screen feel like one app?), dark-mode intentionality, and design-system adherence if a spec exists.

### 5. Write the report
Write `docs/DESIGN-AUDIT.md` (or `docs/DESIGN-AUDIT-{feature}.md` if scoped):

```markdown
# Design Audit — {scope}

**Date:** {YYYY-MM-DD} · **Scope:** {…} · **Validated against screenshots:** {yes / no}

## Design Snapshot
{3–5 sentences on the current visual impression and design maturity.}

## Summary
| Category | HIGH | MEDIUM | LOW |
|----------|------|--------|-----|
| Color · Typography · Spacing · Motion · Hierarchy · Emotional · Visibility · Consistency | … | … | … |

**Lever profile:** Typography {safe/moderate/bold} · Color {…} · Vocabulary {…} · Data Viz {…} · Status {…} · Motion {…}
**Verdict:** {AWARD-READY / POLISHED / SOLID / NEEDS ATTENTION / BARE BONES}

## Strengths
- {What works, with screen + file citations.}

## Findings
Grouped by category. Each finding:
#### {CODE-N}: {title} — {HIGH/MEDIUM/LOW}
- **Screen / Location:** {which screenshot} · `path/to/File.swift:line`
- **Observation:** {what's visible on screen}
- **Consider:** {suggestion with trade-off}

## Elevation Opportunities
The few highest-leverage changes that move this from good to exceptional. For each: current state (1 line), concrete prescription (name exact screen + specific SwiftUI techniques/values from the pattern library — not "add delight"), effort (Low/Med/High).

## Signature Moment
**Current candidate:** {closest thing today} · **Prescribed:** {the one defining visual moment this app should own}

## Drift from Design System
{Only if DESIGN-SYSTEM.md exists. Where the rendering differs from the doc, list it as a question — `code: X · doc: Y · which is intended?` — not a finding. Default assumption: the implementation is deliberate and the doc may need updating. Only promote a drift item to a real finding above if it genuinely looks wrong on screen.}

## Quick Wins
{3–5 high-impact, low-effort changes with file paths.}
```

Severity guide (always judged by on-screen impact, never by distance from the doc): **HIGH** = significant issue affecting perception (no hierarchy, competing focal points, invisible cards, materials/system-colors rendering wrong); **MEDIUM** = visible convention gap or missed opportunity (inconsistent spacing, generic cards that read flat, uniform type with no contrast); **LOW** = polish (rhythm, spring timing, symbol weight). A value that merely differs from `DESIGN-SYSTEM.md` but looks fine is **not** a finding — it goes under *Drift* as a question.

### 6. Summary in chat
Verdict + finding counts, any HIGH findings (one line each), top 3 quick wins, the signature-moment prescription, and an offer to run `/ios-design-elevate` to implement. Point to the report file.

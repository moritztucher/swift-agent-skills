---
name: ios-design-brief
description: Establish a project's visual design system. Looks at the running app (builds + screenshots the simulator) and the project brief, proposes a concrete design direction in chat, refines by reaction, then writes docs/DESIGN-SYSTEM.md with implementable SwiftUI-level specs. Draft-first — no in-document questionnaires.
user_invocable: true
---

# /ios-design-brief — Visual Design System

Establish the project's visual identity and write it to `docs/DESIGN-SYSTEM.md` as a concrete, implementable spec. **Draft-first and sighted:** look at the actual app and the brief, propose a direction in chat, refine with the user, then write the doc. No code changes here — that's `/ios-design-elevate`.

> **Next step:** `/ios-design-elevate` applies this system to the Views, verifying each screen visually.

## Principles

- **Look before you decide.** If the app builds, screenshot it and judge the *real* rendered screens — never design from imagination. (Visual Loop below.)
- **Draft-first, in chat.** Propose a concrete direction; the user reacts. Never write questionnaires into the document.
- **Fit this app.** Derive the direction from the brief's personality/audience and what's on screen. Do not reach for a house aesthetic — there is no default theme. A fitness app, a finance app, and a journaling app should look nothing alike.
- **Concrete, not vague.** Every choice is specified at the SwiftUI level — actual weights, sizes, `design:` variants, tracking, hex values with role assignments, gradient stops, indicator shapes, animation curves/durations. "Bold typography" is not a spec; `.system(size: 34, weight: .black, design: .rounded)` is.
- **Distinctive over safe.** Aim for a look recognizable from a single screenshot. Avoid startup-blue, generic cards, platform-default-everything — but let the distinctiveness come from the app's domain, not a template.
- **Color scheme is foundational.** Decide dark / light / adaptive first — every color, material, and contrast choice depends on it.

## Visual Loop (how to "look")

When the project has a buildable app with UI:
1. Find a booted simulator UDID: `axe list-simulators` (boot one with `xcrun simctl boot <UDID>` if none).
2. Build & run: `xcodebuild -scheme "<Scheme>" -destination 'platform=iOS Simulator,name=<device>' -derivedDataPath .build build`, then `xcrun simctl install booted <App.app>` and `xcrun simctl launch booted <bundleID>` (or just run from Xcode if already installed).
3. Navigate with AXe (`axe tap --label … --udid <UDID>`) to reach key screens (see `/ios-automate` for AXe usage).
4. Capture: `axe screenshot --udid <UDID> --output .design/<screen>.png` (or `xcrun simctl io booted screenshot <file>`).
5. **Read the PNG** with the Read tool and judge the actual pixels.

If the app doesn't build yet or has no UI (greenfield), skip the loop and design from the brief — note in the doc that the system is unvalidated against real screens.

## Flow

### 1. Gather context
- Read `docs/PROJECT-BRIEF.md` (personality, audience, features, any visual hints). If absent, ask the user for a one-line personality brief in chat, or suggest `/ios-brief` first.
- Read `CLAUDE.md` for tech context.
- Read the lever reference: `~/.claude/docs/ios/swiftui/design-craft-patterns.md` (the 6 levers + concrete techniques — use it for vocabulary, not as a style to copy).
- **Scan existing design infrastructure:** design packages (`import DesignSystem`, etc.), theme/token files (`Theme.swift`, `Colors.swift`, `DesignTokens.swift`), color assets in `*.xcassets`, hardcoded colors in Views, and whether `.preferredColorScheme()` is set. Record these for the doc's `## Existing Design Infrastructure` section — the elevate skill must reconcile them.

### 2. See the current state
Run the Visual Loop on 2–4 key screens. Form a quick read: what's the current lever state (typography, color, motion, indicators — safe or pushed?), what's generic, what's already working.

### 3. Draft a direction (in chat)
Propose **one** primary direction (offer a second only if there's a genuine fork), grounded in the brief + screenshots:
- **Color scheme:** dark / light / adaptive — and why.
- **2–3 levers to push** (from: Typography, Color, Vocabulary, Data Viz, Status Indicators, Motion) — the ones that fit *this* app's domain. Name them and say why.
- **Concrete specs** for the pushed levers: palette with roles (hex + light/dark), type scale (sizes/weights/`design:`), spacing density, signature element (the one treatment that makes it ownable), motion language.
- Keep it tight and show it; let the user react, adjust, approve. Iterate in chat.

### 4. Write the system
Once the user is happy:
1. Read the template `~/.claude/docs/templates/design-system-template.md`.
2. Write `docs/DESIGN-SYSTEM.md` with: the agreed direction, concrete SwiftUI-level specs for every section, the `## Existing Design Infrastructure` findings, a **Quick Reference** value table, and an `## Implementation Notes` section for elevate — color-scheme enforcement (e.g. "set `.preferredColorScheme(.dark)` on root"), packages to override/remove, and any visibility caveats (e.g. materials need a dark background; borders need ≥2pt at ≥0.6 opacity to register).
3. If the design contradicts existing infrastructure, state the override explicitly.
4. If you validated against screenshots, note which screens; if not, mark the system **unvalidated — verify during elevate**.

## Output

`docs/DESIGN-SYSTEM.md` — implementable enough that `/ios-design-elevate` (or a developer) can build a consistent visual identity from it without guessing. Sections: Existing Infrastructure · Color (scheme + palette with roles) · Typography · Spacing · Components · Motion · Iconography · Visual Hierarchy · Quick Reference · Implementation Notes. Mark thin areas `[TBD]` rather than inventing.

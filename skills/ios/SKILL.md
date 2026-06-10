---
name: ios
description: Guided entry point for the iOS workflow. Detects where the current project is in the lifecycle (Setup → Plan → Build → Verify → Ship), shows a one-glance status map, and routes you to the right next skill. Use when the user types /ios, asks "what's next", "where am I in the workflow", "what should I do next on this project", or wants help orchestrating the iOS skills.
user_invocable: true
---

# /ios — Workflow Orchestrator

The single entry point for the iOS skill workflow. Detect the project's current state, show the user where they are, and route them to the right next step. Do **not** do the downstream work yourself — your job is to diagnose and hand off.

The workflow is deliberately light: plan with a living brief, then **build features UI-first** (get the flow feeling good before wiring logic), with build/test/automate/elevate as on-demand tools. There is no formal epic/preflight/TDD-delivery pipeline.

## Step 1 — Detect State (silent)

Check these signals in the working directory:

| Signal | Means |
|--------|-------|
| `CLAUDE.md` with `@~/.claude/docs/ios/ios-guide.md` on line 1 | **Initialized** |
| any `*.xcodeproj` / `*.xcworkspace` / `*.swift` | has code |
| `docs/PROJECT-BRIEF.md` | **Brief done** (read its Features section — MVP vs Later) |
| `docs/DESIGN-SYSTEM.md` | design system established |
| feature dirs under `Features/`, recent commits | build in progress |
| `git status --short`, `git branch --show-current`, `git log --oneline -5` | uncommitted work, branch, activity |

If the brief exists, read its **Features** list (MVP / Later, each split into UI and Logic & Backend) and compare against what's actually built in `Features/` to gauge progress and suggest what to build next.

## Step 2 — Show the Map

Print a compact status line per phase — ✅ done / ▶️ current / ⬜️ not started:

```
iOS workflow — <project name or dir>

  Setup    ✅ initialized
  Plan     ✅ brief done · design system pending (optional)
  Build    ▶️ 2/5 MVP features have UI · logic pending
  Verify   ⬜️
  Ship     ⬜️  (branch: main · 3 uncommitted files)
```

Keep it to the phases that matter; don't pad.

## Step 3 — Recommend & Offer to Launch

State the single best next step in one sentence, then offer to act on it. If the user agrees, invoke the skill directly (don't make them type it). Routing:

| Current state | Recommend | Skill / action |
|---------------|-----------|----------------|
| No `CLAUDE.md` import | Initialize the project | `/ios-init` |
| Initialized, no brief | Build the project brief | `/ios-brief` |
| Brief done, no design system *(optional)* | Establish the design system | `/ios-design-brief` |
| Brief done | Build the next MVP feature — **UI first**, then logic | just start building (build/test with `xcodebuild`, drive the simulator with `/ios-automate`) |
| UI built, feels good | Layer in logic & backend for that feature | continue building |
| Want to raise the visual bar | Audit / elevate the design | `/ios-design-audit`, `/ios-design-elevate` |
| Code written, want a check | Review or audit | `/ios-review`, `/ios-audit` |
| Uncommitted changes | Commit | `/ios-commit` |
| Committed on a feature branch | Open a PR | `/pr-to-develop` |
| Ready to release | Release PR + notes | `/pr-to-main`, `/ios-release-notes` |

When more than one path is reasonable (design-system is optional; you might audit before committing), give the primary recommendation first and list alternatives briefly. The brief is a **living reference** — if the project has drifted from it, suggest re-running `/ios-brief` to update it.

## The Phases (reference)

- **Setup** — `/ios-load` (ad-hoc, no project), `/ios-init`
- **Plan** — `/ios-brief`, `/ios-design-brief`
- **Build** — write features UI-first; `/ios-design-elevate`, `/ios-automate` (build/test via `xcodebuild` directly)
- **Verify** — `/ios-review`, `/ios-audit`, `/ios-design-audit`, `/ios-onboarding-audit`
- **Ship** — `/ios-commit`, `/pr-to-develop`, `/pr-to-main`, `/ios-release-notes`

Craft skills (`swiftui-pro`, `swiftui-expert-skill`, `swift-concurrency`) trigger automatically while writing/reviewing SwiftUI and concurrency code — they aren't part of the linear path. The advisor subagents (`ios-ux-advisor`, `ios-ui-design-advisor`, `ios-onboarding-advisor`, `context7-docs-writer`) are spawned by the audit skills, not invoked directly.

## Edge Cases

- **Not an iOS project / no signals:** ask whether to start fresh (`/ios-init`) or load ad-hoc iOS context (`/ios-load`).
- **Uncommitted changes mid-flight:** surface them in the Ship line and, per commit hygiene, flag before recommending anything that moves past them.
- **User asked a specific question** ("how do I ship?"): jump straight to that phase's recommendation instead of the full map.

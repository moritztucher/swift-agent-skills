---
name: ios
description: Guided entry point for the iOS workflow. Detects where the current project is in the lifecycle (Setup → Plan → Build → Verify → Ship), shows a one-glance status map, and routes you to the right next skill. Use when the user types /ios, asks "what's next", "where am I in the workflow", "what should I do next on this project", or wants help orchestrating the iOS skills.
user_invocable: true
---

# /ios — Workflow Orchestrator

The single entry point for the iOS skill workflow. Detect the project's current state, show the user where they are, and route them to the right next step. Do **not** do the downstream work yourself — your job is to diagnose and hand off.

## Step 1 — Detect State (silent)

Check these signals in the working directory. Each maps to a lifecycle phase.

| Signal | Means |
|--------|-------|
| `CLAUDE.md` exists with `@~/.claude/docs/ios/ios-guide.md` on line 1 | **Initialized** |
| any `*.xcodeproj` / `*.xcworkspace` / `*.swift` | has code (existing project) |
| `docs/PROJECT-BRIEF.md` | **Brief done** |
| `docs/DESIGN-SYSTEM.md` | design system established |
| `docs/epics/` with `EPIC-*.md` files | **Epics detailed** (count them) |
| `docs/PREFLIGHT-REPORT.md` | **Preflight passed** |
| `git log --oneline -5`, `git status --short`, `git branch --show-current` | recent activity, uncommitted work, branch |

Read `docs/PROJECT-BRIEF.md`'s Epics section (if present) to know how many epics exist vs. how many have `docs/epics/EPIC-N.md` detail docs — that gap drives the recommendation.

## Step 2 — Show the Map

Print a compact status line per phase, marking each ✅ done / ▶️ current / ⬜️ not started. Example:

```
iOS workflow — <project name or dir>

  Setup    ✅ initialized (existing codebase)
  Plan     ▶️ brief done · 2/5 epics detailed · preflight pending
  Build    ⬜️
  Verify   ⬜️
  Ship     ⬜️  (branch: main · clean)
```

Keep it to the phases that matter; don't pad.

## Step 3 — Recommend & Offer to Launch

State the single best next step in one sentence, then offer to launch it. If the user agrees, invoke the skill directly (don't make them type it). Use this routing:

| Current state | Recommend | Skill |
|---------------|-----------|-------|
| No `CLAUDE.md` import | Initialize the project | `/ios-init` |
| Initialized, no brief | Build the project brief | `/ios-brief` |
| Brief done, no design system *(optional)* | Establish the design system | `/ios-design-brief` |
| Brief done, epics not all detailed | Detail the next epic | `/ios-epic <n>` |
| All epics detailed, no preflight | Cross-validate before building | `/ios-preflight` |
| Preflight passed, epic not built | Implement the next epic (TDD) | `/ios-implement <n>` |
| Epic implemented | Verify ACs / review / audit | `/ios-verify <n>`, `/ios-review`, `/ios-audit` |
| Work verified, uncommitted | Commit | `/ios-commit` |
| Committed on a feature branch | Open a PR | `/ios-pr` |
| Ready to release | Release PR + notes | `/ios-release-pr`, `/ios-release-notes` |

When more than one path is reasonable (e.g. design-system is optional, or the user could audit before committing), present the primary recommendation first and list the alternatives briefly. Always offer the design/UX skills (`/ios-design-audit`, `/ios-onboarding-audit`, `/ios-design-elevate`) as available side-quests when there's UI in the project, but don't force them into the linear path.

## The Phases (reference)

- **Setup** — `/ios-load` (ad-hoc, no project), `/ios-init`
- **Plan** — `/ios-brief`, `/ios-design-brief`, `/ios-epic`, `/ios-preflight`
- **Build** — `/ios-implement`, `/ios-design-elevate`, `/ios-build`, `/ios-test`, `/ios-automate`
- **Verify** — `/ios-verify`, `/ios-review`, `/ios-audit`, `/ios-design-audit`, `/ios-onboarding-audit`
- **Ship** — `/ios-commit`, `/ios-pr`, `/ios-release-pr`, `/ios-release-notes`

Craft skills (`swiftui-pro`, `swiftui-expert-skill`, `swift-concurrency`) trigger automatically while writing/reviewing SwiftUI and concurrency code — they aren't part of the linear path. List `/ios-agents` if the user wants to see the specialist subagents.

## Edge Cases

- **Not an iOS project / no signals at all:** ask whether they want to start fresh (`/ios-init`) or load ad-hoc iOS context (`/ios-load`).
- **Mid-flight with uncommitted changes:** surface them in the Ship line and, per commit hygiene, flag before recommending anything that would move past them.
- **User asked a specific question** ("how do I ship?"): jump straight to that phase's recommendation instead of the full map.

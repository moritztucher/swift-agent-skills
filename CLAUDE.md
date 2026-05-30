# Claude Code — Global Instructions

Universal rules that apply to every session. Domain-specific guides (iOS, etc.) are loaded only by projects that opt in via their own `CLAUDE.md`.

---

## Directory Exclusions

When working inside paths that contain team-owned repositories (often `~/work` or similar), follow project-specific rules instead of this guide — use team commit formats and architecture decisions.

---

## Session Management

**Start:** Check git branch + uncommitted changes, note current state.

**End:** Summarize what was done, note pending items, mention decisions to remember.

**Progress:** Update only at milestones, not every change.

---

## Development Modes

Infer mode from task, announce when switching.

| Mode | Focus | Triggers |
|------|-------|----------|
| Architect | Design first, questions before code, ADRs | "design", "should we", "architecture" |
| Developer | Implementation, minimal decisions | "implement", "add", "create", "build" |
| QA | Testing, edge cases, review mindset | "test", "review", "check", "verify" |
| Refactor | Code quality only, no new features | "cleanup", "refactor", "optimize" |
| Debug | Investigation and fixing only | "bug", "fix", "broken", "investigate" |
| Prototype | Fast iteration, relaxed standards | "experiment", "prototype", "quick test" |

**Prototype Rules:** Skip tests/docs, use `prototype/` branch, add `// TODO: Cleanup` comments, keep security standards.

---

## Git Identity

Identity is auto-managed by `~/.gitconfig` conditional includes — do not set `user.email` / `user.name` per-repo unless explicitly required. Configure conditional includes once globally and let path-based rules handle the rest:

```gitconfig
# ~/.gitconfig
[includeIf "gitdir:~/Personal/"]
    path = ~/.gitconfig-personal
[includeIf "gitdir:~/Work/"]
    path = ~/.gitconfig-work
```

---

## Commit Hygiene

- **Commit after a feature/task is done.** Don't let completed work sit uncommitted across turns.
- **Confirm before committing.** When a feature looks complete, ask the user ("feature looks done — commit now?") and wait for explicit approval before running `git commit`. Never commit silently.
- **Commit only files related to the task.** Stage files by name (`git add <path>`). Never use `git add -A` or `git add .` — unrelated changes from prior work or local experiments must not be swept into a task's commit.
- **New-feature guard.** Before starting a new feature/task, run `git status`. If there are uncommitted changes from a prior task/feature, stop and warn the user first, then offer three choices:
  1. Commit the prior changes now (recommended when the prior work is complete),
  2. Stash them,
  3. Continue and leave them uncommitted.

---

## Self-Review (Silent)

Before presenting code, verify:
- No security vulnerabilities (OWASP Top 10)
- Adheres to project standards
- No obvious performance issues

Present options for significant architectural decisions.

---

## Communication

Write in complete, natural sentences — but cut anything that doesn't carry information.

**Always cut:**
- Pleasantries and acknowledgments ("Great question!", "Certainly!", "I'd be happy to…")
- Preamble that restates the task before doing it
- Narration of tool calls the user can already see
- Post-completion victory laps
- Hedging filler
- Trailing offers the user didn't ask for
- Markdown headers and tables for short answers
- Restating what the diff already shows

**Keep:**
- The one-sentence "about to do X" before the first tool call of a turn
- Short updates at real decision points
- A one-sentence end-of-turn summary: what changed + what's next
- Questions when assumptions would be risky
- Full technical clarity — tight, not cryptic

**Other rules:**
- Fix your own mistakes silently
- Blockers: try one approach, then ask
- Progress updates: only at milestones

---

## Memory & Context

Maintain `.claude/memory.md` in each project:
- Decisions made and why
- User preferences discovered
- Common issues and solutions

Update after significant discoveries.

---

## MCP Servers

| Server | When to Use |
|--------|-------------|
| Context7 | Always check before implementing unfamiliar frameworks |
| GitHub | Via `gh` CLI for Issues/PRs |

---

## Domain Guides

Project-specific context lives in per-project `CLAUDE.md` files. Projects opt into domain guides by `@import`-ing them.

| Domain | Guide | How to opt in |
|--------|-------|---------------|
| iOS | `~/.claude/docs/ios/ios-guide.md` | Add `@~/.claude/docs/ios/ios-guide.md` to the project's root `CLAUDE.md` |

The iOS guide bundles: core stack, naming, architecture rules, ViewModel rules, SwiftUI rules, Swift style, security, testing, the full `/ios-*` workflow, and pointers to framework guides and templates. `/ios-init` adds the import automatically when scaffolding a new project `CLAUDE.md` (it auto-detects new vs. existing codebases). Run `/ios` anytime to see where a project is in the workflow and what to do next.

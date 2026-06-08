# Cross-Agent Portability — TODO

Goal: make the setup usable by non-Claude agents (Codex, Kiro CLI, Cursor, Gemini CLI, and other [Agent Skills](https://agentskills.io/clients) clients), not just Claude Code.

## Current state (baseline)

- **Already portable:** all 87 skills install anywhere via `npx skills add moritztucher/swift-agent-skills` — plain `SKILL.md` + `references/`, the open Agent Skills format.
- **Claude-only today:** the `@import` house-rules docs, the 4 advisor agents, the 2 active hooks, and the 7 skills that fan out to subagents.

What's missing for a non-Claude user is the **house rules** (delivered to Claude via `@import`) and the **advisor agents / hooks** — not the skill catalog itself.

---

## Tier 1 — close the docs gap (highest value, ~1 hr, no risk to Claude UX)

- [ ] **Create `AGENTS.md` at repo root** carrying the same house rules Claude gets via `@~/.claude/docs/ios/ios-guide.md`.
  - Source content from `docs/ios/ios-guide.md`, `docs/ios/ios-coding-standards.md`, `docs/ios/architecture-patterns.md`.
  - Keep it agent-neutral (no `@import`, no Claude-specific tool references).
  - `AGENTS.md` is the convention Codex / Cursor / Gemini / Kiro read.
  - Acceptance: a Codex/Kiro user in an iOS project gets the SwiftUI-first / `@Observable` / accessibility taste without any Claude features.
- [ ] **Add a "Non-Claude users" section to `README.md`.**
  - Lead with `npx skills add moritztucher/swift-agent-skills` as the install path.
  - Explain the split: skills are portable; agents + hooks + `@import` are Claude-enhanced.
  - Note that the 7 fan-out skills work but run inline (no parallel advisors) elsewhere — see Tier 2.
- [ ] **Fix the stale comment** in `bin/install.mjs:6` — drop "(once published to npm)" now that it's published.

## Tier 2 — make the advisors + fan-out skills portable (~half day)

- [ ] **Re-author the 4 advisor agents as skills** (or ship both forms):
  - `ios-ux-advisor`, `ios-ui-design-advisor`, `ios-onboarding-advisor`, `context7-docs-writer`.
  - As skills they're invokable everywhere; you lose the Task-tool parallel fan-out but keep the guidance.
- [ ] **Add graceful degradation to the 7 fan-out skills** — "if subagents available, spawn; else run the review inline":
  - `ios-agents`, `ios-design-elevate`, `ios-design-audit`, `ios-onboarding-audit`, `ios-audit`, `ios-review` (+ the design-elevate path).
  - Acceptance: each produces a useful result on an agent with no Task tool, just without parallelism.

## Tier 3 — hooks + discovery (small)

- [ ] **Ship `swiftlint-autofix` as a tool-agnostic git pre-commit hook** (in addition to the Claude hook), so non-Claude users get the same lint-on-save behavior.
  - `notify-done.sh` is Claude-stop-specific — document as Claude-only, no portable equivalent needed.
- [ ] **List the repo on the agentskills.io directory** so non-Claude users can discover it, not just install by GitHub slug.

---

## Out of scope / won't port

- Claude `settings.json` (hooks + statusline wiring) — Claude-specific by design.
- `notify-done.sh` — depends on Claude's Stop event.
- The `@import` mechanism itself — superseded by `AGENTS.md` for other agents.

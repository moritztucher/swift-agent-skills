# Cross-Agent Portability

Goal: make the setup usable by non-Claude agents (Codex, Kiro CLI, Cursor, Gemini CLI, and other [Agent Skills](https://agentskills.io/clients) clients), not just Claude Code.

## Current state

- **Portable:** all 91 skills install anywhere via `npx skills add moritztucher/swift-agent-skills` — plain `SKILL.md` + `references/`, the open Agent Skills format.
- **House rules:** delivered to Claude via `@import`; to everyone else via the repo-root `AGENTS.md` (copy into the iOS project root).
- **Advisors:** ship in both forms — Claude subagents in `agents/` and portable skills (`ios-ux-advisor`, `ios-ui-design-advisor`, `ios-onboarding-advisor`, `context7-docs-writer`).
- **Fan-out skills degrade gracefully:** `ios-audit`, `ios-design-audit`, `ios-onboarding-audit`, `ios-design-elevate` spawn advisors on Claude Code and carry a documented no-subagent fallback (run the lens skills inline) everywhere else. `ios-agents` documents both worlds. (`ios-review` turned out to have no fan-out — nothing to degrade.)
- **Lint hook:** `hooks/pre-commit.swiftlint` is a tool-agnostic git pre-commit variant of `swiftlint-autofix.sh`.
- **Skill-routing rule in `AGENTS.md`:** agent-neutral instruction to check the catalog and load the matching framework skill before implementing. Backs up auto-triggering on every client — Claude Code (where the curated `skillOverrides` tiering in `settings.json.example` keeps 69 framework-literal skills name-only), Codex (8k-char description budget), Gemini, and Kiro.
- **Kiro CLI caveat documented:** Kiro's automatic skill activation is best-effort — one-shot description matching with no enforcement, diluting at 91 skills, and custom Kiro agents don't auto-load skills at all (they need explicit `skill://` resources). The README's "Non-Claude users" section documents the two mitigations: explicit `/skill-name` invocation, and an always-on `.kiro/steering/skill-router.md` rule telling Kiro to check the skill catalog before implementing framework features.

## Done

- [x] **Tier 1** — `AGENTS.md` at repo root (agent-neutral house rules from `ios-guide.md` + `ios-coding-standards.md` + `architecture-patterns.md`).
- [x] **Tier 1** — "Non-Claude users" section in `README.md` (install path, portable-vs-Claude-enhanced split, inline fallback note).
- [x] **Tier 1** — stale "(once published to npm)" comment fixed in `bin/install.mjs`.
- [x] **Tier 2** — 4 advisor agents re-authored as skills (both forms shipped).
- [x] **Tier 2** — graceful degradation in the fan-out skills (spawn if subagents available, else apply the lens skills inline).
- [x] **Tier 3** — `swiftlint-autofix` shipped as a tool-agnostic git pre-commit hook (`hooks/pre-commit.swiftlint`); installer chmods it.
- [x] **Follow-up** — Kiro CLI auto-activation caveat + mitigations (slash invocation, `skill-router` steering rule) documented in the README's "Non-Claude users" section.

## Remaining

- [ ] **List the repo on the agentskills.io directory** so non-Claude users can discover it, not just install by GitHub slug. (External submission — manual step.)

## Out of scope / won't port

- Claude `settings.json` (hooks + statusline wiring) — Claude-specific by design.
- `notify-done.sh` / `definition-of-done.sh` — depend on Claude's Stop event; documented as Claude-only.
- The `@import` mechanism itself — superseded by `AGENTS.md` for other agents.

## Maintenance note

The advisor content intentionally exists twice (agent in `agents/<name>.md`, skill in `skills/<name>/SKILL.md`). When updating an advisor's guidance, update both files.

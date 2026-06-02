# research/

A running knowledge base of verified findings from building and maintaining this bundle — the root-causes, gotchas, and API-drift catches that don't belong in any single skill but are worth recording once and citing often.

## What goes here

- **API drift** — where current Apple/vendor APIs diverge from what's widely documented or what an AI assistant produces by default (caught during the Context7/Apple-docs currency-checks every skill goes through). Each entry: the wrong version, the verified truth, the source.
- **Patterns** — non-obvious solutions worked out in real apps (e.g. docking a custom IME candidate strip above the keyboard) before they graduate into a skill.
- **Remediations** — recurring failure modes and their fixes.

## Why

Every skill in this bundle is currency-checked against authoritative docs before shipping (see the project memory on currency-checking). That process surfaces real, citable findings — this folder is where they're kept so the verification is visible, not just claimed.

## Conventions

- One finding per file, dated, with a source link.
- State what was wrong, what's correct, and how it was verified.
- Link to the skill(s) the finding informed.

_Seeded as structure; entries added as findings accumulate._

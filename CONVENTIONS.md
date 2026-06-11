# Conventions

How skills in this bundle are shaped, verified, and versioned. Kept deliberately light — git is the source of truth for history; these are the rules that aren't obvious from the code.

## Skill shape

Each framework/engineering/craft skill is a directory under `skills/<name>/`:

```
skills/<name>/
  SKILL.md            # the lean decision + discipline layer
  references/         # the deep API reference(s) the SKILL dispatches to
    guide.md
```

`SKILL.md` follows a fixed template (see `skills/storekit/SKILL.md` as the canonical example):

- **Frontmatter** — `name`, `description` (packed with real trigger keywords for model-invocation + cross-links to related skills), `license: MIT`, and a `metadata` block with `author`, `version`, `currency_checked`, and `source`.
- **Dials** — 3 numbered configuration dials that change what "correct" means for the skill.
- **When to use** — scope, and explicit boundaries against neighbouring skills.
- **Core rules** — the non-negotiables.
- **Anti-rationalization** — a table of the real footguns: "the rationalization" vs "the reality."
- **Verification gate** — a pre-ship checklist.
- **Deep reference** — dispatches to `references/`.

Keep `SKILL.md` terse (the decision layer); put exhaustive API detail in `references/`.

## Currency-check (required)

Every skill or guide is verified against **Context7 + the live Apple/vendor docs** before it ships — never drafted from training data alone. Record the result in frontmatter: `currency_checked: "<date>"` and `source: "<library id used>"`. Patch small drift in place; flag large staleness explicitly. (See the project memory `currency-check-skills-context7`.)

## Versioning

- **Per-skill:** semver in `metadata.version` (starts at `"1.0"`). Bump on a material change to the skill's guidance or API surface. `currency_checked` tracks freshness independently — re-checking and finding no drift updates the date, not the version.
- **Bundle/manifest:** `.claude-plugin/plugin.json` + `marketplace.json` carry the bundle version (`0.1.0` pre-launch). Bump to `1.0.0` at first public release, then semver thereafter.
- **No `v1/` copies.** Rollback is `git`, not duplicated files. History lives in commits, not parallel directories.

## Registries to keep in sync

When adding/removing a skill, update in the same change: the README badge count + the relevant table, `skills/llms.txt` (count + entry), and the `skillOverrides` block in `settings/settings.json.example` (plus the name-only/full-description counts in the README's context-budget section). The link count in `llms.txt` should always equal the number of skill directories.

## Advisors exist in two forms

Each advisor intentionally ships twice — as a Claude subagent (`agents/<name>.md`) and as a portable skill (`skills/<name>/SKILL.md`) for non-Claude clients. When updating an advisor's guidance, update both files in the same change.

# View Inventory — {{ProjectName}}

> **Optional.** Searching the codebase is the default way to discover existing components. Keep this file only if a curated index earns its upkeep — and if the project keeps it, update entries in the same diff that adds, renames, or removes a shared component. Stale entries are worse than none.

Last updated: {{YYYY-MM-DD}}

| Component | File | Purpose |
|-----------|------|---------|
| _e.g. PrimaryButton_ | `ViewComponents/Buttons/PrimaryButton.swift` | App-wide primary CTA with loading state |
| _e.g. CardStyle_ | `ViewComponents/Modifiers/CardStyle.swift` | Standard card surface (corner radius, shadow, padding) |

**Promotion rule:** a feature-scoped component used by 2+ features moves to `ViewComponents/` — move the file, update imports, and update its row.

# View Inventory — {{ProjectName}}

> **Read this file before implementing any new View, ViewModifier, or shared UI component.** If a component matching what you need already exists here, reuse or extend it — do not invent a parallel one. **Update this file whenever you add, rename, or remove a shared component.**

Last updated: {{YYYY-MM-DD}}

---

## How to use this file

1. **Before building a new screen or component:** scan the relevant section below. If something close exists, reuse/extend it.
2. **When adding a new shared component:** add an entry here in the same turn that introduces the file. Treat it as part of the diff.
3. **When renaming or deleting:** update or remove the entry. Stale entries are worse than no entry.
4. **One row per file.** If a file exports multiple subcomponents that are independently reusable, list each.

---

## Shared Components (`ViewComponents/`)

Cross-feature reusable UI. Pure, stateless or self-contained, no feature-specific dependencies.

| Component | File | Purpose | Key Inputs | Notes |
|-----------|------|---------|------------|-------|
| _e.g. PrimaryButton_ | `ViewComponents/Buttons/PrimaryButton.swift` | App-wide primary CTA button with theme + loading state | `title: String, isLoading: Bool, action: () -> Void` | Uses `Theme.primary`. Disabled state has reduced opacity. |

---

## Feature Components

Components scoped to a single feature, in `Features/[Feature]/Views/ViewComponents/`. Listed here so they can be promoted to shared when reused elsewhere.

### {{FeatureName}}

| Component | File | Purpose | Key Inputs | Notes |
|-----------|------|---------|------------|-------|
| _e.g. WorkoutRow_ | `Features/Workout/Views/ViewComponents/WorkoutRow.swift` | Row cell for a workout in lists | `workout: Workout` | Tap forwards to coordinator. |

---

## Screens (top-level Views)

Top-level Views that represent a route/destination. Useful index when navigating the codebase.

| Screen | File | Feature | ViewModel | Notes |
|--------|------|---------|-----------|-------|
| _e.g. HomeView_ | `Features/Home/Views/HomeView.swift` | Home | `HomeViewModel` | Entry point after auth. |

---

## View Modifiers & Styles

Custom `ViewModifier`, `ButtonStyle`, `LabelStyle`, etc.

| Modifier / Style | File | Apply via | Purpose |
|------------------|------|-----------|---------|
| _e.g. CardStyle_ | `ViewComponents/Modifiers/CardStyle.swift` | `.modifier(CardStyle())` or `.cardStyle()` | Standard card surface (corner radius, shadow, padding) |

---

## Promotion rules

- A feature-scoped component used by **2+ features** should be promoted to `ViewComponents/`.
- A modifier applied in **3+ places** should be extracted into a named `ViewModifier`.
- When promoting, move the file, update imports, and move the row from the feature section to the shared section here.

---
name: swiftdata
description: Build and review local persistence with SwiftData — @Model, ModelContainer, ModelContext, @Query, #Predicate, relationships, schema migrations, and CloudKit sync. Use when the user mentions SwiftData, persistence, @Model, @Query, ModelContainer, #Predicate, local database, offline storage, or migrating from Core Data. For purchases/entitlement storage use the `storekit` skill instead.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple SwiftData docs via Context7 (/websites/developer_apple_swiftdata)
---

# SwiftData

Apple's modern persistence layer (the Core Data successor) — `@Model` classes, a `ModelContainer`, `ModelContext` for CRUD, and `@Query` for reactive SwiftUI fetches. The deep API reference — model attributes, relationships, fetching, migrations, concurrency, CloudKit, iOS 26 additions — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `CONCURRENCY` — `main-context` (default; all reads/writes on `mainContext` from `@MainActor` code) · `model-actor` (heavy imports, batch writes, or background work go through a `@ModelActor`-isolated context — `ModelContext` is not `Sendable` and may not cross actors).
2. `MIGRATION` — `lightweight` (additive changes pre-ship, or trivial property adds with defaults) · `versioned-schema` (anything shipped to users: `VersionedSchema` + `SchemaMigrationPlan`, lightweight or custom stages).
3. `CLOUDKIT_SYNC` — `off` (default; local store only) · `on` (`.modelContainer(... ,cloudKitDatabase:)` or `ModelConfiguration(cloudKitDatabase: .automatic)` — forces extra schema constraints, see anti-rationalization).

## When to use

Designing or reviewing any local data model, query, write path, relationship graph, schema migration, or CloudKit-synced store that goes through SwiftData. iOS 17+ for the framework, iOS 18+ for `#Index`/`#Unique`, iOS 26 the default target. If the app is on Core Data and not migrating, this skill does not apply; if it's migrating off Core Data, it does.

## Core rules

- One `@Model` class = one table. Plain classes, no protocol conformance needed; SwiftData synthesizes persistence.
- One `ModelContainer` per store for the app lifetime — created with `.modelContainer(for:)` on the `App`/scene, or once and injected. Don't spin up containers per view.
- Read/write on the context that owns the objects. UI uses `@Query` + `mainContext`; background work uses a `@ModelActor` context and passes `PersistentIdentifier`s across the boundary, never model instances.
- Every to-many `@Relationship` gets an explicit `deleteRule`. The default (`.nullify`) is rarely what you want for owned children.
- Once the schema ships, changes go through a `VersionedSchema` — never mutate a live `@Model` in place and hope.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll fetch on a background `Task` to keep the UI smooth." | `ModelContext` is **not `Sendable`** and is bound to its actor. Background work needs a `@ModelActor`; move `PersistentIdentifier`s across the boundary and re-fetch, never the model objects. |
| "I'll use `@Query` in my view model / manager to stay reactive." | `@Query` is a SwiftUI property wrapper — it only works inside a `View`. Off the view, use `FetchDescriptor` + `modelContext.fetch`; reactivity there is your job. |
| "`#Predicate` is just a closure, I'll call my helper inside it." | `#Predicate` is **compiled to a query expression**, not arbitrary Swift. Function calls, most non-trivial optionals, and unsupported operators fail at build or runtime. Keep it to comparisons/`contains`/boolean logic; filter the rest in memory. |
| "Deleting the parent will clean up the children." | Only if the relationship declares `deleteRule: .cascade`. The default leaves orphans (`.nullify`) or, with `.deny`, blocks the delete. Set the rule explicitly per relationship. |
| "I'll just add the new property to the `@Model` — it's a tiny change." | After v1 ships, an in-place model edit is an unversioned schema change and can fail to open the existing store. Add a `VersionedSchema` + a `MigrationStage` (lightweight is fine for additive). |
| "Turn on CloudKit sync and it just works." | CloudKit-backed stores can't use `@Attribute(.unique)`, require every property to be optional or have a default, and need to-one inverses on relationships. Design the schema for those constraints before flipping `cloudKitDatabase`. |

## Verification gate

Before shipping SwiftData code, confirm every line:

- [ ] Exactly one `ModelContainer` for the store's lifetime; views get the context via `.modelContainer`/`@Environment(\.modelContext)`, not freshly built containers.
- [ ] No `ModelContext` or `@Model` instance crosses an actor/`Task` boundary; background work is in a `@ModelActor` and hands off `PersistentIdentifier`s.
- [ ] `@Query` appears only in `View`s; non-view fetches use `FetchDescriptor` (with `fetchLimit` where lists can grow).
- [ ] Every `#Predicate` contains only query-expressible logic — no helper calls or unsupported operations.
- [ ] Every to-many relationship has an explicit `deleteRule`; inverses declared where both sides are navigated.
- [ ] If the schema has shipped, changes go through a `VersionedSchema` + `SchemaMigrationPlan` stage, not in-place edits.
- [ ] If `CLOUDKIT_SYNC = on`: no `.unique` attributes, all properties optional or defaulted, relationships have inverses; iCloud capability + container configured.
- [ ] Writes are persisted — autosave relied on intentionally, or `modelContext.save()` called (in a `do/catch`) for batch/explicit paths.

## Deep reference

`references/guide.md` — full setup, `@Model` attributes (`.unique`, `.externalStorage`, `.encrypt`, `.preserveValueOnDeletion`, `#Index`/`#Unique`), relationships and delete rules, `@Query`/`FetchDescriptor`/`#Predicate`, CRUD, SwiftUI integration, the `@ModelActor` manager pattern, versioned-schema migration, error handling, and iOS 26 additions (history tracking, preserved values). Load it for any concrete API question.

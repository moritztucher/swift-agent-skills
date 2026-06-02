---
name: realmswift
description: Build and review an on-device object database with Realm Swift — Object/@Persisted models, read/write transactions, type-safe queries, @ObservedResults/@ObservedRealmObject SwiftUI binding, schema migrations, thread confinement, and change notifications. Use when the user mentions Realm, RealmSwift, @Persisted, Realm database, object database, Realm migration, @ObservedResults, or LinkingObjects. Realm is a third-party SDK now in community-maintained mode — for a new Apple-only app prefer the `swiftdata` skill.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Realm Swift docs via Context7 (/realm/realm-swift, community branch)
---

# Realm Swift

On-device object database for Apple platforms (also cross-platform: Kotlin/.NET/Dart). The deep API reference — models, configuration, CRUD, queries, SwiftUI integration, async writes, notifications, migrations, threading, and best practices — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

**Status, read this first.** Realm Swift is a **third-party SDK** (Realm → MongoDB) now in **community-maintained mode**: the local database still works and ships in production, but it gets no active feature investment, and Atlas Device Sync (the cloud sync layer) is end-of-life. For a **new Apple-only app, default to SwiftData** (first-party, Apple-native — use the `swiftdata` skill). Choose Realm only with a real reason: maintaining an existing Realm app, cross-platform model parity, or a feature SwiftData lacks. Name the reason before adding the dependency.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `WHY_REALM` — `legacy` (maintaining an existing Realm app) · `cross-platform` (shared model with Kotlin/.NET/Dart) · `feature-gap` (need something SwiftData lacks). If none apply, stop and use `swiftdata` instead. No "we already know Realm" — that's not a reason for a new Apple-only app.
2. `CONCURRENCY` — `main-only` (all Realm access on `@MainActor`, default — simplest, no thread bugs) · `actors` (actor-isolated Realms via `await Realm()` + `observe(on:)`) · `gcd` (manual `DispatchQueue` + per-thread Realm + `autoreleasepool` — only for heavy batch writes).
3. `ENCRYPTION` — `none` (default) · `encrypted` (64-byte key in `Realm.Configuration(encryptionKey:)`, key stored in Keychain, never in code/UserDefaults). Turn on for any sensitive user data.

## When to use

Building or reviewing Realm models, transactions, queries, SwiftUI data binding, migrations, or threading. If the app is new and Apple-only, first confirm `WHY_REALM` is satisfied — otherwise route to the `swiftdata` skill before writing any Realm code.

## Core rules

- Models subclass `Object` (or `EmbeddedObject`), every stored property is `@Persisted`, and SwiftUI models add `ObjectKeyIdentifiable`. Primary key via `@Persisted(primaryKey: true)`, prefer `ObjectId`.
- **Every mutation lives inside a write transaction.** Setting a property on a managed object outside `realm.write {}` either no-ops or throws. Keep transactions small.
- **Realm instances and live objects are thread-confined.** Never pass a live `Object`, `Results`, or `Realm` across a thread/actor boundary — use `freeze()`, a primary key, or `ThreadSafeReference` resolved on the destination.
- **Live objects and `Results` auto-update.** Read derived values at point of use; don't snapshot a `.count` or a property into a stored variable and assume it stays valid.
- Any schema change requires bumping `schemaVersion` and handling it in `migrationBlock`. `deleteRealmIfMigrationNeeded` is dev-only — it wipes data.
- Prefer the type-safe `where { $0.age < 3 }` query API; keep string `filter("...")` only where an `NSPredicate` is required (e.g. `@ObservedResults`).

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll just set the property — it's a quick change." | Mutating a managed object outside `realm.write {}` doesn't persist (and throws on a managed object). Every write is wrapped in a transaction, no exceptions. |
| "I'll grab this object on the main thread and use it in a Task / background queue." | Live Realm objects are **thread/actor-confined** — touching one off its origin thread crashes. Pass a `freeze()`'d copy, a primary key, or a `ThreadSafeReference` resolved on the destination. |
| "I'll cache `results.count` (or a property) so I don't re-query." | Live `Results` and objects update in place. A cached derived value silently goes stale; read it where you use it, or observe changes via a `NotificationToken`. |
| "I added a field to the model, it'll just work." | Any schema change needs `schemaVersion` bumped + a `migrationBlock`, or Realm throws on open. Skipping it crashes existing installs on first launch after update. |
| "It's a new app but the team knows Realm, so we'll use it." | Realm is community-maintained third-party with sync EOL; "we know it" isn't a reason. New Apple-only apps default to SwiftData (`swiftdata` skill) — pick Realm only for a real `WHY_REALM` reason. |
| "`try!` everywhere is fine, Realm rarely fails." | `Realm()` and `write` fail on migration mismatch, disk-full, and decryption errors — exactly the cases that strand real users. Use `do/catch` on open and on writes in production code. |

## Verification gate

Before shipping Realm code, confirm every line:

- [ ] `WHY_REALM` is a stated reason; a new Apple-only app without one was routed to SwiftData instead.
- [ ] Every property mutation is inside a `realm.write {}` (or `asyncWrite`/`writeAsync`) transaction.
- [ ] No live `Object`/`Results`/`Realm` crosses a thread or actor boundary — `freeze()`, primary key, or `ThreadSafeReference` used at every boundary.
- [ ] Schema changes bump `schemaVersion` and are handled in `migrationBlock`; `deleteRealmIfMigrationNeeded` is not in a release build.
- [ ] No derived value (`count`, property) cached across time where the underlying live data can change.
- [ ] Every `NotificationToken` is retained while observing and `invalidate()`d in `deinit`.
- [ ] `Realm()` open and writes use real error handling (not `try!`) on any path a user can hit; sensitive data uses an encrypted configuration with the key in the Keychain.

## Deep reference

`references/guide.md` — full install, model definitions and relationships, configuration (default/in-memory/encrypted), CRUD, type-safe and string queries, aggregates, SwiftUI integration (`@ObservedResults`/`@ObservedRealmObject`/environment injection), async writes, object and collection notifications, schema migrations, threading and frozen objects, best practices, and a quick reference. Load it for any concrete API question.

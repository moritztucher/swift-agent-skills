---
name: cloudkit
description: Implement and review CloudKit on Apple platforms — CKContainer, public/private/shared databases, CKRecord, CKQuery, subscriptions, CKShare sharing, and cross-device sync (manual operations or CKSyncEngine). Use when the user mentions CloudKit, CKRecord, iCloud sync, private database, CKShare, cross-device sync, CKSyncEngine, or syncing app data to iCloud. If the model layer is SwiftData and you only need iCloud mirroring of a local store, use the `swiftdata` skill (SwiftData can sync via CloudKit automatically) — reach for raw CloudKit only when you need public/shared databases, sharing, or direct record access.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple Developer docs via Context7 (/websites/developer_apple, /apple/sample-cloudkit-sync-engine)
---

# CloudKit

Storing and syncing data to iCloud on Apple platforms: containers, the three database scopes, records, queries, subscriptions, sharing, and sync. The deep API reference — setup, every class, CRUD, querying, subscriptions, CKSyncEngine, conflict resolution, error handling, SwiftUI integration — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `DATABASE_SCOPE` — `private` (default; per-user data, counts against the user's iCloud quota, requires sign-in) · `public` (shared by all users, counts against the app's quota, readable signed-out) · `shared` (collaboration via `CKShare`). Most apps are `private`-only; reach for `public`/`shared` only for leaderboards/feeds or real collaboration.
2. `SYNC_STRATEGY` — `manual` (you drive `CKDatabase`/`CKModifyRecordsOperation`/`CKFetchRecordZoneChangesOperation` + subscriptions; full control, more code) · `sync-engine` (iOS 17+ `CKSyncEngine`, owns scheduling/retries/batching — you keep local persistence and a delegate) · `swiftdata` (let SwiftData/Core Data mirror a local store to CloudKit — least code, no public/shared, no custom record types). Pick `swiftdata` unless you need public/shared databases or direct record control.
3. `OFFLINE` — `online-only` (act directly on the server; simplest, fails without network) · `offline-first` (local store is source of truth, CloudKit is the sync layer; required for a real sync app and the natural fit for `sync-engine`).

## When to use

Building or reviewing any code that talks to CloudKit directly — containers, records, queries, subscriptions, sharing, or sync. For a local model that just needs iCloud mirroring, prefer the `swiftdata` skill (SwiftData syncs via CloudKit with almost no CloudKit code); use this skill when you need public/shared databases, `CKShare`, custom zones, or raw `CKRecord` access.

## Core rules

- Use the async/await APIs (iOS 15+): `accountStatus()`, `database.save(_:)`, `database.record(for:)`, `database.records(matching:)`. `CKSyncEngine` is iOS 17+. iOS 26 is the default target.
- **Check `accountStatus()` before any operation.** No `.available` account → no private/shared access. Surface "sign in to iCloud", don't fail silently.
- **The CloudKit schema is configuration, not code.** Queryable/sortable/searchable fields need indexes set in the CloudKit Dashboard (or pushed via schema), and the schema must be deployed to Production before release. A field your code queries on won't query until it's indexed server-side.
- **Local store is the source of truth in any sync app.** Don't treat the server round-trip as your model; persist locally, sync in the background, reconcile on fetch. `CKSyncEngine` requires you to persist its `stateSerialization`.
- Records are zone-scoped: queries and zone-change fetches never cross zones. The default zone doesn't support `CKFetchRecordZoneChangesOperation` — use a custom zone for any incremental/sync workflow.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll just call `database.records(matching:)` — sign-in is the user's problem." | Without an `.available` iCloud account every private/shared op throws `.notAuthenticated`. Gate on `accountStatus()` first and tell the user to sign in; also observe `.CKAccountChanged` so you react to sign-out/switch. |
| "The query returns nothing but my data is right there." | Queryable fields need an index set in the CloudKit Dashboard/schema, and the schema must be deployed to Production. Unindexed field = empty/failed query. This is config, not a code bug. |
| "I'll fetch everything in one query across my zones." | CloudKit has no cross-zone query. `CKQuery` runs against one zone; `CKFetchRecordZoneChangesOperation` is per-zone. Design zones around what you fetch together. |
| "Last write wins — just re-save on conflict." | A `.serverRecordChanged` error carries `error.serverRecord` with the server's change tag. Merge onto *that* record (preserving its tag) and re-save, or you'll loop or clobber. Blindly re-saving the client record drops the other device's edits. |
| "Public and private databases are interchangeable, I'll move data later." | Public counts against the *app's* fixed quota and is world-readable; private counts against each *user's* iCloud quota and needs sign-in; they have different subscription rules. Scope is an architecture decision — picking wrong means a migration. |
| "I'll write my own operation/retry loop instead of CKSyncEngine." | On iOS 17+ `CKSyncEngine` owns scheduling, batching, retry/backoff, and account-change handling — but only if you persist its `stateSerialization` on every `.stateUpdate` and implement the delegate. Hand-rolling means reimplementing all of that correctly. If you go manual, honor `CKErrorRetryAfterKey` and treat `.zoneBusy`/`.requestRateLimited` as retryable. |

## Verification gate

Before shipping CloudKit code, confirm every line:

- [ ] `accountStatus()` checked before private/shared operations; non-`.available` shows a sign-in prompt, not a silent failure; `.CKAccountChanged` is observed.
- [ ] Every queryable/sortable field used in a predicate or sort has an index in the CloudKit Dashboard schema, and the schema is deployed to Production.
- [ ] No query or zone-change fetch assumes cross-zone results; sync workflows use a custom zone (not the default zone).
- [ ] Conflicts handle `.serverRecordChanged` by merging onto `error.serverRecord` and re-saving — no blind client re-save.
- [ ] Database scope (`private`/`public`/`shared`) is a deliberate choice; quota and access implications understood.
- [ ] If `CKSyncEngine`: `stateSerialization` persisted on every `.stateUpdate`, delegate `handleEvent`/`nextRecordZoneChangeBatch` implemented (both `async`), remote notifications registered (won't work on Simulator).
- [ ] Retryable errors (`.networkUnavailable`, `.serviceUnavailable`, `.requestRateLimited`, `.zoneBusy`) honor `CKErrorRetryAfterKey`; large mutations batched (≤400 records/op).
- [ ] Tested with a real device and a signed-in iCloud account end-to-end — Simulator can't register for the push notifications CloudKit sync depends on.

## Deep reference

`references/guide.md` — full setup and entitlements, CKContainer/account status, the three databases, CKRecord (fields, assets, references, model conversion), CKQuery/predicates/pagination, subscriptions and push handling, CKSyncEngine (iOS 17+), SwiftUI `@Observable` integration, error mapping/retry, conflict resolution, best practices, common pitfalls, and a version-compatibility matrix. Load it for any concrete API question.

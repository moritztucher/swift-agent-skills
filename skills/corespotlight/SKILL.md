---
name: corespotlight
description: Index app content into Spotlight and deep-link back from search results with Core Spotlight — CSSearchableItem, CSSearchableItemAttributeSet, CSSearchableIndex, NSUserActivity continuation, deletion, and iOS 18.4+ Apple Intelligence summary/priority. Use when the user mentions Core Spotlight, Spotlight search, CSSearchableItem, app indexing, searchable content, making content discoverable in system search, or deep linking from a search result. For App Intents / App Shortcuts that also surface in Spotlight and Siri, use the `appintents` skill.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple Core Spotlight docs via Context7 (/websites/developer_apple_corespotlight)
---

# Core Spotlight

Make your app's content searchable in system Spotlight and route taps back into the app. The deep API reference — indexing, attribute sets, batch indexing, deletion, NSUserActivity continuation, your own `CSSearchQuery`, App Intents association, and iOS 18.4+ Apple Intelligence summarization — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `INDEX_TRIGGER` — `on-change` (default; index/update/delete inline as the user's data store mutates) · `bulk-launch` (rebuild the whole index on launch/migration via `beginBatch`/`endBatch`) · `both` (on-change for live edits + a periodic reconcile).
2. `CONTINUATION` — how a tapped result re-enters the app: `swiftui` (default; `.onContinueUserActivity(CSSearchableItemActionType)`) · `appdelegate` (`application(_:continue:restorationHandler:)` for UIKit/legacy).
3. `INTELLIGENCE` — `off` (default) · `on` (iOS 18.4+ `textContentSummary` / `isPriority` via `updateListenerOptions` + a CoreSpotlight Delegate extension; needs ≥200 chars of `textContent`).

## When to use

Building or reviewing any code that indexes content for Spotlight, deletes/updates that index, or handles a tap on a Spotlight result. If the surface is an App Shortcut, an `AppEntity`, or a Siri phrase, that's the `appintents` skill — Core Spotlight only complements it (you can `associateAppEntity` / `indexAppEntities` to merge both, covered in the guide).

## Core rules

- iOS 26 is the default target; the Core Spotlight indexing/continuation API is iOS 9+, so no availability gating is needed for the basics. The Apple Intelligence summary/priority properties are iOS 18.4+ — gate those.
- Indexing is pointless without continuation. Every indexed item must have a working tap-handler path (`CSSearchableItemActionType`) that deep-links to the exact content, or you are decorating Spotlight for nothing.
- `uniqueIdentifier` is the contract. It must be stable and unique per item, set before first index, and be the same string you can resolve back to a model object on continuation.
- The index is a cache you own, not a mirror that self-heals. You add, you update (re-index same id), and you delete. Nothing else cleans it up except expiration.
- Guard with `CSSearchableIndex.isIndexingAvailable()` and never crash on index errors — failed indexing is a degraded feature, not a fatal one.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I indexed the items — Spotlight integration is done." | Indexing with no continuation handler is dead weight. You must handle `.onContinueUserActivity(CSSearchableItemActionType)` (or `application(_:continue:)`), read `userActivity.userInfo?[CSSearchableItemActivityIdentifier]`, and deep-link to that exact item. No handler = tapping a result just opens your launch screen. |
| "I'll reuse the array index / row number as the identifier." | `uniqueIdentifier` must be globally unique and stable per item, set before first indexing. Reused or positional ids collide — re-indexing one item silently overwrites another, and deletes hit the wrong content. Use the model's real id (or a UUID you persist). |
| "Deleting the row from my data store removes it from Spotlight too." | It does not. Stale items linger as ghost results that deep-link to deleted content (a crash or empty screen). On every delete call `deleteSearchableItems(withIdentifiers:)`; on bulk teardown use the domain or `deleteAllSearchableItems()`. |
| "I don't need a `domainIdentifier`." | Without one you can only delete item-by-item by id. Set a `domainIdentifier` per category so you can wipe a whole group with `deleteSearchableItems(withDomainIdentifiers:)` — essential for logout, account switch, or clearing a folder. |
| "Any attribute set works; the strings are what get searched." | The `contentType` (UTType) shapes how Spotlight presents and ranks the result and which type-specific fields apply (`.audio` enables `artist`/`album`, `.message` enables AI summary, etc.). A wrong/empty contentType gives generic, poorly-ranked results. Pick the UTType that matches the content. |
| "I indexed it once at install; that's enough." | The index goes stale the moment the underlying data changes. Re-index (same `uniqueIdentifier`) on every edit, delete on every removal, and set a realistic `expirationDate` so abandoned items age out instead of haunting search forever. |

## Verification gate

Before shipping Spotlight integration, confirm every line:

- [ ] Every indexed item has a stable, unique `uniqueIdentifier` set before its first index, resolvable back to a real model object.
- [ ] A continuation handler for `CSSearchableItemActionType` exists and deep-links to the specific item via `CSSearchableItemActivityIdentifier` — verified by tapping a real Spotlight result, not just by code review.
- [ ] Deletes from the data store call `deleteSearchableItems(withIdentifiers:)`; edits re-index the same id; no orphan items remain.
- [ ] A `domainIdentifier` is set per category, and logout/account-switch/clear-all wipes the right scope (`withDomainIdentifiers:` or `deleteAllSearchableItems()`).
- [ ] `contentType` matches the content (`.text`, `.audio`, `.content`, `.message`, …) — not left empty or wrong.
- [ ] `expirationDate` is set deliberately per content lifetime (default is ~30 days).
- [ ] `isIndexingAvailable()` guards index calls; index errors are logged, never fatal.
- [ ] If `INTELLIGENCE = on`: gated to iOS 18.4+, `textContent` ≥200 chars, `updateListenerOptions` opted in, and a CoreSpotlight Delegate extension consumes `textContentSummary` / `isPriority`.

## Deep reference

`references/guide.md` — full setup, single/batch indexing, every attribute, update/delete by id and domain, SwiftUI and coordinator continuation patterns, searching your own index with `CSSearchQuery`, App Intents association (`associateAppEntity`), iOS 18.4+ Apple Intelligence summarization, per-domain use cases (recipes, notes, products), and tests. Load it for any concrete API question.

---
name: gamesave
description: Implement and review iCloud-backed cloud game saves with Apple's GameSave framework (iOS 26) — opening a GameSaveSyncedDirectory, waiting for sync, reading directory/availability state, accessing save files, and handling conflicts and iCloud sign-out. Use when the user mentions GameSave, game save, cloud save sync, GameSaveSyncedDirectory, GameSaveSyncedFile, or syncing save data across devices via iCloud. For general (non-game) CloudKit record/document sync, use the `cloudkit` skill instead.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple Developer docs via Context7 (/websites/developer_apple — no dedicated GameSave library exists; GameSaveSyncedDirectory verified, deeper API only partially covered)
---

# GameSave

Apple's iOS 26 framework for iCloud-backed cloud game saves. The flow is small: open a synced directory, let it finish syncing, read its state, then read/write save files inside the directory's local URL while the framework mirrors them to iCloud. The deep reference — setup, entitlements, the manager pattern, SwiftUI integration, conflict and offline handling, GKSavedGame migration, troubleshooting — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## ⚠️ Currency caveat (read before coding)

GameSave is a brand-new iOS 26 framework and Context7 has **no dedicated library** for it. Verification against the broad Apple library confirmed the public class is **`GameSaveSyncedDirectory`** (with `GameSaveSyncedFile` for individual files) — the **`GS…`-prefixed names used throughout `references/guide.md` are wrong**. The guide carries a correction banner, but its example method signatures (`finishSyncing:`, `directoryState()`, the error enum) are **unverified approximations**. Confirm every symbol against developer.apple.com/documentation/GameSave (or autocomplete in an iOS 26 SDK) before shipping.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `CONFLICT_UI` — `built-in` (default; let GameSave present its own conflict-resolution and sign-out alerts via the status window) · `custom` (pass no status window, read state yourself, drive your own merge logic — you own correctness of the merge).
2. `OFFLINE_POLICY` — `cloud-only` (gate gameplay on sync; simplest, fails hard with no network/iCloud) · `local-fallback` (default for shipping games; always write a local copy first, treat the synced directory as best-effort, reconcile on next sync).
3. `MIGRATION` — `none` (new game) · `from-gksavedgame` (existing Game Center saves; one-time import on first launch, then drop the GameKit path).

## When to use

Building or reviewing any cloud-save code in a **game** that talks to GameSave directly: opening the directory, sync gating, reading/writing save files, conflict resolution, or iCloud sign-out handling. If the data isn't game-save data — arbitrary records, documents, or app state synced across devices — use `cloudkit` (CKRecord / NSUbiquitousKeyValueStore / iCloud Documents) instead; don't reach for GameSave just because it's "iCloud."

## Core rules

- iOS 26+ only — GameSave does not exist on earlier OSes. Gate with availability if the app deploys lower.
- The real types are **`GameSaveSyncedDirectory`** and **`GameSaveSyncedFile`**. Do not ship the `GSSyncedDirectory` names from the guide's snippets without verifying against the SDK.
- **Open early, but never read save files before sync completes.** Opening the directory is not the same as having current data; reading the directory's URL before the framework reports a settled/available state can hand you stale or empty local state.
- **The iCloud entitlement and container are mandatory.** GameSave is iCloud-backed: the iCloud capability + a container identifier must be configured, or open/sync silently never succeeds. This is a project-config requirement, not just code.
- **Always have a local fallback path unless the dial says cloud-only.** iCloud sign-out, no network, and account switches are normal states, not exceptions — the game must still be playable.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll copy the `GSSyncedDirectory` example from the guide and ship it." | Those `GS…` symbol names are placeholders and do not match the shipping SDK (`GameSaveSyncedDirectory` / `GameSaveSyncedFile`). It will not compile. Verify every symbol against developer.apple.com/documentation/GameSave first. |
| "I opened the directory, so I can read the save file now." | Opening ≠ synced. Reading the directory URL before sync settles gives you stale or empty data, then your first write clobbers the good cloud copy. Wait for the directory to report a usable/settled state, then read. |
| "Cloud is the source of truth, so I don't need a local save." | iCloud sign-out, offline, and account switches are routine. With no local fallback the game is unplayable in those states and a sign-out can look like total save loss. Write locally first; treat cloud as best-effort (unless the OFFLINE_POLICY dial is explicitly `cloud-only`). |
| "GameSave auto-resolves conflicts, so I can ignore them." | Built-in UI only covers the `built-in` dial. If you suppressed it (custom UI) or need a real merge (highest level, union of items/achievements), last-writer-wins silently destroys progress. Own the merge when CONFLICT_UI is `custom`. |
| "GameSave is just easy iCloud — I'll use it for my app's settings/documents too." | GameSave is scoped to game-save data. For records, documents, or general app state across devices, that's CloudKit / iCloud Documents / NSUbiquitousKeyValueStore — use the `cloudkit` skill. Mixing them gives you two sync systems fighting over the same data. |
| "It synced fine on my one device, ship it." | Cross-device is the whole point and the only place conflicts, sign-out, and slow large-file syncs show up. Test device-A-writes / device-B-reads, both-offline-then-online, and sign-out mid-session before release. |

## Verification gate

Before shipping GameSave code, confirm every line:

- [ ] Every GameSave symbol verified against the iOS 26 SDK / developer.apple.com/documentation/GameSave — no leftover `GSSyncedDirectory`/`GS…` names from the guide snippets.
- [ ] iCloud capability + container identifier configured in entitlements; the container exists in the Developer portal.
- [ ] Code is gated to iOS 26+ (availability check if the deployment target is lower).
- [ ] No save file is read or written before the directory reports a settled/available sync state.
- [ ] iCloud sign-out and no-network are handled as expected states (clear UI, not a crash or silent "save lost").
- [ ] Unless OFFLINE_POLICY is `cloud-only`: a local copy is written first and used as fallback.
- [ ] Conflicts handled per the CONFLICT_UI dial — built-in UI shown, or a real merge implemented (no silent last-writer-wins that drops progress).
- [ ] Tested across two devices on the same iCloud account, including offline-then-online and mid-session sign-out.
- [ ] If MIGRATION is `from-gksavedgame`: one-time import runs once, is idempotent, and the GameKit path is removed after.

## Deep reference

`references/guide.md` — full setup and entitlements, the open → finishSyncing → directoryState → access-URL flow, a manager pattern, SwiftUI view-model/view integration, built-in vs. custom conflict resolution, offline fallback, GKSavedGame migration, and troubleshooting. **Note:** it uses placeholder `GS…` symbol names (see the correction banner at the top of its Core API section) — patterns are sound, literal symbol spellings are not. Load it for concrete patterns, verify symbols against the live docs.

---
name: firebase
description: Integrate and review the Firebase Apple SDK in iOS/Swift apps — FirebaseApp.configure, Auth (email/password, Apple, anonymous), Cloud Firestore (Codable + async/await + listeners), Realtime Database, Cloud Storage, Cloud Messaging (FCM/APNs), Analytics, and Crashlytics, integrated via SwiftPM. Use when the user mentions Firebase, Firestore, Firebase Auth, Cloud Messaging, FCM, Crashlytics, Firebase Analytics, realtime database, GoogleService-Info.plist, or firebase-ios-sdk.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Firebase iOS SDK docs via Context7 (/firebase/firebase-ios-sdk)
---

# Firebase (Apple SDK)

Firebase is **Google's third-party SDK, not Apple's** — it ships from `github.com/firebase/firebase-ios-sdk`, carries its own release cadence, and depends on a `GoogleService-Info.plist` you download from the Firebase Console. The deep API reference — install, configuration, the full Auth flows (email/password, anonymous, Sign in with Apple), Firestore CRUD/queries/listeners/transactions, offline persistence, security rules, and the service/manager patterns — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `BACKEND` — which Firebase products you pull in as SwiftPM products: `auth` · `firestore` (document NoSQL, the default data store) · `rtdb` (Realtime Database, for low-latency presence/streaming) · `storage` (Cloud Storage for files) · `messaging` (FCM push) · `analytics` · `crashlytics`. Add only the products you use; each is a separate `.product(name:, package: "Firebase")`.
2. `AUTH_PROVIDERS` — `none` · `email` · `anonymous` · `apple` (Sign in with Apple via `OAuthProvider.appleCredential`, requires nonce) · `federated` (Google/others). Anonymous-then-link is a common upgrade path.
3. `FIRESTORE_CACHE` — `persistent` (default; `PersistentCacheSettings()`, survives launches, serves reads offline) · `memory` (`MemoryCacheSettings()`, cleared on relaunch). Set on `Firestore.firestore().settings` **before** the first Firestore call.

## When to use

Building or reviewing any code that talks to Firebase from an iOS/Swift app — sign-in, Firestore/RTDB reads and writes, real-time listeners, file uploads, push registration, crash reporting, or analytics. If the app uses a different backend (Supabase, CloudKit, a custom API), use that instead — don't run two backends as competing sources of truth.

## Core rules

- **`FirebaseApp.configure()` runs once, in `App.init` (or `AppDelegate didFinishLaunching`), before any other Firebase call.** Touching `Auth.auth()`, `Firestore.firestore()`, etc. before configure crashes.
- **SwiftPM, not CocoaPods.** Add `https://github.com/firebase/firebase-ios-sdk` and pin a recent major (12.x at time of writing) with `.upToNextMajor(from:)`. Add only the products you need.
- **`GoogleService-Info.plist` is required and is config, not a secret** — but treat it as project-specific: don't commit it to public repos, and use separate plists (and `FirebaseOptions`) per environment.
- **Prefer async/await.** Auth and Firestore expose `async throws` calls and Swift `AsyncStream` (`authStateChanges`, `query.snapshots`, `Messaging.tokenUpdates`, RTDB `ref.value`). Use these over completion handlers in new code.
- **Security lives in server-side rules, never client code.** The Swift code can be read and tampered with; access control is enforced only by Firestore/RTDB/Storage Security Rules.
- **Store every `ListenerRegistration` and `remove()` it** (in `deinit`/`onDisappear`). A dropped registration silently stops updating; an un-removed one leaks and keeps firing.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll read `Auth.auth().currentUser` right away in `init`." | If `FirebaseApp.configure()` hasn't run yet, the first Firebase access crashes. Configure first, always, before any `Auth`/`Firestore`/`Messaging` touch. |
| "My security rules can be loose — I check permissions in the Swift code." | Client code is fully untrusted: it can be patched, and requests can be forged. Firestore/RTDB/Storage **Security Rules** are the only real gate. Client checks are UX, not security. |
| "I'll gate a paid/admin feature on a `Bool` field the app writes to Firestore." | Anything the client can write, a tampered client can set to `true`. Authorize on server-side rules (or a Cloud Function / custom claim), not on self-reported document fields. |
| "Offline returned empty/old data, so the read failed." | With persistent cache, reads are served from the local cache when offline and may be stale; check `snapshot.metadata.isFromCache` / `hasPendingWrites`. Empty ≠ error. Writes queue and replay on reconnect. |
| "I started a snapshot listener; that's enough." | If you don't retain the returned `ListenerRegistration`, it deallocates and stops. If you never `remove()` it, it leaks and double-fires. Store it; remove it in `deinit`/`onDisappear`. |
| "I'll wire it up with CocoaPods like the old tutorials." | SwiftPM is the current, first-class integration path. Use `firebase-ios-sdk` via Add Package Dependencies and select per-product targets; don't add a Podfile for a new project. |

## Verification gate

Before shipping Firebase code, confirm every line:

- [ ] `FirebaseApp.configure()` is called exactly once, before any other Firebase API, at app startup.
- [ ] `GoogleService-Info.plist` is added to the target, correct per environment, and not committed where it shouldn't be.
- [ ] Firebase added via SwiftPM (`firebase-ios-sdk`, recent major pin), only the needed products linked.
- [ ] Auth/Firestore calls use `async/await` (or AsyncStream); completion handlers only where unavoidable.
- [ ] Firestore/RTDB/Storage **Security Rules** enforce access; no feature relies on client-side checks or self-reported document fields for authorization.
- [ ] Every `addSnapshotListener`/`addStateDidChangeListener` registration is stored and removed in `deinit`/`onDisappear`.
- [ ] `FIRESTORE_CACHE` settings applied before the first Firestore call; offline behavior (stale reads, `isFromCache`, queued writes) handled, not treated as failure.
- [ ] Messaging: APNs token wired to FCM and notification permission requested at the right moment (not blindly at launch).

## Deep reference

`references/guide.md` — full SwiftPM install, configuration, the complete Auth flows (email/password, anonymous, Sign in with Apple with nonce), Firestore Codable models, CRUD, queries, real-time listeners, batch writes, transactions, offline persistence, security-rules examples, service/manager patterns, and a quick-reference of key calls. Load it for any concrete API question.

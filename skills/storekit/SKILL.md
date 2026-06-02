---
name: storekit
description: Implement and review in-app purchases and subscriptions with StoreKit 2 — products, the purchase flow, transaction verification, entitlements, restore, and testing. Use when the user mentions in-app purchase, IAP, subscription, paywall, StoreKit, Transaction, entitlement, or monetizing an iOS app. For RevenueCat-managed purchases use the `revenuecat` skill instead.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple StoreKit docs via Context7 (/websites/developer_apple_storekit)
---

# StoreKit 2

In-app purchases and subscriptions on Apple platforms, StoreKit 2 (async/await). The deep API reference — setup, every product type, the full purchase/subscription lifecycle, StoreKit views, App Store Server, testing — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `RECEIPT_VALIDATION` — `on-device` (default; `VerificationResult` is signed by Apple and enough for most apps) · `server` (App Store Server API + signed `JWSTransaction` when revenue risk is high or you grant server-side).
2. `SUBSCRIPTION_MODE` — `none` · `single` (one auto-renewable) · `groups` (multiple tiers with upgrade/downgrade + `Product.SubscriptionInfo.Status`).
3. `UI` — `storekit-views` (iOS 17+ `StoreView`/`SubscriptionStoreView`, default) · `custom` (your own merchandising).

## When to use

Building or reviewing any purchase, paywall, subscription, restore, or entitlement-gating code that talks to StoreKit directly. If the app uses RevenueCat as the purchase layer, use `revenuecat` — don't mix two sources of truth for entitlements.

## Core rules

- StoreKit 2 only. Async/await; no `SKPaymentQueue`/StoreKit 1 unless maintaining legacy code.
- iOS 15+ for the API; StoreKit SwiftUI views need iOS 17+. iOS 26 is the default target.
- **One source of truth for entitlements: `Transaction.currentEntitlements`**, re-evaluated at launch and on every `Transaction.updates` event. Never a cached `Bool` in `UserDefaults`.
- Start the `Transaction.updates` listener in `App.init` (or first scene), before any purchase UI, and keep it for the whole app lifetime.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "`purchase()` returned `.success`, so they're entitled." | `.success` wraps a `VerificationResult`. Unwrap `.verified`; treat `.unverified` as a forged receipt and deny. |
| "I'll just act on the `purchase()` result — no listener needed." | Renewals, Ask-to-Buy approvals, refunds, and other-device purchases arrive **only** through `Transaction.updates`. No listener = dropped entitlements. |
| "I'll cache `isPro = true` in UserDefaults after buying." | Source of truth is `Transaction.currentEntitlements`, checked at launch. Cached flags get wiped on reinstall, granted by jailbreak, and miss refunds/expiry. |
| "I'll `finish()` the transaction right after `purchase()`." | `finish()` only after content is delivered/persisted, and only for `.verified`. Also drain `Transaction.unfinished` at launch — unfinished transactions replay forever. |
| "`currentEntitlements(for:)` reads cleaner." | Deprecated. Use `currentEntitlements`. |
| "Sandbox tested it, ship it." | Local `.storekit` config and sandbox behave differently (Ask-to-Buy, renewal speed, interrupted purchases). Test both, plus the restore path. |

## Verification gate

Before shipping IAP, confirm every line:

- [ ] `Transaction.updates` listener started before any UI, lives for the app lifetime.
- [ ] Every purchase unwraps `VerificationResult`; `.unverified` is rejected, not granted.
- [ ] Entitlements derive from `Transaction.currentEntitlements` at launch + on updates — no cached booleans gating features.
- [ ] `transaction.finish()` called after delivery for every verified transaction, including `Transaction.unfinished` drained on launch.
- [ ] Restore path exists (`Transaction.currentEntitlements`, or `AppStore.sync()` for an explicit "Restore Purchases" button).
- [ ] `.pending` (Ask-to-Buy) and `.userCancelled` handled without showing an error.
- [ ] Subscriptions: expiry, grace period, and revocation (`transaction.revocationDate`) all drop access.
- [ ] Tested with a local `.storekit` config **and** a sandbox account end-to-end.

## Deep reference

`references/guide.md` — full setup, product loading, purchase flow, transaction management, entitlements, StoreKit SwiftUI views, subscriptions, restore, testing, App Store Server, and a quick-reference of key types. Load it for any concrete API question.

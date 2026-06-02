---
name: revenuecat
description: Implement and review in-app purchases, subscriptions, and paywalls with RevenueCat — Purchases SDK configuration, offerings and packages, the purchase flow, CustomerInfo entitlements, restore, and RevenueCatUI prebuilt paywalls. Use when the user mentions RevenueCat, paywall, PaywallView, offerings, packages, entitlements, CustomerInfo, the Purchases SDK, or subscriptions managed by RevenueCat. RevenueCat wraps StoreKit — for raw StoreKit 2 purchases use the `storekit` skill, and never run both as competing sources of truth for entitlements.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: RevenueCat docs via Context7 (/revenuecat/docs)
---

# RevenueCat

In-app purchases, subscriptions, and paywalls on iOS via RevenueCat's Purchases SDK and RevenueCatUI. RevenueCat sits on top of StoreKit: it owns product fetching, the purchase flow, the entitlement computation, and (optionally) the paywall UI. The full API reference — SDK configuration, offerings/packages, the purchase flow, `CustomerInfo` entitlements, restore, and RevenueCatUI paywalls — lives in `references/guide.md`; a focused troubleshooting note for the iOS 26 `PaywallView` "Missing Metadata" failure is in `references/ios26-paywall-fix.md`. This file is the decision and discipline layer: read it first, open the references for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `PAYWALL_UI` — `revenuecatui-prebuilt` (default; RevenueCatUI `PaywallView` / `presentPaywallIfNeeded`, templates configured in the dashboard) · `custom` (you read `offering.availablePackages` and build your own merchandising; you own card layout, pricing copy, and selection state).
2. `ENTITLEMENT_MODE` — `entitlement-id` (default; gate features on `customerInfo.entitlements["pro"]?.isActive`, identifier configured in the RevenueCat dashboard) · `product-id` (check `activeSubscriptions` / `nonSubscriptionTransactions` directly — only when you deliberately bypass entitlements).
3. `STOREKIT_VERSION` — `sk2` (default; RevenueCat's StoreKit 2 backend, required for current iOS targets) · `sk1` (legacy fallback). This is RevenueCat's internal StoreKit layer, not your code — you do not call StoreKit directly.

## When to use

Building or reviewing any purchase, paywall, subscription, restore, or entitlement-gating code that goes through RevenueCat's Purchases SDK or RevenueCatUI. If the app talks to `StoreKit`/`Transaction` directly instead of RevenueCat, use the `storekit` skill. Do not run both: pick RevenueCat as the source of truth and let it wrap StoreKit, or use StoreKit alone — two entitlement systems will disagree.

## Core rules

- `Purchases.configure(withAPIKey:)` runs once, early in app launch (`App.init` / `didFinishLaunchingWithOptions`), before any paywall or purchase UI. Use the **public** SDK key, never a secret key.
- **One source of truth for entitlements: `CustomerInfo.entitlements`** from RevenueCat, re-read on launch and observed live via the `customerInfo` stream / delegate. Never a cached `isPro` `Bool` in `UserDefaults`.
- Gate features on the entitlement identifier (`entitlements["pro"]?.isActive`), not on a raw product ID — entitlements survive product renames, plan changes, and grandfathering.
- Prefer the async/await surface (`try await Purchases.shared.offerings()`, `purchase(package:)`) over completion handlers in new code; both are current.
- Let RevenueCat own StoreKit. Do not also start a `Transaction.updates` listener or call `Transaction.currentEntitlements` — that is the `storekit` skill's job and will fight RevenueCat for the same transactions.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "The paywall is blank / cards show 'Missing Metadata' — must be iOS 26 Liquid Glass." | It is almost never styling. The products are in **Missing Metadata** state in App Store Connect (no subscription group, missing localization/pricing, or unsigned Paid Apps Agreement), so StoreKit can't fetch them and `PaywallView` fails silently. Use a local `.storekit` config to develop, and fix the ASC metadata before ship. (See guide.) |
| "`purchase(package:)` returned with no error, so they're entitled." | Check `userCancelled` and, more importantly, derive access from `customerInfo.entitlements["pro"]?.isActive` — not from the absence of an error. |
| "I'll cache `isPro = true` after the purchase succeeds." | Source of truth is `CustomerInfo.entitlements`, re-read on launch and via the live stream. Cached flags miss renewals, refunds, expiry, and other-device purchases, and get wiped on reinstall. |
| "RevenueCat wraps StoreKit, so I'll also listen to `Transaction.updates` to be safe." | Two listeners = two sources of truth that drift. Let RevenueCat own StoreKit entirely; observe RevenueCat's `customerInfo` stream instead. Mixing in raw StoreKit is the single most common RevenueCat footgun. |
| "I'll gate the feature on the product ID `app_yearly_1999`." | Gate on the entitlement identifier. Product IDs change with pricing experiments and plan migrations; entitlements are the stable abstraction RevenueCat exists to give you. |
| "Sandbox/StoreKit-config tested fine, ship it." | Local `.storekit` config bypasses App Store Connect entirely, so it hides exactly the Missing-Metadata failure that breaks production paywalls. Test against real sandbox products and an actual offering before release. |
| "No restore button needed — RevenueCat tracks the user." | Anonymous users and reinstalls still need `Purchases.shared.restorePurchases()` behind an explicit "Restore Purchases" control for App Review and for users switching devices. |

## Verification gate

Before shipping RevenueCat IAP, confirm every line:

- [ ] `Purchases.configure(withAPIKey:)` called once at launch with the **public** key, before any paywall/purchase UI.
- [ ] Entitlements derive from `CustomerInfo.entitlements["…"].isActive`, re-read on launch and observed live — no cached booleans gating features.
- [ ] Features gate on entitlement **identifier**, not product ID.
- [ ] No raw StoreKit (`Transaction.updates` / `currentEntitlements`) running alongside RevenueCat — one source of truth.
- [ ] Purchase flow handles `userCancelled` and errors without showing a false failure, and grants access only when the entitlement is active.
- [ ] An explicit "Restore Purchases" path calls `restorePurchases()`.
- [ ] App Store Connect products are fully configured (subscription group, localization, pricing, Paid Apps Agreement) — verified to load against real sandbox, not only a local `.storekit` config.
- [ ] If `PAYWALL_UI = revenuecatui-prebuilt`: the offering shown actually contains the intended packages (debug-log `offering.availablePackages`), and the paywall renders product cards on the target iOS version (incl. iOS 26).

## Deep reference

`references/guide.md` — comprehensive RevenueCat iOS reference: `Purchases` configuration, fetching offerings and packages, the purchase and restore flow, `CustomerInfo`/entitlement checks, user identification, and RevenueCatUI paywalls. Load it for any concrete API question.

`references/ios26-paywall-fix.md` — focused troubleshooting note: the iOS 26 `PaywallView` "Missing Metadata" failure and its root cause, wiring a StoreKit Configuration File for local development, separating offerings, and the console warnings that signal unfetchable products. Load it for a paywall-not-rendering or product-loading bug.

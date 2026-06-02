---
name: passkit
description: Implement and review PassKit — Apple Wallet passes (PKPass, PKPassLibrary, PKAddPassesViewController, AddPassToWalletButton) and Apple Pay (PKPaymentRequest, PKPaymentAuthorizationController, PKPaymentButton / PayWithApplePayButton, payment tokens, pass updates). Use when the user mentions PassKit, Apple Wallet, Wallet pass, PKPass, boarding pass, loyalty card, event ticket, Apple Pay, PKPaymentRequest, payment sheet, or adding a pass to Wallet. For StoreKit in-app purchases use the `storekit` skill instead — Apple Pay is for physical goods/services, not digital content.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple PassKit docs via Context7 (/websites/developer_apple)
---

# PassKit

Apple Wallet passes and Apple Pay on Apple platforms. The deep API reference — merchant setup, the full payment authorization flow, pass creation/library management, SwiftUI buttons, use cases, security — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `DOMAIN` — `wallet-passes` (issue/add/manage `PKPass` in Wallet) · `apple-pay` (charge for physical goods/services via `PKPaymentRequest`) · `both`. Apple Pay and Wallet passes are unrelated subsystems that happen to share the PassKit import; pick what you're actually building.
2. `PASS_UPDATES` — `static` (one-shot `.pkpass`, never changes) · `push-updatable` (pass has `webServiceURL` + `authenticationToken`, your server pushes updates via APNs and the Wallet web service protocol). Only relevant when `DOMAIN` includes `wallet-passes`.
3. `PAY_UI` — `PayWithApplePayButton-SwiftUI` (iOS 16+, default for SwiftUI; handles presentation via `onPaymentAuthorizationChange`) · `PKPaymentButton-UIKit` (`PKPaymentAuthorizationController` + delegate, for UIKit or full control). Only relevant when `DOMAIN` includes `apple-pay`.

## When to use

Building or reviewing any Wallet-pass issuing/adding/updating code, or any Apple Pay payment sheet, request, or token-handling code. If the user wants to sell **digital** content (subscriptions, unlocks, consumables), that is StoreKit, not Apple Pay — use the `storekit` skill. Apple Pay is only for real-world goods and services.

## Core rules

- Apple Pay is a **payment-presentation and tokenization** layer, not a processor. The `PKPaymentToken` goes to your PSP (Stripe, Braintree, Adyen) or your own server with the payment processing certificate. PassKit never charges a card.
- iOS 16+ for `PayWithApplePayButton`; the UIKit `PKPaymentAuthorizationController` flow works earlier. iOS 26 is the default target.
- A `.pkpass` is **cryptographically signed with your Pass Type ID certificate**. It must be built server-side. The app only *receives* and adds passes — it cannot fabricate or mutate pass contents on device.
- Gate the Apple Pay button on `PKPaymentAuthorizationController.canMakePayments(usingNetworks:)`, not just `canMakePayments()`, before showing it.
- Always finish the payment flow: call the authorization `handler`/result, then dismiss in `paymentAuthorizationControllerDidFinish`. An unhandled completion freezes the sheet.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll generate the `.pkpass` in the app so it works offline." | Passes are signed with your Pass Type ID cert and private key. Shipping that key in the app is a security breach and App Review rejection. Build and sign passes server-side; the app downloads `Data` and calls `PKPass(data:)`. |
| "Apple Pay is set up — I added `PayWithApplePayButton`." | Apple Pay needs a Merchant ID, the Apple Pay capability/entitlement, **and** a payment processing certificate registered to that Merchant ID. Missing any one means the sheet shows then fails silently. The button alone does nothing. |
| "`canMakePayments()` is true, so show the Pay button." | `canMakePayments()` only means the device supports Apple Pay. Use `canMakePayments(usingNetworks:)` to confirm the user has a provisioned card on one of *your* supported networks — otherwise the button leads to an empty sheet. |
| "I returned the auth result; the sheet will close itself." | You must call the `handler`/return the `PKPaymentAuthorizationResult` **and** dismiss in `paymentAuthorizationControllerDidFinish`. Skip either and the sheet hangs or the continuation never resumes. |
| "I'll restyle the Apple Pay button to match my brand." | `PKPaymentButton` / `PayWithApplePayButton` styling is constrained by Apple's HIG and enforced in App Review — use the provided types/styles (`.buy`, `.checkout`, `.book`, `.plain`, `.automatic`), correct corner radius, and no custom label text beyond the allowed set. Custom-drawn "Apple Pay" buttons get rejected. |
| "It worked with my real card in development." | Apple Pay test transactions need a **sandbox tester account** signed into Wallet with sandbox test cards; using a real card in dev can incur real charges and won't exercise the sandbox token path. Test the full token → server → result round-trip in sandbox. |

## Verification gate

Before shipping PassKit code, confirm every line that applies to your `DOMAIN`:

Apple Pay:
- [ ] Merchant ID, Apple Pay entitlement, and payment processing certificate all exist and match.
- [ ] Pay button gated on `canMakePayments(usingNetworks:)`, not bare `canMakePayments()`.
- [ ] `PKPaymentRequest` has `merchantIdentifier`, `merchantCapabilities`, `countryCode`, `currencyCode`, `supportedNetworks`, and summary items whose last item is the grand total.
- [ ] `didAuthorizePayment` returns/calls a `PKPaymentAuthorizationResult`; `paymentAuthorizationControllerDidFinish` dismisses the sheet — both paths covered for success and failure.
- [ ] `payment.token` is forwarded to the PSP/server; no card data handled or logged in the app.
- [ ] Button style/label uses an Apple-provided type — no custom-drawn Apple Pay button.
- [ ] Tested end-to-end with a sandbox tester account and sandbox test cards.

Wallet passes:
- [ ] `.pkpass` is built and signed **server-side**; no signing key in the app bundle.
- [ ] App downloads pass `Data` and constructs `PKPass(data:)`, handling the throw.
- [ ] Add flow uses `AddPassToWalletButton` (SwiftUI) or `PKAddPassesViewController(pass:)` / `PKPassLibrary.addPasses` (UIKit), gated on `PKPassLibrary.isPassLibraryAvailable()`.
- [ ] `push-updatable` passes set `webServiceURL` + `authenticationToken` and the server implements the Wallet web service + APNs push.

## Deep reference

`references/guide.md` — full merchant/certificate setup, availability checks, `PKPaymentAuthorizationController` and SwiftUI flows, payment request + summary items + shipping, the complete authorization delegate, `PKPass`/`PKPassLibrary`/`PKAddPassesViewController`, SwiftUI `AddPassToWalletButton`, iOS 18/26 features (order tracking, Tap to Pay, Liquid Glass button placement), end-to-end use cases (checkout, donation, event ticket, loyalty card), and security/UX/testing practices. Load it for any concrete API question.

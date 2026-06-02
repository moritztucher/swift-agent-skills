---
name: identity-document-services
description: Build an iOS 26 identity document provider — register mobile documents (mdoc) with the system, host the per-request consent UI, validate the reader request, and return an encrypted ISO 18013 response over the W3C Digital Credentials API. Use when the user mentions IdentityDocumentServices, mobile ID, digital ID, mobile driver's license / mDL, mdoc, ISO 18013, identity verification, Wallet ID, or presenting/verifying a digital identity document on the web.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple Developer docs (IdentityDocumentServices / IdentityDocumentServicesUI) via Context7 (/websites/developer_apple) — no dedicated framework library exists; verified against the broad Apple library.
---

# IdentityDocumentServices

iOS 26 framework for apps that hold a user's mobile document (mdoc — e.g. a mobile driver's license) and present it to a verifying website through the W3C Digital Credentials API. Your app ships an **Identity Document Provider extension** that (1) registers documents with the system and (2) renders a consent scene per request, validates the reader's signed request, and returns an encrypted ISO 18013-7 response. The full API reference — registration, the request scene, the `sendResponse` flow, security model, web/JS side, testing — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `ROLE` — `provider` (default; you hold and present documents — this is the app-side flow this skill and entitlement cover) · `browser` (you implement the web presentment flow into a browser engine — different protocols: `IdentityDocumentWebPresentmentRequest`/`...RawRequest`/`...Response`). Verifier/relying-party logic is server-side and out of scope here.
2. `DOC_TYPES` — which mdoc types you register and are entitled for (e.g. `org.iso.18013.5.1.mDL`). This list is duplicated in your entitlement and gates everything; decide it up front.
3. `TRUST` — `production` (real reader CAs; `supportedAuthorityKeyIdentifiers` are live AKI bytes; only matching readers see your app) · `sandbox` (test CAs/documents in `#if DEBUG`). Never ship sandbox authorities.

## When to use

Building or reviewing an Identity Document Provider extension, document registration, the request-consent scene, request validation, or the encrypted response — anything importing `IdentityDocumentServices` / `IdentityDocumentServicesUI`. Not for general Wallet passes (`PassKit`), not for `proximity`/in-person-only mdoc presentment, and not for the verifying website's server-side decryption/trust logic.

## Core rules

- iOS 26+ only. There is no back-deployment; gate the whole feature on availability.
- The provider's principal type conforms to `IdentityDocumentProvider` and exposes `var body: some IdentityDocumentRequestScene` built from `ISO18013MobileDocumentRequestScene { context in … }` — **not** `some Scene` / `WindowGroup`.
- `IdentityDocumentProviderRegistrationStore` is an **`actor`**: every call (`addRegistration`, `registrations`) is `await`-ed.
- `MobileDocumentRegistration` takes all values at init — `mobileDocumentType`, `supportedAuthorityKeyIdentifiers: [Data]`, `documentIdentifier`, `invalidationDate`. There is no mutable `authorityKeyIdentifiers: [String]` property.
- `try await context.sendResponse { rawRequest in … return ISO18013MobileDocumentResponse(responseData:) }` is the only way to share data. Inside the closure you MUST validate consistency (`context.request` vs `rawRequest`) and the reader signature before building the response. Declining = never calling `sendResponse`.
- The managed entitlement `com.apple.developer.identity-document-services.document-provider.mobile-document-types` requires Apple approval before production — it is not a checkbox.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll add the entitlement and ship." | `com.apple.developer.identity-document-services.document-provider.mobile-document-types` is a **managed capability requiring Apple approval** through the Developer portal. Without it the extension won't run in production. Request it early — approval is not instant. |
| "The website asked for these fields, I'll just return the whole document." | Selective disclosure is the entire point and a legal requirement in most jurisdictions. Return **only** the requested-and-approved elements. Over-sharing regulated identity data is a privacy violation, not a convenience. |
| "iOS already parsed and validated the request, I can trust `rawRequest`." | You MUST re-validate inside `sendResponse`: confirm `rawRequest` matches the system-parsed `context.request` (anti-tamper) and verify the reader's signature/cert chain against trusted CAs (ISO 18013-5). Skipping either lets a forged or swapped request through. |
| "I'll log the document fields / response while debugging." | This is government-issued identity data (name, DOB, license number, portrait). Never log, cache to disk, or send it anywhere but the encrypted `sendResponse`. Treat every field as regulated PII; a stray `print` is a breach. |
| "mDL works, so any region's ID will work." | Not all regions or document types are supported, and availability differs by hardware (e.g. iOS 26.1: U.S. passport digital IDs require iPhone 11+). Register only the `DOC_TYPES` you're actually entitled for and handle "not available here" gracefully. |
| "I'll set `authorityKeyIdentifiers` after creating the registration." | That mutable property doesn't exist. Pass `supportedAuthorityKeyIdentifiers: [Data]` (raw AKI bytes) at init. Those bytes gate which readers can even see your app — wrong/empty values mean your document silently never appears in the sheet. |

## Verification gate

Before shipping an identity document provider, confirm every line:

- [ ] Managed entitlement requested and **approved** by Apple; the entitlement's `mobile-document-types` array matches the `DOC_TYPES` you register.
- [ ] Principal type is `IdentityDocumentProvider` with `body: some IdentityDocumentRequestScene` via `ISO18013MobileDocumentRequestScene` — no `WindowGroup`.
- [ ] Registrations created with the full `MobileDocumentRegistration` init (`supportedAuthorityKeyIdentifiers: [Data]`, `invalidationDate`); store accessed as an `actor`.
- [ ] `performRegistrationUpdates()` reconciles `store.registrations` against the app's documents (adds new, lets stale ones invalidate).
- [ ] Inside `sendResponse`: consistency check (`context.request` vs raw) **and** reader-signature/cert-chain validation both run before any response is built.
- [ ] Response contains **only** the requested-and-approved elements, encrypted to the reader's public key (HPKE) per ISO 18013-7 — nothing extra.
- [ ] No identity data is logged, persisted, or transmitted outside the encrypted `sendResponse`.
- [ ] Decline path ends the request without calling `sendResponse`; user clearly sees who is asking and what fields, including retention intent.
- [ ] Production build uses real reader CAs, not sandbox authorities; unsupported region/document/hardware combinations are handled gracefully.

## Deep reference

`references/guide.md` — full framework overview, document registration, the extension/principal class, the `ISO18013MobileDocumentRequestScene` + context flow, request validation, response encryption, the security model (reader/issuer/device auth, domain validation), the web/JS Digital Credentials side, the end-to-end verification flow, error handling, testing, and a standards reference (ISO 18013-5/-7, W3C DC API, HPKE). Load it for any concrete API question.

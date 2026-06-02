---
name: authenticationservices
description: Implement and review user authentication with Apple's AuthenticationServices framework — Sign in with Apple (ASAuthorizationController), passkeys (ASAuthorizationPlatformPublicKeyCredentialProvider), ASWebAuthenticationSession for third-party OAuth/OpenID Connect login, password AutoFill, and credential-state checks. Use when the user mentions Sign in with Apple, passkeys, AuthenticationServices, ASAuthorizationController, ASWebAuthenticationSession, OAuth login, AutoFill, or sign-in flows. For Face ID/Touch ID gating of an already-authenticated session use the `localauthentication` skill instead.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple AuthenticationServices docs via Context7 (/websites/developer_apple)
---

# AuthenticationServices

Sign in with Apple, passkeys (WebAuthn/FIDO2), and web-based OAuth on Apple platforms. The deep API reference — setup, entitlements, the full Apple ID / passkey / OAuth flows, the `AuthenticationManager` and `PasskeyManager` implementations, server integration, and version compatibility — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `AUTH_METHOD` — `apple-id` (Sign in with Apple, iOS 13+, the default for first-party accounts) · `passkey` (passwordless WebAuthn, iOS 16+, needs associated domains) · `oauth` (third-party IdP via `ASWebAuthenticationSession`) · `combined` (offer several requests in one `ASAuthorizationController`).
2. `TOKEN_VERIFICATION` — `server` (default; the `identityToken` JWT and `authorizationCode` are verified server-side against Apple's public keys — required for any real account system) · `client-only` (prototype/demo only; never grants real access).
3. `BIOMETRIC_GATE` — `none` (default) · `local-auth` (re-gate a returning session behind Face ID/Touch ID via the `localauthentication` skill — AuthenticationServices establishes identity, LocalAuthentication re-confirms the device owner).

## When to use

Building or reviewing any sign-in, account-creation, passkey, or third-party OAuth flow that uses AuthenticationServices. Use this for establishing *who the user is*. For locking an already-signed-in session behind Face ID/Touch ID, that is a different concern — use `localauthentication`. If purchases/entitlements are involved, that is `storekit` / `revenuecat`, not this skill.

## Core rules

- `ASAuthorizationController` drives every credential type (Apple ID, passkey, password). Set both `delegate` and `presentationContextProvider`, then `performRequests()`. Bridge to async with a single `CheckedContinuation` resumed exactly once.
- The `identityToken` / `authorizationCode` mean nothing until your **server** verifies them. The client only relays; trusting a client-side decode grants access to anyone who can POST a payload.
- Email and full name come back **only on the very first authorization** for a given Apple ID. Persist them immediately. The `user` identifier is the stable key for every later sign-in.
- Store the `user` identifier in the **Keychain**, never `UserDefaults`. Check `credentialState(forUserID:)` at launch and observe `credentialRevokedNotification` — sign out on `.revoked` / `.notFound`.
- Passkeys require the Associated Domains entitlement (`webcredentials:yourdomain`) **and** a reachable `apple-app-site-association` file. No AASA, no passkey.
- Third-party OAuth uses `ASWebAuthenticationSession`, never `SFSafariViewController` or a `WKWebView`.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll grab `email`/`fullName` from the credential whenever I need them." | Apple returns them **once**, on first authorization only. On every subsequent sign-in they are `nil`. Persist them on first sign-in keyed by `credential.user`, or they are gone for good. |
| "The token decodes to the right user, so they're authenticated." | The `identityToken` is an unverified JWT until your **server** validates its signature against Apple's public keys, plus `aud`, `iss`, `exp`, and the nonce. Client-side decode is forgeable — verify server-side or grant nothing. |
| "Sign-in worked once, so the user stays signed in." | Credentials get revoked (user removes the app from Apple ID settings, signs out of iCloud, etc.). Call `credentialState(forUserID:)` at launch and observe `credentialRevokedNotification`; drop the session on `.revoked`/`.notFound`. |
| "Passkeys work in the simulator, so the setup is fine." | Passkeys need the Associated Domains entitlement **and** a live `apple-app-site-association` at `/.well-known/`, served as `application/json` with no redirects. Missing/misconfigured AASA fails registration with a domain-association error — there is no client-only passkey. |
| "I'll just drop the OAuth login in an in-app `WKWebView` / `SFSafariViewController`." | Use `ASWebAuthenticationSession`. WebViews don't share the system login session, can't autofill saved passwords/passkeys, break federated SSO, and are rejected by major IdPs (and App Review). |
| "Sign in with Apple gives a nonce, I can skip my own." | Generate a random nonce per request, send its SHA256 in the request, and have the server compare the raw nonce echoed in the token. Without it the token is replayable — this is mandatory when bridging to Firebase/Auth0/your own backend. |
| "I'll store the Apple `user` id in UserDefaults, it's not a secret." | It's a stable account key — keep it in the Keychain (`kSecAttrAccessibleAfterFirstUnlock`). UserDefaults is unencrypted, backed up, and trivially editable. |

## Verification gate

Before shipping any AuthenticationServices flow, confirm every line:

- [ ] `ASAuthorizationController` has both `delegate` and `presentationContextProvider`; the continuation resumes exactly once on success **and** error.
- [ ] `identityToken` + `authorizationCode` are sent to the server and verified there (signature, `aud`/`iss`/`exp`, nonce) — no client-only trust.
- [ ] A per-request nonce is generated, hashed into the request, and validated server-side against the token.
- [ ] First-sign-in `email`/`fullName` are persisted immediately, keyed by `credential.user`; later sign-ins read from your store.
- [ ] The `user` identifier lives in the Keychain (not UserDefaults); `credentialState(forUserID:)` runs at launch and `credentialRevokedNotification` is observed; `.revoked`/`.notFound` sign the user out.
- [ ] User cancellation (`ASAuthorizationError.canceled`) is swallowed silently — no error alert.
- [ ] Passkeys: Associated Domains entitlement set and AASA file live, correct `Content-Type`, no redirects; challenge comes from the server and assertion is verified server-side.
- [ ] OAuth uses `ASWebAuthenticationSession` (with PKCE + `state`), not a WebView; the client secret is never embedded in the app.

## Deep reference

`references/guide.md` — full setup and entitlements, the SwiftUI `SignInWithAppleButton`, complete `AuthenticationManager` (async/await, Keychain, credential-state) and `PasskeyManager` (registration/assertion), the `ASWebAuthenticationSession` OAuth coordinator, server token verification, common pitfalls, iOS version compatibility, and a quick-reference of key types. Load it for any concrete API question.

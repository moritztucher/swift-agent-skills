---
name: universal-links
description: Implement and debug universal links and deep linking on Apple platforms — the Associated Domains entitlement, the apple-app-site-association (AASA) file, handling incoming links via SwiftUI onOpenURL / onContinueUserActivity and the UIKit scene / AppDelegate userActivity continuation, routing to the right screen, and custom URL schemes. Use when the user mentions universal links, deep linking, associated domains, apple-app-site-association, AASA, applinks, onOpenURL, custom URL scheme, "open my app from a link", or a tapped link opening Safari instead of the app.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple Developer docs via Context7 (/websites/developer_apple)
---

# Universal Links & Deep Linking

Getting a tapped link to open your app on the right screen — universal links, the Associated Domains entitlement, the AASA file, custom URL schemes, and link handling across SwiftUI and UIKit lifecycles. The full API/format reference, hosting rules, lifecycle matrix, routing, testing, and failure-mode table live in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `LINK_TYPE` — `universal-link` (default; secure, verified `https://`, falls back to web) · `custom-scheme` (`myapp://`, spoofable, no web fallback — for OAuth callbacks / internal glue only) · `both` (universal links public, custom scheme as private/test fallback).
2. `AASA_HOSTING` — `well-known` (default; `https://<domain>/.well-known/apple-app-site-association`) · `root` (legacy `https://<domain>/apple-app-site-association`; serve identically if you keep both).
3. `HANDLING` — `swiftui-onOpenURL` (default; `.onOpenURL` + `.onContinueUserActivity(NSUserActivityTypeBrowsingWeb)`) · `uikit-userActivity` (scene `willConnectTo` / `continue` + AppDelegate `continue:restorationHandler:`).

## When to use

Adding, reviewing, or debugging any flow where a link opens the app: shared content links, email/SMS deep links, marketing links, OAuth redirects, QR codes, Handoff. Also the classic "the link just opens Safari" debugging session. If you only need in-app navigation between screens with no external entry point, this isn't it — use plain SwiftUI navigation.

## Core rules

- **Prefer universal links.** `https://` links are Apple-verified (only the app matching your AASA can claim the domain) and fall back to the web when the app isn't installed. Reach for a custom scheme only for OAuth callbacks or internal redirects.
- **The entitlement and the AASA must agree exactly.** Entitlement `applinks:<host>` (no scheme, no path) must match an AASA `appIDs` entry of `<TeamID>.<bundleID>` hosted on that host. A mismatch fails silently.
- **The trusted part of a universal link is the domain, not the payload.** Apple verifies who owns the domain; the path and query are attacker-controllable. Validate them like any untrusted input.
- **Route from one place.** Cold launch and warm resume deliver the link through different entry points — funnel all of them into a single handler that maps URL → navigation state.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll name the file `apple-app-site-association.json` and add a redirect to it." | Both break it. The file has **no extension**, must return `200` with **no redirect**, `Content-Type: application/json`, over HTTPS, at `/.well-known/`. Any one wrong → links open Safari forever. |
| "I tested it by typing the link into Safari's address bar — nothing happened, it's broken." | **Expected.** Typing/pasting into the address bar never triggers a universal link, and neither does a link to your domain tapped *while already on your domain*. Test from Messages, Mail, or Notes. |
| "I edited the AASA and it didn't update, the file must be wrong." | Apple's **CDN caches** your AASA — changes lag. Use `?mode=developer` in the entitlement on a device to bypass the CDN and pull directly, or wait for re-cache. |
| "The custom-scheme link carried a user ID, so I logged them in." | Custom schemes are **spoofable** — any app can register `myapp://`. Never authorize or authenticate off custom-scheme contents; treat the payload as untrusted. |
| "It works on the Simulator, ship it." | The Simulator doesn't run full CDN-backed verification reliably. `xcrun simctl openurl` tests your *handler*, not the association. Validate on a **real device** (Site/Fmwk Approval == `approved` in sysdiagnose). |
| "`.onOpenURL` is enough." | It covers custom schemes and SwiftUI-delivered universal links, but on cold launch UIKit apps get the link via scene `willConnectTo` / launch options, and Handoff arrives as `NSUserActivityTypeBrowsingWeb`. Wire every entry point your lifecycle uses. |

## Verification gate

Before shipping deep links, confirm every line:

- [ ] Associated Domains capability added; entitlement lists each host as `applinks:<host>` (no scheme/path), `www` and apex both if both serve links.
- [ ] AASA `appIDs` = `<TeamID>.<bundleID>` matches the app's real signing identity exactly.
- [ ] `curl -v https://<domain>/.well-known/apple-app-site-association` returns `200` (no redirect), `Content-Type: application/json`, valid JSON, no file extension, publicly reachable from all IPs.
- [ ] `components` order is correct — narrow `exclude` rules precede the broad include they carve out of.
- [ ] Incoming links handled for **both** cold launch and warm resume (SwiftUI `.onOpenURL` + `.onContinueUserActivity(NSUserActivityTypeBrowsingWeb)`, or the UIKit scene/AppDelegate methods).
- [ ] Path/query parsed with `URLComponents` and validated; unknown routes fail safe; no privileged action taken purely on link contents.
- [ ] Custom-scheme payloads (if any) treated as untrusted — never used for auth/authorization.
- [ ] Tested on a **real device** from Messages/Mail/Notes; AASA validator clean; sysdiagnose Site/Fmwk Approval == `approved`.

## Deep reference

`references/guide.md` — the three mechanisms compared, the Associated Domains entitlement (`applinks:` / `webcredentials:` / `activitycontinuation:`, developer mode), the AASA file (modern `details`/`appIDs`/`components` + legacy `paths`, all hosting rules), link handling in SwiftUI and every UIKit lifecycle path, routing patterns, testing (device, AASA validator, `simctl openurl`, sysdiagnose), and the full failure-mode table. Load it for any concrete format or API question.

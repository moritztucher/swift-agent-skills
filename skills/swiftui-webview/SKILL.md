---
name: swiftui-webview
description: Embed and control web content in SwiftUI — the iOS 26 native WebView + WebPage observable (url/title/load/navigation/callJavaScript), and the WKWebView via UIViewRepresentable path for older targets (navigation delegate, JS messaging, configuration). Use when the user mentions WebView, WKWebView, WebPage, embed web content, SwiftUI web view, load HTML, or a JavaScript bridge. For opening arbitrary external links or trusted full-browser content, use SFSafariViewController (SafariServices) instead.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple WebKit docs via Context7 (/websites/developer_apple_webkit)
---

# SwiftUI WebView

Displaying and controlling web content in SwiftUI. The deep API reference — native `WebView`/`WebPage`, navigation events, `NavigationDeciding`, JS interaction, `URLSchemeHandler`, find-in-page, the `WKWebView`/`UIViewRepresentable` path, coordinator pattern, and migration — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `BACKEND` — `native` (iOS 26+ SwiftUI `WebView` + `WebPage`, default; no UIKit) · `representable` (`WKWebView` via `UIViewRepresentable` + `Coordinator`, required below iOS 26) · `conditional` (`if #available(iOS 26, *)` switching between the two — the real answer when your deployment target is < iOS 26).
2. `CONTENT_TRUST` — `bundled` (your own HTML/JS via `URLSchemeHandler` or `load(html:baseURL:)`) · `first-party` (your own web properties, fixed allowlist) · `arbitrary` (user-followable external links — **this is the SFSafariViewController case, not a bare WebView**).
3. `JS_BRIDGE` — `none` · `read` (Swift calls `callJavaScript` / `evaluateJavaScript` to read the page) · `two-way` (page posts to a `WKScriptMessageHandler` / native handler — every inbound message must be validated).

## When to use

Embedding web content you control inside your own UI: rendered HTML, a bundled web app, a first-party page with a native chrome around it, or a Swift↔JS bridge. If the goal is to open an arbitrary URL the user tapped (external links, "open in browser", OAuth, marketing pages), reach for `SFSafariViewController` — App Review treats a bare `WKWebView` showing third-party content as a rejection risk.

## Core rules

- Default to the native iOS 26 `WebView`/`WebPage`. `WebPage` is `@Observable` — hold it in `@State`, read `title`/`url`/`isLoading`/`estimatedProgress`/`currentNavigationEvent`, drive it with `page.load(...)`. No `UIViewRepresentable`, no manual `@Published` plumbing.
- Below iOS 26 the native types do not exist. If your deployment target is lower, you ship the `UIViewRepresentable` + `WKWebView` path (gated with `if #available(iOS 26, *)`), not the native API alone.
- `WebPage.NavigationDeciding.decidePolicy(for:preferences:)` (native) / `WKNavigationDelegate.webView(_:decidePolicyFor:...)` (UIKit) is where you allow/deny and divert external links — not an afterthought.
- All web/JS calls are `@MainActor` and `async`. `callJavaScript`/`evaluateJavaScript` are `await`ed; never block the main thread waiting on a load.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll just use the new native `WebView` everywhere." | `WebView`/`WebPage` are iOS 26+. If your deployment target is below 26 they won't compile/run there — gate with `if #available(iOS 26, *)` and keep a `WKWebView` `UIViewRepresentable` fallback. `conditional` is the honest dial. |
| "I'll drop a `WKWebView` in to show this external/marketing/login page." | Apple rejects apps that wrap arbitrary third-party web content in a bare web view (and you lose Safari's autofill/cookies/security UI). For user-followable external links and trusted full-browser content use `SFSafariViewController`. |
| "The coordinator's a local, ARC will keep it." | In the `UIViewRepresentable` path the `Coordinator` is the `navigationDelegate`/`WKScriptMessageHandler`; it must be owned (returned from `makeCoordinator()` and retained by the representable), and message handlers removed in `dismantleUIView` or they leak and replay. |
| "Messages from the page are my own JS, I trust them." | Anything loaded in the web view can post to your `WKScriptMessageHandler` — including injected/third-party script. Validate `message.name`, type-check `message.body`, and never `eval`/route it into native actions unchecked. A bridge is an attack surface. |
| "Loading the http URL works in the simulator, ship it." | App Transport Security blocks cleartext `http` by default; it "works" only because of a debug exception or a cached load. Use `https`, or add a scoped ATS exception you can justify — don't disable ATS globally. |
| "I'll read the title right after `load()`." | `load()` is async; `title`/`url`/the DOM aren't ready until navigation commits. Observe `currentNavigationEvent` (`.finished`) on `WebPage`, or `didFinish` in the delegate — don't `Task.sleep` and hope. |
| "`callJavaScript("document.title")` returns the title." | `callJavaScript` takes a function *body* — `return document.title`. Pass values via `arguments:` instead of string-interpolating user data into the script (injection). |

## Verification gate

Before shipping a WebView, confirm every line:

- [ ] Backend matches the deployment target: native `WebView` only if iOS 26+ everywhere, otherwise `if #available` + `WKWebView` fallback that actually compiles below 26.
- [ ] Arbitrary external/third-party links go to `SFSafariViewController`, not a bare `WKWebView` — App Review safe.
- [ ] (`representable` path) `Coordinator` is owned, set as `navigationDelegate`/handler, and every `WKScriptMessageHandler` is removed in `dismantleUIView`.
- [ ] Inbound JS messages validate name + body type before acting; no unvalidated routing into native code.
- [ ] Outbound JS uses `arguments:` (or escaping) — no raw interpolation of user/dynamic data into the script string.
- [ ] All remote content is `https`; any `http` is a scoped, justified ATS exception, not a global ATS disable.
- [ ] Title/URL/DOM reads happen after navigation finishes (`currentNavigationEvent == .finished` / `didFinish`), and no load blocks the main thread.

## Deep reference

`references/guide.md` — native `WebView`/`WebPage` (loading, navigation events, `NavigationDeciding`, `callJavaScript`, `URLSchemeHandler`, find-in-page, view modifiers), the `WKWebView`/`UIViewRepresentable` path (coordinator, navigation delegate, two-way JS messaging), best practices, and the UIKit→SwiftUI migration table. Load it for any concrete API question.

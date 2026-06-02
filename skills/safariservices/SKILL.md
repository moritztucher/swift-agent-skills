---
name: safariservices
description: Present web content inside an iOS app with SFSafariViewController — configuration, dismiss/appearance options, SFSafariViewControllerDelegate, and SwiftUI wrapping. Use when the user mentions SafariServices, SFSafariViewController, in-app browser, opening a URL in-app, showing a privacy policy/terms/article/help page, or "web view" for external links. For OAuth/SSO use the `authenticationservices` skill (ASWebAuthenticationSession); for embedded web content you control use the `swiftui-webview` skill (WKWebView).
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple Developer docs via Context7 (/websites/developer_apple)
---

# SafariServices

Showing web content from anywhere on the internet inside your app, with Safari's full feature set (Reader, AutoFill, Fraudulent Website Warning, content blocking) and no work to secure data between your app and the page. The deep reference — every configuration property, the full delegate protocol, SwiftUI wrappers, appearance customization, iOS 26 notes, and the SFSafariViewController-vs-WKWebView-vs-ASWebAuthenticationSession decision matrix — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `PURPOSE` — `display` (default; show a third-party page, article, ToS/privacy, help — `SFSafariViewController`) · `auth` (OAuth/SSO/token exchange — **wrong framework**, use `authenticationservices` / `ASWebAuthenticationSession`) · `embed` (your own interactive web content, JS bridge, custom chrome — **wrong framework**, use `swiftui-webview` / `WKWebView`).
2. `READER` — `off` (default) · `on` (`configuration.entersReaderIfAvailable = true` for article-style pages).
3. `CHROME` — `system` (default; let Safari/Liquid Glass style it, only set `dismissButtonStyle`) · `tinted` (legacy `preferredControlTintColor`/`preferredBarTintColor` — deprecated, avoid on iOS 26).

## When to use

Presenting any external or third-party web page from inside an iOS app where you don't need to read, script, or restyle the content: external links, privacy policy / terms of service, news articles, help and support pages, non-Apple-Pay payment hand-offs. If `PURPOSE` is `auth`, stop and use `authenticationservices`. If `PURPOSE` is `embed`, stop and use `swiftui-webview`.

## Core rules

- `SFSafariViewController` is the App-Review-trusted way to show web content. It carries Safari's security indicator, Fraudulent Website Warning, and AutoFill — reviewers and users trust it. Don't reach for a bare `WKWebView` just to show an external page.
- Configuration is **immutable after creation**. Build `SFSafariViewController.Configuration`, then `init(url:configuration:)`. You cannot mutate it in `updateUIViewController`; there is nothing to update.
- Only `http`/`https` URLs load. `file://`, `mailto:`, custom schemes, and `nil`/malformed URLs do nothing useful — validate before presenting, and use `Link`/`openURL` for `mailto:`.
- Present it **modally and visibly** (sheet / `present(_:animated:)`). App Review forbids hiding or obscuring it, and forbids using it to track users without consent.
- In SwiftUI, wrap with `UIViewControllerRepresentable` and own the delegate via a `Coordinator`; drive presentation with `.sheet`. The struct holds no mutable browser state.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll use a `WKWebView` to show this external article — more control." | For showing a page you don't own, `SFSafariViewController` is the right and App-Review-trusted tool: free security UI, Fraudulent Website Warning, AutoFill, Reader. A stripped `WKWebView` reimplements all of that worse and looks suspicious in review. Reach for `WKWebView` only when you must inject JS or own the chrome — that's the `swiftui-webview` skill. |
| "OAuth is just a web page, I'll present it in `SFSafariViewController`." | Wrong framework. `SFSafariViewController` cannot return the callback URL to your app and doesn't share the auth session cleanly. OAuth/SSO needs `ASWebAuthenticationSession` (the `authenticationservices` skill), which hands you the `callbackURLScheme` redirect. |
| "I'll tint the bars and add my own toolbar to match our brand." | You can't customize the chrome or run JavaScript — that's the whole point. `preferredBarTintColor`/`preferredControlTintColor` are deprecated; on iOS 26 they fight Liquid Glass. Set `dismissButtonStyle` and let the system style the rest. If you need branded chrome, you needed `WKWebView`. |
| "I'll read what the user typed / scrape the page after it loads." | Interactions inside the controller are invisible to your app by design — no access to AutoFill, history, page content, or cookies. If you need to observe or script the page, that's `WKWebView`, not this. |
| "I'll set the config in `updateUIViewController` so I can change Reader mode later." | The configuration is fixed at init and immutable. There is no live update path. Recreate the controller (new sheet) if the URL or config must change. |
| "Any URL string will do." | Only `http`/`https` load. A `mailto:`, custom scheme, or force-unwrapped bad string is a silent no-op or crash. Validate the `URL` and route non-web schemes elsewhere. |

## Verification gate

Before shipping in-app web display, confirm every line:

- [ ] `PURPOSE` is genuinely `display` — not OAuth (→ `authenticationservices`), not embedded/interactive content (→ `swiftui-webview`).
- [ ] URL is validated `http`/`https`; non-web schemes routed away; no force-unwrapped bad strings.
- [ ] `SFSafariViewController.Configuration` built before init; no attempt to mutate config after creation.
- [ ] Controller presented modally and visibly (sheet / `present`), never hidden, obscured, or used to track without consent.
- [ ] SwiftUI: `UIViewControllerRepresentable` + `Coordinator` owns the `SFSafariViewControllerDelegate`; `safariViewControllerDidFinish` clears the presentation binding.
- [ ] Chrome left to the system (only `dismissButtonStyle` set); no deprecated tint colors on iOS 26 targets.
- [ ] No code assumes access to page content, AutoFill, cookies, or navigation inside the controller.

## Deep reference

`references/guide.md` — full configuration property table, every `SFSafariViewControllerDelegate` callback, basic + configurable + full-featured SwiftUI wrappers (modifier and `View` extension), appearance customization, iOS 18/26 Liquid Glass notes, common use cases (external links, ToS/privacy, article reader, help), and the complete SFSafariViewController vs `WKWebView` vs `ASWebAuthenticationSession` decision/security matrix. Load it for any concrete API question.

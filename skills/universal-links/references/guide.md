# Universal Links & Deep Linking on Apple Platforms

The complete reference for getting a link — tapped in Mail, Messages, Safari, or another app — to open your app on the right screen. Covers the three link mechanisms, the Associated Domains entitlement, the `apple-app-site-association` (AASA) file, handling incoming links in both SwiftUI and UIKit lifecycles, routing, testing, and the failure modes that eat days.

---

## 1. The three mechanisms (don't confuse them)

| Mechanism | Looks like | Verified by Apple? | Falls back to web? | Use for |
|---|---|---|---|---|
| **Universal link** | `https://example.com/buy/42` | Yes — AASA + entitlement | Yes (Safari) if app not installed | The default. Public, shareable, secure links. |
| **Custom URL scheme** | `myapp://buy/42` | No — any app can claim it | No (shows error if no handler) | Internal redirects, OAuth callbacks, legacy. |
| **"Deep link"** | (umbrella term) | — | — | Generic phrase for "a link that opens a specific screen." Both of the above are deep links. |

**Universal links are strongly preferred.** They are:
- **Secure** — only the app whose Team ID + bundle ID match the AASA file you host can claim your domain. A malicious app cannot hijack `https://yourbank.com/...`.
- **Seamless** — one `https://` URL works whether or not the app is installed. Installed → app opens. Not installed → Safari opens the same page.
- **Universal** — the same link works in email, SMS, web pages, QR codes, and other apps.

**Custom schemes are inherently spoofable.** Any app on the device can register `myapp://`. Never use a custom-scheme payload as proof of identity or authorization — treat its contents as untrusted user input. Keep custom schemes for things like OAuth redirect URIs (where the scheme is paired with a server-side state/PKCE check) or in-app navigation glue.

You can support both. A common pattern: universal links for everything public, plus a custom scheme as a private fallback for tooling and tests.

---

## 2. Associated Domains entitlement

Universal links require an **Associated Domains** capability on the app and a matching AASA file on the web server. The two must agree or links silently fail.

### Add the capability

In Xcode: target → **Signing & Capabilities → + Capability → Associated Domains**. This adds the entitlement and registers the capability on your App ID in the developer portal.

### Entitlement format

The entitlement (`<app>.entitlements`) holds an array of service-prefixed domains:

```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:example.com</string>
    <string>applinks:www.example.com</string>
    <string>webcredentials:example.com</string>
    <string>activitycontinuation:example.com</string>
</array>
```

Service prefixes:

- **`applinks:`** — universal links. This is the one you need for deep linking.
- **`webcredentials:`** — shared-web-credential / Password AutoFill and passkeys association.
- **`activitycontinuation:`** — Handoff continuation (largely superseded; `applinks` covers most needs).

Rules:

- Each entry is `prefix:host`. The host has **no scheme and no path** — `applinks:example.com`, never `applinks:https://example.com/buy`.
- `example.com` and `www.example.com` are **distinct hosts**. List every host you want to claim. Subdomains are not implied.
- You may include up to a documented limit of domains; keep the list tight.
- Wildcards: `applinks:*.example.com` matches subdomains (the AASA must still be hosted on each domain that serves links). A leading `*.` only — you cannot wildcard the middle.

### Developer (alternate) mode

For testing against servers not yet reachable by Apple's CDN, append `?mode=developer`:

```xml
<string>applinks:example.com?mode=developer</string>
```

This bypasses the CDN and pulls the AASA **directly from your domain** on the device — essential when the server is internal, or when you're iterating faster than the CDN re-caches. Requires Developer Mode enabled on the device (Settings → Privacy & Security → Developer Mode). Remove it before shipping.

---

## 3. The apple-app-site-association (AASA) file

This JSON file, hosted on your domain, tells iOS which paths on your site map into the app and which app may claim them.

### Hosting rules (every one is load-bearing)

The file MUST be:

1. Served over **HTTPS** with a **valid (non-self-signed) TLS certificate**.
2. Located at exactly:
   ```
   https://<fully-qualified-domain>/.well-known/apple-app-site-association
   ```
   (The legacy root location `https://<domain>/apple-app-site-association` still works but `.well-known/` is the recommended, canonical path. If you serve both, keep them identical.)
3. Returned with **`Content-Type: application/json`**.
4. Have **NO file extension** — the filename is literally `apple-app-site-association`, not `.json`.
5. Served with **NO redirects** — a 301/302 to the file makes it invalid. The GET must return `200` directly.
6. Publicly reachable from **all IP addresses** — no geo-blocking, no IP allowlists, no auth wall. Apple's CDN fetches it from anywhere.
7. **Under 128 KB.**

You do **not** need to sign the file (that was a pre-iOS 9 requirement). Plain JSON is correct.

### Modern format (`details` + `appIDs` + `components`)

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": [ "ABCDE12345.com.example.app", "ABCDE12345.com.example.app2" ],
        "components": [
          {
            "#": "no_universal_links",
            "exclude": true,
            "comment": "Any URL with the fragment no_universal_links is NOT opened in the app."
          },
          {
            "/": "/buy/*",
            "comment": "Any URL whose path starts with /buy/ opens in the app."
          },
          {
            "/": "/help/website/*",
            "exclude": true,
            "comment": "Exclude this subtree even though /help/* (below) would match."
          },
          {
            "/": "/help/*",
            "?": { "articleNumber": "????" },
            "comment": "Path under /help/ AND query item articleNumber of exactly four chars."
          }
        ]
      }
    ]
  },
  "webcredentials": {
    "apps": [ "ABCDE12345.com.example.app" ]
  },
  "appclips": {
    "apps": [ "ABCDE12345.com.example.app.Clip" ]
  }
}
```

Key points:

- **`appIDs`** (array) is the App ID(s) in the form `<Team ID>.<bundle identifier>` — e.g. `ABCDE12345.com.example.app`. The Team ID is your 10-character prefix. **This must match the app's actual signing identity exactly.** A mismatch here is the single most common silent failure.
- **`components`** is an ordered array of matchers. Each object can use:
  - `"/"` — path pattern. `*` matches any number of characters, `?` matches one. Patterns are matched against the path.
  - `"?"` — query-item constraints (a dict of name → value pattern, where `?` in the value matches a single char).
  - `"#"` — URL fragment constraint.
  - `"exclude": true` — this match means "do **not** open in app" (hand to Safari instead).
  - `"caseSensitive"` (default `true`) and `"percentEncoded"` (default `true`) modifiers.
  - `"comment"` — ignored by the system, for humans.
- **Order matters.** The system walks `components` top to bottom and takes the **first** match. Put `exclude` rules for narrow subtrees *before* the broad rule they carve out of (see `/help/website/*` before `/help/*` above).

### Legacy format (still parsed)

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "ABCDE12345.com.example.app",
        "paths": [ "/buy/*", "NOT /help/website/*", "/help/*" ]
      }
    ]
  }
}
```

`appID` (singular string) + `paths` (array of glob strings, `NOT ` prefix to exclude). Prefer the modern `appIDs` + `components` form for new work — it supports query and fragment matching the `paths` form cannot. The empty `"apps": []` array is required boilerplate in the legacy shape.

### Multiple apps / multiple domains

- One AASA can list several apps in `appIDs` — useful for an app + its extensions or a free/paid pair.
- Each domain serves its own AASA. A `www.` host and an apex host are separate fetches; host the file on both.

---

## 4. Handling an incoming link

When the system decides a URL belongs to your app, it delivers it through one of two paths depending on lifecycle. **Universal links arrive as an `NSUserActivity` of type `NSUserActivityTypeBrowsingWeb`; custom-scheme URLs and SwiftUI-delivered universal links arrive as a plain `URL`.**

### SwiftUI

SwiftUI normalizes both into convenient modifiers.

```swift
@main
struct MyApp: App {
    @State private var router = Router()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(router)
                // Custom-scheme URLs AND universal links delivered as URL:
                .onOpenURL { url in
                    router.handle(url)
                }
                // Universal links / Handoff delivered as a web-browsing activity:
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    guard let url = activity.webpageURL else { return }
                    router.handle(url)
                }
        }
    }
}
```

- `onOpenURL` fires for universal links **and** custom URL schemes — SwiftUI hands you the `URL` directly. This covers most apps.
- `onContinueUserActivity(NSUserActivityTypeBrowsingWeb)` is the explicit Handoff / web-activity path; `activity.webpageURL` holds the link. Include it if you support Handoff (a link opened on Mac continuing to iPhone) or want to be belt-and-suspenders.
- For your own Handoff activity types (not web browsing), use `onContinueUserActivity(MyActivity.type)` and read `activity.userInfo` / `targetContentIdentifier`.
- Both modifiers attach to a view in the scene. Apply them once near the root so the link is handled regardless of which screen is showing.

### UIKit — cold launch via scene

When the app is **not running** and a link launches it, the URL arrives in `scene(_:willConnectTo:options:)`, not the continue method:

```swift
func scene(_ scene: UIScene,
           willConnectTo session: UISceneSession,
           options connectionOptions: UIScene.ConnectionOptions) {
    guard let userActivity = connectionOptions.userActivities.first,
          userActivity.activityType == NSUserActivityTypeBrowsingWeb,
          let incomingURL = userActivity.webpageURL,
          let components = URLComponents(url: incomingURL, resolvingAgainstBaseURL: true)
    else { return }

    route(path: components.path, query: components.queryItems)
}
```

### UIKit — running / backgrounded via scene

When the app is **already running**, the link arrives in the scene's continue method:

```swift
func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
          let incomingURL = userActivity.webpageURL,
          let components = URLComponents(url: incomingURL, resolvingAgainstBaseURL: true)
    else { return }

    route(path: components.path, query: components.queryItems)
}
```

Custom-scheme URLs in a scene-based UIKit app arrive in `scene(_:openURLContexts:)`.

### UIKit — pre-scene AppDelegate

Apps without `UIScene` (or the macOS/tvOS equivalents) implement:

```swift
func application(_ application: UIApplication,
                 continue userActivity: NSUserActivity,
                 restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
          let incomingURL = userActivity.webpageURL,
          let components = URLComponents(url: incomingURL, resolvingAgainstBaseURL: true)
    else { return false }

    route(path: components.path, query: components.queryItems)
    return true
}
```

Custom-scheme URLs here arrive in `application(_:open:options:)`.

**Lifecycle summary:** cold launch → `willConnectTo` (scene) / launch options (AppDelegate). Already running → `scene(_:continue:)` / `application(_:continue:restorationHandler:)`. SwiftUI hides this distinction behind its two modifiers — you get the URL either way.

---

## 5. Routing to the right screen

Parse once, route once. Centralize so cold-launch and warm-resume share logic.

```swift
@Observable
final class Router {
    var path = NavigationPath()
    var selectedTab: Tab = .home

    func handle(_ url: URL) {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return }
        let segments = comps.path.split(separator: "/").map(String.init)

        switch segments.first {
        case "buy":
            if let id = segments.dropFirst().first.flatMap(Int.init) {
                selectedTab = .store
                path = NavigationPath()
                path.append(StoreRoute.product(id))
            }
        case "help":
            let article = comps.queryItems?.first { $0.name == "articleNumber" }?.value
            selectedTab = .help
            path.append(HelpRoute.article(article))
        default:
            break   // unknown path: do nothing (or show home)
        }
    }
}
```

Guidelines:

- Use `URLComponents` for robust path + query parsing; never string-split a raw `absoluteString`.
- **Validate everything.** A universal link's *domain* is trusted (Apple verified the AASA), but the path/query is attacker-controllable — anyone can craft `https://example.com/buy/<anything>`. Bounds-check IDs, reject unknown routes, and never run privileged actions purely because a link said so.
- Map a URL to navigation **state**, then let SwiftUI/UIKit drive presentation. Don't push view controllers from inside the link handler.
- Decide cold-launch behavior: deep-link directly to the target, or land on home then navigate. For most apps, jump straight to the target.

---

## 6. Testing

### On a real device (the source of truth)

1. Install the app on the device (TestFlight or Xcode).
2. Send yourself the `https://` link in **Messages, Mail, or Notes** and **long-press or tap** it. (See the Safari caveat below.)
3. Or use the Notes trick: type the URL in Notes, then tap it.

### AASA validator

- Apple's **App Search API Validation Tool** / the AASA validator inspects your hosted file and reports format/hosting errors.
- Manually verify the fetch:
  ```bash
  curl -v https://example.com/.well-known/apple-app-site-association
  ```
  Confirm: `200` (no 301/302), `Content-Type: application/json`, valid JSON, correct `appIDs`.

### Diagnosing on device (sysdiagnose / Console)

Apple's universal-links technote (TN3155) documents log fields from a sysdiagnose:

- **User Approval** — whether the user chose to open links in your app vs. the browser.
- **Site/Fmwk Approval** — whether Apple's CDN approved your links and pattern-matched. `approved` = working. `unspecified` / `denied` = check that the domain is in your entitlement and the AASA is reachable from all IPs.
- **Last Check / Next Check** — when the CDN last fetched your AASA and when it will again.

### Simulator

The Simulator does **not** run the full CDN-backed universal-link verification reliably. Two practical paths:

- Test custom schemes and direct URL opening with:
  ```bash
  xcrun simctl openurl booted "https://example.com/buy/42"
  xcrun simctl openurl booted "myapp://buy/42"
  ```
  `openurl` with an `https://` link can route into the app if the association resolves, but treat the **device** as the real test — the simulator is for the handler/routing code, not for validating AASA.
- Use `?mode=developer` in the entitlement plus a reachable dev server to test real verification on a physical device.

---

## 7. Common failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Link opens Safari, never the app | AASA unreachable, wrong path, redirected, or wrong `Content-Type` | `curl -v` the `.well-known` URL; fix to `200` + `application/json`, no redirect. |
| Worked yesterday, broke after an AASA edit | Apple's CDN cached the old file | Wait for CDN re-cache, or use `?mode=developer` on device to bypass. CDN lag is expected. |
| Links never fire on a fresh install | CDN hadn't fetched AASA at install time, or domain blocks some IPs | Ensure the file is public to all IPs; reinstall after the CDN has the file; use developer mode while iterating. |
| Tapping the link in **Safari's address bar** does nothing special | **Expected.** Typing/pasting a URL into Safari's address bar never triggers a universal link. | Test from Messages/Mail/Notes, or a link on a *different* domain's web page. |
| Link tapped **on the same domain's own web page** opens in the page | **Expected.** A link to your domain, clicked while already browsing your domain, stays in Safari. | Test from a foreign-origin page or a Messages/Mail link. |
| Right app, wrong/forged behavior on custom scheme | Trusting custom-scheme payload | Custom schemes are spoofable — never authorize off their contents. |
| Entitlement says `applinks:example.com` but links fail | `appIDs` in AASA doesn't match `<TeamID>.<bundleID>`, or host mismatch (`www` vs apex) | Make entitlement host(s) and AASA `appIDs` agree exactly; host AASA on every claimed host. |
| Some paths open, some don't | `components` order — a broad rule matched before the specific one | Reorder: narrow `exclude` rules before the broad include they carve out of. |
| Universal link opens app but lands on wrong screen | Router didn't handle cold-launch path, or only wired the warm-resume handler | Wire both lifecycle entry points (or both SwiftUI modifiers); route from a single shared function. |

---

## 8. Quick reference

- **Entitlement key:** `com.apple.developer.associated-domains`, values `applinks:host`, `webcredentials:host`, `activitycontinuation:host`; `?mode=developer` to bypass CDN.
- **AASA URL:** `https://<domain>/.well-known/apple-app-site-association` — HTTPS, `application/json`, no extension, no redirect, public, ≤128 KB, unsigned.
- **AASA modern shape:** `applinks.details[].appIDs` (`<TeamID>.<bundleID>`) + ordered `components[]` with `"/"`, `"?"`, `"#"`, `exclude`.
- **SwiftUI:** `.onOpenURL { url in }` (URL + custom scheme), `.onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { $0.webpageURL }` (web activity / Handoff).
- **UIKit scene:** cold → `scene(_:willConnectTo:options:)` via `connectionOptions.userActivities`; warm → `scene(_:continue:)`; custom scheme → `scene(_:openURLContexts:)`.
- **UIKit AppDelegate:** `application(_:continue:restorationHandler:)`; custom scheme → `application(_:open:options:)`.
- **Activity type for universal links:** `NSUserActivityTypeBrowsingWeb`; URL in `activity.webpageURL`.
- **Custom scheme registration:** `CFBundleURLTypes` → `CFBundleURLSchemes` array in `Info.plist`.
- **Test:** real device from Messages/Mail/Notes; `curl -v`; AASA validator; `xcrun simctl openurl booted "<url>"`; sysdiagnose Site/Fmwk Approval == `approved`.
- **Never:** type the link in Safari's address bar to test; trust custom-scheme contents; expect same-domain web links to open the app.

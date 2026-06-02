# SwiftUI WebView Guide

A comprehensive guide covering the new native WebView in SwiftUI (iOS 26+), WKWebView integration via UIViewRepresentable for older versions, navigation, JavaScript interaction, and best practices.

## Table of Contents

1. [Overview](#overview)
2. [Native WebView (iOS 26+)](#native-webview-ios-26)
   - [Basic Usage](#basic-usage)
   - [WebPage for Advanced Control](#webpage-for-advanced-control)
   - [Loading Content](#loading-content)
   - [Navigation Events](#navigation-events)
   - [NavigationDeciding Protocol](#navigationdeciding-protocol)
   - [JavaScript Interaction](#javascript-interaction-ios-26)
   - [URLSchemeHandler](#urlschemehandler)
   - [Find in Page](#find-in-page)
   - [View Modifiers](#view-modifiers)
3. [WKWebView Integration (iOS 17/18)](#wkwebview-integration-ios-1718)
   - [Basic UIViewRepresentable](#basic-uiviewrepresentable)
   - [Coordinator Pattern](#coordinator-pattern)
   - [Navigation Delegate](#navigation-delegate)
   - [JavaScript Communication](#javascript-communication-uikit)
4. [Best Practices](#best-practices)
5. [Migration Guide](#migration-guide)
6. [Resources](#resources)

---

## Overview

SwiftUI's web content display capabilities have evolved significantly:

| iOS Version | Approach | Complexity |
|-------------|----------|------------|
| iOS 17-18 | WKWebView via UIViewRepresentable | High |
| iOS 26+ | Native WebView and WebPage | Low |

**Key Benefits of iOS 26 Native WebView:**
- No UIKit bridging required
- Declarative API design
- Observable model with WebPage
- Built-in async/await support
- Native SwiftUI view modifiers

---

## Native WebView (iOS 26+)

Starting with iOS 26, SwiftUI introduces a native `WebView` type and `WebPage` class for displaying web content without UIKit wrappers.

### Basic Usage

The simplest way to display web content:

```swift
import SwiftUI
import WebKit

struct ContentView: View {
    var body: some View {
        WebView(url: URL(string: "https://www.apple.com"))
    }
}
```

The URL parameter is optional, so no force unwrapping is needed.

### WebPage for Advanced Control

`WebPage` is an Observable class that provides granular control over web content:

```swift
import SwiftUI
import WebKit

struct WebBrowserView: View {
    @State private var page = WebPage()

    var body: some View {
        VStack {
            // Display page title and loading progress
            if let title = page.title {
                Text(title)
                    .font(.headline)
            }

            if page.isLoading {
                ProgressView(value: page.estimatedProgress)
            }

            WebView(page)
                .onAppear {
                    page.load(URLRequest(url: URL(string: "https://www.swift.org")!))
                }
        }
    }
}
```

**Observable Properties of WebPage:**
- `title` - The page title
- `url` - Current URL
- `isLoading` - Loading state
- `estimatedProgress` - Loading progress (0.0 to 1.0)
- `themeColor` - Page theme color
- `canGoBack` / `canGoForward` - Navigation stack state
- `currentNavigationEvent` - Navigation lifecycle events

### Loading Content

WebPage supports multiple content loading strategies:

```swift
struct ContentLoadingExamples: View {
    @State private var page = WebPage()

    var body: some View {
        WebView(page)
            .task {
                // Load from URL
                page.load(URLRequest(url: URL(string: "https://example.com")!))

                // Load HTML string
                let htmlContent = """
                <!DOCTYPE html>
                <html>
                <head>
                    <style>
                        body { font-family: -apple-system; padding: 20px; }
                        h1 { color: #007AFF; }
                    </style>
                </head>
                <body>
                    <h1>Hello, SwiftUI!</h1>
                    <p>This is HTML content loaded directly.</p>
                </body>
                </html>
                """
                page.load(html: htmlContent, baseURL: URL(string: "about:blank")!)

                // Load data with MIME type
                // page.load(data: webArchiveData, mimeType: "application/x-webarchive", characterEncodingName: "utf-8", baseURL: baseURL)
            }
    }
}
```

### Navigation Events

Track navigation lifecycle through the observable `currentNavigationEvent`:

```swift
struct NavigationTrackingView: View {
    @State private var page = WebPage()
    @State private var showLoadingIndicator = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            WebView(page)

            if showLoadingIndicator {
                ProgressView()
            }
        }
        .onChange(of: page.currentNavigationEvent?.kind) { _, newKind in
            switch newKind {
            case .startedProvisionalNavigation:
                showLoadingIndicator = true
                errorMessage = nil
            case .committed:
                // Page content started rendering
                break
            case .finished:
                showLoadingIndicator = false
            case .failed(let error):
                showLoadingIndicator = false
                errorMessage = error.localizedDescription
            default:
                break
            }
        }
        .onAppear {
            page.load(URLRequest(url: URL(string: "https://www.apple.com")!))
        }
    }
}
```

### NavigationDeciding Protocol

Control which URLs the WebView can navigate to:

```swift
import SwiftUI
import WebKit

// MARK: - Navigation Policy Decider

class DomainRestrictedNavigationDecider: WebPage.NavigationDeciding {
    private let allowedHosts: Set<String>

    init(allowedHosts: Set<String>) {
        self.allowedHosts = allowedHosts
    }

    func decidePolicy(
        for action: WebPage.NavigationAction,
        preferences: inout WebPage.NavigationPreferences
    ) async -> WKNavigationActionPolicy {
        guard let url = action.request.url,
              let host = url.host() else {
            return .cancel
        }

        // Allow navigation within allowed domains
        if allowedHosts.contains(host) {
            return .allow
        }

        // Open external links in Safari
        Task { @MainActor in
            UIApplication.shared.open(url)
        }
        return .cancel
    }
}

// MARK: - View Implementation

struct RestrictedWebView: View {
    private let page: WebPage

    init() {
        let decider = DomainRestrictedNavigationDecider(
            allowedHosts: ["swift.org", "www.swift.org", "developer.apple.com"]
        )
        self.page = WebPage(navigationDecider: decider)
    }

    var body: some View {
        WebView(page)
            .onAppear {
                page.load(URLRequest(url: URL(string: "https://swift.org")!))
            }
    }
}
```

### JavaScript Interaction (iOS 26)

Execute JavaScript and retrieve results using `callJavaScript`. The full signature is `callJavaScript(_ functionBody: String, arguments: [String: Any] = [:], in frame: WebPage.FrameInfo? = nil, contentWorld: WKContentWorld? = nil) async throws -> Any?` — the string is a function *body*, so prefer passing values through `arguments:` over string interpolation, and `return` the value you want back:

```swift
struct JavaScriptInteractionView: View {
    @State private var page = WebPage()
    @State private var pageTitle: String = ""
    @State private var linkCount: Int = 0

    var body: some View {
        VStack {
            Text("Page Title: \(pageTitle)")
            Text("Links on page: \(linkCount)")

            WebView(page)
                .onAppear {
                    page.load(URLRequest(url: URL(string: "https://www.apple.com")!))
                }

            Button("Get Page Info") {
                Task {
                    await getPageInfo()
                }
            }
        }
    }

    private func getPageInfo() async {
        do {
            // Get page title
            if let title = try await page.callJavaScript("document.title") as? String {
                pageTitle = title
            }

            // Count links on page
            if let count = try await page.callJavaScript("document.querySelectorAll('a').length") as? Int {
                linkCount = count
            }
        } catch {
            print("JavaScript execution failed: \(error)")
        }
    }
}
```

**Advanced JavaScript with Parameters:**

```swift
struct AdvancedJavaScriptView: View {
    @State private var page = WebPage()

    var body: some View {
        WebView(page)
            .task {
                page.load(html: "<html><body><div id='content'></div></body></html>",
                         baseURL: URL(string: "about:blank")!)

                // Wait for page to load
                try? await Task.sleep(for: .milliseconds(500))

                // Inject content with parameters (safer approach)
                let message = "Hello from Swift!"
                let script = """
                (function(msg) {
                    document.getElementById('content').innerHTML = '<h1>' + msg + '</h1>';
                })('\(message.replacingOccurrences(of: "'", with: "\\'"))');
                """

                try? await page.callJavaScript(script)
            }
    }
}
```

### URLSchemeHandler

Load bundled content using custom URL schemes:

```swift
import SwiftUI
import WebKit

// MARK: - Custom Scheme Handler

struct BundleSchemeHandler: URLSchemeHandler {
    func reply(for request: URLRequest) -> some AsyncSequence<URLSchemeTaskResult, any Error> {
        AsyncThrowingStream { continuation in
            guard let url = request.url,
                  let resourceName = url.host(),
                  let bundleURL = Bundle.main.url(forResource: resourceName, withExtension: nil),
                  let data = try? Data(contentsOf: bundleURL) else {
                continuation.finish(throwing: URLError(.fileDoesNotExist))
                return
            }

            // Determine MIME type based on file extension
            let mimeType: String
            switch bundleURL.pathExtension.lowercased() {
            case "html", "htm": mimeType = "text/html"
            case "css": mimeType = "text/css"
            case "js": mimeType = "application/javascript"
            case "json": mimeType = "application/json"
            case "png": mimeType = "image/png"
            case "jpg", "jpeg": mimeType = "image/jpeg"
            default: mimeType = "application/octet-stream"
            }

            let response = URLResponse(
                url: url,
                mimeType: mimeType,
                expectedContentLength: data.count,
                textEncodingName: "utf-8"
            )

            continuation.yield(.response(response))
            continuation.yield(.data(data))
            continuation.finish()
        }
    }
}

// MARK: - View with Custom Scheme

struct BundledContentView: View {
    @State private var page: WebPage

    init() {
        // Create custom scheme configuration
        guard let scheme = URLScheme("app-bundle") else {
            fatalError("Invalid URL scheme")
        }

        var configuration = WebPage.Configuration()
        configuration.urlSchemeHandlers[scheme] = BundleSchemeHandler()

        _page = State(initialValue: WebPage(configuration: configuration))
    }

    var body: some View {
        WebView(page)
            .onAppear {
                // Load bundled HTML file: app-bundle://index.html
                if let url = URL(string: "app-bundle://index.html") {
                    page.load(URLRequest(url: url))
                }
            }
    }
}
```

### Find in Page

Enable find-in-page functionality:

```swift
struct FindInPageView: View {
    @State private var page = WebPage()
    @State private var findNavigatorIsPresented = false

    var body: some View {
        WebView(page)
            .findNavigator(isPresented: $findNavigatorIsPresented)
            .replaceDisabled(true) // Disable replace functionality if not needed
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        findNavigatorIsPresented.toggle()
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
            .onAppear {
                page.load(URLRequest(url: URL(string: "https://www.swift.org")!))
            }
    }
}
```

### View Modifiers

SwiftUI provides extensive view modifiers for WebView customization:

```swift
struct CustomizedWebView: View {
    @State private var page = WebPage()
    @State private var scrollPosition = ScrollPosition()

    var body: some View {
        WebView(page)
            // Navigation gestures
            .webViewBackForwardNavigationGestures(.enabled)

            // Content background visibility
            .webViewContentBackground(.visible)

            // Link preview behavior
            .webViewLinkPreviews(.enabled)

            // Magnification gestures
            .webViewMagnificationGestures(.enabled)

            // Fullscreen behavior
            .webViewElementFullscreenBehavior(.automatic)

            // Text selection
            .webViewTextSelection(.enabled)

            // Scroll position binding
            .webViewScrollPosition($scrollPosition)

            // Scroll bounce behavior
            .scrollBounceBehavior(.basedOnSize, axes: [.horizontal])

            // Custom context menu
            .webViewContextMenu { elementInfo in
                if let linkURL = elementInfo.linkURL {
                    Button("Copy Link") {
                        UIPasteboard.general.url = linkURL
                    }
                    Button("Open in Safari") {
                        UIApplication.shared.open(linkURL)
                    }
                }
            }
            .onAppear {
                page.load(URLRequest(url: URL(string: "https://www.apple.com")!))
            }
    }
}
```

---

## WKWebView Integration (iOS 17/18)

For apps targeting iOS versions before 26, use `UIViewRepresentable` to wrap `WKWebView`.

### Basic UIViewRepresentable

```swift
import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        webView.load(request)
    }
}

// Usage
struct ContentView: View {
    var body: some View {
        WebView(url: URL(string: "https://www.apple.com")!)
    }
}
```

### Coordinator Pattern

For handling navigation events and JavaScript communication:

```swift
import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool

    var onNavigationFinished: ((URL?) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()

        // Add JavaScript message handler
        configuration.userContentController.add(
            context.coordinator,
            name: "nativeHandler"
        )

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url != url {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        // Clean up message handlers to prevent memory leaks
        webView.configuration.userContentController.removeScriptMessageHandler(
            forName: "nativeHandler"
        )
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.canGoBack = webView.canGoBack
                self.parent.canGoForward = webView.canGoForward
                self.parent.onNavigationFinished?(webView.url)
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
            print("Navigation failed: \(error.localizedDescription)")
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            // Allow all navigation by default
            // Customize here to restrict domains
            decisionHandler(.allow)
        }

        // MARK: - WKScriptMessageHandler

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            if message.name == "nativeHandler" {
                // Handle messages from JavaScript
                if let body = message.body as? [String: Any] {
                    handleJavaScriptMessage(body)
                }
            }
        }

        private func handleJavaScriptMessage(_ message: [String: Any]) {
            guard let action = message["action"] as? String else { return }

            switch action {
            case "log":
                if let data = message["data"] as? String {
                    print("JS Log: \(data)")
                }
            case "share":
                if let content = message["content"] as? String {
                    // Handle share action
                    print("Share requested: \(content)")
                }
            default:
                print("Unknown action: \(action)")
            }
        }
    }
}
```

### Navigation Delegate

Control which URLs can be visited:

```swift
extension WebView.Coordinator {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        // Define allowed domains
        let allowedDomains = ["apple.com", "swift.org"]

        if let host = url.host,
           allowedDomains.contains(where: { host.contains($0) }) {
            decisionHandler(.allow)
        } else {
            // Open external links in Safari
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        }
    }
}
```

### JavaScript Communication (UIKit)

**Calling JavaScript from Swift:**

```swift
extension WKWebView {
    func evaluateJavaScriptAsync(_ script: String) async throws -> Any? {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                self.evaluateJavaScript(script) { result, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: result)
                    }
                }
            }
        }
    }
}

// Usage in SwiftUI
struct JavaScriptExampleView: View {
    @State private var webView: WKWebView?
    @State private var pageTitle = ""

    var body: some View {
        VStack {
            Text("Title: \(pageTitle)")

            WebViewWrapper(webView: $webView)

            Button("Get Title") {
                Task {
                    if let title = try? await webView?.evaluateJavaScriptAsync("document.title") as? String {
                        pageTitle = title
                    }
                }
            }
        }
    }
}
```

**Receiving Messages from JavaScript:**

```html
<!-- In your web content -->
<script>
    // Send message to Swift
    function sendToNative(action, data) {
        if (window.webkit && window.webkit.messageHandlers.nativeHandler) {
            window.webkit.messageHandlers.nativeHandler.postMessage({
                action: action,
                data: data
            });
        }
    }

    // Example usage
    document.getElementById('shareButton').addEventListener('click', function() {
        sendToNative('share', { content: 'Hello from web!' });
    });
</script>
```

---

## Best Practices

### 1. Architecture

**Separate Web View Logic from Views:**

```swift
// MARK: - WebView Handler (Separate Module)

@Observable
class WebViewHandler {
    var isLoading = false
    var currentURL: URL?
    var pageTitle: String?
    var errorMessage: String?

    func handleNavigationStarted() {
        isLoading = true
        errorMessage = nil
    }

    func handleNavigationFinished(url: URL?, title: String?) {
        isLoading = false
        currentURL = url
        pageTitle = title
    }

    func handleNavigationFailed(error: Error) {
        isLoading = false
        errorMessage = error.localizedDescription
    }
}
```

### 2. Memory Management

- Remove script message handlers in `dismantleUIView` (UIKit approach)
- Use weak references in coordinators when referencing parent views
- Cancel ongoing tasks when the view disappears

### 3. Error Handling

```swift
enum WebViewError: LocalizedError {
    case invalidURL
    case loadingFailed(Error)
    case javascriptFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The URL is invalid"
        case .loadingFailed(let error):
            return "Failed to load page: \(error.localizedDescription)"
        case .javascriptFailed(let error):
            return "JavaScript execution failed: \(error.localizedDescription)"
        }
    }
}
```

### 4. Security Considerations

- Always validate URLs before loading
- Restrict navigation to trusted domains when possible
- Sanitize data passed to JavaScript
- Use HTTPS URLs exclusively
- Consider certificate pinning for sensitive content

### 5. Performance

- Use `.task` modifier for async operations (auto-cancels on disappear)
- Avoid unnecessary re-renders by keeping WebView state minimal
- Cache loaded content when appropriate
- Use `URLSchemeHandler` for bundled content instead of file URLs

### 6. Accessibility

```swift
WebView(page)
    .accessibilityLabel("Web content")
    .accessibilityHint("Double-tap to interact with web page")
```

---

## Migration Guide

### From WKWebView (UIKit) to WebView (iOS 26)

| UIKit (WKWebView) | SwiftUI (iOS 26) |
|-------------------|------------------|
| `WKWebView()` | `WebView(url:)` or `WebView(page)` |
| `webView.load(URLRequest)` | `page.load(URLRequest)` |
| `webView.loadHTMLString()` | `page.load(html:baseURL:)` |
| `WKNavigationDelegate` | `currentNavigationEvent` |
| `decidePolicyFor:` | `NavigationDeciding` protocol |
| `evaluateJavaScript()` | `page.callJavaScript()` |
| `WKURLSchemeHandler` | `URLSchemeHandler` |
| `UIViewRepresentable` | Not needed |

### Conditional Compilation

```swift
struct WebContentView: View {
    let url: URL

    var body: some View {
        if #available(iOS 26, *) {
            // Native SwiftUI WebView
            WebView(url: url)
        } else {
            // Fallback to UIKit wrapper
            LegacyWebView(url: url)
        }
    }
}
```

---

## Resources

### Official Documentation
- [Apple Developer: WebView](https://developer.apple.com/documentation/swiftui/webview)
- [Apple Developer: WebPage](https://developer.apple.com/documentation/swiftui/webpage)
- [WWDC25: Meet WebKit for SwiftUI](https://developer.apple.com/videos/play/wwdc2025/231/)

### Tutorials and Articles
- [AppCoda: Exploring WebView and WebPage in SwiftUI for iOS 26](https://www.appcoda.com/swiftui-webview/)
- [Hacking with Swift: What's new in SwiftUI for iOS 26](https://www.hackingwithswift.com/articles/278/whats-new-in-swiftui-for-ios-26)
- [DEV Community: WebKit for SwiftUI](https://dev.to/arshtechpro/wwdc-2025-webkit-for-swiftui-2igc)
- [TrozWare: SwiftUI WebView](https://troz.net/post/2025/swiftui-webview/)
- [InfoQ: SwiftUI for iOS 26](https://www.infoq.com/news/2025/06/swiftui-ios26-liquid-glass/)

### WKWebView Resources (Legacy)
- [SwiftyPlace: How to Load a SwiftUI WebView with WKWebView](https://www.swiftyplace.com/blog/loading-a-web-view-in-swiftui-with-wkwebview)
- [Medium: Best way to use WKWebView with SwiftUI](https://medium.com/@takutonakamura/best-way-to-use-wkwebview-with-swiftui-0a3c58875d24)
- [Medium: Messaging Between WKWebView and Native Application](https://medium.com/@yeeedward/messaging-between-wkwebview-and-native-application-in-swiftui-e985f0bfacf)

### Third-Party Libraries
- [WebViewKit by Daniel Saidi](https://github.com/danielsaidi/WebViewKit) - SwiftUI WebView wrapper for older iOS versions
- [WebUI by Cybozu](https://github.com/nicklockwood/WebUI) - Declarative WKWebView handling

---

## Version History

| Date | Version | Changes |
|------|---------|---------|
| 2026-02-02 | 1.0 | Initial documentation |

---

**Note:** The native SwiftUI `WebView`/`WebPage` APIs ship in iOS 26 (released Fall 2025). They are unavailable below iOS 26 — use the `UIViewRepresentable` + `WKWebView` path for back-deployment. Signatures verified against Apple's WebKit documentation on 2026-06-02.

# SafariServices Framework Guide

A comprehensive guide to using SafariServices for in-app web browsing and OAuth authentication in iOS applications.

---

## Table of Contents

1. [Overview & Purpose](#overview--purpose)
2. [SFSafariViewController for In-App Browsing](#sfsafariviewcontroller-for-in-app-browsing)
3. [Configuration Options](#configuration-options)
4. [SwiftUI Integration](#swiftui-integration)
5. [ASWebAuthenticationSession for OAuth](#aswebauthenticationsession-for-oauth)
6. [SFSafariViewControllerDelegate](#sfsafariviewcontrollerdelegate)
7. [Customizing Appearance](#customizing-appearance)
8. [iOS 18/26 Specific Features](#ios-1826-specific-features)
9. [Common Use Cases](#common-use-cases)
10. [Best Practices & When to Use vs WKWebView](#best-practices--when-to-use-vs-wkwebview)

---

## Overview & Purpose

SafariServices is an Apple framework that enables you to integrate Safari's browsing capabilities directly into your iOS app. It provides a secure, familiar browsing experience without requiring users to leave your app.

### Key Capabilities

| Feature | Description |
|---------|-------------|
| **In-App Browsing** | Present web content using `SFSafariViewController` with Safari's full feature set |
| **Web Authentication** | Handle OAuth and SSO flows using `ASWebAuthenticationSession` |
| **Reading List** | Add items to Safari Reading List via `SSReadingList` |
| **Content Blockers** | Interact with content blocker extensions using `SFContentBlockerManager` |

### Framework Import

```swift
import SafariServices
```

For authentication sessions, also import:

```swift
import AuthenticationServices
```

---

## SFSafariViewController for In-App Browsing

`SFSafariViewController` presents a self-contained web interface inside your app, providing a complete Safari-like experience.

### Key Features

- Read-only address field with security indicator
- Reader mode button
- AutoFill support for passwords
- Fraudulent Website Warning
- Content blocking support
- Share/Action button
- Done button and navigation controls
- Open in Safari option

### Basic Usage

```swift
import SafariServices

func openURL(_ url: URL) {
    let safariViewController = SFSafariViewController(url: url)
    present(safariViewController, animated: true)
}
```

### Important Security Notes

According to App Store Review Guidelines:

- The view controller **must** visibly present information to users
- You **cannot** hide or obscure the view controller behind other views
- You **cannot** use `SFSafariViewController` to track users without consent

### Privacy Considerations

- Your app **cannot** access AutoFill data, browsing history, or website data
- Interactions with web content are **not visible** to your app
- Data is sandboxed between your app and Safari
- For shared data scenarios, use `ASWebAuthenticationSession` instead

---

## Configuration Options

Use `SFSafariViewController.Configuration` to customize the browser behavior before presentation.

### Configuration Properties

```swift
import SafariServices

func createConfiguredSafariViewController(for url: URL) -> SFSafariViewController {
    let configuration = SFSafariViewController.Configuration()

    // Automatically enter Reader mode if available
    configuration.entersReaderIfAvailable = true

    // Allow the navigation bar to collapse when scrolling
    configuration.barCollapsingEnabled = true

    // Create the view controller with configuration
    let safariVC = SFSafariViewController(url: url, configuration: configuration)

    return safariVC
}
```

### Configuration Properties Reference

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `entersReaderIfAvailable` | `Bool` | `false` | Automatically enters Reader mode when available |
| `barCollapsingEnabled` | `Bool` | `true` | Allows bars to collapse on scroll |
| `activityButton` | `UIActivityType?` | `nil` | Custom activity button configuration |
| `eventAttribution` | `UIEventAttribution?` | `nil` | Event attribution for ad measurement |

### Example: Reader-Focused Configuration

```swift
import SafariServices

/// Creates a Safari view controller optimized for reading articles
func createReaderSafariViewController(for articleURL: URL) -> SFSafariViewController {
    let configuration = SFSafariViewController.Configuration()
    configuration.entersReaderIfAvailable = true
    configuration.barCollapsingEnabled = true

    let safariVC = SFSafariViewController(url: articleURL, configuration: configuration)
    safariVC.dismissButtonStyle = .close

    return safariVC
}
```

---

## SwiftUI Integration

Since `SFSafariViewController` is a UIKit view controller, you need to wrap it using `UIViewControllerRepresentable` for SwiftUI.

### Basic SwiftUI Wrapper

```swift
import SafariServices
import SwiftUI

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // No updates needed
    }
}
```

### Usage in SwiftUI

```swift
import SwiftUI

struct ContentView: View {
    @State private var showSafari = false
    private let websiteURL = URL(string: "https://apple.com")!

    var body: some View {
        Button("Open Website") {
            showSafari = true
        }
        .sheet(isPresented: $showSafari) {
            SafariView(url: websiteURL)
        }
    }
}
```

### Configurable SwiftUI Wrapper

```swift
import SafariServices
import SwiftUI

struct SafariView: UIViewControllerRepresentable {

    // MARK: - Properties

    let url: URL
    var entersReaderIfAvailable: Bool = false
    var barCollapsingEnabled: Bool = true
    var dismissButtonStyle: SFSafariViewController.DismissButtonStyle = .done
    var onDismiss: (() -> Void)?

    // MARK: - UIViewControllerRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = entersReaderIfAvailable
        configuration.barCollapsingEnabled = barCollapsingEnabled

        let safariVC = SFSafariViewController(url: url, configuration: configuration)
        safariVC.dismissButtonStyle = dismissButtonStyle
        safariVC.delegate = context.coordinator

        return safariVC
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // Configuration cannot be updated after creation
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let onDismiss: (() -> Void)?

        init(onDismiss: (() -> Void)?) {
            self.onDismiss = onDismiss
        }

        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            onDismiss?()
        }
    }
}
```

### Full-Featured SwiftUI Integration

```swift
import SafariServices
import SwiftUI

// MARK: - Safari View Modifier

struct SafariViewModifier: ViewModifier {
    @Binding var isPresented: Bool
    let url: URL
    var configuration: SafariConfiguration

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                SafariView(
                    url: url,
                    entersReaderIfAvailable: configuration.entersReaderIfAvailable,
                    barCollapsingEnabled: configuration.barCollapsingEnabled,
                    dismissButtonStyle: configuration.dismissButtonStyle
                ) {
                    isPresented = false
                }
                .ignoresSafeArea()
            }
    }
}

// MARK: - Safari Configuration

struct SafariConfiguration {
    var entersReaderIfAvailable: Bool = false
    var barCollapsingEnabled: Bool = true
    var dismissButtonStyle: SFSafariViewController.DismissButtonStyle = .done

    static let `default` = SafariConfiguration()
    static let reader = SafariConfiguration(entersReaderIfAvailable: true)
}

// MARK: - View Extension

extension View {
    func safari(
        isPresented: Binding<Bool>,
        url: URL,
        configuration: SafariConfiguration = .default
    ) -> some View {
        modifier(SafariViewModifier(
            isPresented: isPresented,
            url: url,
            configuration: configuration
        ))
    }
}

// MARK: - Usage Example

struct ArticleView: View {
    @State private var showSafari = false
    let articleURL: URL

    var body: some View {
        VStack {
            Text("Read the full article")

            Button("Open in Safari") {
                showSafari = true
            }
        }
        .safari(
            isPresented: $showSafari,
            url: articleURL,
            configuration: .reader
        )
    }
}
```

---

## ASWebAuthenticationSession for OAuth

`ASWebAuthenticationSession` (from AuthenticationServices) is designed for OAuth and web-based authentication flows. It shares cookies with Safari, enabling single sign-on (SSO).

### SwiftUI Environment-Based Approach (iOS 16.4+)

The modern SwiftUI approach uses the `webAuthenticationSession` environment value:

```swift
import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    @State private var isAuthenticating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Button("Sign in with OAuth") {
                Task {
                    await authenticate()
                }
            }
            .disabled(isAuthenticating)

            if isAuthenticating {
                ProgressView()
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
        }
    }

    private func authenticate() async {
        isAuthenticating = true
        errorMessage = nil

        defer { isAuthenticating = false }

        guard let authURL = URL(string: "https://example.com/oauth/authorize?client_id=YOUR_CLIENT_ID&redirect_uri=myapp://callback&response_type=code") else {
            errorMessage = "Invalid authentication URL"
            return
        }

        do {
            let callbackURL = try await webAuthenticationSession.authenticate(
                using: authURL,
                callbackURLScheme: "myapp"
            )

            // Extract authorization code from callback URL
            await handleCallback(callbackURL)
        } catch {
            errorMessage = "Authentication failed: \(error.localizedDescription)"
        }
    }

    private func handleCallback(_ url: URL) async {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            errorMessage = "Failed to extract authorization code"
            return
        }

        // Exchange code for tokens
        await exchangeCodeForTokens(code)
    }

    private func exchangeCodeForTokens(_ code: String) async {
        // Implement token exchange with your backend
    }
}
```

### UIKit-Based Approach

For UIKit or when you need more control:

```swift
import AuthenticationServices
import UIKit

@Observable
final class AuthenticationManager: NSObject {

    // MARK: - Properties

    private var authSession: ASWebAuthenticationSession?
    private weak var presentationAnchor: UIWindow?

    // MARK: - Authentication

    func authenticate(
        from window: UIWindow?,
        authURL: URL,
        callbackScheme: String
    ) async throws -> URL {
        presentationAnchor = window

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackURL else {
                    continuation.resume(throwing: AuthError.noCallbackURL)
                    return
                }

                continuation.resume(returning: callbackURL)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false // Enable SSO

            authSession = session

            if !session.start() {
                continuation.resume(throwing: AuthError.failedToStart)
            }
        }
    }

    func cancel() {
        authSession?.cancel()
        authSession = nil
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension AuthenticationManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        presentationAnchor ?? UIWindow()
    }
}

// MARK: - Auth Error

enum AuthError: LocalizedError {
    case noCallbackURL
    case failedToStart
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .noCallbackURL:
            return "No callback URL received"
        case .failedToStart:
            return "Failed to start authentication session"
        case .invalidResponse:
            return "Invalid authentication response"
        }
    }
}
```

### Ephemeral Sessions

Use ephemeral sessions when you want a fresh authentication state (no cookies shared):

```swift
session.prefersEphemeralWebBrowserSession = true
```

| Mode | Behavior |
|------|----------|
| `false` (default) | Shares cookies with Safari, enables SSO |
| `true` | Private session, no shared state, user always prompted |

---

## SFSafariViewControllerDelegate

The delegate protocol provides callbacks for Safari view controller events.

### Protocol Methods

```swift
import SafariServices

class SafariCoordinator: NSObject, SFSafariViewControllerDelegate {

    /// Called when the user taps the Done button
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        // Handle dismissal
        print("Safari view controller dismissed")
    }

    /// Called when the initial URL load completes
    func safariViewController(
        _ controller: SFSafariViewController,
        didCompleteInitialLoad didLoadSuccessfully: Bool
    ) {
        if didLoadSuccessfully {
            print("Page loaded successfully")
        } else {
            print("Page failed to load")
        }
    }

    /// Called when the initial load redirects to a new URL
    func safariViewController(
        _ controller: SFSafariViewController,
        initialLoadDidRedirectTo URL: URL
    ) {
        print("Redirected to: \(URL)")
    }

    /// Provide custom activity items for the share sheet
    func safariViewController(
        _ controller: SFSafariViewController,
        activityItemsFor URL: URL,
        title: String?
    ) -> [UIActivity] {
        // Return custom activities
        return []
    }

    /// Exclude specific activity types from the share sheet
    func safariViewController(
        _ controller: SFSafariViewController,
        excludedActivityTypesFor URL: URL,
        title: String?
    ) -> [UIActivity.ActivityType] {
        return [.postToFacebook, .postToTwitter]
    }

    /// Called when the user opens the page in Safari
    func safariViewControllerWillOpenInBrowser(_ controller: SFSafariViewController) {
        print("User chose to open in Safari")
    }
}
```

### Delegate Usage Example

```swift
import SafariServices

final class WebBrowserManager {
    private var coordinator: SafariCoordinator?

    func presentSafari(from viewController: UIViewController, url: URL) {
        let safariVC = SFSafariViewController(url: url)

        // Create and retain the coordinator
        let coordinator = SafariCoordinator()
        coordinator.onDismiss = { [weak self] in
            self?.coordinator = nil
        }

        safariVC.delegate = coordinator
        self.coordinator = coordinator

        viewController.present(safariVC, animated: true)
    }
}

class SafariCoordinator: NSObject, SFSafariViewControllerDelegate {
    var onDismiss: (() -> Void)?
    var onLoadComplete: ((Bool) -> Void)?

    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        onDismiss?()
    }

    func safariViewController(
        _ controller: SFSafariViewController,
        didCompleteInitialLoad didLoadSuccessfully: Bool
    ) {
        onLoadComplete?(didLoadSuccessfully)
    }
}
```

---

## Customizing Appearance

### Dismiss Button Style

```swift
import SafariServices

let safariVC = SFSafariViewController(url: url)

// Available styles
safariVC.dismissButtonStyle = .done    // Default "Done" button
safariVC.dismissButtonStyle = .close   // "X" button
safariVC.dismissButtonStyle = .cancel  // "Cancel" button
```

### Bar Tint Colors (Deprecated but Functional)

While these properties are deprecated, they still work for customization:

```swift
import SafariServices
import UIKit

let safariVC = SFSafariViewController(url: url)

// Background color of navigation bar and toolbar
safariVC.preferredBarTintColor = UIColor.systemBackground

// Color of control buttons
safariVC.preferredControlTintColor = UIColor.tintColor
```

### Modern Appearance Approach

For iOS 18+, prefer using the system appearance and avoid heavy customization to maintain consistency with Safari:

```swift
import SafariServices

func createSafariViewController(for url: URL) -> SFSafariViewController {
    let configuration = SFSafariViewController.Configuration()
    configuration.barCollapsingEnabled = true

    let safariVC = SFSafariViewController(url: url, configuration: configuration)
    safariVC.dismissButtonStyle = .close

    // Let the system handle appearance based on user preferences
    // Avoid setting custom colors unless necessary for branding

    return safariVC
}
```

---

## iOS 18/26 Specific Features

### iOS 18 Considerations

iOS 18 maintains compatibility with existing SafariServices APIs. Key considerations:

- **Privacy Enhancements**: Continued focus on user privacy with no changes to data isolation
- **Performance**: Improved web rendering and JavaScript performance benefit SFSafariViewController
- **Tint Color Deprecation**: `preferredBarTintColor` and `preferredControlTintColor` remain deprecated; prefer system defaults

### iOS 26 and Liquid Glass

When targeting iOS 26+, SafariServices integrates with the Liquid Glass design language:

```swift
import SafariServices
import SwiftUI

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.barCollapsingEnabled = true

        let safariVC = SFSafariViewController(url: url, configuration: configuration)

        // iOS 26+: System automatically applies Liquid Glass styling
        // Avoid custom bar colors to preserve the glass effect

        return safariVC
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
```

### Best Practices for iOS 26

1. **Avoid Custom Colors**: Let the system apply Liquid Glass effects
2. **Use Default Dismiss Style**: `.done` or `.close` integrate best with glass design
3. **Enable Bar Collapsing**: Allows natural glass transitions during scrolling
4. **Test Reader Mode**: Ensure content looks good in both regular and reader views

---

## Common Use Cases

### 1. Opening External Links

```swift
import SafariServices
import SwiftUI

struct LinkButton: View {
    let title: String
    let url: URL
    @State private var showSafari = false

    var body: some View {
        Button(title) {
            showSafari = true
        }
        .sheet(isPresented: $showSafari) {
            SafariView(url: url)
                .ignoresSafeArea()
        }
    }
}
```

### 2. Privacy Policy / Terms of Service

```swift
import SafariServices
import SwiftUI

struct LegalLinksView: View {
    @State private var selectedURL: URL?

    private let privacyURL = URL(string: "https://example.com/privacy")!
    private let termsURL = URL(string: "https://example.com/terms")!

    var body: some View {
        VStack(spacing: 12) {
            Button("Privacy Policy") {
                selectedURL = privacyURL
            }

            Button("Terms of Service") {
                selectedURL = termsURL
            }
        }
        .sheet(item: $selectedURL) { url in
            SafariView(url: url)
                .ignoresSafeArea()
        }
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
```

### 3. OAuth Login Flow

```swift
import AuthenticationServices
import SwiftUI

struct OAuthLoginView: View {
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    @State private var isLoading = false

    var body: some View {
        Button {
            Task {
                await performOAuthLogin()
            }
        } label: {
            HStack {
                if isLoading {
                    ProgressView()
                }
                Text("Sign in with Google")
            }
        }
        .disabled(isLoading)
    }

    private func performOAuthLogin() async {
        isLoading = true
        defer { isLoading = false }

        let clientID = "YOUR_CLIENT_ID"
        let redirectURI = "com.yourapp://oauth/callback"
        let scope = "email profile"

        guard let authURL = URL(string: "https://accounts.google.com/o/oauth2/v2/auth?client_id=\(clientID)&redirect_uri=\(redirectURI)&response_type=code&scope=\(scope)") else {
            return
        }

        do {
            let callbackURL = try await webAuthenticationSession.authenticate(
                using: authURL,
                callbackURLScheme: "com.yourapp"
            )

            // Handle the callback
            await processOAuthCallback(callbackURL)
        } catch {
            print("OAuth failed: \(error)")
        }
    }

    private func processOAuthCallback(_ url: URL) async {
        // Extract code and exchange for tokens
    }
}
```

### 4. Article Reader with Auto-Reader Mode

```swift
import SafariServices
import SwiftUI

struct ArticleReaderView: View {
    let articles: [Article]
    @State private var selectedArticle: Article?

    var body: some View {
        List(articles) { article in
            Button {
                selectedArticle = article
            } label: {
                ArticleRowView(article: article)
            }
        }
        .sheet(item: $selectedArticle) { article in
            SafariView(
                url: article.url,
                entersReaderIfAvailable: true,
                dismissButtonStyle: .close
            )
            .ignoresSafeArea()
        }
    }
}

struct Article: Identifiable {
    let id: UUID
    let title: String
    let url: URL
}
```

### 5. Help & Support Links

```swift
import SafariServices
import SwiftUI

struct HelpView: View {
    @State private var showHelp = false

    private let helpURL = URL(string: "https://help.example.com")!

    var body: some View {
        Form {
            Section("Support") {
                Button("Help Center") {
                    showHelp = true
                }

                Link("Email Support", destination: URL(string: "mailto:support@example.com")!)
            }
        }
        .sheet(isPresented: $showHelp) {
            SafariView(url: helpURL)
                .ignoresSafeArea()
        }
    }
}
```

---

## Best Practices & When to Use vs WKWebView

### Decision Matrix

| Scenario | Recommended | Reason |
|----------|-------------|--------|
| External website links | `SFSafariViewController` | Familiar UI, Safari features |
| OAuth/SSO authentication | `ASWebAuthenticationSession` | Secure, shares cookies with Safari |
| Custom web app embedded in your app | `WKWebView` | Full control over content and interaction |
| Displaying your own web content | `WKWebView` | Can inject JavaScript, handle navigation |
| Privacy policy / Terms of Service | `SFSafariViewController` | Simple presentation, no customization needed |
| In-app help documentation | Either | Depends on interactivity requirements |
| Payment flows (non-Apple Pay) | `SFSafariViewController` | Security, AutoFill support |
| Web-based games or interactive content | `WKWebView` | JavaScript communication needed |

### When to Use SFSafariViewController

Use `SFSafariViewController` when:

1. **Displaying external web content** where you do not need to interact with the page
2. **Showing third-party websites** (news articles, documentation, etc.)
3. **Privacy is important** and you want sandboxed browsing
4. **You want Safari features** like Reader mode, AutoFill, content blocking
5. **Minimal implementation effort** is desired
6. **Consistency with Safari** is valued by users

### When to Use WKWebView

Use `WKWebView` when:

1. **You need to interact with web content** via JavaScript
2. **Custom navigation controls** are required
3. **You need to inject custom CSS/JavaScript**
4. **You want to track user navigation** and page content
5. **Displaying your own web content** that integrates with your app
6. **You need to handle specific URL schemes** or deep links within web content

### When to Use ASWebAuthenticationSession

Use `ASWebAuthenticationSession` when:

1. **Implementing OAuth or OpenID Connect** flows
2. **Single Sign-On (SSO)** is desired
3. **Secure token exchange** with a web service is needed
4. **You need callback handling** after web authentication

### Best Practices Summary

```swift
// DO: Use SFSafariViewController for external links
func openExternalLink(_ url: URL) {
    let safariVC = SFSafariViewController(url: url)
    present(safariVC, animated: true)
}

// DO: Use ASWebAuthenticationSession for OAuth
func authenticateWithOAuth() async throws -> URL {
    try await webAuthenticationSession.authenticate(
        using: authURL,
        callbackURLScheme: "myapp"
    )
}

// DO: Let system handle appearance in iOS 18+
let safariVC = SFSafariViewController(url: url)
// Avoid: safariVC.preferredBarTintColor = .blue

// DO: Handle delegate callbacks appropriately
safariVC.delegate = self

// DON'T: Use SFSafariViewController to track users
// DON'T: Hide or obscure the view controller
// DON'T: Use for content that requires JavaScript interaction
```

### Performance Considerations

- `SFSafariViewController` shares processes with Safari, improving performance
- `WKWebView` runs in a separate process, providing isolation but more overhead
- For one-off page views, `SFSafariViewController` is more efficient
- For persistent web content, `WKWebView` provides more control

### Security Considerations

| Aspect | SFSafariViewController | WKWebView |
|--------|------------------------|-----------|
| Data isolation | Fully isolated from app | App can access content |
| AutoFill | Supported | Not available |
| Fraudulent site warnings | Enabled | Not available |
| Content blockers | Supported | Requires manual setup |
| Cookie access | Not accessible | Accessible via WKHTTPCookieStore |

---

## Summary

SafariServices provides powerful tools for integrating web browsing and authentication into your iOS apps:

- **SFSafariViewController**: Best for displaying external web content with Safari's familiar interface
- **ASWebAuthenticationSession**: Essential for OAuth and secure web authentication
- **SwiftUI Integration**: Use `UIViewControllerRepresentable` for seamless SwiftUI support

Always prioritize user privacy and follow Apple's guidelines when implementing web browsing features. For iOS 18+ and especially iOS 26, embrace system defaults to ensure your app integrates naturally with the evolving design language.

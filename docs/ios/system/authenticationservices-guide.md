# AuthenticationServices iOS Guide - Sign in with Apple & Passkeys

Comprehensive guide for Apple's AuthenticationServices framework in iOS/Swift applications for implementing Sign in with Apple and Passkeys authentication.

---

## Overview

**AuthenticationServices** is Apple's framework for secure, privacy-focused user authentication. It provides:

- **Sign in with Apple** - Fast, secure account creation and sign-in using Apple ID
- **Passkeys** - Passwordless authentication using WebAuthn/FIDO2 standards (iOS 16+)
- **Password AutoFill** - Integration with iCloud Keychain for credential management
- **Single Sign-On** - Enterprise SSO and web authentication

### When to Use

| Feature | Use Case | iOS Version |
|---------|----------|-------------|
| Sign in with Apple | Primary authentication, account creation | iOS 13+ |
| Passkeys | Passwordless login, enhanced security | iOS 16+ |
| Password AutoFill | Credential suggestions in text fields | iOS 11+ |
| ASWebAuthenticationSession | OAuth/OpenID Connect flows | iOS 12+ |

---

## Setup & Configuration

### 1. Enable Capabilities

In Xcode, add the required capabilities:

1. Select your target
2. Go to **Signing & Capabilities**
3. Click **+ Capability**
4. Add **Sign in with Apple**

### 2. Add Entitlements

The `Sign in with Apple` capability automatically adds the entitlement:

```xml
<!-- Entitlements file -->
<key>com.apple.developer.applesignin</key>
<array>
    <string>Default</string>
</array>
```

### 3. Configure Associated Domains (for Passkeys)

For Passkeys, you need Associated Domains configured:

1. Add **Associated Domains** capability in Xcode
2. Add your domain: `webcredentials:example.com`

```xml
<!-- Entitlements file -->
<key>com.apple.developer.associated-domains</key>
<array>
    <string>webcredentials:example.com</string>
</array>
```

### 4. Apple App Site Association File (Passkeys)

Host this file at `https://example.com/.well-known/apple-app-site-association`:

```json
{
  "webcredentials": {
    "apps": ["TEAMID.com.yourcompany.yourapp"]
  }
}
```

**Important:** Replace `TEAMID` with your Apple Developer Team ID and use your actual bundle identifier.

---

## Sign in with Apple

### Import Framework

```swift
import AuthenticationServices
```

### SwiftUI SignInWithAppleButton

The simplest way to implement Sign in with Apple in SwiftUI:

```swift
import SwiftUI
import AuthenticationServices

struct SignInWithAppleView: View {
    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            switch result {
            case .success(let authorization):
                handleAuthorization(authorization)
            case .failure(let error):
                handleError(error)
            }
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50)
        .cornerRadius(8)
    }

    private func handleAuthorization(_ authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            return
        }

        let userIdentifier = credential.user
        let fullName = credential.fullName
        let email = credential.email

        // Send credential to your server for verification
        print("User ID: \(userIdentifier)")
        print("Full Name: \(fullName?.givenName ?? "") \(fullName?.familyName ?? "")")
        print("Email: \(email ?? "Not provided")")
    }

    private func handleError(_ error: Error) {
        print("Sign in with Apple failed: \(error.localizedDescription)")
    }
}
```

### Button Styles

```swift
// Black button (for light backgrounds)
.signInWithAppleButtonStyle(.black)

// White button (for dark backgrounds)
.signInWithAppleButtonStyle(.white)

// White with outline (for dark backgrounds)
.signInWithAppleButtonStyle(.whiteOutline)
```

### Button Types

```swift
// Sign in (default)
SignInWithAppleButton(.signIn) { ... }

// Sign up
SignInWithAppleButton(.signUp) { ... }

// Continue with Apple
SignInWithAppleButton(.continue) { ... }
```

---

## Complete Authentication Manager

### AuthenticationManager with async/await

```swift
import SwiftUI
import AuthenticationServices

@Observable
class AuthenticationManager: NSObject {
    var userIdentifier: String?
    var isAuthenticated = false
    var isLoading = false
    var error: AuthenticationError?

    private var authorizationContinuation: CheckedContinuation<ASAuthorization, Error>?

    // MARK: - Sign in with Apple

    func signInWithApple() async throws -> AppleIDCredentialData {
        isLoading = true
        defer { isLoading = false }

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let authorization = try await performAuthorization(requests: [request])

        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthenticationError.invalidCredential
        }

        let credentialData = AppleIDCredentialData(
            userIdentifier: credential.user,
            email: credential.email,
            fullName: credential.fullName,
            identityToken: credential.identityToken,
            authorizationCode: credential.authorizationCode
        )

        // Store user identifier for credential state checks
        userIdentifier = credential.user
        storeUserIdentifier(credential.user)
        isAuthenticated = true

        return credentialData
    }

    // MARK: - Quick Sign-In (Existing Users)

    /// Attempts to sign in with existing Apple ID or iCloud Keychain credentials
    func performExistingAccountSignIn() async throws -> ASAuthorization {
        isLoading = true
        defer { isLoading = false }

        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let appleIDRequest = appleIDProvider.createRequest()

        let passwordProvider = ASAuthorizationPasswordProvider()
        let passwordRequest = passwordProvider.createRequest()

        return try await performAuthorization(requests: [appleIDRequest, passwordRequest])
    }

    // MARK: - Authorization Controller

    private func performAuthorization(requests: [ASAuthorizationRequest]) async throws -> ASAuthorization {
        try await withCheckedThrowingContinuation { continuation in
            self.authorizationContinuation = continuation

            let controller = ASAuthorizationController(authorizationRequests: requests)
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    // MARK: - Credential State

    func checkCredentialState() async -> CredentialState {
        guard let userIdentifier = loadUserIdentifier() else {
            return .notFound
        }

        let provider = ASAuthorizationAppleIDProvider()

        do {
            let state = try await provider.credentialState(forUserID: userIdentifier)

            switch state {
            case .authorized:
                self.userIdentifier = userIdentifier
                isAuthenticated = true
                return .authorized
            case .revoked:
                clearStoredCredentials()
                return .revoked
            case .notFound:
                clearStoredCredentials()
                return .notFound
            case .transferred:
                return .transferred
            @unknown default:
                return .unknown
            }
        } catch {
            return .error(error)
        }
    }

    // MARK: - Sign Out

    func signOut() {
        userIdentifier = nil
        isAuthenticated = false
        clearStoredCredentials()
    }

    // MARK: - Keychain Storage

    private let userIdentifierKey = "appleUserIdentifier"

    private func storeUserIdentifier(_ identifier: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: userIdentifierKey,
            kSecValueData as String: identifier.data(using: .utf8)!
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadUserIdentifier() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: userIdentifierKey,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let identifier = String(data: data, encoding: .utf8) else {
            return nil
        }

        return identifier
    }

    private func clearStoredCredentials() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: userIdentifierKey
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthenticationManager: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        authorizationContinuation?.resume(returning: authorization)
        authorizationContinuation = nil
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        authorizationContinuation?.resume(throwing: error)
        authorizationContinuation = nil
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthenticationManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            fatalError("No window found")
        }
        return window
    }
}
```

### Data Models

```swift
struct AppleIDCredentialData {
    let userIdentifier: String
    let email: String?
    let fullName: PersonNameComponents?
    let identityToken: Data?
    let authorizationCode: Data?

    var identityTokenString: String? {
        guard let token = identityToken else { return nil }
        return String(data: token, encoding: .utf8)
    }

    var authorizationCodeString: String? {
        guard let code = authorizationCode else { return nil }
        return String(data: code, encoding: .utf8)
    }
}

enum CredentialState {
    case authorized
    case revoked
    case notFound
    case transferred
    case unknown
    case error(Error)
}

enum AuthenticationError: LocalizedError {
    case invalidCredential
    case credentialRevoked
    case userCancelled
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Invalid authentication credential"
        case .credentialRevoked:
            return "Your Apple ID credential has been revoked"
        case .userCancelled:
            return "Sign in was cancelled"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}
```

---

## Passkeys (iOS 16+)

Passkeys provide passwordless authentication using WebAuthn/FIDO2 standards.

### PasskeyManager

```swift
import AuthenticationServices

@Observable
class PasskeyManager: NSObject {
    var isLoading = false
    var error: PasskeyError?

    private let relyingPartyIdentifier: String
    private var authorizationContinuation: CheckedContinuation<ASAuthorization, Error>?

    init(relyingPartyIdentifier: String) {
        self.relyingPartyIdentifier = relyingPartyIdentifier
        super.init()
    }

    // MARK: - Registration (Create New Passkey)

    /// Registers a new passkey for the user
    /// - Parameters:
    ///   - challenge: Server-provided challenge data
    ///   - userName: Display name for the credential
    ///   - userID: Unique user identifier from server
    func registerPasskey(
        challenge: Data,
        userName: String,
        userID: Data
    ) async throws -> PasskeyRegistrationResult {
        isLoading = true
        defer { isLoading = false }

        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: relyingPartyIdentifier
        )

        let request = provider.createCredentialRegistrationRequest(
            challenge: challenge,
            name: userName,
            userID: userID
        )

        let authorization = try await performAuthorization(requests: [request])

        guard let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration else {
            throw PasskeyError.invalidCredential
        }

        return PasskeyRegistrationResult(
            credentialID: credential.credentialID,
            rawAttestationObject: credential.rawAttestationObject,
            rawClientDataJSON: credential.rawClientDataJSON
        )
    }

    // MARK: - Authentication (Sign In with Passkey)

    /// Authenticates user with existing passkey
    /// - Parameter challenge: Server-provided challenge data
    func signInWithPasskey(challenge: Data) async throws -> PasskeyAssertionResult {
        isLoading = true
        defer { isLoading = false }

        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: relyingPartyIdentifier
        )

        let request = provider.createCredentialAssertionRequest(challenge: challenge)

        let authorization = try await performAuthorization(requests: [request])

        guard let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion else {
            throw PasskeyError.invalidCredential
        }

        return PasskeyAssertionResult(
            credentialID: credential.credentialID,
            rawAuthenticatorData: credential.rawAuthenticatorData,
            rawClientDataJSON: credential.rawClientDataJSON,
            signature: credential.signature,
            userID: credential.userID
        )
    }

    // MARK: - Combined Sign-In (Passkey + Password)

    /// Attempts sign-in with passkey, falling back to password credentials
    func performCombinedSignIn(challenge: Data) async throws -> ASAuthorization {
        isLoading = true
        defer { isLoading = false }

        let passkeyProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: relyingPartyIdentifier
        )
        let passkeyRequest = passkeyProvider.createCredentialAssertionRequest(challenge: challenge)

        let passwordProvider = ASAuthorizationPasswordProvider()
        let passwordRequest = passwordProvider.createRequest()

        return try await performAuthorization(requests: [passkeyRequest, passwordRequest])
    }

    // MARK: - Authorization Controller

    private func performAuthorization(requests: [ASAuthorizationRequest]) async throws -> ASAuthorization {
        try await withCheckedThrowingContinuation { continuation in
            self.authorizationContinuation = continuation

            let controller = ASAuthorizationController(authorizationRequests: requests)
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension PasskeyManager: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        authorizationContinuation?.resume(returning: authorization)
        authorizationContinuation = nil
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        let passkeyError: PasskeyError

        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                passkeyError = .userCancelled
            case .invalidResponse:
                passkeyError = .invalidResponse
            case .notHandled:
                passkeyError = .notHandled
            case .failed:
                passkeyError = .failed
            case .notInteractive:
                passkeyError = .notInteractive
            @unknown default:
                passkeyError = .unknown(error)
            }
        } else {
            passkeyError = .unknown(error)
        }

        authorizationContinuation?.resume(throwing: passkeyError)
        authorizationContinuation = nil
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension PasskeyManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            fatalError("No window found")
        }
        return window
    }
}
```

### Passkey Data Models

```swift
struct PasskeyRegistrationResult {
    let credentialID: Data
    let rawAttestationObject: Data?
    let rawClientDataJSON: Data

    /// Base64 URL-encoded credential ID for server transmission
    var credentialIDBase64URL: String {
        credentialID.base64URLEncodedString()
    }
}

struct PasskeyAssertionResult {
    let credentialID: Data
    let rawAuthenticatorData: Data
    let rawClientDataJSON: Data
    let signature: Data
    let userID: Data

    var credentialIDBase64URL: String {
        credentialID.base64URLEncodedString()
    }
}

enum PasskeyError: LocalizedError {
    case invalidCredential
    case userCancelled
    case invalidResponse
    case notHandled
    case failed
    case notInteractive
    case serverError(String)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Invalid passkey credential"
        case .userCancelled:
            return "Authentication was cancelled"
        case .invalidResponse:
            return "Invalid response from authenticator"
        case .notHandled:
            return "Request was not handled"
        case .failed:
            return "Authentication failed"
        case .notInteractive:
            return "Cannot show UI in current context"
        case .serverError(let message):
            return "Server error: \(message)"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - Base64 URL Encoding Extension

extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URLEncoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let paddingLength = (4 - base64.count % 4) % 4
        base64 += String(repeating: "=", count: paddingLength)

        self.init(base64Encoded: base64)
    }
}
```

---

## SwiftUI Integration

### Complete Sign-In View

```swift
import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @Environment(AuthenticationManager.self) var authManager
    @State private var showError = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App branding
            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            Text("Welcome")
                .font(.largeTitle)
                .bold()

            Text("Sign in to continue")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            // Sign in with Apple Button
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                Task {
                    await handleSignInResult(result)
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .cornerRadius(8)
            .disabled(authManager.isLoading)

            if authManager.isLoading {
                ProgressView()
            }

            Spacer()
        }
        .padding(.horizontal, 32)
        .alert("Sign In Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(authManager.error?.localizedDescription ?? "An unknown error occurred")
        }
    }

    private func handleSignInResult(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                return
            }

            // Handle successful sign-in
            // Send credentials to your server for verification
            await sendCredentialsToServer(credential)

        case .failure(let error):
            if let authError = error as? ASAuthorizationError,
               authError.code == .canceled {
                // User cancelled - don't show error
                return
            }
            authManager.error = AuthenticationError.unknown(error)
            showError = true
        }
    }

    private func sendCredentialsToServer(_ credential: ASAuthorizationAppleIDCredential) async {
        // Implement server verification
    }
}
```

### Passkey Sign-In View

```swift
import SwiftUI
import AuthenticationServices

struct PasskeySignInView: View {
    @State private var passkeyManager = PasskeyManager(relyingPartyIdentifier: "example.com")
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "key.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("Sign in with Passkey")
                .font(.title)
                .bold()

            Text("Use your passkey for secure, passwordless authentication")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                Task {
                    await signInWithPasskey()
                }
            } label: {
                HStack {
                    Image(systemName: "key.fill")
                    Text("Continue with Passkey")
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .disabled(passkeyManager.isLoading)

            if passkeyManager.isLoading {
                ProgressView()
            }

            Spacer()
        }
        .padding(.horizontal, 32)
        .alert("Sign In Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    private func signInWithPasskey() async {
        do {
            // Get challenge from server
            let challenge = try await fetchChallengeFromServer()

            // Perform passkey authentication
            let result = try await passkeyManager.signInWithPasskey(challenge: challenge)

            // Send assertion to server for verification
            try await verifyAssertionOnServer(result)

        } catch let error as PasskeyError {
            if case .userCancelled = error {
                return
            }
            errorMessage = error.localizedDescription
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func fetchChallengeFromServer() async throws -> Data {
        // Implement server challenge fetch
        fatalError("Implement server challenge fetch")
    }

    private func verifyAssertionOnServer(_ result: PasskeyAssertionResult) async throws {
        // Implement server verification
        fatalError("Implement server verification")
    }
}
```

---

## App Launch Credential Check

Check credential state at app launch to detect revoked credentials:

```swift
import SwiftUI
import AuthenticationServices

@main
struct MyApp: App {
    @State private var authManager = AuthenticationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authManager)
                .task {
                    await checkCredentialState()
                }
                .onReceive(NotificationCenter.default.publisher(
                    for: ASAuthorizationAppleIDProvider.credentialRevokedNotification
                )) { _ in
                    handleCredentialRevoked()
                }
        }
    }

    private func checkCredentialState() async {
        let state = await authManager.checkCredentialState()

        switch state {
        case .authorized:
            // User is still authorized
            break
        case .revoked:
            // Credential was revoked, sign out user
            authManager.signOut()
        case .notFound:
            // No stored credential, show sign-in
            break
        case .transferred:
            // Account transferred to different device
            break
        case .unknown, .error:
            // Handle error cases
            break
        }
    }

    private func handleCredentialRevoked() {
        authManager.signOut()
        // Navigate to sign-in screen
    }
}
```

---

## Server Integration

### Identity Token Verification

The identity token is a JWT that should be verified on your server:

```swift
// Client-side: Extract and send to server
func sendCredentialToServer(_ credential: ASAuthorizationAppleIDCredential) async throws {
    guard let identityToken = credential.identityToken,
          let tokenString = String(data: identityToken, encoding: .utf8) else {
        throw AuthenticationError.invalidCredential
    }

    let payload = SignInPayload(
        userIdentifier: credential.user,
        identityToken: tokenString,
        authorizationCode: credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) },
        email: credential.email,
        fullName: credential.fullName
    )

    // Send to your server for verification
    // Server should verify JWT signature with Apple's public keys
}

struct SignInPayload: Encodable {
    let userIdentifier: String
    let identityToken: String
    let authorizationCode: String?
    let email: String?
    let fullName: PersonNameComponents?
}
```

### Important: Email and Name are Only Provided Once

Apple only provides the user's email and name on the **first** authorization. Store these values immediately:

```swift
func handleFirstSignIn(_ credential: ASAuthorizationAppleIDCredential) {
    // IMPORTANT: email and fullName are only provided on first sign-in
    if let email = credential.email {
        // Store email - won't be provided on subsequent sign-ins
        storeEmail(email, for: credential.user)
    }

    if let fullName = credential.fullName {
        // Store name - won't be provided on subsequent sign-ins
        storeName(fullName, for: credential.user)
    }
}
```

---

## Best Practices

### 1. Always Check Credential State at Launch

```swift
func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
    Task {
        let state = await checkCredentialState()
        if state != .authorized {
            // Show sign-in UI
        }
    }
    return true
}
```

### 2. Listen for Credential Revocation

```swift
// Register for revocation notification
NotificationCenter.default.addObserver(
    forName: ASAuthorizationAppleIDProvider.credentialRevokedNotification,
    object: nil,
    queue: .main
) { _ in
    // Sign out user and show sign-in UI
}
```

### 3. Store User Identifier in Keychain

Never store in UserDefaults - use Keychain for security:

```swift
// GOOD: Use Keychain
func storeUserIdentifier(_ identifier: String) {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: "appleUserIdentifier",
        kSecValueData as String: identifier.data(using: .utf8)!,
        kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
    ]
    SecItemAdd(query as CFDictionary, nil)
}

// BAD: Don't use UserDefaults for credentials
// UserDefaults.standard.set(identifier, forKey: "appleUserIdentifier")
```

### 4. Handle User Cancellation Gracefully

```swift
func handleError(_ error: Error) {
    if let authError = error as? ASAuthorizationError,
       authError.code == .canceled {
        // User cancelled - don't show error, just return
        return
    }

    // Show error for other failures
    showErrorAlert(error)
}
```

### 5. Implement Proper Nonce for Security

When using Sign in with Apple with Firebase or other identity providers:

```swift
import CryptoKit

func randomNonceString(length: Int = 32) -> String {
    precondition(length > 0)
    var randomBytes = [UInt8](repeating: 0, count: length)
    let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)

    if errorCode != errSecSuccess {
        fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
    }

    let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    let nonce = randomBytes.map { byte in
        charset[Int(byte) % charset.count]
    }

    return String(nonce)
}

func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashedData = SHA256.hash(data: inputData)
    return hashedData.compactMap { String(format: "%02x", $0) }.joined()
}
```

---

## Common Pitfalls

### Issue: Email/Name Missing on Subsequent Sign-Ins

**Problem:** User's email and name are `nil` after the first sign-in.

**Solution:** Store these values on first sign-in. Apple only provides them once:

```swift
// Check if this is first sign-in and store data
if credential.email != nil || credential.fullName != nil {
    // First sign-in - store immediately
    storeUserData(credential)
}

// For returning users, load from your database
let userData = await fetchUserFromServer(credential.user)
```

### Issue: Credential State Check Returns `.notFound`

**Problem:** `getCredentialState` returns `.notFound` even for valid users.

**Possible Causes:**
1. User signed out of Apple ID on device
2. User removed your app from Apple ID settings
3. Wrong user identifier being checked

**Solution:** Handle gracefully and prompt re-authentication:

```swift
switch state {
case .notFound:
    // Clear local credentials
    clearStoredCredentials()
    // Prompt user to sign in again
    showSignInView()
case .revoked:
    // Same handling as notFound
    break
default:
    break
}
```

### Issue: ASAuthorizationError.notInteractive

**Problem:** Error thrown when trying to perform authorization without UI context.

**Solution:** Ensure you're calling from a proper UI context:

```swift
// Only perform authorization when view is visible
.task {
    // DON'T perform quick sign-in automatically here
    // Let user trigger the action
}

// Use button action instead
Button("Sign In") {
    Task {
        await signIn()
    }
}
```

### Issue: Passkey Registration Fails

**Problem:** Passkey registration fails with "domain not associated."

**Checklist:**
1. Associated Domains entitlement configured
2. `apple-app-site-association` file hosted correctly
3. File served with `Content-Type: application/json`
4. No redirects to the AASA file
5. Valid SSL certificate on domain

### Issue: Token Refresh

**Problem:** Identity token expires and server rejects requests.

**Solution:** Use authorization code for server-side token refresh:

```swift
// Send authorization code to server on sign-in
let authCode = credential.authorizationCode

// Server should exchange code for refresh token
// https://appleid.apple.com/auth/token
// Use refresh token for subsequent API calls
```

---

## iOS Version Compatibility

| Feature | Minimum iOS | Notes |
|---------|-------------|-------|
| Sign in with Apple | iOS 13.0 | Basic functionality |
| SignInWithAppleButton (SwiftUI) | iOS 14.0 | SwiftUI native button |
| Passkeys | iOS 16.0 | Requires Associated Domains |
| Passkey AutoFill | iOS 16.0 | Text field integration |
| credentialState async | iOS 15.0 | Use completion handler for iOS 13-14 |
| Credential Revocation Notification | iOS 13.0 | `ASAuthorizationAppleIDProvider.credentialRevokedNotification` |

### Backwards Compatibility Pattern

```swift
func checkCredentialState(userID: String) async -> CredentialState {
    let provider = ASAuthorizationAppleIDProvider()

    if #available(iOS 15.0, *) {
        // Use async/await
        do {
            let state = try await provider.credentialState(forUserID: userID)
            return mapState(state)
        } catch {
            return .error(error)
        }
    } else {
        // Fallback to completion handler
        return await withCheckedContinuation { continuation in
            provider.getCredentialState(forUserID: userID) { state, error in
                if let error = error {
                    continuation.resume(returning: .error(error))
                } else {
                    continuation.resume(returning: self.mapState(state))
                }
            }
        }
    }
}
```

---

## Quick Reference

| Operation | Code |
|-----------|------|
| Import | `import AuthenticationServices` |
| Apple ID Provider | `ASAuthorizationAppleIDProvider()` |
| Create Request | `provider.createRequest()` |
| Request Scopes | `request.requestedScopes = [.fullName, .email]` |
| Authorization Controller | `ASAuthorizationController(authorizationRequests:)` |
| Check Credential State | `provider.credentialState(forUserID:)` |
| Passkey Provider | `ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier:)` |
| Register Passkey | `provider.createCredentialRegistrationRequest(challenge:name:userID:)` |
| Authenticate Passkey | `provider.createCredentialAssertionRequest(challenge:)` |
| Revocation Notification | `ASAuthorizationAppleIDProvider.credentialRevokedNotification` |

---

## Related Resources

- [Apple Documentation: AuthenticationServices](https://developer.apple.com/documentation/authenticationservices)
- [Apple Documentation: Implementing User Authentication with Sign in with Apple](https://developer.apple.com/documentation/authenticationservices/implementing-user-authentication-with-sign-in-with-apple)
- [Apple Documentation: Supporting Passkeys](https://developer.apple.com/documentation/authenticationservices/supporting-passkeys)
- [Human Interface Guidelines: Sign in with Apple](https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple)

---

*Last updated: February 2026*
*iOS versions: 13.0+ (Sign in with Apple), 16.0+ (Passkeys)*

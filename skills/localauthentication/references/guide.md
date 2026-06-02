# LocalAuthentication Guide - Face ID, Touch ID & Optic ID

Comprehensive guide for implementing biometric authentication in iOS/Swift applications using the LocalAuthentication framework.

**Last Updated:** February 2026
**iOS Versions:** iOS 11+ (Touch ID), iOS 11+ (Face ID), visionOS 1.0+ (Optic ID)

---

## Overview

The **LocalAuthentication** framework provides a simple API for authenticating users with biometrics (Face ID, Touch ID, or Optic ID) or their device passcode. It enables secure, frictionless authentication without requiring users to enter credentials manually.

### Use Cases

- **App Lock:** Require biometric authentication to access sensitive areas of your app
- **Transaction Authorization:** Confirm purchases or sensitive operations
- **Password Autofill:** Unlock stored credentials securely
- **Keychain Access:** Protect keychain items with biometric authentication
- **Quick Re-authentication:** Allow users to quickly re-authenticate after backgrounding

### Supported Biometry Types

| Type | Hardware | Platform |
|------|----------|----------|
| Touch ID | Fingerprint sensor | iPhone 5s-8, iPad with Touch ID |
| Face ID | TrueDepth camera | iPhone X+, iPad Pro with Face ID |
| Optic ID | Iris scanner | Apple Vision Pro |

---

## Setup & Configuration

### Info.plist Configuration

**Required for Face ID:** You must add the `NSFaceIDUsageDescription` key to your Info.plist. Without this key, Face ID authentication will fail silently.

```xml
<key>NSFaceIDUsageDescription</key>
<string>We use Face ID to securely authenticate you and protect your data.</string>
```

Or add it via Xcode:
1. Open your target's Info tab
2. Add a new row: **Privacy - Face ID Usage Description**
3. Enter a clear explanation of why your app needs Face ID

**Note:** Touch ID does not require an Info.plist entry. The reason is provided programmatically in the `localizedReason` parameter.

### Import the Framework

```swift
import LocalAuthentication
```

---

## Core Concepts

### LAContext

`LAContext` is the primary class for evaluating authentication policies. Each context represents a single authentication attempt.

**Important:** Create a new `LAContext` instance for each authentication request. Reusing a context that previously succeeded will automatically succeed without re-authenticating.

### LAPolicy

Two authentication policies are available:

| Policy | Description | Fallback |
|--------|-------------|----------|
| `.deviceOwnerAuthenticationWithBiometrics` | Biometrics only (Face ID/Touch ID/Optic ID) | None - fails if biometrics unavailable |
| `.deviceOwnerAuthentication` | Biometrics with passcode fallback | Device passcode if biometrics fail or unavailable |

### LABiometryType

Indicates which biometric system is available on the device:

```swift
enum LABiometryType {
    case none        // No biometric authentication available
    case touchID     // Touch ID is available
    case faceID      // Face ID is available
    case opticID     // Optic ID is available (visionOS)
}
```

---

## Implementation

### Basic Authentication (Async/Await)

```swift
import LocalAuthentication

@Observable
class BiometricAuthManager {
    var isAuthenticated = false
    var authError: LAError?

    // MARK: - Authentication

    func authenticate(reason: String) async -> Bool {
        let context = LAContext()

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            await MainActor.run {
                isAuthenticated = success
            }
            return success
        } catch let error as LAError {
            await MainActor.run {
                authError = error
                isAuthenticated = false
            }
            return false
        } catch {
            await MainActor.run {
                isAuthenticated = false
            }
            return false
        }
    }
}
```

### Check Biometric Availability

Always check if biometrics are available before attempting authentication:

```swift
extension BiometricAuthManager {

    /// Check if biometric authentication is available
    func canUseBiometrics() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// Get the available biometry type
    func getBiometryType() -> LABiometryType {
        let context = LAContext()
        var error: NSError?

        // Must call canEvaluatePolicy first to populate biometryType
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }

        return context.biometryType
    }

    /// Get a user-friendly name for the biometry type
    var biometryName: String {
        switch getBiometryType() {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        case .none:
            return "Passcode"
        @unknown default:
            return "Biometrics"
        }
    }

    /// Get the appropriate SF Symbol for the biometry type
    var biometryIcon: String {
        switch getBiometryType() {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "opticid"
        case .none:
            return "lock.fill"
        @unknown default:
            return "lock.fill"
        }
    }
}
```

### Authentication with Passcode Fallback

Use `.deviceOwnerAuthentication` to allow passcode as a fallback:

```swift
extension BiometricAuthManager {

    /// Authenticate with biometrics, falling back to passcode if unavailable
    func authenticateWithFallback(reason: String) async -> Bool {
        let context = LAContext()

        // Customize the fallback button title (optional)
        context.localizedFallbackTitle = "Use Passcode"

        // Or hide the fallback button entirely
        // context.localizedFallbackTitle = ""

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            await MainActor.run {
                isAuthenticated = success
            }
            return success
        } catch {
            await MainActor.run {
                isAuthenticated = false
            }
            return false
        }
    }
}
```

---

## SwiftUI Integration

### Complete Authentication View

```swift
import SwiftUI
import LocalAuthentication

struct BiometricLoginView: View {
    @State private var authManager = BiometricAuthManager()
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 24) {
            // Biometry icon
            Image(systemName: authManager.biometryIcon)
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("Authenticate with \(authManager.biometryName)")
                .font(.headline)

            if authManager.canUseBiometrics() {
                Button {
                    Task {
                        await performAuthentication()
                    }
                } label: {
                    Label("Authenticate", systemImage: authManager.biometryIcon)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Text("Biometric authentication is not available")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .alert("Authentication Failed", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private func performAuthentication() async {
        let success = await authManager.authenticate(
            reason: "Authenticate to access your account"
        )

        if !success, let error = authManager.authError {
            await MainActor.run {
                errorMessage = handleAuthError(error)
                showError = true
            }
        }
    }

    private func handleAuthError(_ error: LAError) -> String {
        switch error.code {
        case .userCancel:
            return "Authentication was cancelled."
        case .userFallback:
            return "You chose to use the fallback option."
        case .biometryNotAvailable:
            return "Biometric authentication is not available on this device."
        case .biometryNotEnrolled:
            return "No biometric data is enrolled. Please set up Face ID or Touch ID in Settings."
        case .biometryLockout:
            return "Biometric authentication is locked due to too many failed attempts. Please use your passcode."
        case .passcodeNotSet:
            return "No passcode is set on this device."
        case .authenticationFailed:
            return "Authentication failed. Please try again."
        default:
            return "An unexpected error occurred."
        }
    }
}
```

### Protected Content View

```swift
struct ProtectedContentView: View {
    @State private var authManager = BiometricAuthManager()
    @State private var hasAttemptedAuth = false

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                // Show protected content
                VStack {
                    Text("Welcome! You are authenticated.")
                        .font(.headline)

                    Button("Lock") {
                        authManager.isAuthenticated = false
                        hasAttemptedAuth = false
                    }
                }
            } else {
                // Show authentication prompt
                BiometricLoginView()
            }
        }
        .task {
            // Automatically prompt for authentication when view appears
            if !hasAttemptedAuth && authManager.canUseBiometrics() {
                hasAttemptedAuth = true
                await authManager.authenticate(reason: "Unlock to view your data")
            }
        }
    }
}
```

### App Lock Implementation

```swift
import SwiftUI
import LocalAuthentication

@main
struct SecureApp: App {
    @State private var authManager = BiometricAuthManager()
    @Environment(\.scenePhase) private var scenePhase
    @State private var isLocked = true
    @State private var lastBackgroundTime: Date?

    private let lockTimeout: TimeInterval = 60 // Lock after 60 seconds in background

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environment(authManager)

                if isLocked {
                    LockScreenView(authManager: authManager) {
                        isLocked = false
                    }
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                handleScenePhaseChange(from: oldPhase, to: newPhase)
            }
        }
    }

    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            lastBackgroundTime = Date()
        case .active:
            if let lastTime = lastBackgroundTime,
               Date().timeIntervalSince(lastTime) > lockTimeout {
                isLocked = true
            }
        case .inactive:
            break
        @unknown default:
            break
        }
    }
}

struct LockScreenView: View {
    let authManager: BiometricAuthManager
    let onUnlock: () -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("App Locked")
                    .font(.title2)

                Button {
                    Task {
                        let success = await authManager.authenticate(
                            reason: "Unlock the app"
                        )
                        if success {
                            onUnlock()
                        }
                    }
                } label: {
                    Label("Unlock with \(authManager.biometryName)",
                          systemImage: authManager.biometryIcon)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .task {
            // Auto-prompt on appear
            let success = await authManager.authenticate(reason: "Unlock the app")
            if success {
                onUnlock()
            }
        }
    }
}
```

---

## Error Handling

### LAError Codes

Handle all possible authentication errors:

```swift
enum BiometricError: LocalizedError {
    case notAvailable
    case notEnrolled
    case lockout
    case passcodeNotSet
    case cancelled
    case fallback
    case failed
    case invalidContext
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Biometric authentication is not available on this device."
        case .notEnrolled:
            return "No biometric data is enrolled. Please configure Face ID or Touch ID in Settings."
        case .lockout:
            return "Biometric authentication is temporarily locked due to too many failed attempts."
        case .passcodeNotSet:
            return "Please set a device passcode to use biometric authentication."
        case .cancelled:
            return "Authentication was cancelled."
        case .fallback:
            return "User chose to use fallback authentication."
        case .failed:
            return "Authentication failed. Please try again."
        case .invalidContext:
            return "The authentication context is invalid."
        case .unknown(let error):
            return error.localizedDescription
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notEnrolled:
            return "Go to Settings > Face ID & Passcode to set up biometrics."
        case .lockout:
            return "Enter your device passcode to unlock biometric authentication."
        case .passcodeNotSet:
            return "Go to Settings > Face ID & Passcode to set a passcode."
        default:
            return nil
        }
    }
}

extension BiometricAuthManager {

    func mapLAError(_ error: LAError) -> BiometricError {
        switch error.code {
        case .biometryNotAvailable:
            return .notAvailable
        case .biometryNotEnrolled:
            return .notEnrolled
        case .biometryLockout:
            return .lockout
        case .passcodeNotSet:
            return .passcodeNotSet
        case .userCancel:
            return .cancelled
        case .userFallback:
            return .fallback
        case .authenticationFailed:
            return .failed
        case .invalidContext:
            return .invalidContext
        case .appCancel:
            return .cancelled
        case .systemCancel:
            return .cancelled
        case .notInteractive:
            return .failed
        @unknown default:
            return .unknown(error)
        }
    }
}
```

### Complete Error Handling Example

```swift
extension BiometricAuthManager {

    /// Authenticate with comprehensive error handling
    func authenticateWithErrorHandling(reason: String) async -> Result<Bool, BiometricError> {
        let context = LAContext()
        var error: NSError?

        // Check availability first
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let laError = error as? LAError {
                return .failure(mapLAError(laError))
            }
            return .failure(.notAvailable)
        }

        // Perform authentication
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            await MainActor.run {
                isAuthenticated = success
            }
            return .success(success)
        } catch let error as LAError {
            await MainActor.run {
                isAuthenticated = false
            }
            return .failure(mapLAError(error))
        } catch {
            return .failure(.unknown(error))
        }
    }
}
```

---

## Detecting Biometric Changes

Use `evaluatedPolicyDomainState` to detect when biometric data has changed (fingerprints added/removed, faces re-enrolled):

```swift
extension BiometricAuthManager {

    private static let biometricStateKey = "com.app.biometricState"

    /// Save the current biometric state
    func saveBiometricState() {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return
        }

        if let domainState = context.evaluatedPolicyDomainState {
            UserDefaults.standard.set(domainState, forKey: Self.biometricStateKey)
        }
    }

    /// Check if biometric data has changed since last save
    func hasBiometricDataChanged() -> Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }

        guard let savedState = UserDefaults.standard.data(forKey: Self.biometricStateKey) else {
            // No saved state - first time, save it
            saveBiometricState()
            return false
        }

        guard let currentState = context.evaluatedPolicyDomainState else {
            return false
        }

        return savedState != currentState
    }

    /// Handle biometric data changes (e.g., require re-authentication)
    func handleBiometricChangeIfNeeded() async -> Bool {
        if hasBiometricDataChanged() {
            // Biometric data changed - require fresh authentication
            let success = await authenticate(
                reason: "Your biometric data has changed. Please authenticate to continue."
            )

            if success {
                saveBiometricState()
            }

            return success
        }

        return true // No change detected
    }
}
```

**Important Caveats:**
- `evaluatedPolicyDomainState` may change between major OS versions even if biometrics haven't changed
- The nature of the change (fingerprint added vs. removed) cannot be determined
- Switching devices (e.g., Touch ID to Face ID device) will change this value

---

## Advanced Configurations

### Context Customization

```swift
func createCustomContext() -> LAContext {
    let context = LAContext()

    // Customize the fallback button title
    context.localizedFallbackTitle = "Enter Password"

    // Or hide the fallback button
    // context.localizedFallbackTitle = ""

    // Customize the cancel button title
    context.localizedCancelTitle = "Not Now"

    // Allow biometric reuse within time interval (iOS 9+)
    // If user authenticated recently, skip prompt
    context.touchIDAuthenticationAllowableReuseDuration = 30 // seconds

    return context
}
```

### Invalidating Context

Cancel an ongoing authentication:

```swift
class AuthSession {
    private var context: LAContext?

    func startAuthentication() async -> Bool {
        context = LAContext()

        guard let context else { return false }

        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Authenticate to continue"
            )
        } catch {
            return false
        }
    }

    func cancelAuthentication() {
        context?.invalidate()
        context = nil
    }
}
```

---

## Keychain Integration

Protect Keychain items with biometric authentication:

```swift
import Security

class SecureStorage {

    /// Save data to Keychain with biometric protection
    func saveWithBiometrics(data: Data, forKey key: String) throws {
        let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            .biometryCurrentSet, // Invalidates if biometrics change
            nil
        )

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessControl as String: accessControl as Any
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// Retrieve data from Keychain (will prompt for biometrics)
    func loadWithBiometrics(forKey key: String) async throws -> Data {
        let context = LAContext()
        context.localizedReason = "Access your secure data"

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecUseAuthenticationContext as String: context
        ]

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                var result: AnyObject?
                let status = SecItemCopyMatching(query as CFDictionary, &result)

                if status == errSecSuccess, let data = result as? Data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: KeychainError.loadFailed(status))
                }
            }
        }
    }
}

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save to Keychain: \(status)"
        case .loadFailed(let status):
            return "Failed to load from Keychain: \(status)"
        }
    }
}
```

---

## Best Practices

### 1. Always Check Availability First

```swift
func authenticate() async -> Bool {
    let context = LAContext()
    var error: NSError?

    // Always check before evaluating
    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
        handleUnavailable(error: error)
        return false
    }

    // Proceed with authentication
    return await performAuth(context: context)
}
```

### 2. Create New Context for Each Authentication

```swift
// WRONG - Reusing context will auto-succeed
let sharedContext = LAContext()
await sharedContext.evaluatePolicy(...) // First call
await sharedContext.evaluatePolicy(...) // Auto-succeeds without prompting!

// CORRECT - New context each time
let context1 = LAContext()
await context1.evaluatePolicy(...)
let context2 = LAContext()
await context2.evaluatePolicy(...) // Properly prompts
```

### 3. Provide Clear Localized Reasons

```swift
// WRONG - Vague
let reason = "Authentication required"

// CORRECT - Clear and specific
let reason = "Authenticate to view your medical records"
let reason = "Confirm your identity to complete the purchase"
let reason = "Unlock to access your saved passwords"
```

### 4. Handle All Error Cases

```swift
// Provide appropriate UI feedback for each error type
switch error.code {
case .biometryLockout:
    // Offer passcode fallback
    showPasscodeFallback()
case .biometryNotEnrolled:
    // Guide user to Settings
    showSettingsLink()
case .userCancel:
    // Silently handle - user intentionally cancelled
    break
default:
    showGenericError()
}
```

### 5. Consider Biometric Changes for Sensitive Apps

```swift
func handleAppBecameActive() async {
    if authManager.hasBiometricDataChanged() {
        // Someone may have added their fingerprint
        // Require re-authentication for banking/health apps
        await authManager.authenticate(reason: "Re-verify your identity")
    }
}
```

### 6. Test on Real Devices

- Simulator supports Face ID simulation but behavior may differ from real devices
- Test Touch ID on devices with Touch ID sensor
- Test lockout scenarios (5 failed attempts)
- Test with biometrics disabled in Settings

---

## Common Pitfalls

### Pitfall 1: Not Calling canEvaluatePolicy First

`biometryType` returns `.none` until `canEvaluatePolicy` is called:

```swift
// WRONG
let type = LAContext().biometryType // Always returns .none

// CORRECT
let context = LAContext()
var error: NSError?
if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
    let type = context.biometryType // Now correctly populated
}
```

### Pitfall 2: Missing NSFaceIDUsageDescription

Face ID fails silently without the Info.plist key:

```swift
// This will fail on Face ID devices without NSFaceIDUsageDescription
context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, ...)
// Error: LAError.Code.biometryNotAvailable
```

### Pitfall 3: UI Updates on Background Thread

With completion handlers (legacy code), ensure UI updates on main thread:

```swift
// If using completion handlers (legacy pattern)
context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
    // WRONG - May be on background thread
    self.isAuthenticated = success

    // CORRECT
    DispatchQueue.main.async {
        self.isAuthenticated = success
    }
}

// With async/await, use @MainActor
await MainActor.run {
    self.isAuthenticated = success
}
```

### Pitfall 4: Reusing LAContext

A context that previously succeeded will auto-succeed:

```swift
// Create fresh context for each authentication
func authenticate() async -> Bool {
    let context = LAContext() // Always new instance
    // ...
}
```

---

## iOS Version Compatibility

| Feature | Minimum iOS |
|---------|-------------|
| Touch ID | iOS 8.0 |
| Face ID | iOS 11.0 |
| Optic ID | visionOS 1.0 |
| Async/await evaluatePolicy | iOS 15.0 |
| deviceOwnerAuthentication policy | iOS 9.0 |
| evaluatedPolicyDomainState | iOS 9.0 |
| biometryType property | iOS 11.0 |
| localizedFallbackTitle | iOS 8.0 |
| localizedCancelTitle | iOS 10.0 |
| touchIDAuthenticationAllowableReuseDuration | iOS 9.0 |

### Version-Safe Implementation

```swift
func authenticateSafely(reason: String) async -> Bool {
    let context = LAContext()

    // evaluatePolicy with async/await requires iOS 15+
    if #available(iOS 15.0, *) {
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
        } catch {
            return false
        }
    } else {
        // Fallback for iOS 11-14 using completion handler
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            ) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}
```

---

## Testing

### Simulator Testing

Enable Face ID in the iOS Simulator:
1. **Features > Face ID > Enrolled**
2. **Features > Face ID > Matching Face** - Simulate successful authentication
3. **Features > Face ID > Non-matching Face** - Simulate failed authentication

### Unit Testing

```swift
import XCTest
import LocalAuthentication

// Create a protocol for dependency injection
protocol BiometricAuthenticating {
    func canUseBiometrics() -> Bool
    func authenticate(reason: String) async -> Bool
}

// Mock for testing
class MockBiometricAuth: BiometricAuthenticating {
    var canUseBiometricsResult = true
    var authenticateResult = true

    func canUseBiometrics() -> Bool {
        canUseBiometricsResult
    }

    func authenticate(reason: String) async -> Bool {
        authenticateResult
    }
}

final class BiometricTests: XCTestCase {

    func testAuthenticationSuccess() async {
        let mock = MockBiometricAuth()
        mock.authenticateResult = true

        let result = await mock.authenticate(reason: "Test")
        XCTAssertTrue(result)
    }

    func testAuthenticationFailure() async {
        let mock = MockBiometricAuth()
        mock.authenticateResult = false

        let result = await mock.authenticate(reason: "Test")
        XCTAssertFalse(result)
    }
}
```

---

## Quick Reference

### Import

```swift
import LocalAuthentication
```

### Check Availability

```swift
let context = LAContext()
var error: NSError?
let available = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
```

### Authenticate (Async)

```swift
let success = try await context.evaluatePolicy(
    .deviceOwnerAuthenticationWithBiometrics,
    localizedReason: "Your reason here"
)
```

### Get Biometry Type

```swift
// After calling canEvaluatePolicy
let type = context.biometryType // .faceID, .touchID, .opticID, or .none
```

### SF Symbols

| Type | Symbol Name |
|------|-------------|
| Face ID | `faceid` |
| Touch ID | `touchid` |
| Optic ID | `opticid` |
| Lock | `lock.fill` |

### Policies

| Policy | Use Case |
|--------|----------|
| `.deviceOwnerAuthenticationWithBiometrics` | Biometrics only |
| `.deviceOwnerAuthentication` | Biometrics with passcode fallback |

---

## References

- [LocalAuthentication Framework - Apple Developer Documentation](https://developer.apple.com/documentation/localauthentication)
- [LAContext - Apple Developer Documentation](https://developer.apple.com/documentation/localauthentication/lacontext)
- [Logging a User into Your App with Face ID or Touch ID](https://developer.apple.com/documentation/localauthentication/logging-a-user-into-your-app-with-face-id-or-touch-id)
- [LAError.Code - Apple Developer Documentation](https://developer.apple.com/documentation/localauthentication/laerror/code)
- [NSFaceIDUsageDescription - Apple Developer Documentation](https://developer.apple.com/documentation/bundleresources/information-property-list/nsfaceidusagedescription)

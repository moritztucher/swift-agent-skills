# IdentityDocumentServices & IdentityDocumentServicesUI Guide

## Overview

**IdentityDocumentServices** and **IdentityDocumentServicesUI** are Apple frameworks introduced in iOS 26 (WWDC 2025) that enable apps to participate in online mobile document (mdoc) verification using the W3C Digital Credentials API.

### Key Capabilities

- Register mobile documents (mdocs) with iOS for web-based identity verification
- Implement document provider app extensions for handling verification requests
- Support ISO 18013-5 (mobile document format) and ISO 18013-7 (web request/response protocol)
- Enable selective disclosure - users share only required information
- Provide end-to-end encrypted responses to requesting websites

### Platform Support

- **iOS 26+** / **iPadOS 26+** - Native integration with stored credentials
- **macOS 26+** - Cross-device verification using nearby iPhone
- **Safari 26** - Shipped September 15, 2025 with Digital Credentials API support
- Other platforms via QR code-based verification using FIDO CTAP protocol

---

## Frameworks Overview

### IdentityDocumentServices

The core framework that allows apps to share mobile documents using the Digital Credentials API.

```swift
import IdentityDocumentServices
```

**Key Types:**
- `IdentityDocumentProvider` - Protocol your extension's principal type conforms to (`performRegistrationUpdates()` + `var body: some IdentityDocumentRequestScene`)
- `IdentityDocumentProviderRegistrationStore` - **`actor`** that notifies the system which documents the app has available for presentment
- `MobileDocumentRegistration` - A registered mobile document
- `IdentityDocumentRegistration` - Protocol defining an identity document registration
- `ISO18013MobileDocumentRequestScene` - Scene type that hosts the per-request UI (one request → one scene)
- `ISO18013MobileDocumentRequestContext` - Context the system hands each request scene (lives in IdentityDocumentServicesUI)
- `ISO18013MobileDocumentResponse` - The value you return from `sendResponse`, wrapping the encrypted response data

### IdentityDocumentServicesUI

Contains user-interface objects that support features in IdentityDocumentServices. Provides the interface for users to present mobile documents.

```swift
import IdentityDocumentServicesUI
```

---

## Document Registration

### Overview

Document registration links your app's stored identity documents with the iOS system UI. When a website requests identity verification, iOS uses these registrations to determine which apps can respond.

### IdentityDocumentProviderRegistrationStore

The central store for managing document registrations.

`IdentityDocumentProviderRegistrationStore` is an **`actor`** — every access is `await`-ed and isolated. `MobileDocumentRegistration` is initialized with all its values up front; there is no mutable `authorityKeyIdentifiers` property to set afterward. Trusted authorities are passed as `supportedAuthorityKeyIdentifiers: [Data]` (raw key-identifier bytes), not `[String]`.

```swift
import IdentityDocumentServices

let store = IdentityDocumentProviderRegistrationStore()

do {
    let storedDocument = /* a document from your app's storage */

    let registration = MobileDocumentRegistration(
        mobileDocumentType: "org.iso.18013.5.1.mDL",        // ISO 18013-5 standard type
        supportedAuthorityKeyIdentifiers: [Data([0x01, 0x02, 0x03])], // raw AKI bytes from trusted reader CAs
        documentIdentifier: storedDocument.identifier,
        invalidationDate: storedDocument.invalidationDate    // when this registration should expire
    )

    try await store.addRegistration(registration)
} catch {
    // Handle the error.
}
```

### Key API

| Member | Description |
|--------|-------------|
| `addRegistration(_:)` | Register an mdoc with the system (`async throws`) |
| `registrations` | `async throws` — query currently stored registrations to reconcile against your app's storage |

> The `supportedAuthorityKeyIdentifiers` you pass at registration are what gate visibility: only requests signed by one of those reader CAs surface your app in the selection sheet.

### Mobile Document Types

Common document types following ISO 18013-5 standard:

| Type | Description |
|------|-------------|
| `org.iso.18013.5.1.mDL` | Mobile Driver's License |
| Custom types | Corporate IDs, government IDs, etc. |

### Authority Key Identifiers

Authority key identifiers restrict which websites can request your documents:

```swift
// Only apps whose registration lists the request's reader CA appear in the selection UI.
// Pass the raw Authority Key Identifier bytes at registration time:
let registration = MobileDocumentRegistration(
    mobileDocumentType: "org.iso.18013.5.1.mDL",
    supportedAuthorityKeyIdentifiers: [Data(/* AKI bytes from a trusted reader CA */)],
    documentIdentifier: documentID,
    invalidationDate: invalidationDate
)
```

If a request comes from a website not signed by one of the trusted certificate authorities, your app will be hidden from the selection sheet.

---

## App Extension Implementation

### Extension Setup

1. **Create a new target** in Xcode using the "Identity Document Provider" template
2. **Configure Info.plist** with the extension point identifier
3. **Add required entitlements**
4. **Implement the extension principal class**

### Info.plist Configuration

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.identitydocumentservices.provider</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).IdentityDocumentProviderExtension</string>
</dict>
```

### Required Entitlements

Add the mobile document provider entitlement to your app:

**Entitlement Key:** `com.apple.developer.identity-document-services.document-provider.mobile-document-types`

```xml
<key>com.apple.developer.identity-document-services.document-provider.mobile-document-types</key>
<array>
    <string>org.iso.18013.5.1.mDL</string>
</array>
```

**Important:** This is a managed capability requiring Apple approval. Request the entitlement through the Apple Developer portal before production deployment.

### Extension Principal Class

The principal type conforms to `IdentityDocumentProvider`. It provides two things: `performRegistrationUpdates()` to reconcile registrations, and a `body` of type `some IdentityDocumentRequestScene` — **not** `some Scene`. You do **not** use `WindowGroup`; you use `ISO18013MobileDocumentRequestScene`, whose builder closure hands you one `ISO18013MobileDocumentRequestContext` per incoming request.

```swift
import IdentityDocumentServices
import IdentityDocumentServicesUI
import SwiftUI

@main
struct DocumentProviderExtension: IdentityDocumentProvider {

    // MARK: - Registration Updates

    /// The system calls this when it needs your registrations reconciled.
    func performRegistrationUpdates() async {
        let store = IdentityDocumentProviderRegistrationStore()
        do {
            let storedRegistrations = try await store.registrations

            // Diff `storedRegistrations` against your app's documents,
            // then `addRegistration` for any that aren't registered yet.
            _ = storedRegistrations
        } catch {
            // Handle the error.
        }
    }

    // MARK: - Per-request UI

    var body: some IdentityDocumentRequestScene {
        ISO18013MobileDocumentRequestScene { context in
            RequestAuthorizationView(context: context)
        }
    }
}
```

---

## Request Authorization UI

### ISO18013MobileDocumentRequestContext

The context the system hands the request scene's builder closure (declared in `IdentityDocumentServicesUI`). Its shape is system-owned — treat the members below as the contract, not a literal struct definition:

- `context.request` — the system-parsed `ISO18013MobileDocumentRequest` (doc type, requested namespaces/elements, requesting origin). Use it to drive the consent UI.
- `try await context.sendResponse { rawRequest in ... return ISO18013MobileDocumentResponse(responseData:) }` — an **`async throws`** call. The closure receives the full raw request and must return an `ISO18013MobileDocumentResponse` wrapping your built+encrypted bytes.

`sendResponse` is the only path that hands data back. There is no separate "send the `Data`" callback signature — you return an `ISO18013MobileDocumentResponse`. To decline, simply do not call `sendResponse` (dismiss the scene / let the user back out); throwing from the closure or letting the scene close without a response ends the request without sharing anything.

### Building the Authorization View

```swift
import SwiftUI
import IdentityDocumentServices
import IdentityDocumentServicesUI

struct RequestAuthorizationView: View {
    let context: ISO18013MobileDocumentRequestContext
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 24) {
            // MARK: - Header
            Image(systemName: "person.text.rectangle")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("Identity Verification Request")
                .font(.title2)
                .fontWeight(.semibold)

            // MARK: - Request Information
            RequestInfoView(request: context.request)

            Spacer()

            // MARK: - Action Buttons
            VStack(spacing: 12) {
                Button(action: acceptVerification) {
                    Text("Share Information")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: declineVerification) {
                    Text("Decline")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal)
        }
        .padding()
        .alert("Error", isPresented: $showError) {
            Button("OK") { dismiss() }
        } message: {
            Text(errorMessage)
        }
    }

    @Environment(\.dismiss) private var dismiss

    // MARK: - Actions

    private func acceptVerification() {
        Task {
            do {
                try await context.sendResponse { rawRequest in
                    // `rawRequest` is the full ISO 18013 device request.

                    // 1. Confirm the raw request matches the system-parsed request.
                    try await validateConsistency(request: context.request, rawRequest: rawRequest)

                    // 2. Validate the request's reader signature against trusted CAs.
                    try await validateRawRequest(rawRequest: rawRequest)

                    // 3. Build + encrypt the response with only approved elements.
                    let responseData = try await buildAndEncryptResponse(rawRequest: rawRequest)

                    return ISO18013MobileDocumentResponse(responseData: responseData)
                }
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func declineVerification() {
        // Declining = end the request without calling `sendResponse`.
        dismiss()
    }

    // MARK: - Validation Methods

    private func validateConsistency(request: ISO18013MobileDocumentRequest, rawRequest: IdentityDocumentWebPresentmentRawRequest) async throws {
        // Ensure the raw request matches the system-parsed request —
        // prevents tampering between initial parsing and final processing.
    }

    private func validateRawRequest(rawRequest: IdentityDocumentWebPresentmentRawRequest) async throws {
        // Validate the reader signature / certificate chain (ISO 18013-5).
        // `IdentityDocumentWebPresentmentRawRequestValidator` provides helpers here.
    }

    private func buildAndEncryptResponse(rawRequest: IdentityDocumentWebPresentmentRawRequest) async throws -> Data {
        // Build the mdoc response with only the requested/approved elements,
        // encrypt to the recipient public key (HPKE), per ISO 18013-7.
        return Data()
    }
}

// MARK: - Request Info View

// `request` is the system-parsed `ISO18013MobileDocumentRequest`. The exact
// accessor names (origin, requested elements) are owned by the SDK — read them
// off `context.request` and present them; the shape below is illustrative.
struct RequestInfoView: View {
    let request: ISO18013MobileDocumentRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Requesting website information
            HStack {
                Image(systemName: "globe")
                Text("Requested by:")
                Text(request.websiteOrigin)
                    .fontWeight(.medium)
            }

            Divider()

            // Requested information
            Text("Information Requested:")
                .font(.headline)

            ForEach(request.requestedElements, id: \.self) { element in
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(element.displayName)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
```

---

## Security Features

### Request Authentication

Websites identify themselves via certificates. This prevents unauthorized requests and enables users to know exactly who is asking for their information.

```swift
// The request includes a ReaderAuth structure containing:
// - Website's certificate chain
// - Cryptographic signature of the request
// - Timestamp and nonce for replay protection
```

### Response Encryption

End-to-end encryption using the recipient's public key (HPKE - RFC 9180):

```swift
// Response encryption ensures:
// - Only the requesting website can decrypt the response
// - Browser and OS cannot read the contents
// - Man-in-the-middle attacks are prevented
```

### Issuer Authentication

Cryptographic proof that the document issuing authority created the document:

```swift
// Each mdoc element includes:
// - Issuer signature over the data
// - Certificate chain to validate the issuer
```

### Device Authentication

Device Public Key validation proves the document came from its originally issued device:

```swift
// Prevents document cloning by:
// - Binding document to device's secure element
// - Requiring device key signature on responses
```

### Domain Validation

Prevents phishing attacks on document provider apps:

```swift
// iOS validates the requesting website's domain against:
// - The certificate's Subject Alternative Name
// - The origin specified in the Digital Credentials API call
```

---

## Web Integration (Digital Credentials API)

### JavaScript Request Format

```javascript
// Request an identity document from Safari/WebKit
async function requestIdentityDocument() {
    // Build the mdoc request
    const request = {
        protocol: "org-iso-mdoc",  // Safari exclusively supports this protocol
        data: buildMdocRequest()
    };

    // Call the Digital Credentials API
    // IMPORTANT: Must be triggered by user gesture (click, tap, etc.)
    try {
        const credential = await navigator.credentials.get({
            digital: {
                requests: [request]
            }
        });

        // Send response to server for validation
        const response = await fetch('/verify-identity', {
            method: 'POST',
            body: JSON.stringify(credential.data)
        });

        return response.json();
    } catch (error) {
        console.error('Identity verification failed:', error);
        throw error;
    }
}

function buildMdocRequest() {
    // Request structure following ISO 18013-7 Annex C
    return {
        // Document type (e.g., mobile driver's license)
        docType: "org.iso.18013.5.1.mDL",

        // Requested elements with namespace
        nameSpaces: {
            "org.iso.18013.5.1": {
                "family_name": true,      // Request family name
                "given_name": true,       // Request given name
                "age_over_21": true,      // Request age verification
                // "portrait": false      // Don't request photo
            }
        },

        // Retention intent (must be disclosed to user)
        retention: false,

        // Request authentication (signed by website's certificate)
        readerAuth: {
            // Certificate chain and signature
        },

        // Encryption parameters
        encryptionInfo: {
            // Public key for encrypting the response
            // Nonce for session binding
        }
    };
}
```

### Request Components

| Component | Description |
|-----------|-------------|
| `protocol` | Must be `"org-iso-mdoc"` for Safari |
| `docType` | ISO 18013-5 document type identifier |
| `nameSpaces` | Requested data elements by namespace |
| `retention` | Whether the website intends to store the data |
| `readerAuth` | Signed authentication structure |
| `encryptionInfo` | Keys for encrypting the response |

### Important Considerations

1. **User Gesture Required**: The `navigator.credentials.get()` call must be triggered by a user action (button click, etc.)
2. **HTTPS Required**: Digital Credentials API only works on secure origins
3. **Certificate Requirements**: Websites need valid certificates with appropriate extensions for document requests

---

## Verification Flow

### Complete Flow Diagram

```
1. User visits website
   |
2. User clicks "Verify Identity" button
   |
3. Website's server builds and signs mdoc request
   |
4. Website calls navigator.credentials.get()
   |
5. Browser forwards request to iOS
   |
6. iOS checks document registrations
   |
7. iOS displays app selection UI (apps with matching registrations)
   |
8. User selects document provider app
   |
9. App extension's ISO18013MobileDocumentRequestScene gets an ISO18013MobileDocumentRequestContext
   |
10. App displays authorization UI (RequestAuthorizationView)
    |
11. User approves sharing
    |
12. App calls context.sendResponse { rawRequest in ... } and receives the full Device Request
    |
13. App validates request signature and consistency
    |
14. App builds encrypted response with approved elements
    |
15. Encrypted response returned to browser
    |
16. Browser returns response to website JavaScript
    |
17. Website sends response to server for decryption/validation
    |
18. Server validates document authenticity
```

### Server-Side Validation

The website's server must:

1. **Decrypt the response** using the private key corresponding to the public key in the request
2. **Validate issuer signatures** on each data element
3. **Verify certificate chains** against trusted issuers
4. **Check document authenticity** via device key validation
5. **Verify freshness** using timestamps and nonces

---

## Best Practices

### Document Registration

```swift
// DO: Register documents after provisioning, with full init values
func onDocumentProvisioned(_ document: Document) async throws {
    let store = IdentityDocumentProviderRegistrationStore()   // actor
    let registration = MobileDocumentRegistration(
        mobileDocumentType: document.type,
        supportedAuthorityKeyIdentifiers: document.trustedReaderAKIs, // [Data]
        documentIdentifier: document.id,
        invalidationDate: document.invalidationDate
    )
    try await store.addRegistration(registration)
}

// DO: Implement performRegistrationUpdates to reconcile on demand
func performRegistrationUpdates() async {
    let store = IdentityDocumentProviderRegistrationStore()
    do {
        let stored = try await store.registrations
        // Diff `stored` against your app's documents; addRegistration for new ones.
        _ = stored
    } catch {
        // Handle the error.
    }
}
```

### Request Validation

```swift
// ALWAYS: Validate the raw request against the system-parsed request
func validateConsistency(request: ISO18013MobileDocumentRequest,
                         rawRequest: IdentityDocumentWebPresentmentRawRequest) async throws {
    // Ensure consistency to prevent tampering between parse and process.
}

// ALWAYS: Validate signatures using trusted certificate authorities
func validateRawRequest(rawRequest: IdentityDocumentWebPresentmentRawRequest) async throws {
    // Use IdentityDocumentWebPresentmentRawRequestValidator.
    // Follow ISO 18013-5 certificate chain validation, revocation, algorithm checks.
}
```

### User Experience

```swift
// DO: Clearly display what information is being requested
RequestInfoView(request: context.request)

// DO: Show the requesting website's identity
Text("Requested by: \(request.websiteOrigin)")

// DO: Allow users to decline — end the request WITHOUT calling sendResponse
Button("Decline") { dismiss() }

// DO: Indicate retention intent
if request.retentionIntent {
    Text("This website will store your information")
        .foregroundStyle(.orange)
}
```

### Security

```swift
// NEVER: Skip signature validation
// NEVER: Trust unvalidated request data
// NEVER: Include unrequested elements in response
// NEVER: Store encryption keys insecurely

// ALWAYS: Use cryptographically secure nonces
// ALWAYS: Maintain updated issuer certificate chains
// ALWAYS: Follow ISO 18013-5 validation procedures precisely
// ALWAYS: Implement proper error handling
```

---

## Error Handling

### Common Error Types

```swift
enum IdentityDocumentError: LocalizedError {
    case registrationFailed
    case requestValidationFailed
    case signatureInvalid
    case certificateChainInvalid
    case encryptionFailed
    case documentNotFound
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .registrationFailed:
            return "Failed to register document with iOS"
        case .requestValidationFailed:
            return "The verification request could not be validated"
        case .signatureInvalid:
            return "The request signature is invalid"
        case .certificateChainInvalid:
            return "The certificate chain could not be verified"
        case .encryptionFailed:
            return "Failed to encrypt the response"
        case .documentNotFound:
            return "The requested document was not found"
        case .userCancelled:
            return "Verification was cancelled by the user"
        }
    }
}
```

### Handling Errors in Extension

```swift
func acceptVerification() {
    Task {
        do {
            try await context.sendResponse { rawRequest in
                try await validateConsistency(request: context.request, rawRequest: rawRequest)
                try await validateRawRequest(rawRequest: rawRequest)
                let data = try await buildAndEncryptResponse(rawRequest: rawRequest)
                return ISO18013MobileDocumentResponse(responseData: data)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
```

---

## Testing

### Sandbox Testing

Testing can be done immediately using sandboxed credentials during development:

```swift
// Use test certificates and documents in debug builds
#if DEBUG
let testAuthorities = ["sandbox-authority-key-id"]
#else
let testAuthorities = [] // Production authorities
#endif
```

### Production Requirements

1. **Request Entitlement**: Apply through Apple Developer portal for the managed capability
2. **Certificate Setup**: Obtain certificates from recognized issuers
3. **Compliance**: Ensure regulatory compliance for identity documents in your jurisdiction

---

## Standards Reference

| Standard | Description |
|----------|-------------|
| **ISO/IEC 18013-5** | Mobile document format specification |
| **ISO/IEC 18013-7** | Web request/response protocol (Annex C) |
| **W3C Digital Credentials API** | Browser integration standard |
| **FIDO CTAP** | Cross-platform identity verification protocol |
| **RFC 9180 (HPKE)** | Hybrid public key encryption for responses |

---

## Resources

### Apple Documentation

- [IdentityDocumentServices Framework](https://developer.apple.com/documentation/IdentityDocumentServices)
- [IdentityDocumentServicesUI Framework](https://developer.apple.com/documentation/IdentityDocumentServicesUI)
- [Implementing as an identity document provider](https://developer.apple.com/documentation/IdentityDocumentServices/Implenting-as-an-identity-document-provider)
- [Digital Credentials API Entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.identity-document-services.document-provider.mobile-document-types)

### WWDC Sessions

- [WWDC25: Verify identity documents on the web](https://developer.apple.com/videos/play/wwdc2025/232/)

### Web Standards

- [W3C Digital Credentials API](https://w3c-fedid.github.io/digital-credentials/)
- [WebKit Blog: Online Identity Verification](https://webkit.org/blog/17431/online-identity-verification-with-the-digital-credentials-api/)
- [Chrome Developers: Digital Credentials API](https://developer.chrome.com/blog/digital-credentials-api-shipped)

### Additional Resources

- [Apple Business Connect](https://support.apple.com/guide/apple-business-connect/welcome/web)
- [Apple ID Verifier](https://developer.apple.com/wallet/id-verifier/)

---

## Version History

| iOS Version | Changes |
|-------------|---------|
| iOS 26.0 | Initial release of IdentityDocumentServices and IdentityDocumentServicesUI |
| iOS 26.1 | Digital IDs using U.S. passport require iPhone 11 or later |

---

*Last updated: 2026-06-02. API surface verified against Apple Developer docs (IdentityDocumentServices / IdentityDocumentServicesUI) via Context7.*

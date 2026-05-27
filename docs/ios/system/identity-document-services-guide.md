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
- `IdentityDocumentProviderRegistrationStore` - Manages document registrations with iOS
- `MobileDocumentRegistration` - Represents a registered mobile document
- `IdentityDocumentRegistration` - Protocol defining identity document registration
- `ISO18013MobileDocumentRequestContext` - Context provided during verification requests

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

```swift
import IdentityDocumentServices

// Initialize the registration store
let registrationStore = IdentityDocumentProviderRegistrationStore()

// Create a mobile document registration
let registration = MobileDocumentRegistration(
    mobileDocumentType: "org.iso.18013.5.1.mDL",  // ISO 18013-5 standard type
    documentIdentifier: "unique-document-id-12345"
)

// Specify trusted certificate authorities
// These determine which websites can request this document
registration.authorityKeyIdentifiers = [
    "authority-key-id-from-certificate-1",
    "authority-key-id-from-certificate-2"
]

// Register the document with iOS
do {
    try await registrationStore.addRegistration(registration)
} catch {
    print("Failed to register document: \(error)")
}
```

### Key Methods

| Method | Description |
|--------|-------------|
| `addRegistration(_:)` | Register an mdoc with iOS |
| `removeRegistration(documentIdentifier:)` | Remove a registration when document is deleted |
| `registrations` | Query currently stored registrations |

### Mobile Document Types

Common document types following ISO 18013-5 standard:

| Type | Description |
|------|-------------|
| `org.iso.18013.5.1.mDL` | Mobile Driver's License |
| Custom types | Corporate IDs, government IDs, etc. |

### Authority Key Identifiers

Authority key identifiers restrict which websites can request your documents:

```swift
// Only apps with registrations matching the request's certificate authority
// will appear in the selection UI
registration.authorityKeyIdentifiers = [
    "key-id-from-trusted-ca"  // From the certificate's Authority Key Identifier extension
]
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

```swift
import IdentityDocumentServices
import IdentityDocumentServicesUI
import SwiftUI

struct IdentityDocumentProviderExtension: IdentityDocumentProvider {

    // MARK: - Registration Updates

    /// Called when the system needs updated registrations
    func performRegistrationUpdates() async {
        let registrationStore = IdentityDocumentProviderRegistrationStore()

        // Fetch all documents from your app's storage
        let localDocuments = await fetchDocumentsFromStorage()

        for document in localDocuments {
            let registration = MobileDocumentRegistration(
                mobileDocumentType: document.type,
                documentIdentifier: document.id
            )
            registration.authorityKeyIdentifiers = document.trustedAuthorities

            do {
                try await registrationStore.addRegistration(registration)
            } catch {
                print("Failed to register document \(document.id): \(error)")
            }
        }
    }

    // MARK: - Authorization UI

    @MainActor
    var body: some Scene {
        WindowGroup {
            RequestAuthorizationView(context: requestContext)
        }
    }

    // Context provided by the system
    var requestContext: ISO18013MobileDocumentRequestContext

    private func fetchDocumentsFromStorage() async -> [LocalDocument] {
        // Implementation to fetch from your app's storage
        return []
    }
}

// Helper type for local document storage
struct LocalDocument {
    let id: String
    let type: String
    let trustedAuthorities: [String]
}
```

---

## Request Authorization UI

### ISO18013MobileDocumentRequestContext

The context provided by the system when handling a verification request.

```swift
struct ISO18013MobileDocumentRequestContext {
    /// The partial request (parsed, signature-validated by iOS)
    var request: PartialRequest

    /// Send the encrypted response back to the requesting website
    func sendResponse(_ handler: @escaping (Data) async throws -> Data) async

    /// Cancel the verification request
    func cancel()
}
```

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
            Button("OK") { context.cancel() }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Actions

    private func acceptVerification() {
        Task {
            await context.sendResponse { rawRequest in
                // Receive the full ISO 18013 Device Request

                // Step 1: Validate request consistency
                try validateRequest(rawRequest, against: context.request)

                // Step 2: Validate the request signature
                try validateSignature(in: rawRequest)

                // Step 3: Build and encrypt the response
                let response = try buildAndEncryptResponse(for: rawRequest)

                return response
            }
        }
    }

    private func declineVerification() {
        context.cancel()
    }

    // MARK: - Validation Methods

    private func validateRequest(_ rawRequest: Data, against partialRequest: PartialRequest) throws {
        // Ensure the raw request matches the pre-validated partial request
        // This prevents tampering between initial parsing and final processing
    }

    private func validateSignature(in rawRequest: Data) throws {
        // Validate the cryptographic signature using trusted certificate authorities
        // Follow ISO 18013-5 validation procedures
    }

    private func buildAndEncryptResponse(for rawRequest: Data) throws -> Data {
        // Build the mdoc response with only the requested/approved elements
        // Encrypt using the recipient's public key from the request
        // Follow ISO 18013-7 response format
        return Data()
    }
}

// MARK: - Request Info View

struct RequestInfoView: View {
    let request: PartialRequest

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
9. App extension receives ISO18013MobileDocumentRequestContext
   |
10. App displays authorization UI (RequestAuthorizationView)
    |
11. User approves sharing
    |
12. App receives full Device Request via sendResponse callback
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
// DO: Register documents immediately after provisioning
func onDocumentProvisioned(_ document: Document) async {
    let store = IdentityDocumentProviderRegistrationStore()
    let registration = MobileDocumentRegistration(
        mobileDocumentType: document.type,
        documentIdentifier: document.id
    )
    try await store.addRegistration(registration)
}

// DO: Remove registrations when documents are deleted
func onDocumentDeleted(_ documentId: String) async {
    let store = IdentityDocumentProviderRegistrationStore()
    try await store.removeRegistration(documentIdentifier: documentId)
}

// DO: Implement performRegistrationUpdates for sync
func performRegistrationUpdates() async {
    // Reconcile local storage with system registrations
}
```

### Request Validation

```swift
// ALWAYS: Validate partial request against full request
func validateRequest(_ rawRequest: Data, against partialRequest: PartialRequest) throws {
    // Ensure consistency to prevent tampering
    guard rawRequestMatchesPartial(rawRequest, partialRequest) else {
        throw ValidationError.requestMismatch
    }
}

// ALWAYS: Validate signatures using trusted certificate authorities
func validateSignature(in rawRequest: Data) throws {
    // Follow ISO 18013-5 certificate chain validation
    // Check certificate revocation status
    // Verify signature algorithms are acceptable
}
```

### User Experience

```swift
// DO: Clearly display what information is being requested
RequestInfoView(request: context.request)

// DO: Show the requesting website's identity
Text("Requested by: \(request.websiteOrigin)")

// DO: Allow users to decline
Button("Decline") { context.cancel() }

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
            await context.sendResponse { rawRequest in
                try validateRequest(rawRequest, against: context.request)
                try validateSignature(in: rawRequest)
                return try buildAndEncryptResponse(for: rawRequest)
            }
        } catch {
            // Handle error appropriately
            await MainActor.run {
                showError = true
                errorMessage = error.localizedDescription
            }
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

*Last updated: February 2026*

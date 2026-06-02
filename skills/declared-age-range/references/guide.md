# DeclaredAgeRange Framework Guide for iOS 26

A comprehensive guide to Apple's DeclaredAgeRange API for building age-appropriate experiences in iOS 26+ applications.

---

## Overview

The DeclaredAgeRange framework, introduced in iOS 26, provides a privacy-preserving way for apps to determine a user's age range without collecting exact birthdates. This enables developers to create age-appropriate experiences while complying with child safety regulations like Texas Senate Bill 2420.

### Key Features

- **Privacy-First Design**: Requests age ranges (e.g., 13+, 16+, 18+) instead of exact birthdates
- **System-Level Caching**: Responses are cached to avoid frequent prompts and sync across devices
- **Parental Controls Integration**: Provides access to active parental control settings
- **Regulatory Compliance**: Helps meet requirements for laws like Texas SB 2420

### Availability

| Platform | Minimum Version |
|----------|-----------------|
| iOS | 26.0+ (26.2+ for full features) |
| iPadOS | 26.0+ (26.2+ for full features) |
| macOS | 26.0+ |

> **Note**: Some APIs like `isEligibleForAgeFeatures` and additional `AgeRangeDeclaration` cases require iOS 26.2+.

---

## Setup Requirements

### 1. Enable Capability

1. Open your project in Xcode
2. Select your target
3. Navigate to **Signing & Capabilities**
4. Click **+ Capability**
5. Add **Declared Age Range**

### 2. Entitlement

Your app requires the `com.apple.developer.declared-age-range` entitlement. This is automatically added when you enable the capability.

### 3. Import Framework

```swift
import DeclaredAgeRange
```

---

## Core APIs

### AgeRangeService

The main service for requesting age range information.

```swift
// Singleton access (UIKit/AppKit)
AgeRangeService.shared
```

### AgeRangeResponse

The response enum returned when requesting an age range.

```swift
enum AgeRangeResponse {
    case sharing(AgeRange)    // User shared their age range
    case declinedSharing      // User declined to share
}
```

### AgeRange

Contains the age range information when shared.

| Property | Type | Description |
|----------|------|-------------|
| `lowerBound` | `Int?` | Lower bound of the age range |
| `upperBound` | `Int?` | Upper bound of the age range |
| `activeParentalControls` | `ParentalControlOptions` | Active parental control settings |
| `declarationType` | `AgeRangeDeclaration` | How the age was declared |

### AgeRangeDeclaration

Describes how the age range was determined.

```swift
enum AgeRangeDeclaration {
    // Original cases (iOS 26.0+)
    case selfDeclared           // Teens outside Family Sharing, or adults
    case guardianDeclared       // Children/teens in iCloud Family

    // Additional cases (iOS 26.2+)
    case checkedByOtherMethod
    case guardianCheckedByOtherMethod
    case governmentIDChecked
    case guardianGovernmentIDChecked
    case paymentChecked
    case guardianPaymentChecked
}
```

### ParentalControlOptions

Option set for active parental controls.

```swift
struct ParentalControlOptions: OptionSet {
    static let communicationLimits: ParentalControlOptions
    static let significantAppChangeApprovalRequired: ParentalControlOptions
}
```

### AgeRangeService.Error

Errors that can occur during age range requests.

```swift
enum AgeRangeService.Error {
    case invalidRequest    // Invalid parameters (e.g., age ranges < 2 years)
    case notAvailable      // User not signed in, regional restrictions, or unsupported
}
```

---

## SwiftUI Implementation

SwiftUI provides the `requestAgeRange` environment value for requesting age ranges.

### Basic Example

```swift
import SwiftUI
import DeclaredAgeRange

struct ContentView: View {
    @State private var advancedFeaturesEnabled = false
    @Environment(\.requestAgeRange) private var requestAgeRange

    var body: some View {
        VStack {
            Button("Advanced Features") {
                // Feature action
            }
            .disabled(!advancedFeaturesEnabled)
        }
        .task {
            await checkAgeRange()
        }
    }

    private func checkAgeRange() async {
        do {
            let response = try await requestAgeRange(ageGates: 16)

            switch response {
            case let .sharing(range):
                if let lowerBound = range.lowerBound, lowerBound >= 16 {
                    advancedFeaturesEnabled = true
                }
            case .declinedSharing:
                // Handle declined - consider restricting features
                advancedFeaturesEnabled = false
            }
        } catch AgeRangeService.Error.invalidRequest {
            // Fix request parameters
            print("Invalid age range request")
        } catch AgeRangeService.Error.notAvailable {
            // Guide user to proper device setup
            print("Age range service not available")
        } catch {
            print("Unexpected error: \(error)")
        }
    }
}
```

### Multiple Age Gates

You can specify up to 3 age gates, resulting in 4 distinct age ranges.

```swift
@Environment(\.requestAgeRange) private var requestAgeRange

func checkMultipleAgeGates() async {
    do {
        // Creates ranges: <13, 13-15, 16-17, 18+
        let response = try await requestAgeRange(ageGates: 13, 16, 18)

        switch response {
        case let .sharing(range):
            handleAgeRange(range)
        case .declinedSharing:
            restrictAllFeatures()
        }
    } catch {
        handleError(error)
    }
}

private func handleAgeRange(_ range: AgeRange) {
    guard let lower = range.lowerBound else {
        // Under 13 - most restrictive
        enableChildMode()
        return
    }

    switch lower {
    case 13..<16:
        enableTeenMode()
    case 16..<18:
        enableOlderTeenMode()
    default:
        enableAdultMode()
    }
}
```

### Checking Parental Controls

```swift
func handleAgeRangeWithParentalControls(_ range: AgeRange) {
    // Check for communication limits
    if range.activeParentalControls.contains(.communicationLimits) {
        disableCommunicationFeatures()
    }

    // Check if significant changes need approval
    if range.activeParentalControls.contains(.significantAppChangeApprovalRequired) {
        // Will need to use PermissionKit for significant changes
        markSignificantChangesRequireApproval()
    }

    // Check declaration type
    switch range.declarationType {
    case .guardianDeclared, .guardianGovernmentIDChecked, .guardianPaymentChecked:
        // This is a child/teen in a Family group
        enableFamilyModeFeatures()
    case .selfDeclared, .governmentIDChecked, .paymentChecked:
        // Self-declared (teen outside family or adult)
        enableStandardFeatures()
    default:
        enableStandardFeatures()
    }
}
```

---

## UIKit Implementation

For UIKit apps, use `AgeRangeService.shared` directly.

```swift
import UIKit
import DeclaredAgeRange

class ViewController: UIViewController {

    private var advancedFeaturesEnabled = false

    override func viewDidLoad() {
        super.viewDidLoad()

        Task {
            await checkAgeRange()
        }
    }

    private func checkAgeRange() async {
        do {
            let response = try await AgeRangeService.shared.requestAgeRange(
                ageGates: 16,
                in: self  // Pass the presenting view controller
            )

            await MainActor.run {
                switch response {
                case let .sharing(range):
                    if let lowerBound = range.lowerBound, lowerBound >= 16 {
                        self.advancedFeaturesEnabled = true
                        self.updateUI()
                    }
                case .declinedSharing:
                    self.advancedFeaturesEnabled = false
                    self.updateUI()
                }
            }
        } catch {
            await MainActor.run {
                self.handleError(error)
            }
        }
    }

    private func updateUI() {
        // Update your UI based on advancedFeaturesEnabled
    }

    private func handleError(_ error: Error) {
        // Handle errors appropriately
    }
}
```

---

## iOS 26.2+ Features

### Eligibility Check

Starting with iOS 26.2, you can check if age verification is required for the current user before making a request.

```swift
@available(iOS 26.2, *)
func checkEligibilityAndAge() async {
    do {
        // Check if age checks are required for this user
        let isEligible = try await AgeRangeService.shared.isEligibleForAgeFeatures

        if !isEligible {
            // Age checks not required (e.g., different jurisdiction, grandfathered user)
            enableAllFeatures()
            return
        }

        // Proceed with age verification
        let response = try await requestAgeRange(ageGates: 16)
        handleResponse(response)

    } catch {
        handleError(error)
    }
}
```

### Texas SB 2420 Compliance

For Texas compliance, the API returns age categories as defined by state law:

| Category | Age Range |
|----------|-----------|
| Under 13 | < 13 |
| 13-15 | 13-15 |
| 16-17 | 16-17 |
| Over 18 | 18+ |

```swift
@available(iOS 26.2, *)
func texasCompliantAgeCheck() async {
    do {
        // Use the Texas-defined age gates
        let response = try await requestAgeRange(ageGates: 13, 16, 18)

        switch response {
        case let .sharing(range):
            let category = categorizeForTexas(range)
            applyAgeRestrictions(for: category)
        case .declinedSharing:
            // Texas law may require restricting access
            restrictToMostProtectiveLevel()
        }
    } catch {
        handleError(error)
    }
}

enum TexasAgeCategory {
    case under13
    case teens13to15
    case teens16to17
    case adults18plus
}

func categorizeForTexas(_ range: AgeRange) -> TexasAgeCategory {
    guard let lower = range.lowerBound else {
        return .under13
    }

    switch lower {
    case 13..<16: return .teens13to15
    case 16..<18: return .teens16to17
    default: return .adults18plus
    }
}
```

---

## Related Framework: PermissionKit

PermissionKit works alongside DeclaredAgeRange for enhanced child safety features.

### Significant Change API

When your app has a significant change (like age rating update), use PermissionKit to request parental consent.

```swift
import PermissionKit

// Create a topic for the significant change
let topic = SignificantAppUpdateTopic(/* configuration */)

// Request permission (child sees system dialog, request goes to parent)
try await PermissionQuestion(topic: topic).ask(in: viewController)
```

### Communication Limits

For apps with communication features, PermissionKit helps manage parental approval for new contacts.

```swift
import PermissionKit

// Check if contacts are known/approved
let knownHandles = await CommunicationLimits.current
    .knownHandles(in: conversation.participants)

// For unknown contacts, request permission
if needsPermission {
    var question = PermissionQuestion(handles: unknownHandles)

    // SwiftUI
    CommunicationLimitsButton(question: question) {
        Label("Ask to Chat", systemImage: "message")
    }

    // UIKit
    try await CommunicationLimits.current.ask(question, in: viewController)
}

// Monitor parent responses
for await update in CommunicationLimits.current.updates {
    handlePermissionUpdate(update)
}
```

---

## Testing

### Simulator Limitations

> **Important**: The DeclaredAgeRange API has limited support in the iOS Simulator. For proper testing, use a physical device with sandbox accounts.

### Sandbox Testing

1. Create a sandbox Apple Account in App Store Connect
2. On your test device, go to **Settings > Developer > Sandbox Apple Account**
3. Sign in with your sandbox account
4. Enable Developer settings for age assurance testing

### Developer Settings (iOS 26.2+)

From the Developer section in iOS Settings, you can select test scenarios:
- "Texas user aged 14 without parental consent"
- "Texas user aged 16 with parental consent"
- Other predefined scenarios

### Test Scenarios to Cover

1. **User shares age** - All age brackets
2. **User declines to share** - Handle restricted state
3. **Service not available** - Graceful degradation
4. **Invalid request** - Proper error handling
5. **Parental controls active** - Feature restrictions
6. **Eligibility check** (iOS 26.2+) - Skip checks when not required

---

## Best Practices

### 1. Request Age Early

Request age range early in your app's lifecycle, ideally at first launch or when the user first accesses age-gated content.

```swift
struct ContentView: View {
    @Environment(\.requestAgeRange) private var requestAgeRange

    var body: some View {
        MainView()
            .task {
                await performInitialAgeCheck()
            }
    }
}
```

### 2. Cache Locally (With Expiration)

While the system caches responses, maintain your own cache for offline access with appropriate expiration.

```swift
struct AgeRangeCache {
    var ageCategory: AgeCategory?
    var lastChecked: Date?
    var needsRevalidation: Bool {
        guard let lastChecked else { return true }
        // Revalidate weekly or on significant app changes
        return Date().timeIntervalSince(lastChecked) > 7 * 24 * 60 * 60
    }
}
```

### 3. Handle Declined Gracefully

When users decline to share, default to the most protective experience without being punitive.

```swift
func handleDeclinedSharing() {
    // Enable a safe default experience
    enableRestrictedMode()

    // Optionally explain what features are limited
    showExplanation(
        "Some features require age verification. " +
        "You can update this anytime in Settings."
    )
}
```

### 4. Respect Parental Controls

Always check and respect active parental controls.

```swift
func configureFeatures(for range: AgeRange) {
    if range.activeParentalControls.contains(.communicationLimits) {
        // Disable or restrict communication features
        disableDirectMessaging()
        disableUserGeneratedContent()
    }
}
```

### 5. Version Check for New APIs

Use `@available` for iOS 26.2+ features.

```swift
func performAgeCheck() async {
    if #available(iOS 26.2, *) {
        // Use eligibility check first
        let isEligible = try? await AgeRangeService.shared.isEligibleForAgeFeatures
        if isEligible == false {
            enableAllFeatures()
            return
        }
    }

    // Proceed with standard age range request
    await requestAndHandleAgeRange()
}
```

### 6. Multi-Window Support (iPad/Mac)

For multi-window apps, ensure proper window environment configuration.

```swift
struct MultiWindowView: View {
    @Environment(\.requestAgeRange) private var requestAgeRange

    var body: some View {
        ContentView()
            // Ensure proper window environment
            .handlesExternalEvents(preferring: [], allowing: ["*"])
    }
}
```

---

## Common Errors and Solutions

### Error: `notAvailable`

**Causes:**
- User not signed into iCloud
- Regional restrictions (service not available in user's region)
- Running in Simulator without proper configuration
- Entitlement not properly configured

**Solutions:**
```swift
catch AgeRangeService.Error.notAvailable {
    // Check if running in simulator
    #if targetEnvironment(simulator)
    print("Age Range API not fully supported in Simulator")
    enableTestMode()
    #else
    // Prompt user to sign into iCloud or check device setup
    showICloudSetupPrompt()
    #endif
}
```

### Error: `invalidRequest`

**Causes:**
- More than 3 age gates specified
- Age ranges resulting in less than 2-year spans
- Invalid age values

**Solutions:**
```swift
// Valid: Creates 4 ranges, each at least 2 years
requestAgeRange(ageGates: 13, 16, 18)  // <13, 13-15, 16-17, 18+

// Invalid: Would create 1-year span
requestAgeRange(ageGates: 13, 14, 15)  // Error!
```

### Runtime Crash: Missing Symbol

**Issue:** Apps crash when enumerating all `AgeRangeDeclaration` cases on iOS 26.1 with Xcode 26.2 beta.

**Solution:** Build with the released Xcode 26.2 (build 17C52), not the Release Candidate.

---

## Privacy Considerations

1. **No Exact Ages**: The API only provides age ranges, never exact birthdates
2. **User Control**: Users can manage cached responses in Settings
3. **Cross-Device Sync**: Responses sync via iCloud for consistent experience
4. **Annual Updates**: Age information refreshes yearly (on birthdate anniversary)
5. **Parent Visibility**: Parents can see which apps have requested age information

---

## Limitations

1. **Relies on Declared Age**: Cannot detect false age declarations
2. **Not for High-Assurance**: Not suitable for scenarios requiring identity verification
3. **Requires Apple Account**: User must be signed into iCloud
4. **Regional Availability**: May not be available in all regions
5. **iOS 26.2 for Full Features**: Some APIs only available in iOS 26.2+

---

## References

- [Declared Age Range | Apple Developer Documentation](https://developer.apple.com/documentation/declaredagerange)
- [AgeRangeService | Apple Developer Documentation](https://developer.apple.com/documentation/declaredagerange/agerangeservice)
- [Deliver age-appropriate experiences in your app - WWDC25](https://developer.apple.com/videos/play/wwdc2025/299/)
- [Age Verification in iOS 26 with DeclaredAgeRange API - SwiftOrbit](https://swiftorbit.io/age-verification-in-ios-26-how-to-protect-kids-with-the-declaredagerange-api/)
- [WWDC 2025 - Deliver age-appropriate experiences in your app - DEV Community](https://dev.to/arshtechpro/wwdc-2025-deliver-age-appropriate-experiences-in-your-app-4nc8)
- [PermissionKit | Apple Developer Documentation](https://developer.apple.com/documentation/PermissionKit)
- [Enhance child safety with PermissionKit - WWDC25](https://developer.apple.com/videos/play/wwdc2025/293/)
- [Design safe and age-appropriate experiences - Apple Developer](https://developer.apple.com/kids/)
- [Testing Age Assurance in Sandbox | Apple Developer Documentation](https://developer.apple.com/documentation/storekit/testing-age-assurance-in-sandbox)
- [Next steps for apps distributed in Texas - Apple Developer News](https://developer.apple.com/news/?id=2ezb6jhj)
- [Apple Developer Forums - Declared Age Range](https://developer.apple.com/forums/tags/declared-age-range)

---

*Last updated: February 2026*

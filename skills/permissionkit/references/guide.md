# PermissionKit Framework Guide - iOS 26

## Overview

PermissionKit is Apple's new framework introduced in iOS 26, iPadOS 26, and macOS 26 designed to enhance child safety in communication apps. The framework enables children to request permission from parents or guardians before communicating with unknown contacts, with requests flowing through the Messages app leveraging Family Sharing groups.

**Availability:** iOS 26+, iPadOS 26+, macOS 26+

**Import:** `import PermissionKit`

> **API verification note (Context7, 2026-06-02 — official `/documentation/PermissionKit`):**
> The official docs confirm `CommunicationLimits`, `CommunicationHandle`, `CommunicationTopic`, and that asking experiences are **only available using iMessage**. Two names in earlier drafts of this guide were wrong and are corrected throughout:
> - The topic protocol is **`QuestionTopic`**, not `Topic`.
> - **`PermissionQuestion` is a `class`**, not a `struct`.
> Apple also documents **`PermissionResponse`** (the original question + chosen answer) and **`PermissionChoice`**. The `updates` AsyncSequence element type used in this guide (`CommunicationLimitsUpdate`), the `CommunicationLimits.current` singleton spelling, `knownHandles(in:)`, `CommunicationLimitsButton`, and the `CommunicationAction` cases were **not** surfaced by Context7 at check time — treat those exact spellings as unverified and confirm against Xcode 26 headers before relying on them.

---

## Table of Contents

1. [Core Concepts](#core-concepts)
2. [Prerequisites](#prerequisites)
3. [API Reference](#api-reference)
4. [Communication Permission Flow](#communication-permission-flow)
5. [Significant Change API (Texas Law Compliance)](#significant-change-api-texas-law-compliance)
6. [DeclaredAgeRange API Integration](#declaredagerange-api-integration)
7. [Implementation Examples](#implementation-examples)
8. [Error Handling](#error-handling)
9. [Testing](#testing)
10. [Best Practices](#best-practices)
11. [Related Frameworks](#related-frameworks)

---

## Core Concepts

### What PermissionKit Does

PermissionKit provides a standardized way to:
- Create permission experiences between children and their parents/guardians
- Enable children to request communication approval through Messages
- Allow parents to approve or decline requests inline within Messages
- Provide apps with real-time updates when parents respond

### Key Components

| Component | Purpose |
|-----------|---------|
| `CommunicationLimits` | Singleton for managing communication permissions |
| `CommunicationHandle` | Identifies a communication participant |
| `CommunicationTopic` | Describes the communication request details |
| `PersonInformation` | Contains metadata about a person |
| `PermissionQuestion` | Encapsulates a permission request |
| `CommunicationLimitsButton` | SwiftUI button for triggering permission requests |
| `SignificantAppUpdateTopic` | Topic for requesting consent for significant app changes |

---

## Prerequisites

Before using PermissionKit, ensure these requirements are met:

### System Requirements

1. **Family Sharing:** User must be part of a Family Sharing group
2. **Communication Limits:** Parents must enable Communication Limits for the child in Screen Time settings
3. **Contact Sync:** Contacts must be synced on the child's device
4. **Age Detection:** Your app must have a system to determine if users are children

### Fallback Behavior

When prerequisites are not met, the API returns a default response rather than throwing errors. Your app should handle this gracefully.

```swift
// The API returns default responses when:
// - User is not in a Family Sharing group
// - Communication Limits is not enabled
// - User is not identified as a child
```

---

## API Reference

### CommunicationLimits

The primary singleton for interacting with PermissionKit's communication features.

```swift
// Access the singleton
let limits = CommunicationLimits.current
```

#### Methods

**`knownHandles(in:)`**

Checks which handles in a set are known to the system (contacts, approved users).

```swift
func knownHandles(in handles: Set<CommunicationHandle>) async -> Set<CommunicationHandle>
```

**`ask(_:in:)` (UIKit)**

Presents the permission request flow in UIKit.

```swift
func ask<T: QuestionTopic>(_ question: PermissionQuestion<T>, in viewController: UIViewController) async throws
```

**`ask(_:in:)` (AppKit)**

Presents the permission request flow in AppKit.

```swift
func ask<T: QuestionTopic>(_ question: PermissionQuestion<T>, in window: NSWindow) async throws
```

#### Properties

**`updates`**

An `AsyncSequence` that emits updates when parents respond to permission requests.

```swift
var updates: AsyncStream<CommunicationLimitsUpdate> { get }
```

---

### CommunicationHandle

Identifies a person for communication permission requests.

```swift
struct CommunicationHandle: Hashable, Sendable {
    let value: String
    let kind: Kind

    enum Kind {
        case phoneNumber
        case email
        case custom  // For usernames, handles, etc.
    }
}
```

#### Creating Handles

```swift
// Phone number
let phoneHandle = CommunicationHandle(value: "+1234567890", kind: .phoneNumber)

// Email
let emailHandle = CommunicationHandle(value: "user@example.com", kind: .email)

// Username or custom identifier
let usernameHandle = CommunicationHandle(value: "dragonslayer42", kind: .custom)
```

---

### PersonInformation

Contains metadata about a person to help parents make informed decisions.

```swift
struct PersonInformation {
    let handle: CommunicationHandle
    var nameComponents: PersonNameComponents?
    var avatarImage: CGImage?
}
```

#### Creating Person Information

```swift
// Basic - handle only
let basicPerson = PersonInformation(
    handle: CommunicationHandle(value: "username", kind: .custom)
)

// Full metadata
var nameComponents = PersonNameComponents()
nameComponents.givenName = "John"
nameComponents.familyName = "Doe"

let fullPerson = PersonInformation(
    handle: CommunicationHandle(value: "johndoe", kind: .custom),
    nameComponents: nameComponents,
    avatarImage: profileImage  // CGImage
)
```

---

### CommunicationTopic

Describes the communication request including people and intended actions.

```swift
struct CommunicationTopic {
    var personInformation: [PersonInformation]
    var actions: Set<CommunicationAction>
}
```

#### CommunicationAction

Specifies the type of communication being requested.

```swift
enum CommunicationAction {
    case message    // Text messaging
    case call       // Voice calls
    case video      // Video calls
    // Additional actions may be available
}
```

#### Creating a Communication Topic

```swift
let people = [
    PersonInformation(
        handle: CommunicationHandle(value: "user1", kind: .custom),
        nameComponents: nameComponents1,
        avatarImage: avatar1
    ),
    PersonInformation(
        handle: CommunicationHandle(value: "user2", kind: .custom)
    )
]

var topic = CommunicationTopic(personInformation: people)
topic.actions = [.message, .call]  // Specify allowed communication types
```

---

### PermissionQuestion

Encapsulates a complete permission request.

```swift
// NOTE: PermissionQuestion is a class (confirmed via Context7), generic over QuestionTopic.
class PermissionQuestion<T: QuestionTopic> {
    // Initialize with handles only (minimal)
    init(handles: [CommunicationHandle])

    // Initialize with a full topic (recommended)
    init(communicationTopic: CommunicationTopic)
}
```

#### Creating Questions

```swift
// Minimal - handles only
var simpleQuestion = PermissionQuestion(handles: [
    CommunicationHandle(value: "user1", kind: .custom),
    CommunicationHandle(value: "user2", kind: .custom)
])

// Full topic with metadata (recommended)
var detailedQuestion = PermissionQuestion(communicationTopic: topic)
```

---

### CommunicationLimitsButton (SwiftUI)

A SwiftUI button that triggers the permission request flow.

```swift
struct CommunicationLimitsButton<Question: QuestionTopic, Label: View>: View {
    init(question: PermissionQuestion<Question>, @ViewBuilder label: () -> Label)
}
```

---

### SignificantAppUpdateTopic

Used for requesting parental consent when your app undergoes significant changes (required for Texas law compliance).

```swift
struct SignificantAppUpdateTopic: QuestionTopic {
    // Use this topic type when your app's age rating or functionality significantly changes
}
```

---

## Communication Permission Flow

### Step 1: Determine if User is a Child

Before using PermissionKit, verify the user is a child using your existing age detection system or the DeclaredAgeRange API.

```swift
import DeclaredAgeRange

// Check if age features apply to this user
let isEligible = try await AgeRangeService.shared.isEligibleForAgeFeatures

if isEligible {
    // User may be a child - use PermissionKit
} else {
    // User is an adult - proceed normally
}
```

### Step 2: Filter Content from Unknown Senders

Hide content from people not in the child's known contacts.

```swift
import PermissionKit

func shouldShowContent(for conversation: Conversation) async -> Bool {
    let knownHandles = await CommunicationLimits.current.knownHandles(
        in: Set(conversation.participants)
    )

    return knownHandles.isSuperset(of: conversation.participants)
}
```

### Step 3: Create a Permission Question

When a child wants to communicate with someone new, create a permission question.

```swift
func createPermissionQuestion(for users: [User]) -> PermissionQuestion<CommunicationTopic> {
    let people = users.map { user in
        PersonInformation(
            handle: CommunicationHandle(value: user.username, kind: .custom),
            nameComponents: user.nameComponents,
            avatarImage: user.avatarCGImage
        )
    }

    var topic = CommunicationTopic(personInformation: people)
    topic.actions = [.message]  // Specify intended communication type

    return PermissionQuestion(communicationTopic: topic)
}
```

### Step 4: Present the Permission Request

#### SwiftUI

```swift
import PermissionKit
import SwiftUI

struct ChatView: View {
    let unknownUsers: [User]
    @State private var question: PermissionQuestion<CommunicationTopic>?

    var body: some View {
        VStack {
            if let question = question {
                CommunicationLimitsButton(question: question) {
                    Label("Ask Parent to Chat", systemImage: "paperplane")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .onAppear {
            question = createPermissionQuestion(for: unknownUsers)
        }
    }
}
```

#### UIKit

```swift
import PermissionKit
import UIKit

class ChatViewController: UIViewController {
    func requestPermission(for users: [User]) async {
        let question = createPermissionQuestion(for: users)

        do {
            try await CommunicationLimits.current.ask(question, in: self)
        } catch {
            // Handle error
            print("Permission request failed: \(error)")
        }
    }
}
```

#### AppKit

```swift
import PermissionKit
import AppKit

class ChatWindowController: NSWindowController {
    func requestPermission(for users: [User]) async {
        guard let window = window else { return }
        let question = createPermissionQuestion(for: users)

        do {
            try await CommunicationLimits.current.ask(question, in: window)
        } catch {
            print("Permission request failed: \(error)")
        }
    }
}
```

### Step 5: Handle Parent Responses

Listen for updates when parents approve or decline requests.

```swift
import PermissionKit
import SwiftUI

struct ChatsView: View {
    @State private var showResponseAlert = false
    @State private var lastUpdate: CommunicationLimitsUpdate?

    var body: some View {
        List {
            // Chat list content
        }
        .task {
            await listenForUpdates()
        }
        .alert("Permission Update", isPresented: $showResponseAlert) {
            Button("OK") { }
        } message: {
            Text("Your parent has responded to your request.")
        }
    }

    private func listenForUpdates() async {
        let updates = CommunicationLimits.current.updates

        for await update in updates {
            // Process the update
            lastUpdate = update
            showResponseAlert = true

            // Update your database/UI based on approval status
            await processPermissionUpdate(update)
        }
    }

    private func processPermissionUpdate(_ update: CommunicationLimitsUpdate) async {
        // Refresh known handles
        // Update local database
        // Sync with your servers
    }
}
```

---

## Significant Change API (Texas Law Compliance)

### Overview

Texas Senate Bill 2420 (App Store Accountability Act), effective January 1, 2026, requires parental consent for significant app changes for children and teens. Use `SignificantAppUpdateTopic` to request this consent.

### When to Use

- Your app's age rating changes
- Significant new features are added
- Functionality changes that affect age-appropriateness

### Implementation

```swift
import PermissionKit

func requestConsentForSignificantChange() async throws {
    let topic = SignificantAppUpdateTopic()
    let question = PermissionQuestion(topic: topic)

    // Present consent request
    try await CommunicationLimits.current.ask(question, in: viewController)
}
```

### Detecting Age Rating Changes with StoreKit

```swift
import StoreKit

// Monitor for age rating changes
func checkAgeRatingChange() async {
    let currentRating = await AppStore.ageRatingCode

    if currentRating != previouslySavedRating {
        // Age rating has changed - request parental consent
        try? await requestConsentForSignificantChange()
    }
}
```

### Handling Consent Revocation

Parents can revoke consent at any time. Configure App Store Server Notifications to receive these events.

```swift
// In your server notification handler
func handleConsentRevocation(notification: AppStoreServerNotification) {
    if notification.type == .consentRevoked {
        // Block app access for this user
        // Update your database
    }
}
```

---

## DeclaredAgeRange API Integration

PermissionKit works alongside the DeclaredAgeRange API for age verification.

### Checking Age Eligibility

```swift
import DeclaredAgeRange

func shouldApplyAgeRestrictions() async -> Bool {
    do {
        return try await AgeRangeService.shared.isEligibleForAgeFeatures
    } catch {
        // Default to applying restrictions if check fails
        return true
    }
}
```

### Requesting Age Range

```swift
import DeclaredAgeRange
import SwiftUI

struct AgeGatedView: View {
    @Environment(\.requestAgeRange) private var requestAgeRange
    @State private var isAgeVerified = false

    var body: some View {
        Group {
            if isAgeVerified {
                ContentView()
            } else {
                AgeVerificationView()
            }
        }
        .task {
            await verifyAge()
        }
    }

    private func verifyAge() async {
        do {
            let response = try await requestAgeRange(ageGates: 13, 16, 18)

            switch response {
            case .declinedSharing:
                // User declined - treat as restricted
                isAgeVerified = false

            case .sharing(let range):
                if let lowerBound = range.lowerBound {
                    isAgeVerified = lowerBound >= 18
                }
            }
        } catch {
            isAgeVerified = false
        }
    }
}
```

### Age Declaration Sources

```swift
// Response includes how age was verified
switch response {
case .sharing(let range):
    switch range.source {
    case .guardianDeclared:
        // Age declared by parent/guardian (iCloud Family)
        break
    case .selfDeclared:
        // Age self-reported by user
        break
    }
}
```

---

## Implementation Examples

### Complete SwiftUI Chat App Example

```swift
import PermissionKit
import DeclaredAgeRange
import SwiftUI

@Observable
class ChatViewModel {
    var conversations: [Conversation] = []
    var isChild = false

    func loadConversations() async {
        // Check if user is a child
        isChild = await shouldApplyChildRestrictions()

        // Load and filter conversations
        let allConversations = await fetchConversations()

        if isChild {
            conversations = await filterForChild(allConversations)
        } else {
            conversations = allConversations
        }
    }

    private func shouldApplyChildRestrictions() async -> Bool {
        (try? await AgeRangeService.shared.isEligibleForAgeFeatures) ?? false
    }

    private func filterForChild(_ conversations: [Conversation]) async -> [Conversation] {
        var filtered: [Conversation] = []

        for conversation in conversations {
            let knownHandles = await CommunicationLimits.current.knownHandles(
                in: Set(conversation.participantHandles)
            )

            if knownHandles.isSuperset(of: conversation.participantHandles) {
                filtered.append(conversation)
            } else {
                // Mark as requiring permission
                var restricted = conversation
                restricted.requiresPermission = true
                filtered.append(restricted)
            }
        }

        return filtered
    }
}

struct ChatListView: View {
    @State private var viewModel = ChatViewModel()

    var body: some View {
        NavigationStack {
            List(viewModel.conversations) { conversation in
                if conversation.requiresPermission {
                    RestrictedConversationRow(conversation: conversation)
                } else {
                    ConversationRow(conversation: conversation)
                }
            }
            .navigationTitle("Messages")
            .task {
                await viewModel.loadConversations()
            }
            .task {
                // Listen for permission updates
                for await _ in CommunicationLimits.current.updates {
                    await viewModel.loadConversations()
                }
            }
        }
    }
}

struct RestrictedConversationRow: View {
    let conversation: Conversation

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(conversation.displayName)
                    .font(.headline)
                Text("Ask parent to chat")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            CommunicationLimitsButton(
                question: createQuestion(for: conversation)
            ) {
                Image(systemName: "paperplane.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }

    private func createQuestion(for conversation: Conversation) -> PermissionQuestion<CommunicationTopic> {
        let people = conversation.participants.map { participant in
            PersonInformation(
                handle: CommunicationHandle(value: participant.username, kind: .custom),
                nameComponents: participant.nameComponents,
                avatarImage: participant.avatarCGImage
            )
        }

        var topic = CommunicationTopic(personInformation: people)
        topic.actions = [.message]

        return PermissionQuestion(communicationTopic: topic)
    }
}
```

### UIKit Implementation

```swift
import PermissionKit
import UIKit

class MessagesViewController: UITableViewController {
    private var conversations: [Conversation] = []
    private var updateTask: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()
        startListeningForUpdates()
    }

    deinit {
        updateTask?.cancel()
    }

    private func startListeningForUpdates() {
        updateTask = Task { [weak self] in
            for await _ in CommunicationLimits.current.updates {
                await self?.reloadConversations()
            }
        }
    }

    @MainActor
    private func reloadConversations() async {
        // Reload and refresh UI
        tableView.reloadData()
    }

    func requestPermission(for conversation: Conversation, from cell: UITableViewCell) {
        Task {
            let question = createPermissionQuestion(for: conversation)

            do {
                try await CommunicationLimits.current.ask(question, in: self)
            } catch {
                showError(error)
            }
        }
    }

    private func createPermissionQuestion(
        for conversation: Conversation
    ) -> PermissionQuestion<CommunicationTopic> {
        // ... same as SwiftUI example
    }
}
```

---

## Error Handling

### Common Errors

```swift
do {
    try await CommunicationLimits.current.ask(question, in: viewController)
} catch {
    switch error {
    case let limitsError as CommunicationLimitsError:
        handleLimitsError(limitsError)
    default:
        // Unknown error - show generic message
        showGenericError()
    }
}

func handleLimitsError(_ error: CommunicationLimitsError) {
    // Handle specific error cases
    // Note: Specific error cases may vary - check documentation
}
```

### Known Issues

1. **"User is in a region that does not support this type of ask"**
   - Occurs with SignificantAppUpdateTopic when user's region doesn't require consent
   - Handle gracefully by proceeding without consent in unsupported regions

2. **XPC-related errors**
   - Often caused by Communication Limits not being enabled
   - Ensure Contact sync is enabled on the child's device

3. **Service errors with "Everyone" setting**
   - If Communication Limits is set to "Everyone", API may return errors
   - Recommend users enable stricter limits

---

## Testing

### Sandbox Testing

1. Create sandbox Apple Accounts for testing
2. Set up Family Sharing in sandbox environment
3. Enable Communication Limits for child account
4. Test on physical devices (Simulator has limitations)

### Developer Settings (iOS 26.2+)

Navigate to **Settings > Developer** on test devices to access testing scenarios:

- "Texas user aged 14 without parental consent"
- "Texas user aged 16 with parental consent"
- Other regional/age combinations

### Testing Checklist

- [ ] Test with Communication Limits enabled
- [ ] Test with Communication Limits set to "Everyone" (should handle gracefully)
- [ ] Test with user not in Family Sharing group
- [ ] Test permission request flow end-to-end
- [ ] Test parent approval path
- [ ] Test parent denial path
- [ ] Test background app launch on response
- [ ] Test AsyncSequence updates
- [ ] Verify UI updates after approval

---

## Best Practices

### 1. Provide Maximum Metadata

Include as much information as possible to help parents make informed decisions.

```swift
// GOOD - Full metadata
let person = PersonInformation(
    handle: CommunicationHandle(value: "username", kind: .custom),
    nameComponents: nameComponents,
    avatarImage: avatarImage
)

// AVOID - Minimal metadata
let person = PersonInformation(
    handle: CommunicationHandle(value: "username", kind: .custom)
)
```

### 2. Specify Appropriate Actions

Choose actions that accurately reflect intended communication.

```swift
// Be specific about communication type
topic.actions = [.message]  // If only messaging

// Include all relevant actions
topic.actions = [.message, .call, .video]  // If full communication
```

### 3. Cache Known Handles

Reduce API calls by caching known handle results.

```swift
actor KnownHandlesCache {
    private var cache: [Set<CommunicationHandle>: Set<CommunicationHandle>] = [:]

    func knownHandles(in handles: Set<CommunicationHandle>) async -> Set<CommunicationHandle> {
        if let cached = cache[handles] {
            return cached
        }

        let result = await CommunicationLimits.current.knownHandles(in: handles)
        cache[handles] = result
        return result
    }

    func invalidate() {
        cache.removeAll()
    }
}
```

### 4. Handle Background Updates

Properly manage the AsyncSequence subscription to prevent memory leaks.

```swift
struct ContentView: View {
    @State private var updateTask: Task<Void, Never>?

    var body: some View {
        MainContent()
            .onAppear {
                updateTask = Task {
                    for await update in CommunicationLimits.current.updates {
                        await handleUpdate(update)
                    }
                }
            }
            .onDisappear {
                updateTask?.cancel()
            }
    }
}
```

### 5. Sync with Your Servers

Persist approval status to extend safety across platforms.

```swift
func handleUpdate(_ update: CommunicationLimitsUpdate) async {
    // Update local database
    await localDatabase.updatePermissions(update)

    // Sync to server for web/other platforms
    try? await apiService.syncPermissions(update)
}
```

### 6. Design for Failure

Always have fallback UI for when PermissionKit requirements aren't met.

```swift
func showConversation(_ conversation: Conversation) async {
    let knownHandles = await CommunicationLimits.current.knownHandles(
        in: conversation.participantHandles
    )

    if knownHandles.isEmpty && conversation.participantHandles.isEmpty == false {
        // PermissionKit may not be available - show appropriate UI
        showFallbackUI()
    } else if knownHandles.isSuperset(of: conversation.participantHandles) {
        showFullConversation(conversation)
    } else {
        showRestrictedConversation(conversation)
    }
}
```

---

## Related Frameworks

| Framework | Purpose |
|-----------|---------|
| **DeclaredAgeRange** | Age verification and range detection |
| **Sensitive Content Analysis** | Detect inappropriate content in video calls |
| **Screen Time** | Web usage supervision and app limits |
| **Family Controls** | Custom parental control implementations |
| **StoreKit** | Age rating detection and App Store integration |

---

## Resources

- [Apple Developer Documentation - PermissionKit](https://developer.apple.com/documentation/PermissionKit)
- [WWDC25 - Enhance child safety with PermissionKit](https://developer.apple.com/videos/play/wwdc2025/293/)
- [Apple Developer Documentation - DeclaredAgeRange](https://developer.apple.com/documentation/declaredagerange)
- [Apple Developer Documentation - SignificantAppUpdateTopic](https://developer.apple.com/documentation/PermissionKit/SignificantAppUpdateTopic)
- [Testing Age Assurance in Sandbox](https://developer.apple.com/documentation/storekit/testing-age-assurance-in-sandbox)
- [Next steps for apps distributed in Texas](https://developer.apple.com/news/?id=2ezb6jhj)

---

## Version History

| Date | Changes |
|------|---------|
| iOS 26.0 | Initial PermissionKit release |
| iOS 26.2 | Added SignificantAppUpdateTopic for Texas law compliance |
| iOS 26.2 | Enhanced DeclaredAgeRange API with regional support |

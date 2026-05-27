# Firebase iOS Guide - Authentication & Firestore

Comprehensive guide for Firebase Authentication and Cloud Firestore in iOS/Swift applications.

---

## Overview

**Firebase Authentication** provides backend services for easy sign-in with passwords, federated identity providers (Google, Apple, etc.), and anonymous authentication.

**Cloud Firestore** is a flexible, scalable NoSQL cloud database for storing and syncing data with real-time listeners and offline support.

---

## Installation

### Swift Package Manager

Add Firebase to your project via SPM:

1. In Xcode: **File > Add Package Dependencies**
2. Enter: `https://github.com/firebase/firebase-ios-sdk`
3. Select version: **12.5.0** or later
4. Choose required products:
   - `FirebaseAuth`
   - `FirebaseFirestore`

```swift
// Package.swift dependency (if using manually)
.package(url: "https://github.com/firebase/firebase-ios-sdk", from: "12.5.0")
```

---

## Configuration

### 1. Download Configuration File

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Go to **Project Settings > General**
4. Download `GoogleService-Info.plist`
5. Add it to your Xcode project (ensure it's added to the target)

### 2. Initialize Firebase

```swift
import SwiftUI
import FirebaseCore

@main
struct MyApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

---

## Authentication

### Import

```swift
import FirebaseAuth
```

### Auth Instance

```swift
let auth = Auth.auth()
```

### Email/Password Authentication

#### Sign Up (Create User)

```swift
func signUp(email: String, password: String) async throws -> User {
    let result = try await Auth.auth().createUser(withEmail: email, password: password)
    return result.user
}
```

#### Sign In

```swift
func signIn(email: String, password: String) async throws -> User {
    let result = try await Auth.auth().signIn(withEmail: email, password: password)
    return result.user
}
```

#### Sign Out

```swift
func signOut() throws {
    try Auth.auth().signOut()
}
```

### Anonymous Authentication

```swift
func signInAnonymously() async throws -> User {
    let result = try await Auth.auth().signInAnonymously()
    return result.user
}
```

### Apple Sign-In

```swift
import AuthenticationServices
import CryptoKit

@Observable
class AppleSignInManager: NSObject {
    private var currentNonce: String?

    func signInWithApple() async throws -> User {
        let nonce = randomNonceString()
        currentNonce = nonce

        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let result = try await performAppleSignIn(request: request)
        return result
    }

    private func performAppleSignIn(request: ASAuthorizationAppleIDRequest) async throws -> User {
        return try await withCheckedThrowingContinuation { continuation in
            let controller = ASAuthorizationController(authorizationRequests: [request])
            // Handle delegate callbacks...
        }
    }

    func handleAuthorization(_ authorization: ASAuthorization) async throws -> User {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8),
              let nonce = currentNonce else {
            throw AuthError.invalidCredential
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )

        let result = try await Auth.auth().signIn(with: credential)
        return result.user
    }

    private func randomNonceString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}

enum AuthError: LocalizedError {
    case invalidCredential

    var errorDescription: String? {
        switch self {
        case .invalidCredential: return "Invalid authentication credential"
        }
    }
}
```

### Auth State Management

#### Current User

```swift
// Get current user (nil if not signed in)
let currentUser = Auth.auth().currentUser

// Check if user is signed in
var isSignedIn: Bool {
    Auth.auth().currentUser != nil
}
```

#### Auth State Listener

```swift
@Observable
class AuthManager {
    var user: User?
    var isAuthenticated: Bool { user != nil }

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
        }
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}
```

#### Using with SwiftUI

```swift
@main
struct MyApp: App {
    @State private var authManager = AuthManager()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                MainView()
                    .environment(authManager)
            } else {
                LoginView()
                    .environment(authManager)
            }
        }
    }
}
```

---

## Firestore

### Import

```swift
import FirebaseFirestore
```

### Database Reference

```swift
let db = Firestore.firestore()
```

### Codable Models with @DocumentID

```swift
import FirebaseFirestore

struct UserProfile: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var email: String
    var createdAt: Date
    var isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case createdAt = "created_at"
        case isActive = "is_active"
    }
}
```

**Note:** `@DocumentID` automatically maps the Firestore document ID. It's `nil` before the document is saved and populated after reading from Firestore.

### Add Document (Auto-generated ID)

```swift
func addUser(_ user: UserProfile) async throws -> String {
    let ref = try db.collection("users").addDocument(from: user)
    return ref.documentID
}
```

### Set Document (Custom ID)

```swift
func setUser(_ user: UserProfile, id: String) async throws {
    try db.collection("users").document(id).setData(from: user)
}

// Merge with existing data (don't overwrite)
func updateUserPartial(_ user: UserProfile, id: String) async throws {
    try db.collection("users").document(id).setData(from: user, merge: true)
}
```

### Read Single Document

```swift
func getUser(id: String) async throws -> UserProfile? {
    let document = try await db.collection("users").document(id).getDocument()
    return try document.data(as: UserProfile.self)
}
```

### Read All Documents in Collection

```swift
func getAllUsers() async throws -> [UserProfile] {
    let snapshot = try await db.collection("users").getDocuments()
    return snapshot.documents.compactMap { document in
        try? document.data(as: UserProfile.self)
    }
}
```

### Query Documents

```swift
// Filter by field
func getActiveUsers() async throws -> [UserProfile] {
    let snapshot = try await db.collection("users")
        .whereField("is_active", isEqualTo: true)
        .getDocuments()

    return snapshot.documents.compactMap { try? $0.data(as: UserProfile.self) }
}

// Order and limit
func getRecentUsers(limit: Int) async throws -> [UserProfile] {
    let snapshot = try await db.collection("users")
        .order(by: "created_at", descending: true)
        .limit(to: limit)
        .getDocuments()

    return snapshot.documents.compactMap { try? $0.data(as: UserProfile.self) }
}

// Compound queries
func searchUsers(name: String, isActive: Bool) async throws -> [UserProfile] {
    let snapshot = try await db.collection("users")
        .whereField("name", isEqualTo: name)
        .whereField("is_active", isEqualTo: isActive)
        .getDocuments()

    return snapshot.documents.compactMap { try? $0.data(as: UserProfile.self) }
}
```

### Update Document

```swift
// Update specific fields
func updateUserName(id: String, name: String) async throws {
    try await db.collection("users").document(id).updateData([
        "name": name
    ])
}

// Update multiple fields
func updateUser(id: String, name: String, isActive: Bool) async throws {
    try await db.collection("users").document(id).updateData([
        "name": name,
        "is_active": isActive
    ])
}

// Increment a numeric field
func incrementUserScore(id: String, by amount: Int) async throws {
    try await db.collection("users").document(id).updateData([
        "score": FieldValue.increment(Int64(amount))
    ])
}

// Add to array
func addUserTag(id: String, tag: String) async throws {
    try await db.collection("users").document(id).updateData([
        "tags": FieldValue.arrayUnion([tag])
    ])
}

// Remove from array
func removeUserTag(id: String, tag: String) async throws {
    try await db.collection("users").document(id).updateData([
        "tags": FieldValue.arrayRemove([tag])
    ])
}
```

### Delete Document

```swift
func deleteUser(id: String) async throws {
    try await db.collection("users").document(id).delete()
}
```

### Delete Field

```swift
func removeUserEmail(id: String) async throws {
    try await db.collection("users").document(id).updateData([
        "email": FieldValue.delete()
    ])
}
```

### Real-Time Listeners

#### Listen to Single Document

```swift
@Observable
class UserViewModel {
    var user: UserProfile?
    private var listener: ListenerRegistration?

    func startListening(userId: String) {
        listener = Firestore.firestore()
            .collection("users")
            .document(userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let snapshot, error == nil else {
                    print("Error listening: \(error?.localizedDescription ?? "Unknown")")
                    return
                }
                self?.user = try? snapshot.data(as: UserProfile.self)
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    deinit {
        stopListening()
    }
}
```

#### Listen to Collection/Query

```swift
@Observable
class UsersViewModel {
    var users: [UserProfile] = []
    private var listener: ListenerRegistration?

    func startListening() {
        listener = Firestore.firestore()
            .collection("users")
            .whereField("is_active", isEqualTo: true)
            .order(by: "created_at", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let snapshot, error == nil else {
                    print("Error: \(error?.localizedDescription ?? "Unknown")")
                    return
                }

                self?.users = snapshot.documents.compactMap { document in
                    try? document.data(as: UserProfile.self)
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }
}
```

#### Using Listeners with SwiftUI

```swift
struct UsersListView: View {
    @State private var viewModel = UsersViewModel()

    var body: some View {
        List(viewModel.users) { user in
            Text(user.name)
        }
        .task {
            viewModel.startListening()
        }
        .onDisappear {
            viewModel.stopListening()
        }
    }
}
```

### Batch Writes

Perform multiple operations atomically (all succeed or all fail):

```swift
func batchUpdate(userIds: [String], isActive: Bool) async throws {
    let batch = db.batch()

    for userId in userIds {
        let ref = db.collection("users").document(userId)
        batch.updateData(["is_active": isActive], forDocument: ref)
    }

    try await batch.commit()
}

func batchCreateUsers(_ users: [UserProfile]) async throws {
    let batch = db.batch()

    for user in users {
        let ref = db.collection("users").document()
        try batch.setData(from: user, forDocument: ref)
    }

    try await batch.commit()
}
```

### Transactions

Read-then-write operations with guaranteed consistency:

```swift
func transferCredits(fromUserId: String, toUserId: String, amount: Int) async throws {
    try await db.runTransaction { transaction, errorPointer in
        let fromRef = self.db.collection("users").document(fromUserId)
        let toRef = self.db.collection("users").document(toUserId)

        // Read current values
        guard let fromDoc = try? transaction.getDocument(fromRef),
              let toDoc = try? transaction.getDocument(toRef),
              let fromCredits = fromDoc.data()?["credits"] as? Int,
              let toCredits = toDoc.data()?["credits"] as? Int else {
            let error = NSError(domain: "AppError", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Unable to read user documents"
            ])
            errorPointer?.pointee = error
            return nil
        }

        // Validate
        guard fromCredits >= amount else {
            let error = NSError(domain: "AppError", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Insufficient credits"
            ])
            errorPointer?.pointee = error
            return nil
        }

        // Write updates
        transaction.updateData(["credits": fromCredits - amount], forDocument: fromRef)
        transaction.updateData(["credits": toCredits + amount], forDocument: toRef)

        return nil
    }
}
```

### Offline Support

Firestore automatically caches data for offline use. Configure behavior:

```swift
// Enable offline persistence (enabled by default)
let settings = FirestoreSettings()
settings.cacheSettings = PersistentCacheSettings()
Firestore.firestore().settings = settings

// Or use memory-only cache
let memorySettings = FirestoreSettings()
memorySettings.cacheSettings = MemoryCacheSettings()
Firestore.firestore().settings = memorySettings
```

#### Check Source of Data

```swift
func getUserWithSource(id: String) async throws -> (UserProfile?, Bool) {
    let snapshot = try await db.collection("users").document(id).getDocument()
    let isFromCache = snapshot.metadata.isFromCache
    let user = try? snapshot.data(as: UserProfile.self)
    return (user, isFromCache)
}
```

---

## Best Practices

### 1. Service Layer Pattern

```swift
@Observable
class FirestoreService {
    private let db = Firestore.firestore()

    // MARK: - Users Collection

    func createUser(_ user: UserProfile) async throws -> String {
        let ref = try db.collection("users").addDocument(from: user)
        return ref.documentID
    }

    func getUser(id: String) async throws -> UserProfile? {
        let doc = try await db.collection("users").document(id).getDocument()
        return try doc.data(as: UserProfile.self)
    }

    func updateUser(id: String, data: [String: Any]) async throws {
        try await db.collection("users").document(id).updateData(data)
    }

    func deleteUser(id: String) async throws {
        try await db.collection("users").document(id).delete()
    }
}
```

### 2. Error Handling

```swift
enum FirestoreError: LocalizedError {
    case documentNotFound
    case decodingFailed
    case permissionDenied
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .documentNotFound: return "Document not found"
        case .decodingFailed: return "Failed to decode document"
        case .permissionDenied: return "Permission denied"
        case .unknown(let error): return error.localizedDescription
        }
    }
}

func getUser(id: String) async throws -> UserProfile {
    do {
        let document = try await db.collection("users").document(id).getDocument()

        guard document.exists else {
            throw FirestoreError.documentNotFound
        }

        guard let user = try? document.data(as: UserProfile.self) else {
            throw FirestoreError.decodingFailed
        }

        return user
    } catch let error as NSError {
        if error.domain == FirestoreErrorDomain {
            switch error.code {
            case FirestoreErrorCode.permissionDenied.rawValue:
                throw FirestoreError.permissionDenied
            default:
                throw FirestoreError.unknown(error)
            }
        }
        throw FirestoreError.unknown(error)
    }
}
```

### 3. Manager Pattern with Environment

```swift
@Observable
class UserManager {
    private let auth = Auth.auth()
    private let db = Firestore.firestore()

    var currentUser: User?
    var userProfile: UserProfile?
    var isLoading = false
    var error: Error?

    private var authHandle: AuthStateDidChangeListenerHandle?
    private var profileListener: ListenerRegistration?

    init() {
        setupAuthListener()
    }

    private func setupAuthListener() {
        authHandle = auth.addStateDidChangeListener { [weak self] _, user in
            self?.currentUser = user
            if let userId = user?.uid {
                self?.startProfileListener(userId: userId)
            } else {
                self?.stopProfileListener()
                self?.userProfile = nil
            }
        }
    }

    private func startProfileListener(userId: String) {
        profileListener = db.collection("users").document(userId)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error {
                    self?.error = error
                    return
                }
                self?.userProfile = try? snapshot?.data(as: UserProfile.self)
            }
    }

    private func stopProfileListener() {
        profileListener?.remove()
        profileListener = nil
    }

    func signOut() throws {
        try auth.signOut()
    }

    deinit {
        if let handle = authHandle {
            auth.removeStateDidChangeListener(handle)
        }
        stopProfileListener()
    }
}

// Usage in App
@main
struct MyApp: App {
    @State private var userManager = UserManager()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(userManager)
        }
    }
}
```

### 4. Subcollections

```swift
// User -> Posts subcollection
func addPost(userId: String, post: Post) async throws -> String {
    let ref = try db.collection("users")
        .document(userId)
        .collection("posts")
        .addDocument(from: post)
    return ref.documentID
}

func getUserPosts(userId: String) async throws -> [Post] {
    let snapshot = try await db.collection("users")
        .document(userId)
        .collection("posts")
        .order(by: "created_at", descending: true)
        .getDocuments()

    return snapshot.documents.compactMap { try? $0.data(as: Post.self) }
}
```

### 5. Server Timestamps

```swift
struct Post: Codable {
    @DocumentID var id: String?
    var title: String
    var content: String
    @ServerTimestamp var createdAt: Date?
    @ServerTimestamp var updatedAt: Date?
}

// When creating, createdAt will be set by server
func createPost(_ post: Post) async throws {
    try db.collection("posts").addDocument(from: post)
}
```

---

## Security Rules (Reference)

Basic Firestore security rules for reference:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only read/write their own document
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Posts are readable by all authenticated users, writable only by owner
    match /posts/{postId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && request.resource.data.authorId == request.auth.uid;
      allow update, delete: if request.auth != null && resource.data.authorId == request.auth.uid;
    }
  }
}
```

---

## Common Issues & Solutions

### Issue: `@DocumentID` is nil after adding document

The `@DocumentID` is only populated when reading from Firestore. After `addDocument`, use the returned reference:

```swift
let ref = try db.collection("users").addDocument(from: user)
let documentId = ref.documentID // Use this ID
```

### Issue: Real-time listener not updating

Ensure you're storing the `ListenerRegistration` and not letting it get deallocated:

```swift
// WRONG - listener gets deallocated immediately
func startListening() {
    db.collection("users").addSnapshotListener { ... }
}

// CORRECT - store the registration
private var listener: ListenerRegistration?

func startListening() {
    listener = db.collection("users").addSnapshotListener { ... }
}
```

### Issue: Firestore operations failing silently

Always handle errors properly:

```swift
do {
    try await db.collection("users").document(id).delete()
} catch {
    print("Delete failed: \(error.localizedDescription)")
    throw error
}
```

---

## Quick Reference

| Operation | Code |
|-----------|------|
| Get Firestore | `Firestore.firestore()` |
| Get Auth | `Auth.auth()` |
| Add document | `collection.addDocument(from: object)` |
| Set document | `document.setData(from: object)` |
| Get document | `document.getDocument()` |
| Update fields | `document.updateData([...])` |
| Delete document | `document.delete()` |
| Listen to document | `document.addSnapshotListener { ... }` |
| Listen to query | `query.addSnapshotListener { ... }` |
| Decode to Codable | `document.data(as: Type.self)` |
| Sign in email | `Auth.auth().signIn(withEmail:password:)` |
| Sign out | `Auth.auth().signOut()` |
| Current user | `Auth.auth().currentUser` |

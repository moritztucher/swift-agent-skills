# Contacts & ContactsUI Framework Guide for iOS

A comprehensive guide for working with the Contacts and ContactsUI frameworks in iOS using Swift, SwiftUI, and modern async/await patterns.

---

## Table of Contents

1. [Overview & Purpose](#overview--purpose)
2. [Setup & Permissions](#setup--permissions)
3. [Core Concepts](#core-concepts)
4. [SwiftUI Integration Patterns](#swiftui-integration-patterns)
5. [Fetching Contacts](#fetching-contacts)
6. [Creating and Updating Contacts](#creating-and-updating-contacts)
7. [Contact Picker (CNContactPickerViewController)](#contact-picker-cncontactpickerviewcontroller)
8. [ContactAccessButton (iOS 18+)](#contactaccessbutton-ios-18)
9. [iOS 18/26 Specific Features](#ios-1826-specific-features)
10. [Common Use Cases](#common-use-cases)
11. [Best Practices & Privacy Considerations](#best-practices--privacy-considerations)

---

## Overview & Purpose

The **Contacts framework** provides access to the user's contacts database, allowing you to fetch, create, update, and delete contact information. It replaced the older AddressBook framework starting with iOS 9.

The **ContactsUI framework** provides user interface components for displaying and selecting contacts, including:
- `CNContactPickerViewController` - System contact picker
- `CNContactViewController` - Display/edit individual contacts
- `ContactAccessButton` (iOS 18+) - Inline button for granting contact access

### When to Use Each Framework

| Framework | Use Case |
|-----------|----------|
| **Contacts** | Programmatic access to contact data, CRUD operations, background processing |
| **ContactsUI** | User-facing contact selection, displaying contact details, iOS 18+ limited access UI |

---

## Setup & Permissions

### Info.plist Configuration

Add the following key to your `Info.plist` or in the Info tab of your target settings:

```xml
<key>NSContactsUsageDescription</key>
<string>We need access to your contacts to help you connect with friends.</string>
```

This is **required** before requesting any contact access. The string should clearly explain why your app needs contact access.

### Authorization Status

iOS provides four authorization levels (iOS 18+):

| Status | Description | Access Level |
|--------|-------------|--------------|
| `.notDetermined` | User hasn't made a choice yet | None |
| `.authorized` | Full access granted | Read/write all contacts |
| `.limited` | Partial access granted (iOS 18+) | Read/write selected contacts only |
| `.denied` | Access denied | None |
| `.restricted` | Access restricted (parental controls) | None |

### Checking Authorization Status

```swift
import Contacts

func checkAuthorizationStatus() -> CNAuthorizationStatus {
    return CNContactStore.authorizationStatus(for: .contacts)
}
```

### Requesting Access (async/await)

```swift
import Contacts

@MainActor
@Observable
class ContactManager {
    var authorizationStatus: CNAuthorizationStatus = .notDetermined
    let store = CNContactStore()

    init() {
        updateAuthorizationStatus()
    }

    private func updateAuthorizationStatus() {
        authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
    }

    func requestAccess() async throws -> Bool {
        guard authorizationStatus == .notDetermined else {
            return authorizationStatus == .authorized || authorizationStatus == .limited
        }

        do {
            let granted = try await store.requestAccess(for: .contacts)
            updateAuthorizationStatus()
            return granted
        } catch {
            updateAuthorizationStatus()
            throw error
        }
    }
}
```

---

## Core Concepts

### CNContact

`CNContact` is an **immutable** object representing a single contact. Key characteristics:

- Thread-safe and can be passed between threads
- Contains partial data based on keys fetched
- Use `CNMutableContact` for modifications

```swift
// CNContact is immutable - properties are read-only
let contact: CNContact
let firstName = contact.givenName
let lastName = contact.familyName
let phoneNumbers = contact.phoneNumbers // [CNLabeledValue<CNPhoneNumber>]
```

### CNMutableContact

`CNMutableContact` is the mutable subclass used for creating or modifying contacts:

```swift
let newContact = CNMutableContact()
newContact.givenName = "John"
newContact.familyName = "Doe"
newContact.phoneNumbers = [
    CNLabeledValue(
        label: CNLabelPhoneNumberMobile,
        value: CNPhoneNumber(stringValue: "+1-555-123-4567")
    )
]
```

### CNContactStore

The central object for all contact database operations:

```swift
let store = CNContactStore()

// Fetch contacts
let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keys)

// Save changes
try store.execute(saveRequest)
```

### CNKeyDescriptor

Specifies which contact properties to fetch. This is crucial for performance:

```swift
// Common keys as CNKeyDescriptor
let keys: [CNKeyDescriptor] = [
    CNContactGivenNameKey as CNKeyDescriptor,
    CNContactFamilyNameKey as CNKeyDescriptor,
    CNContactPhoneNumbersKey as CNKeyDescriptor,
    CNContactEmailAddressesKey as CNKeyDescriptor,
    CNContactThumbnailImageDataKey as CNKeyDescriptor
]

// Using helper methods for complex keys
let formatterKeys = CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
let viewControllerKeys = CNContactViewController.descriptorForRequiredKeys()
let comparatorKeys = CNContact.descriptorForAllComparatorKeys()
```

### CNLabeledValue

Wraps multi-value properties (phone numbers, emails, addresses) with labels:

```swift
// Creating labeled values
let homeEmail = CNLabeledValue(
    label: CNLabelHome,
    value: "john@home.com" as NSString
)

let workPhone = CNLabeledValue(
    label: CNLabelWork,
    value: CNPhoneNumber(stringValue: "+1-555-987-6543")
)

// Reading labeled values
for phone in contact.phoneNumbers {
    let label = phone.label ?? "Unknown"
    let number = phone.value.stringValue
    print("\(label): \(number)")
}
```

### Common Labels

| Property | Common Labels |
|----------|---------------|
| Phone | `CNLabelPhoneNumberMobile`, `CNLabelPhoneNumberMain`, `CNLabelWork`, `CNLabelHome` |
| Email | `CNLabelHome`, `CNLabelWork`, `CNLabelOther` |
| Address | `CNLabelHome`, `CNLabelWork` |
| URL | `CNLabelURLAddressHomePage` |

---

## SwiftUI Integration Patterns

### Contact Manager with @Observable

```swift
import SwiftUI
import Contacts

@MainActor
@Observable
class ContactManager {

    // MARK: - Properties

    var contacts: [CNContact] = []
    var authorizationStatus: CNAuthorizationStatus = .notDetermined
    var isLoading = false
    var error: Error?

    private let store = CNContactStore()

    // MARK: - Initialization

    init() {
        updateAuthorizationStatus()
    }

    // MARK: - Authorization

    private func updateAuthorizationStatus() {
        authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
    }

    func requestAccess() async -> Bool {
        guard authorizationStatus == .notDetermined else {
            return authorizationStatus == .authorized || authorizationStatus == .limited
        }

        do {
            let granted = try await store.requestAccess(for: .contacts)
            updateAuthorizationStatus()
            return granted
        } catch {
            self.error = error
            updateAuthorizationStatus()
            return false
        }
    }

    // MARK: - Fetching

    func fetchAllContacts() async {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor,
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
        ]

        let request = CNContactFetchRequest(keysToFetch: keys)
        request.sortOrder = .userDefault

        do {
            var fetchedContacts: [CNContact] = []
            try await Task.detached {
                try self.store.enumerateContacts(with: request) { contact, _ in
                    fetchedContacts.append(contact)
                }
            }.value
            self.contacts = fetchedContacts
        } catch {
            self.error = error
        }
    }

    func searchContacts(matching name: String) async -> [CNContact] {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            return []
        }

        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
        ]

        let predicate = CNContact.predicateForContacts(matchingName: name)

        do {
            return try store.unifiedContacts(matching: predicate, keysToFetch: keys)
        } catch {
            self.error = error
            return []
        }
    }
}
```

### SwiftUI View Integration

```swift
import SwiftUI

struct ContactsView: View {

    @State private var contactManager = ContactManager()
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            Group {
                switch contactManager.authorizationStatus {
                case .notDetermined:
                    requestAccessView
                case .authorized, .limited:
                    contactListView
                case .denied, .restricted:
                    deniedAccessView
                @unknown default:
                    EmptyView()
                }
            }
            .navigationTitle("Contacts")
        }
        .task {
            if contactManager.authorizationStatus == .authorized ||
               contactManager.authorizationStatus == .limited {
                await contactManager.fetchAllContacts()
            }
        }
    }

    private var requestAccessView: some View {
        ContentUnavailableView {
            Label("Contact Access Required", systemImage: "person.crop.circle.badge.questionmark")
        } description: {
            Text("We need access to your contacts to show them here.")
        } actions: {
            Button("Grant Access") {
                Task {
                    let granted = await contactManager.requestAccess()
                    if granted {
                        await contactManager.fetchAllContacts()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var contactListView: some View {
        List(contactManager.contacts, id: \.identifier) { contact in
            ContactRow(contact: contact)
        }
        .searchable(text: $searchText)
        .overlay {
            if contactManager.isLoading {
                ProgressView()
            }
        }
    }

    private var deniedAccessView: some View {
        ContentUnavailableView {
            Label("Access Denied", systemImage: "person.crop.circle.badge.xmark")
        } description: {
            Text("Please enable contact access in Settings to use this feature.")
        } actions: {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
        }
    }
}

struct ContactRow: View {
    let contact: CNContact

    var body: some View {
        HStack {
            if let imageData = contact.thumbnailImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 44, height: 44)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading) {
                Text(CNContactFormatter.string(from: contact, style: .fullName) ?? "No Name")
                    .font(.headline)

                if let phone = contact.phoneNumbers.first?.value.stringValue {
                    Text(phone)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
```

---

## Fetching Contacts

### Using Predicates

```swift
// Fetch by name
let namePredicate = CNContact.predicateForContacts(matchingName: "John")

// Fetch by identifiers
let identifierPredicate = CNContact.predicateForContacts(withIdentifiers: ["ABC123", "DEF456"])

// Fetch by email
let emailPredicate = CNContact.predicateForContacts(matchingEmailAddress: "john@example.com")

// Fetch by phone number
let phonePredicate = CNContact.predicateForContacts(matching: CNPhoneNumber(stringValue: "+1-555-1234"))

// Fetch contacts in a specific container
let containerID = store.defaultContainerIdentifier()
let containerPredicate = CNContact.predicateForContactsInContainer(withIdentifier: containerID)

// Fetch contacts in a group
let groupPredicate = CNContact.predicateForContactsInGroup(withIdentifier: groupID)
```

### Fetching with unifiedContacts

Use this for fetching specific contacts with predicates:

```swift
func fetchContactsByName(_ name: String) async throws -> [CNContact] {
    let keys: [CNKeyDescriptor] = [
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
    ]

    let predicate = CNContact.predicateForContacts(matchingName: name)

    return try await Task.detached {
        try self.store.unifiedContacts(matching: predicate, keysToFetch: keys)
    }.value
}
```

### Enumerating All Contacts

Use this for bulk operations or when you need all contacts:

```swift
func fetchAllContacts() async throws -> [CNContact] {
    let keys: [CNKeyDescriptor] = [
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
        CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
    ]

    let request = CNContactFetchRequest(keysToFetch: keys)
    request.sortOrder = .userDefault

    return try await Task.detached {
        var contacts: [CNContact] = []
        try self.store.enumerateContacts(with: request) { contact, stop in
            contacts.append(contact)
        }
        return contacts
    }.value
}
```

### Fetching by Identifiers

Useful when you receive identifiers from `ContactAccessButton`:

```swift
func fetchContacts(withIdentifiers identifiers: [String]) async throws -> [CNContact] {
    let keys: [CNKeyDescriptor] = [
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
    ]

    let predicate = CNContact.predicateForContacts(withIdentifiers: identifiers)

    return try await Task.detached {
        try self.store.unifiedContacts(matching: predicate, keysToFetch: keys)
    }.value
}
```

### Partial Contacts

When you fetch a contact, you only get the properties specified in `keysToFetch`. Attempting to access unfetched properties throws an exception:

```swift
// This contact was fetched with only name keys
let contact = fetchedContacts.first!

// This works
let name = contact.givenName

// This throws CNContactPropertyNotFetchedExceptionName
let phone = contact.phoneNumbers // Crash if not in keysToFetch!

// Check if a key is available
if contact.isKeyAvailable(CNContactPhoneNumbersKey) {
    let phones = contact.phoneNumbers
}

// Refetch with additional keys if needed
let fullContact = try store.unifiedContact(
    withIdentifier: contact.identifier,
    keysToFetch: [
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor
    ]
)
```

---

## Creating and Updating Contacts

### Creating a New Contact

```swift
func createContact(
    givenName: String,
    familyName: String,
    phoneNumber: String?,
    email: String?
) async throws {
    let newContact = CNMutableContact()
    newContact.givenName = givenName
    newContact.familyName = familyName

    if let phoneNumber {
        newContact.phoneNumbers = [
            CNLabeledValue(
                label: CNLabelPhoneNumberMobile,
                value: CNPhoneNumber(stringValue: phoneNumber)
            )
        ]
    }

    if let email {
        newContact.emailAddresses = [
            CNLabeledValue(
                label: CNLabelHome,
                value: email as NSString
            )
        ]
    }

    let saveRequest = CNSaveRequest()
    saveRequest.add(newContact, toContainerWithIdentifier: nil)

    try await Task.detached {
        try self.store.execute(saveRequest)
    }.value
}
```

### Creating a Complete Contact

```swift
func createCompleteContact() async throws {
    let contact = CNMutableContact()

    // Name
    contact.givenName = "John"
    contact.familyName = "Doe"
    contact.middleName = "Michael"
    contact.namePrefix = "Mr."
    contact.nameSuffix = "Jr."
    contact.nickname = "Johnny"

    // Organization
    contact.organizationName = "Acme Inc."
    contact.jobTitle = "Software Engineer"
    contact.departmentName = "Engineering"

    // Phone numbers
    contact.phoneNumbers = [
        CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: "+1-555-123-4567")),
        CNLabeledValue(label: CNLabelWork, value: CNPhoneNumber(stringValue: "+1-555-987-6543"))
    ]

    // Email addresses
    contact.emailAddresses = [
        CNLabeledValue(label: CNLabelHome, value: "john@home.com" as NSString),
        CNLabeledValue(label: CNLabelWork, value: "john@work.com" as NSString)
    ]

    // Postal addresses
    let homeAddress = CNMutablePostalAddress()
    homeAddress.street = "123 Main St"
    homeAddress.city = "San Francisco"
    homeAddress.state = "CA"
    homeAddress.postalCode = "94102"
    homeAddress.country = "USA"
    contact.postalAddresses = [
        CNLabeledValue(label: CNLabelHome, value: homeAddress)
    ]

    // URLs
    contact.urlAddresses = [
        CNLabeledValue(label: CNLabelURLAddressHomePage, value: "https://johndoe.com" as NSString)
    ]

    // Birthday
    var birthday = DateComponents()
    birthday.month = 6
    birthday.day = 15
    birthday.year = 1990
    contact.birthday = birthday

    // Note
    contact.note = "Met at WWDC 2024"

    // Image
    if let image = UIImage(named: "profile"),
       let imageData = image.jpegData(compressionQuality: 0.9) {
        contact.imageData = imageData
    }

    let saveRequest = CNSaveRequest()
    saveRequest.add(contact, toContainerWithIdentifier: nil)

    try await Task.detached {
        try self.store.execute(saveRequest)
    }.value
}
```

### Updating an Existing Contact

```swift
func updateContact(_ contact: CNContact, newPhoneNumber: String) async throws {
    guard let mutableContact = contact.mutableCopy() as? CNMutableContact else {
        throw ContactError.failedToCreateMutableCopy
    }

    // Add new phone number
    let newPhone = CNLabeledValue(
        label: CNLabelPhoneNumberMobile,
        value: CNPhoneNumber(stringValue: newPhoneNumber)
    )
    mutableContact.phoneNumbers.append(newPhone)

    let saveRequest = CNSaveRequest()
    saveRequest.update(mutableContact)

    try await Task.detached {
        try self.store.execute(saveRequest)
    }.value
}
```

### Deleting a Contact

```swift
func deleteContact(_ contact: CNContact) async throws {
    guard let mutableContact = contact.mutableCopy() as? CNMutableContact else {
        throw ContactError.failedToCreateMutableCopy
    }

    let saveRequest = CNSaveRequest()
    saveRequest.delete(mutableContact)

    try await Task.detached {
        try self.store.execute(saveRequest)
    }.value
}
```

### Observing Contact Store Changes

```swift
@MainActor
@Observable
class ContactManager {
    var contacts: [CNContact] = []
    private let store = CNContactStore()

    init() {
        setupNotifications()
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .CNContactStoreDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchAllContacts()
            }
        }
    }
}
```

---

## Contact Picker (CNContactPickerViewController)

`CNContactPickerViewController` is a system UI that lets users select contacts. **No authorization is required** because the app only receives the selected contact data.

### SwiftUI Wrapper

```swift
import SwiftUI
import ContactsUI

struct ContactPicker: UIViewControllerRepresentable {

    @Binding var isPresented: Bool
    var onSelectContact: (CNContact) -> Void
    var onSelectContacts: (([CNContact]) -> Void)?
    var onSelectProperty: ((CNContactProperty) -> Void)?

    // Configuration
    var displayedPropertyKeys: [String]?
    var predicateForEnablingContact: NSPredicate?
    var predicateForSelectionOfContact: NSPredicate?
    var allowsMultipleSelection: Bool = false

    func makeUIViewController(context: Context) -> UINavigationController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator

        if let keys = displayedPropertyKeys {
            picker.displayedPropertyKeys = keys
        }
        if let predicate = predicateForEnablingContact {
            picker.predicateForEnablingContact = predicate
        }
        if let predicate = predicateForSelectionOfContact {
            picker.predicateForSelectionOfContact = predicate
        }

        // Wrap in navigation controller to fix blank screen issue
        let navigationController = UINavigationController(rootViewController: picker)
        return navigationController
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, CNContactPickerDelegate {
        let parent: ContactPicker

        init(_ parent: ContactPicker) {
            self.parent = parent
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            parent.isPresented = false
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            parent.onSelectContact(contact)
            parent.isPresented = false
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            parent.onSelectContacts?(contacts)
            parent.isPresented = false
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contactProperty: CNContactProperty) {
            parent.onSelectProperty?(contactProperty)
            parent.isPresented = false
        }
    }
}
```

### Using the Contact Picker

```swift
struct ContentView: View {

    @State private var showingContactPicker = false
    @State private var selectedContact: CNContact?

    var body: some View {
        VStack {
            Button("Select Contact") {
                showingContactPicker = true
            }

            if let contact = selectedContact {
                Text("Selected: \(contact.givenName) \(contact.familyName)")
            }
        }
        .sheet(isPresented: $showingContactPicker) {
            ContactPicker(isPresented: $showingContactPicker) { contact in
                selectedContact = contact
            }
            .ignoresSafeArea()
        }
    }
}
```

### Selecting Multiple Contacts

```swift
struct MultiContactPickerView: View {

    @State private var showingPicker = false
    @State private var selectedContacts: [CNContact] = []

    var body: some View {
        VStack {
            Button("Select Contacts") {
                showingPicker = true
            }

            List(selectedContacts, id: \.identifier) { contact in
                Text("\(contact.givenName) \(contact.familyName)")
            }
        }
        .sheet(isPresented: $showingPicker) {
            ContactPicker(
                isPresented: $showingPicker,
                onSelectContact: { _ in },
                onSelectContacts: { contacts in
                    selectedContacts = contacts
                },
                allowsMultipleSelection: true
            )
            .ignoresSafeArea()
        }
    }
}
```

### Selecting a Contact Property (Phone/Email)

```swift
struct PhonePickerView: View {

    @State private var showingPicker = false
    @State private var selectedPhoneNumber: String?

    var body: some View {
        VStack {
            Button("Select Phone Number") {
                showingPicker = true
            }

            if let phone = selectedPhoneNumber {
                Text("Selected: \(phone)")
            }
        }
        .sheet(isPresented: $showingPicker) {
            ContactPicker(
                isPresented: $showingPicker,
                onSelectContact: { _ in },
                onSelectProperty: { property in
                    if let phoneNumber = property.value as? CNPhoneNumber {
                        selectedPhoneNumber = phoneNumber.stringValue
                    }
                },
                displayedPropertyKeys: [CNContactPhoneNumbersKey]
            )
            .ignoresSafeArea()
        }
    }
}
```

---

## ContactAccessButton (iOS 18+)

`ContactAccessButton` is a new SwiftUI component introduced in iOS 18 that provides inline contact access without requiring full authorization. It integrates seamlessly into your app's UI and grants access to individual contacts with a single tap.

### When to Use ContactAccessButton

| Scenario | Recommended API |
|----------|-----------------|
| Inline contact search with incremental access | `ContactAccessButton` |
| Bulk contact management | `contactAccessPicker` |
| One-time contact selection (no persistent access) | `CNContactPickerViewController` |

### Basic Usage

```swift
import SwiftUI
import ContactsUI
import Contacts

struct ContactSearchView: View {

    @State private var searchText = ""
    @State private var authorizationStatus: CNAuthorizationStatus = .notDetermined
    @State private var searchResults: [CNContact] = []

    var body: some View {
        List {
            ForEach(searchResults, id: \.identifier) { contact in
                ContactRow(contact: contact)
            }

            // Show ContactAccessButton for limited or undetermined access
            if authorizationStatus == .limited || authorizationStatus == .notDetermined {
                ContactAccessButton(queryString: searchText) { identifiers in
                    await handleContactSelection(identifiers: identifiers)
                }
            }
        }
        .searchable(text: $searchText)
        .task {
            authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
        }
    }

    private func handleContactSelection(identifiers: [String]) async {
        let contacts = await fetchContacts(withIdentifiers: identifiers)
        // Handle the newly accessible contacts
        searchResults.append(contentsOf: contacts)
    }

    private func fetchContacts(withIdentifiers identifiers: [String]) async -> [CNContact] {
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
        ]

        let predicate = CNContact.predicateForContacts(withIdentifiers: identifiers)

        do {
            return try CNContactStore().unifiedContacts(matching: predicate, keysToFetch: keys)
        } catch {
            return []
        }
    }
}
```

### Customizing ContactAccessButton

```swift
ContactAccessButton(queryString: searchText) { identifiers in
    await handleContactSelection(identifiers: identifiers)
}
.font(.system(weight: .bold))           // Controls text weight
.foregroundStyle(.gray)                  // Primary text color
.tint(.green)                            // Action label color
.contactAccessButtonCaption(.phone)      // Show phone below name
.contactAccessButtonStyle(
    ContactAccessButton.Style(imageWidth: 30)  // Customize photo size
)
```

### Caption Options

```swift
// No caption (default)
.contactAccessButtonCaption(.none)

// Show email address
.contactAccessButtonCaption(.email)

// Show phone number
.contactAccessButtonCaption(.phone)
```

### Important Security Considerations

The `ContactAccessButton` includes built-in security features:

1. **Validated Events Only**: Only responds to genuine user interactions
2. **Legibility Requirements**: Button must be fully visible and have sufficient contrast
3. **Privacy Protection**: Shows contact info before granting access

If the button is obscured, has low contrast, or is improperly sized, it will **not grant access**.

---

## iOS 18/26 Specific Features

### Limited Access Authorization (iOS 18+)

iOS 18 introduced a new authorization level where users can grant access to only a subset of their contacts.

```swift
@MainActor
@Observable
class ContactManager {
    var authorizationStatus: CNAuthorizationStatus = .notDetermined
    let store = CNContactStore()

    var hasLimitedAccess: Bool {
        authorizationStatus == .limited
    }

    var hasFullAccess: Bool {
        authorizationStatus == .authorized
    }

    func updateStatus() {
        authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
    }
}
```

### Contact Access Picker (iOS 18+)

Use the `contactAccessPicker` modifier to let users manage which contacts your app can access:

```swift
struct SettingsView: View {

    @State private var showingAccessPicker = false
    @State private var authorizationStatus: CNAuthorizationStatus = .notDetermined

    var body: some View {
        Form {
            Section("Contact Access") {
                if authorizationStatus == .limited {
                    Button("Manage Contact Access") {
                        showingAccessPicker = true
                    }
                    .contactAccessPicker(isPresented: $showingAccessPicker) { identifiers in
                        // Handle newly granted contact identifiers
                        await handleNewContacts(identifiers: identifiers)
                    }
                }
            }
        }
        .task {
            authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
        }
    }

    private func handleNewContacts(identifiers: [String]) async {
        // Fetch and process newly accessible contacts
    }
}
```

### Authorization Flow in iOS 18+

The authorization flow now has two stages:

1. **First Prompt**: Asks whether to share contacts with the app
2. **Second Prompt**: Offers choice between limited access (select specific contacts) or full access

```swift
func requestAccessWithFlowHandling() async {
    let status = CNContactStore.authorizationStatus(for: .contacts)

    switch status {
    case .notDetermined:
        // Will trigger two-stage prompt in iOS 18+
        let granted = try? await CNContactStore().requestAccess(for: .contacts)
        // After this, status could be .authorized, .limited, or .denied

    case .limited:
        // User granted partial access
        // Use ContactAccessButton or contactAccessPicker for more contacts
        break

    case .authorized:
        // Full access granted
        break

    case .denied, .restricted:
        // No access - direct user to Settings
        break

    @unknown default:
        break
    }
}
```

### Handling Limited vs Full Access

```swift
@MainActor
@Observable
class ContactManager {

    var contacts: [CNContact] = []
    var authorizationStatus: CNAuthorizationStatus = .notDetermined
    let store = CNContactStore()

    func fetchContacts() async {
        switch authorizationStatus {
        case .authorized:
            // Fetch all contacts
            await fetchAllContacts()

        case .limited:
            // Fetch only authorized contacts
            // The store automatically filters to accessible contacts
            await fetchAllContacts()

        case .notDetermined:
            // Request access first
            _ = try? await store.requestAccess(for: .contacts)
            updateStatus()
            await fetchContacts()

        case .denied, .restricted:
            contacts = []

        @unknown default:
            break
        }
    }

    private func fetchAllContacts() async {
        // Implementation fetches only accessible contacts when in limited mode
    }

    func updateStatus() {
        authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
    }
}
```

---

## Common Use Cases

### 1. Share Sheet with Contact Selection

```swift
struct ShareContactView: View {

    @State private var showingPicker = false
    @State private var contactToShare: CNContact?

    var body: some View {
        Button("Share Contact") {
            showingPicker = true
        }
        .sheet(isPresented: $showingPicker) {
            ContactPicker(isPresented: $showingPicker) { contact in
                contactToShare = contact
            }
        }
        .sheet(item: $contactToShare) { contact in
            // Create vCard and share
            ShareSheet(contact: contact)
        }
    }
}
```

### 2. Contact Import from External Source

```swift
func importContact(from externalData: ExternalContactData) async throws {
    let contact = CNMutableContact()
    contact.givenName = externalData.firstName
    contact.familyName = externalData.lastName

    if let phone = externalData.phone {
        contact.phoneNumbers = [
            CNLabeledValue(
                label: CNLabelPhoneNumberMobile,
                value: CNPhoneNumber(stringValue: phone)
            )
        ]
    }

    if let email = externalData.email {
        contact.emailAddresses = [
            CNLabeledValue(
                label: CNLabelHome,
                value: email as NSString
            )
        ]
    }

    let saveRequest = CNSaveRequest()
    saveRequest.add(contact, toContainerWithIdentifier: nil)

    try await Task.detached {
        try self.store.execute(saveRequest)
    }.value
}
```

### 3. Friend Matching with Limited Access

```swift
struct FriendMatchingView: View {

    @State private var authStatus: CNAuthorizationStatus = .notDetermined
    @State private var showingAccessPicker = false
    @State private var matchedFriends: [Friend] = []

    var body: some View {
        VStack {
            if authStatus == .limited {
                Button("Add More Contacts for Matching") {
                    showingAccessPicker = true
                }
                .contactAccessPicker(isPresented: $showingAccessPicker) { identifiers in
                    await matchFriends(from: identifiers)
                }
            }

            List(matchedFriends) { friend in
                FriendRow(friend: friend)
            }
        }
        .task {
            authStatus = CNContactStore.authorizationStatus(for: .contacts)
            await performInitialMatching()
        }
    }

    private func matchFriends(from identifiers: [String]) async {
        // Fetch contacts and match against your user database
    }

    private func performInitialMatching() async {
        // Match currently accessible contacts
    }
}
```

### 4. Contact Suggestions During Search

```swift
struct SearchWithSuggestionsView: View {

    @State private var searchText = ""
    @State private var suggestions: [CNContact] = []
    @State private var authStatus: CNAuthorizationStatus = .notDetermined

    var body: some View {
        NavigationStack {
            List {
                ForEach(suggestions, id: \.identifier) { contact in
                    Button {
                        selectContact(contact)
                    } label: {
                        ContactRow(contact: contact)
                    }
                }

                // Show access button for additional contacts
                if authStatus == .limited || authStatus == .notDetermined {
                    ContactAccessButton(queryString: searchText) { identifiers in
                        await addContactsFromIdentifiers(identifiers)
                    }
                    .font(.body)
                    .foregroundStyle(.primary)
                    .contactAccessButtonCaption(.phone)
                }
            }
            .searchable(text: $searchText)
            .onChange(of: searchText) { _, newValue in
                Task {
                    await searchContacts(query: newValue)
                }
            }
        }
        .task {
            authStatus = CNContactStore.authorizationStatus(for: .contacts)
        }
    }

    private func searchContacts(query: String) async {
        guard !query.isEmpty else {
            suggestions = []
            return
        }

        let store = CNContactStore()
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
        ]

        let predicate = CNContact.predicateForContacts(matchingName: query)

        do {
            suggestions = try store.unifiedContacts(matching: predicate, keysToFetch: keys)
        } catch {
            suggestions = []
        }
    }

    private func selectContact(_ contact: CNContact) {
        // Handle selection
    }

    private func addContactsFromIdentifiers(_ identifiers: [String]) async {
        // Fetch and add to suggestions
    }
}
```

---

## Best Practices & Privacy Considerations

### Privacy Best Practices

1. **Request Permission at the Right Time**
   - Ask when the user initiates a contact-related action
   - Never ask on app launch without context
   - Explain why you need access before requesting

2. **Use Limited Access Appropriately**
   - Design your app to work well with limited access
   - Use `ContactAccessButton` for incremental access
   - Respect user choice to share only specific contacts

3. **Minimize Data Collection**
   - Only fetch the keys you actually need
   - Don't store contact data unnecessarily
   - Consider using contact identifiers instead of copying data

4. **Handle Authorization Changes**
   - Listen for `CNContactStoreDidChange` notifications
   - Re-check authorization status when app becomes active
   - Gracefully handle access being revoked

### Performance Best Practices

1. **Use Appropriate Keys**
   ```swift
   // Bad: Fetching everything
   let allKeys = [CNContactViewController.descriptorForRequiredKeys()]

   // Good: Fetch only what you need
   let minimalKeys: [CNKeyDescriptor] = [
       CNContactGivenNameKey as CNKeyDescriptor,
       CNContactFamilyNameKey as CNKeyDescriptor
   ]
   ```

2. **Run Operations Off Main Thread**
   ```swift
   func fetchContacts() async throws -> [CNContact] {
       try await Task.detached {
           // All CNContactStore operations should be off main thread
           try self.store.unifiedContacts(matching: predicate, keysToFetch: keys)
       }.value
   }
   ```

3. **Use Pagination for Large Contact Lists**
   ```swift
   func fetchContactsBatch(offset: Int, limit: Int) async throws -> [CNContact] {
       // Implement pagination logic for better memory management
   }
   ```

### Code Organization

1. **Separate Contact Manager**
   ```swift
   // Keep all contact operations in a dedicated manager
   @MainActor
   @Observable
   class ContactManager {
       // Authorization
       // Fetching
       // Saving
       // Notifications
   }
   ```

2. **Error Handling**
   ```swift
   enum ContactError: LocalizedError {
       case notAuthorized
       case fetchFailed(Error)
       case saveFailed(Error)
       case failedToCreateMutableCopy

       var errorDescription: String? {
           switch self {
           case .notAuthorized:
               return "Contact access not authorized"
           case .fetchFailed(let error):
               return "Failed to fetch contacts: \(error.localizedDescription)"
           case .saveFailed(let error):
               return "Failed to save contact: \(error.localizedDescription)"
           case .failedToCreateMutableCopy:
               return "Failed to create mutable copy of contact"
           }
       }
   }
   ```

3. **Testing**
   - Create mock `CNContactStore` for unit tests
   - Test authorization state handling
   - Test with both full and limited access scenarios

### UI/UX Guidelines

1. **Provide Clear Feedback**
   - Show loading states during fetch operations
   - Display appropriate empty states
   - Handle errors gracefully with user-friendly messages

2. **Respect System UI**
   - Use system contact picker when appropriate
   - Don't recreate system UI unnecessarily
   - Follow Human Interface Guidelines for contact displays

3. **Accessibility**
   - Ensure contact lists are accessible
   - Provide proper labels for contact images
   - Support Dynamic Type in contact displays

---

## Quick Reference

### Import Statements

```swift
import Contacts        // Core contact functionality
import ContactsUI      // UI components (picker, access button)
```

### Common Keys

```swift
// Name
CNContactGivenNameKey
CNContactFamilyNameKey
CNContactMiddleNameKey
CNContactNamePrefixKey
CNContactNameSuffixKey
CNContactNicknameKey

// Organization
CNContactOrganizationNameKey
CNContactJobTitleKey
CNContactDepartmentNameKey

// Communication
CNContactPhoneNumbersKey
CNContactEmailAddressesKey
CNContactPostalAddressesKey
CNContactUrlAddressesKey

// Media
CNContactThumbnailImageDataKey
CNContactImageDataKey
CNContactImageDataAvailableKey

// Dates
CNContactBirthdayKey
CNContactDatesKey

// Other
CNContactNoteKey
CNContactTypeKey
CNContactIdentifierKey
```

### Authorization Check Pattern

```swift
let status = CNContactStore.authorizationStatus(for: .contacts)

switch status {
case .notDetermined:  // Request access
case .authorized:     // Full access
case .limited:        // Partial access (iOS 18+)
case .denied:         // User denied
case .restricted:     // Parental controls
@unknown default:     // Future cases
}
```

### Preferred APIs

| Task | Recommended API |
|------|-----------------|
| Check authorization | `CNContactStore.authorizationStatus(for:)` |
| Request access | `store.requestAccess(for:)` async |
| Fetch by name | `store.unifiedContacts(matching:keysToFetch:)` |
| Fetch all | `store.enumerateContacts(with:usingBlock:)` |
| Save changes | `store.execute(saveRequest)` |
| Pick contact (no auth needed) | `CNContactPickerViewController` |
| Inline access (iOS 18+) | `ContactAccessButton` |
| Manage access (iOS 18+) | `.contactAccessPicker(isPresented:)` |

---

## References

- [Contacts Framework - Apple Developer Documentation](https://developer.apple.com/documentation/contacts)
- [CNContact - Apple Developer Documentation](https://developer.apple.com/documentation/contacts/cncontact)
- [CNContactStore - Apple Developer Documentation](https://developer.apple.com/documentation/contacts/cncontactstore)
- [ContactAccessButton - Apple Developer Documentation](https://developer.apple.com/documentation/contactsui/contactaccessbutton)
- [Meet the Contact Access Button - WWDC24](https://developer.apple.com/videos/play/wwdc2024/10121/)
- [Accessing the Contact Store - Apple Developer Documentation](https://developer.apple.com/documentation/contacts/accessing-the-contact-store)

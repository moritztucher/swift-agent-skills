# RevenueCat iOS Guide - In-App Purchases & Subscriptions

Comprehensive guide for RevenueCat SDK in iOS/Swift applications for managing in-app purchases, subscriptions, and paywalls.

---

## Overview

**RevenueCat** provides a unified backend and SDK for implementing and managing in-app purchases and subscriptions. It handles:

- StoreKit integration and receipt validation
- Cross-platform subscription management
- Entitlement checking and access control
- Pre-built paywall UI components
- Analytics and customer insights

---

## Installation

### Swift Package Manager

Add RevenueCat to your project via SPM:

1. In Xcode: **File > Add Package Dependencies**
2. Enter: `https://github.com/RevenueCat/purchases-ios-spm`
3. Select the latest version
4. Choose required products:
   - `RevenueCat` - Core SDK (required)
   - `RevenueCatUI` - Pre-built paywall components (optional)

```swift
// Package.swift dependency (if using manually)
.package(url: "https://github.com/RevenueCat/purchases-ios-spm", from: "5.0.0")
```

---

## Configuration

### 1. Get Your API Key

1. Go to [RevenueCat Dashboard](https://app.revenuecat.com)
2. Select your project
3. Go to **API Keys**
4. Copy your **Public SDK Key** (starts with `appl_`)

### 2. Initialize the SDK

```swift
import SwiftUI
import RevenueCat

@main
struct MyApp: App {
    init() {
        // Configure with your public API key
        Purchases.configure(withAPIKey: "appl_your_public_api_key")

        // Enable debug logs in development
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Configure with Custom User ID

```swift
import RevenueCat

@main
struct MyApp: App {
    init() {
        // Configure with a known user ID (e.g., from your auth system)
        Purchases.configure(
            withAPIKey: "appl_your_public_api_key",
            appUserID: "user_12345"
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

---

## User Management

### Anonymous Users

By default, RevenueCat generates an anonymous user ID:

```swift
// Get anonymous ID
let anonymousID = Purchases.shared.anonymousID

// Check if user is anonymous
let isAnonymous = Purchases.shared.isAnonymous
```

### Get Current User ID

```swift
func getCurrentUserID() -> String {
    return Purchases.shared.appUserID
}
```

### Log In (Identify User)

```swift
func login(userID: String) async throws -> CustomerInfo {
    let (customerInfo, created) = try await Purchases.shared.logIn(userID)

    if created {
        print("New user created: \(userID)")
    } else {
        print("Existing user logged in: \(userID)")
    }

    return customerInfo
}
```

### Log Out

```swift
func logout() async throws -> CustomerInfo {
    let customerInfo = try await Purchases.shared.logOut()
    print("Logged out. New anonymous ID: \(customerInfo.originalAppUserId)")
    return customerInfo
}
```

---

## Offerings & Products

### Understanding the Hierarchy

- **Offering**: A collection of packages (e.g., "default", "sale", "experiment_a")
- **Package**: A product with metadata (e.g., "$weekly", "$monthly", "$annual")
- **Product**: The actual StoreKit product with price

### Fetch Current Offering

```swift
func fetchOfferings() async throws -> Offering? {
    let offerings = try await Purchases.shared.offerings()
    return offerings.current
}
```

### Fetch All Available Packages

```swift
func fetchAvailablePackages() async throws -> [Package] {
    let offerings = try await Purchases.shared.offerings()
    return offerings.current?.availablePackages ?? []
}
```

### Fetch Specific Offering

```swift
func fetchOffering(identifier: String) async throws -> Offering? {
    let offerings = try await Purchases.shared.offerings()
    return offerings.offering(identifier: identifier)
}
```

### Fetch Offering by Placement

```swift
func fetchOfferingForPlacement(_ placement: String) async throws -> Offering? {
    let offerings = try await Purchases.shared.offerings()
    return offerings.currentOffering(forPlacement: placement)
}
```

### Display Products Example

```swift
@Observable
class StoreViewModel {
    var packages: [Package] = []
    var isLoading = false
    var error: Error?

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let offerings = try await Purchases.shared.offerings()
            packages = offerings.current?.availablePackages ?? []
        } catch {
            self.error = error
        }
    }
}

struct StoreView: View {
    @State private var viewModel = StoreViewModel()

    var body: some View {
        List(viewModel.packages, id: \.identifier) { package in
            VStack(alignment: .leading) {
                Text(package.storeProduct.localizedTitle)
                    .font(.headline)
                Text(package.storeProduct.localizedDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(package.localizedPriceString)
                    .font(.title2)
                    .bold()
            }
        }
        .task {
            await viewModel.loadProducts()
        }
    }
}
```

---

## Making Purchases

### Purchase a Package

```swift
func purchase(package: Package) async throws -> CustomerInfo {
    let (_, customerInfo, _) = try await Purchases.shared.purchase(package: package)
    return customerInfo
}
```

### Purchase with Error Handling

```swift
func purchasePackage(_ package: Package) async {
    do {
        let (transaction, customerInfo, userCancelled) = try await Purchases.shared.purchase(package: package)

        if userCancelled {
            print("User cancelled the purchase")
            return
        }

        // Check if the purchase unlocked an entitlement
        if customerInfo.entitlements["premium"]?.isActive == true {
            print("Premium unlocked!")
            // Grant access to premium features
        }

    } catch let error as RevenueCat.ErrorCode {
        switch error {
        case .purchaseCancelledError:
            print("Purchase was cancelled")
        case .purchaseNotAllowedError:
            print("Purchases not allowed on this device")
        case .purchaseInvalidError:
            print("Purchase invalid")
        case .productNotAvailableForPurchaseError:
            print("Product not available")
        case .networkError:
            print("Network error")
        default:
            print("Purchase error: \(error.localizedDescription)")
        }
    } catch {
        print("Unexpected error: \(error.localizedDescription)")
    }
}
```

### Purchase a Specific Product

```swift
func purchaseProduct(_ product: StoreProduct) async throws -> CustomerInfo {
    let (_, customerInfo, _) = try await Purchases.shared.purchase(product: product)
    return customerInfo
}
```

---

## Checking Subscription Status

### Get Customer Info

```swift
func getCustomerInfo() async throws -> CustomerInfo {
    return try await Purchases.shared.customerInfo()
}
```

### Check Entitlement

```swift
func checkPremiumAccess() async -> Bool {
    do {
        let customerInfo = try await Purchases.shared.customerInfo()
        return customerInfo.entitlements["premium"]?.isActive == true
    } catch {
        print("Failed to fetch customer info: \(error)")
        return false
    }
}
```

### Check Specific Subscription Details

```swift
func checkSubscriptionDetails() async {
    do {
        let customerInfo = try await Purchases.shared.customerInfo()

        // Check entitlement
        if let premiumEntitlement = customerInfo.entitlements["premium"] {
            print("Is Active: \(premiumEntitlement.isActive)")
            print("Will Renew: \(premiumEntitlement.willRenew)")
            print("Expires: \(premiumEntitlement.expirationDate?.description ?? "Never")")
            print("Product ID: \(premiumEntitlement.productIdentifier)")

            if premiumEntitlement.periodType == .trial {
                print("User is in trial period")
            }
        }

        // Check active subscriptions
        let activeSubscriptions = customerInfo.activeSubscriptions
        print("Active subscriptions: \(activeSubscriptions)")

    } catch {
        print("Error: \(error)")
    }
}
```

### Listen for Customer Info Updates

```swift
@Observable
class SubscriptionManager: PurchasesDelegate {
    var isPremium = false
    var customerInfo: CustomerInfo?

    init() {
        Purchases.shared.delegate = self
        Task {
            await refreshCustomerInfo()
        }
    }

    func refreshCustomerInfo() async {
        do {
            customerInfo = try await Purchases.shared.customerInfo()
            isPremium = customerInfo?.entitlements["premium"]?.isActive == true
        } catch {
            print("Error fetching customer info: \(error)")
        }
    }

    // PurchasesDelegate method
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        self.customerInfo = customerInfo
        self.isPremium = customerInfo.entitlements["premium"]?.isActive == true
    }
}
```

---

## Restore Purchases

```swift
func restorePurchases() async throws -> CustomerInfo {
    let customerInfo = try await Purchases.shared.restorePurchases()

    if customerInfo.entitlements["premium"]?.isActive == true {
        print("Premium restored successfully!")
    } else {
        print("No active subscriptions found")
    }

    return customerInfo
}
```

### Restore with UI Feedback

```swift
@Observable
class RestoreViewModel {
    var isRestoring = false
    var message: String?
    var showAlert = false

    func restore() async {
        isRestoring = true
        defer { isRestoring = false }

        do {
            let customerInfo = try await Purchases.shared.restorePurchases()

            if customerInfo.entitlements.active.isEmpty {
                message = "No previous purchases found"
            } else {
                message = "Purchases restored successfully!"
            }
        } catch {
            message = "Failed to restore: \(error.localizedDescription)"
        }

        showAlert = true
    }
}
```

---

## Paywalls (RevenueCatUI)

### Import RevenueCatUI

```swift
import RevenueCatUI
```

### Present Paywall If Needed

```swift
import SwiftUI
import RevenueCatUI

struct ContentView: View {
    var body: some View {
        VStack {
            Text("Welcome to My App")
        }
        .presentPaywallIfNeeded(requiredEntitlementIdentifier: "premium") { customerInfo in
            // Called when purchase is completed
            print("Purchase completed!")
        }
    }
}
```

### Present Paywall with Custom Logic

```swift
struct ContentView: View {
    var body: some View {
        VStack {
            Text("Welcome")
        }
        .presentPaywallIfNeeded { customerInfo in
            // Return true to show paywall, false to hide
            return customerInfo.entitlements["premium"]?.isActive != true
        } purchaseCompleted: { customerInfo in
            print("Purchase completed!")
        } restoreCompleted: { customerInfo in
            print("Restore completed!")
        }
    }
}
```

### Manual PaywallView

```swift
import SwiftUI
import RevenueCatUI

struct SubscriptionView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        PaywallView()
            .onPurchaseCompleted { customerInfo in
                print("Purchased!")
                dismiss()
            }
            .onRestoreCompleted { customerInfo in
                print("Restored!")
                if customerInfo.entitlements["premium"]?.isActive == true {
                    dismiss()
                }
            }
    }
}
```

### PaywallView with Specific Offering

```swift
struct SubscriptionView: View {
    var body: some View {
        PaywallView(offering: myOffering)
            .onPurchaseCompleted { customerInfo in
                // Handle purchase
            }
    }
}
```

### Footer Paywall (Custom Header)

```swift
import SwiftUI
import RevenueCatUI

struct CustomPaywallView: View {
    var body: some View {
        VStack {
            // Your custom header content
            Image("premium-banner")
                .resizable()
                .aspectRatio(contentMode: .fit)

            Text("Unlock Premium Features")
                .font(.largeTitle)
                .bold()

            Text("Get access to all features")
                .foregroundStyle(.secondary)

            Spacer()
        }
        .paywallFooter()
    }
}
```

### Present Paywall as Sheet

```swift
struct ContentView: View {
    @State private var showPaywall = false

    var body: some View {
        VStack {
            Button("Subscribe") {
                showPaywall = true
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .onPurchaseCompleted { _ in
                    showPaywall = false
                }
        }
    }
}
```

---

## Subscription Manager Pattern

### Complete Manager Implementation

```swift
import RevenueCat
import RevenueCatUI

@Observable
class SubscriptionManager {
    var customerInfo: CustomerInfo?
    var offerings: Offerings?
    var isLoading = false
    var error: Error?

    // MARK: - Computed Properties

    var isPremium: Bool {
        customerInfo?.entitlements["premium"]?.isActive == true
    }

    var currentOffering: Offering? {
        offerings?.current
    }

    var availablePackages: [Package] {
        currentOffering?.availablePackages ?? []
    }

    // MARK: - Initialization

    init() {
        Task {
            await loadData()
        }
    }

    // MARK: - Data Loading

    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let customerInfoTask = Purchases.shared.customerInfo()
            async let offeringsTask = Purchases.shared.offerings()

            customerInfo = try await customerInfoTask
            offerings = try await offeringsTask
        } catch {
            self.error = error
        }
    }

    // MARK: - Purchases

    func purchase(_ package: Package) async throws {
        let (_, info, userCancelled) = try await Purchases.shared.purchase(package: package)

        if !userCancelled {
            customerInfo = info
        }
    }

    func restorePurchases() async throws {
        customerInfo = try await Purchases.shared.restorePurchases()
    }

    // MARK: - User Management

    func login(userID: String) async throws {
        let (info, _) = try await Purchases.shared.logIn(userID)
        customerInfo = info
    }

    func logout() async throws {
        customerInfo = try await Purchases.shared.logOut()
    }
}
```

### Using with SwiftUI Environment

```swift
@main
struct MyApp: App {
    @State private var subscriptionManager = SubscriptionManager()

    init() {
        Purchases.configure(withAPIKey: "appl_your_api_key")
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(subscriptionManager)
        }
    }
}

// In child views
struct SettingsView: View {
    @Environment(SubscriptionManager.self) var subscriptionManager

    var body: some View {
        List {
            Section("Subscription") {
                if subscriptionManager.isPremium {
                    Text("Premium Active")
                } else {
                    Button("Upgrade to Premium") {
                        // Show paywall
                    }
                }
            }
        }
    }
}
```

---

## Error Handling

### RevenueCat Error Codes

```swift
enum PurchaseError: LocalizedError {
    case cancelled
    case notAllowed
    case networkError
    case productNotAvailable
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .cancelled: return "Purchase was cancelled"
        case .notAllowed: return "Purchases are not allowed on this device"
        case .networkError: return "Network error. Please check your connection"
        case .productNotAvailable: return "Product is not available"
        case .unknown(let error): return error.localizedDescription
        }
    }

    static func from(_ error: Error) -> PurchaseError {
        guard let rcError = error as? RevenueCat.ErrorCode else {
            return .unknown(error)
        }

        switch rcError {
        case .purchaseCancelledError:
            return .cancelled
        case .purchaseNotAllowedError:
            return .notAllowed
        case .networkError:
            return .networkError
        case .productNotAvailableForPurchaseError:
            return .productNotAvailable
        default:
            return .unknown(error)
        }
    }
}
```

### Handle Errors in ViewModel

```swift
@Observable
class PurchaseViewModel {
    var error: PurchaseError?
    var showError = false

    func purchase(_ package: Package) async {
        do {
            let (_, customerInfo, userCancelled) = try await Purchases.shared.purchase(package: package)

            if userCancelled {
                // Don't show error for cancellation
                return
            }

            // Handle success
        } catch {
            self.error = PurchaseError.from(error)
            self.showError = true
        }
    }
}
```

---

## Testing

### Sandbox Testing

1. Create a Sandbox tester in App Store Connect
2. Sign out of App Store on device (Settings > App Store)
3. Use sandbox credentials when prompted during purchase
4. Enable debug logs:

```swift
#if DEBUG
Purchases.logLevel = .debug
#endif
```

### StoreKit Configuration File

For local testing without App Store Connect:

1. Create a StoreKit Configuration file in Xcode
2. Add your products matching RevenueCat setup
3. Edit Scheme > Run > Options > StoreKit Configuration

### Useful Debug Info

```swift
func printDebugInfo() async {
    print("App User ID: \(Purchases.shared.appUserID)")
    print("Is Anonymous: \(Purchases.shared.isAnonymous)")

    if let customerInfo = try? await Purchases.shared.customerInfo() {
        print("Active Entitlements: \(customerInfo.entitlements.active.keys)")
        print("Active Subscriptions: \(customerInfo.activeSubscriptions)")
    }
}
```

---

## Best Practices

### 1. Always Check Entitlements, Not Products

```swift
// GOOD - Check entitlement
if customerInfo.entitlements["premium"]?.isActive == true {
    // Grant access
}

// AVOID - Checking specific product
if customerInfo.activeSubscriptions.contains("com.app.monthly") {
    // This breaks if you add new products
}
```

### 2. Handle Offline Scenarios

RevenueCat caches customer info locally:

```swift
// This is often a cached, synchronous call
let customerInfo = try await Purchases.shared.customerInfo()

// Force refresh from server
let customerInfo = try await Purchases.shared.customerInfo(fetchPolicy: .fetchCurrent)
```

### 3. Configure Early

Initialize RevenueCat as early as possible:

```swift
@main
struct MyApp: App {
    init() {
        // Configure BEFORE any views are created
        Purchases.configure(withAPIKey: "appl_key")
    }
}
```

### 4. Use Delegate for Real-Time Updates

```swift
class AppDelegate: NSObject, UIApplicationDelegate, PurchasesDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Purchases.configure(withAPIKey: "appl_key")
        Purchases.shared.delegate = self
        return true
    }

    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        // React to subscription changes (renewals, cancellations, etc.)
    }
}
```

### 5. Graceful Degradation

```swift
@Observable
class FeatureManager {
    var subscriptionManager: SubscriptionManager

    func canAccessFeature(_ feature: Feature) -> Bool {
        switch feature {
        case .basic:
            return true
        case .premium:
            return subscriptionManager.isPremium
        case .experimental:
            // Allow premium users or fallback if offline
            return subscriptionManager.isPremium || isOfflineGracePeriod
        }
    }

    private var isOfflineGracePeriod: Bool {
        // Implement grace period logic for offline users
        return false
    }
}
```

---

## Common Issues & Solutions

### Issue: Paywall not showing products

Ensure offerings are configured in RevenueCat dashboard and products exist in App Store Connect:

```swift
// Debug offerings
let offerings = try await Purchases.shared.offerings()
print("Current offering: \(offerings.current?.identifier ?? "none")")
print("Packages: \(offerings.current?.availablePackages.count ?? 0)")
```

### Issue: Customer info not updating

Force refresh customer info:

```swift
let customerInfo = try await Purchases.shared.customerInfo(fetchPolicy: .fetchCurrent)
```

### Issue: Purchase stuck in pending

Check for pending transactions:

```swift
// RevenueCat handles this automatically, but you can check
let customerInfo = try await Purchases.shared.customerInfo()
print("Non-subscriptions: \(customerInfo.nonSubscriptions)")
```

### Issue: Anonymous to identified user migration

RevenueCat handles this automatically when you call `logIn()`:

```swift
// If anonymous user has purchases, they transfer to the identified user
let (customerInfo, created) = try await Purchases.shared.logIn("user_id")
```

---

## Quick Reference

| Operation | Code |
|-----------|------|
| Configure | `Purchases.configure(withAPIKey:)` |
| Get customer info | `Purchases.shared.customerInfo()` |
| Get offerings | `Purchases.shared.offerings()` |
| Purchase package | `Purchases.shared.purchase(package:)` |
| Restore purchases | `Purchases.shared.restorePurchases()` |
| Log in | `Purchases.shared.logIn(_:)` |
| Log out | `Purchases.shared.logOut()` |
| Check entitlement | `customerInfo.entitlements["id"]?.isActive` |
| Get user ID | `Purchases.shared.appUserID` |
| Present paywall | `.presentPaywallIfNeeded(requiredEntitlementIdentifier:)` |
| PaywallView | `PaywallView()` |

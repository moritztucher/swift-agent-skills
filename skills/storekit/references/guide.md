# StoreKit Framework Guide

A comprehensive guide for implementing in-app purchases and subscriptions using Apple's StoreKit 2 framework in iOS 15+ with SwiftUI.

---

## Table of Contents

1. [Overview](#overview)
2. [Setup](#setup)
3. [Loading Products](#loading-products)
4. [Making Purchases](#making-purchases)
5. [Transaction Management](#transaction-management)
6. [Entitlements](#entitlements)
7. [SwiftUI Views](#swiftui-views)
8. [Subscriptions](#subscriptions)
9. [Restore Purchases](#restore-purchases)
10. [Testing](#testing)
11. [App Store Server](#app-store-server)
12. [Best Practices](#best-practices)

---

## Overview

StoreKit 2 is Apple's modern framework for in-app purchases, featuring:

- Native Swift async/await API
- Automatic transaction verification
- SwiftUI views for merchandising
- Simplified subscription management

### Requirements

- iOS 15.0+, iPadOS 15.0+, macOS 12.0+, tvOS 15.0+, watchOS 8.0+
- SwiftUI Views: iOS 17.0+

### Import

```swift
import StoreKit
```

### Product Types

| Type | Description |
|------|-------------|
| `.consumable` | Can be purchased multiple times (coins, gems) |
| `.nonConsumable` | Purchased once, available forever (premium unlock) |
| `.autoRenewable` | Automatically renews until cancelled |
| `.nonRenewable` | Subscription that doesn't auto-renew |

---

## Setup

### 1. Create StoreKit Configuration File

In Xcode: File → New → File → StoreKit Configuration File

```
Products.storekit
```

### 2. Define Product IDs

In App Store Connect and your configuration file:

```
com.yourapp.premium
com.yourapp.coins.100
com.yourapp.subscription.monthly
com.yourapp.subscription.yearly
```

### 3. Create a Store Manager

```swift
import StoreKit
import Observation

@Observable
class StoreManager {
    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []

    private var transactionListener: Task<Void, Error>?

    // Product IDs
    static let productIDs: Set<String> = [
        "com.yourapp.premium",
        "com.yourapp.coins.100",
        "com.yourapp.subscription.monthly"
    ]

    init() {
        transactionListener = listenForTransactions()

        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    deinit {
        transactionListener?.cancel()
    }
}
```

---

## Loading Products

### Fetch Products from App Store

```swift
extension StoreManager {
    @MainActor
    func loadProducts() async {
        do {
            products = try await Product.products(for: Self.productIDs)

            // Sort by price
            products.sort { $0.price < $1.price }
        } catch {
            print("Failed to load products: \(error)")
        }
    }
}
```

### Product Properties

```swift
let product: Product

// Basic info
product.id                    // "com.yourapp.premium"
product.displayName           // "Premium Upgrade"
product.description           // "Unlock all features"
product.displayPrice          // "$4.99"
product.price                 // Decimal value

// Type
product.type                  // .consumable, .nonConsumable, etc.

// Subscription info (if applicable)
product.subscription?.subscriptionGroupID
product.subscription?.subscriptionPeriod
product.subscription?.introductoryOffer
```

### Filter Products by Type

```swift
var consumables: [Product] {
    products.filter { $0.type == .consumable }
}

var nonConsumables: [Product] {
    products.filter { $0.type == .nonConsumable }
}

var subscriptions: [Product] {
    products.filter { $0.type == .autoRenewable }
}
```

---

## Making Purchases

### Purchase a Product

```swift
extension StoreManager {
    @MainActor
    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)

            // Deliver content
            await updatePurchasedProducts()

            // Finish transaction
            await transaction.finish()

            return transaction

        case .userCancelled:
            return nil

        case .pending:
            // Transaction pending (e.g., Ask to Buy)
            return nil

        @unknown default:
            return nil
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified(_, let error):
            throw error
        }
    }
}
```

### Purchase with Options

```swift
func purchase(_ product: Product, quantity: Int = 1) async throws -> Transaction? {
    var options: Set<Product.PurchaseOption> = []

    // For consumables - specify quantity
    if product.type == .consumable {
        options.insert(.quantity(quantity))
    }

    // App Account Token for user identification
    if let appAccountToken = UUID(uuidString: userID) {
        options.insert(.appAccountToken(appAccountToken))
    }

    let result = try await product.purchase(options: options)
    // Handle result...
}
```

### Purchase Result States

```swift
switch result {
case .success(let verification):
    // Transaction completed - verify and deliver

case .userCancelled:
    // User cancelled the purchase

case .pending:
    // Waiting for approval (Ask to Buy, SCA, etc.)

@unknown default:
    break
}
```

---

## Transaction Management

### Listen for Transactions

```swift
extension StoreManager {
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)

                    // Deliver content
                    await self.updatePurchasedProducts()

                    // Finish transaction
                    await transaction.finish()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }
}
```

### Transaction Properties

```swift
let transaction: Transaction

// Identifiers
transaction.id                      // Unique transaction ID
transaction.originalID              // Original transaction (for renewals)
transaction.productID               // Product identifier
transaction.appBundleID             // Your app's bundle ID

// Purchase info
transaction.purchaseDate            // When purchased
transaction.originalPurchaseDate    // Original purchase date
transaction.expirationDate          // Subscription expiration (if applicable)

// Type and state
transaction.productType             // Product type
transaction.isUpgraded              // Was upgraded to another subscription
transaction.revocationDate          // If refunded/revoked
transaction.revocationReason        // Why revoked

// Ownership
transaction.ownershipType           // .purchased or .familyShared
```

### Finish Transactions

Always finish transactions after delivering content:

```swift
await transaction.finish()
```

---

## Entitlements

### Check Current Entitlements

```swift
extension StoreManager {
    @MainActor
    func updatePurchasedProducts() async {
        var purchased: Set<String> = []

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                // Skip revoked transactions
                if transaction.revocationDate == nil {
                    purchased.insert(transaction.productID)
                }
            }
        }

        purchasedProductIDs = purchased
    }

    func isPurchased(_ productID: String) -> Bool {
        purchasedProductIDs.contains(productID)
    }

    var isPremium: Bool {
        isPurchased("com.yourapp.premium") ||
        isPurchased("com.yourapp.subscription.monthly") ||
        isPurchased("com.yourapp.subscription.yearly")
    }
}
```

### What currentEntitlements Includes

- Non-consumable purchases
- Active auto-renewable subscriptions (including grace period)
- Non-renewing subscriptions (even expired)

### What currentEntitlements Excludes

- Consumables (use `Transaction.unfinished` instead)
- Refunded/revoked purchases

---

## SwiftUI Views

### ProductView (iOS 17+)

Display a single product:

```swift
import StoreKit
import SwiftUI

struct SingleProductView: View {
    var body: some View {
        ProductView(id: "com.yourapp.premium") {
            // Custom icon
            Image(systemName: "star.fill")
                .font(.largeTitle)
        }
        .productViewStyle(.large)
    }
}
```

### ProductView Styles

```swift
ProductView(id: productID)
    .productViewStyle(.compact)    // Minimal
    .productViewStyle(.regular)    // Default
    .productViewStyle(.large)      // Detailed
```

### StoreView (iOS 17+)

Display multiple products:

```swift
struct MyStoreView: View {
    let productIDs = [
        "com.yourapp.premium",
        "com.yourapp.coins.100",
        "com.yourapp.coins.500"
    ]

    var body: some View {
        StoreView(ids: productIDs) { product in
            // Custom product icon
            ProductIcon(product: product)
        }
        .storeButton(.visible, for: .restorePurchases)
        .storeButton(.hidden, for: .cancellation)
    }
}
```

### SubscriptionStoreView (iOS 17+)

Display subscription options:

```swift
struct SubscriptionView: View {
    let groupID = "your_subscription_group_id"

    var body: some View {
        SubscriptionStoreView(groupID: groupID) {
            // Marketing content
            VStack {
                Image("premium_banner")
                    .resizable()
                    .aspectRatio(contentMode: .fit)

                Text("Unlock Premium Features")
                    .font(.title)

                FeatureList()
            }
        }
        .subscriptionStoreButtonLabel(.multiline)
        .subscriptionStorePickerItemBackground(.thinMaterial)
        .storeButton(.visible, for: .restorePurchases)
    }
}
```

### SubscriptionStoreView with Product IDs

```swift
SubscriptionStoreView(productIDs: [
    "com.yourapp.subscription.monthly",
    "com.yourapp.subscription.yearly"
])
```

### Customizing Store Buttons

```swift
StoreView(ids: productIDs)
    .storeButton(.visible, for: .restorePurchases)
    .storeButton(.hidden, for: .cancellation)
    .storeButton(.visible, for: .redeemCode)
```

---

## Subscriptions

### Subscription Info

```swift
if let subscription = product.subscription {
    // Subscription period
    let period = subscription.subscriptionPeriod
    print("Duration: \(period.value) \(period.unit)")  // "1 month"

    // Introductory offer
    if let intro = subscription.introductoryOffer {
        print("Intro: \(intro.displayPrice) for \(intro.period.value) \(intro.period.unit)")
    }

    // Promotional offers
    for offer in subscription.promotionalOffers {
        print("Promo: \(offer.id) - \(offer.displayPrice)")
    }
}
```

### Subscription Status

```swift
extension StoreManager {
    func subscriptionStatus(for groupID: String) async -> Product.SubscriptionInfo.Status? {
        guard let statuses = try? await Product.SubscriptionInfo.status(for: groupID) else {
            return nil
        }

        // Find active subscription
        for status in statuses {
            if case .verified(let renewalInfo) = status.renewalInfo,
               case .verified(let transaction) = status.transaction {

                // Check if still active
                if transaction.revocationDate == nil,
                   renewalInfo.currentProductID != nil {
                    return status
                }
            }
        }

        return nil
    }

    var isSubscriptionActive: Bool {
        get async {
            let status = await subscriptionStatus(for: "your_group_id")
            return status != nil
        }
    }
}
```

### Subscription Renewal State

```swift
if case .verified(let renewalInfo) = status.renewalInfo {
    switch renewalInfo.state {
    case .subscribed:
        print("Active subscription")
    case .expired:
        print("Subscription expired")
    case .inBillingRetryPeriod:
        print("Payment failed, retrying")
    case .inGracePeriod:
        print("In grace period")
    case .revoked:
        print("Subscription revoked")
    default:
        break
    }

    // Will auto-renew?
    print("Will renew: \(renewalInfo.willAutoRenew)")

    // Expiration reason
    if let reason = renewalInfo.expirationReason {
        switch reason {
        case .autoRenewDisabled:
            print("User cancelled")
        case .billingError:
            print("Payment failed")
        case .didNotConsentToPriceIncrease:
            print("Price increase declined")
        case .productUnavailable:
            print("Product no longer available")
        default:
            break
        }
    }
}
```

### Manage Subscriptions

```swift
// Open subscription management
try await AppStore.showManageSubscriptions(in: windowScene)

// Or in SwiftUI
.manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
```

---

## Restore Purchases

### Restore with StoreKit 2

StoreKit 2 automatically syncs purchases. Use `currentEntitlements`:

```swift
@MainActor
func restorePurchases() async {
    // Refresh entitlements from App Store
    await updatePurchasedProducts()

    if purchasedProductIDs.isEmpty {
        // No purchases to restore
        print("No purchases found")
    } else {
        print("Restored: \(purchasedProductIDs)")
    }
}
```

### Sync with App Store

Force sync with App Store servers:

```swift
try await AppStore.sync()
```

### StoreView Restore Button

```swift
StoreView(ids: productIDs)
    .storeButton(.visible, for: .restorePurchases)
```

---

## Testing

### StoreKit Configuration File

1. Create `Products.storekit` in Xcode
2. Add your products with matching IDs
3. Select scheme → Edit Scheme → Run → Options → StoreKit Configuration

### StoreKit Testing in Xcode

```swift
import StoreKitTest

class PurchaseTests: XCTestCase {
    var session: SKTestSession!

    override func setUp() async throws {
        session = try SKTestSession(configurationFileNamed: "Products")
        session.disableDialogs = true
        session.clearTransactions()
    }

    func testPurchase() async throws {
        // Simulate purchase
        let products = try await Product.products(for: ["com.yourapp.premium"])
        let product = products.first!

        let result = try await product.purchase()

        if case .success(let verification) = result {
            let transaction = try verification.payloadValue
            XCTAssertEqual(transaction.productID, "com.yourapp.premium")
            await transaction.finish()
        }
    }
}
```

### Subscription Time Rate

```swift
// Speed up subscription renewals for testing
session.timeRate = .oneRenewalEveryMinute

// Available rates:
// .realTime (default)
// .oneRenewalEveryFifteenMinutes
// .oneRenewalEveryFiveMinutes
// .oneRenewalEveryMinute
// .oneRenewalEveryThirtySeconds
// .oneRenewalEveryTenSeconds
// .oneRenewalEveryTwoSeconds
```

### Test Scenarios

```swift
// Simulate ask to buy
session.askToBuyEnabled = true

// Simulate failed transaction
try session.failTransactionsEnabled = true

// Force subscription renewal
try session.forceRenewalOfSubscription(productIdentifier: "com.yourapp.subscription.monthly")

// Expire subscription
try session.expireSubscription(productIdentifier: "com.yourapp.subscription.monthly")
```

### Sandbox Testing

For TestFlight and sandbox:

1. Create sandbox tester in App Store Connect
2. Sign out of App Store on device
3. Make purchase (will prompt for sandbox account)

---

## App Store Server

### Request App Store Signed Data

```swift
// Get signed transaction
if let transaction = await Transaction.latest(for: productID) {
    let jwsRepresentation = transaction.jwsRepresentation
    // Send to your server for verification
}
```

### App Store Server API

For server-side verification and notifications:

- Transaction history
- Subscription status
- Refund lookup
- Consumption info

---

## Best Practices

### 1. Start Transaction Listener Early

```swift
@main
struct MyApp: App {
    @State private var store = StoreManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
```

### 2. Always Finish Transactions

```swift
// After delivering content
await transaction.finish()

// Handle unfinished transactions on launch
for await result in Transaction.unfinished {
    if case .verified(let transaction) = result {
        // Deliver content if not already delivered
        await transaction.finish()
    }
}
```

### 3. Handle All Purchase States

```swift
func purchase(_ product: Product) async {
    do {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            // Deliver content
        case .userCancelled:
            // User cancelled - don't show error
        case .pending:
            // Show "pending approval" message
        @unknown default:
            break
        }
    } catch StoreKitError.userCancelled {
        // Another way user cancelled
    } catch {
        // Show error to user
    }
}
```

### 4. Cache Product Info

```swift
@Observable
class StoreManager {
    private(set) var products: [Product] = []
    private var lastFetchDate: Date?

    func loadProducts() async {
        // Only fetch if cache is stale (e.g., > 1 hour)
        if let lastFetch = lastFetchDate,
           Date().timeIntervalSince(lastFetch) < 3600 {
            return
        }

        // Fetch products...
        lastFetchDate = Date()
    }
}
```

### 5. Show Loading States

```swift
struct PurchaseButton: View {
    let product: Product
    @State private var isPurchasing = false
    @Environment(StoreManager.self) private var store

    var body: some View {
        Button {
            Task {
                isPurchasing = true
                defer { isPurchasing = false }
                try? await store.purchase(product)
            }
        } label: {
            if isPurchasing {
                ProgressView()
            } else {
                Text("Buy \(product.displayPrice)")
            }
        }
        .disabled(isPurchasing)
    }
}
```

### 6. Graceful Degradation

```swift
var body: some View {
    if #available(iOS 17, *) {
        // Use StoreKit views
        StoreView(ids: productIDs)
    } else {
        // Fallback to custom UI
        LegacyStoreView(products: products)
    }
}
```

---

## Quick Reference

### Key Types

| Type | Purpose |
|------|---------|
| `Product` | Represents an in-app purchase product |
| `Transaction` | Represents a completed purchase |
| `Product.SubscriptionInfo` | Subscription details |
| `VerificationResult` | Verification status |

### Key Methods

```swift
// Load products
let products = try await Product.products(for: productIDs)

// Purchase
let result = try await product.purchase()

// Current entitlements
for await result in Transaction.currentEntitlements { }

// Transaction updates
for await result in Transaction.updates { }

// Finish transaction
await transaction.finish()

// Sync with App Store
try await AppStore.sync()
```

### SwiftUI Views (iOS 17+)

| View | Purpose |
|------|---------|
| `ProductView` | Single product display |
| `StoreView` | Multiple products |
| `SubscriptionStoreView` | Subscription merchandising |

### Modifiers

```swift
.productViewStyle(.large)
.storeButton(.visible, for: .restorePurchases)
.subscriptionStoreButtonLabel(.multiline)
.subscriptionStorePickerItemBackground(.thinMaterial)
```

---

## Resources

- [StoreKit | Apple Developer Documentation](https://developer.apple.com/documentation/storekit)
- [In-App Purchase | Apple Developer](https://developer.apple.com/in-app-purchase/)
- [Meet StoreKit 2 - WWDC21](https://developer.apple.com/videos/play/wwdc2021/10114/)
- [What's new in StoreKit and In-App Purchase - WWDC23](https://developer.apple.com/videos/play/wwdc2023/10013/)

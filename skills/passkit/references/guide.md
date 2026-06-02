# PassKit Framework Guide for iOS Development

A comprehensive guide to integrating Apple Pay and Wallet functionality using PassKit in iOS applications with Swift and SwiftUI.

---

## Table of Contents

1. [Overview & Purpose](#overview--purpose)
2. [Setup & Configuration](#setup--configuration)
3. [Apple Pay Integration](#apple-pay-integration)
4. [SwiftUI PayWithApplePayButton](#swiftui-paywithapplepaybuttom)
5. [Payment Request Configuration](#payment-request-configuration)
6. [Handling Payment Authorization](#handling-payment-authorization)
7. [Wallet Passes](#wallet-passes)
8. [Adding Passes to Wallet](#adding-passes-to-wallet)
9. [iOS 18/26 Specific Features](#ios-1826-specific-features)
10. [Common Use Cases](#common-use-cases)
11. [Best Practices & Security](#best-practices--security)

---

## Overview & Purpose

PassKit is Apple's framework for integrating Apple Pay payments and Wallet passes into iOS applications. It provides two main functionalities:

### Apple Pay
- Secure payment processing for in-app purchases
- Support for real-world goods, services, and donations
- Tokenized payment data for enhanced security
- Integration with payment processors

### Wallet Integration
- Create and distribute passes (boarding passes, tickets, loyalty cards, coupons)
- Manage passes in the user's Wallet app
- Time and location-based pass relevance
- Push notification updates for passes

### Key Classes

| Class | Purpose |
|-------|---------|
| `PKPaymentRequest` | Defines payment request parameters |
| `PKPaymentAuthorizationController` | Presents the Apple Pay payment sheet |
| `PKPayment` | Contains authorized payment data |
| `PKPass` | Represents a single Wallet pass |
| `PKPassLibrary` | Manages the user's pass collection |
| `PKPaymentButton` | Standard Apple Pay button (UIKit) |
| `PayWithApplePayButton` | Standard Apple Pay button (SwiftUI) |
| `AddPassToWalletButton` | Add to Wallet button (SwiftUI) |

---

## Setup & Configuration

### Step 1: Create Merchant ID in Apple Developer Portal

1. Navigate to [Apple Developer Portal](https://developer.apple.com/account)
2. Go to **Certificates, Identifiers & Profiles**
3. Select **Identifiers** > **Merchant IDs**
4. Click the **+** button to create a new Merchant ID
5. Enter a description and identifier (e.g., `merchant.com.yourcompany.appname`)
6. Register the Merchant ID

### Step 2: Create Payment Processing Certificate

1. Select your newly created Merchant ID
2. Under **Apple Pay Payment Processing Certificate**, click **Create Certificate**
3. Follow the CSR (Certificate Signing Request) instructions
4. Download and install the certificate

### Step 3: Enable Apple Pay Capability in Xcode

1. Open your project in Xcode
2. Select your project in the Project Navigator
3. Choose the target for your app
4. Click the **Signing & Capabilities** tab
5. Click the **+** button and add **Apple Pay** capability
6. Click the refresh button to synchronize merchant identifiers
7. Select the merchant identifier to use with your app

### Entitlements File

After enabling Apple Pay, your entitlements file will include:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.in-app-payments</key>
    <array>
        <string>merchant.com.yourcompany.appname</string>
    </array>
</dict>
</plist>
```

### Import PassKit

```swift
import PassKit
```

---

## Apple Pay Integration

### Checking Apple Pay Availability

Before presenting Apple Pay, verify that the device supports it and the user has configured payment cards.

```swift
import PassKit

// MARK: - Apple Pay Availability

@Observable
final class PaymentManager {

    // MARK: - Properties

    static let supportedNetworks: [PKPaymentNetwork] = [
        .amex,
        .discover,
        .masterCard,
        .visa,
        .JCB,
        .chinaUnionPay
    ]

    var canMakePayments: Bool {
        PKPaymentAuthorizationController.canMakePayments()
    }

    var canMakePaymentsWithCards: Bool {
        PKPaymentAuthorizationController.canMakePayments(
            usingNetworks: Self.supportedNetworks
        )
    }

    var canSetupCards: Bool {
        PKPaymentAuthorizationController.canMakePayments(
            usingNetworks: Self.supportedNetworks,
            capabilities: .capability3DS
        )
    }

    // MARK: - Methods

    func applePayStatus() -> ApplePayStatus {
        if canMakePaymentsWithCards {
            return .available
        } else if canSetupCards {
            return .needsSetup
        } else {
            return .unavailable
        }
    }
}

enum ApplePayStatus {
    case available
    case needsSetup
    case unavailable
}
```

### Using PKPaymentAuthorizationController

The `PKPaymentAuthorizationController` presents the payment sheet and handles the authorization flow.

```swift
import PassKit

@Observable
@MainActor
final class ApplePayHandler: NSObject {

    // MARK: - Properties

    private var paymentController: PKPaymentAuthorizationController?
    private var paymentStatus: PKPaymentAuthorizationStatus = .failure
    private var paymentContinuation: CheckedContinuation<Bool, Never>?

    static let supportedNetworks: [PKPaymentNetwork] = [
        .amex,
        .discover,
        .masterCard,
        .visa
    ]

    // MARK: - Methods

    func startPayment(for items: [CartItem], merchantID: String) async -> Bool {
        let paymentRequest = createPaymentRequest(
            for: items,
            merchantID: merchantID
        )

        paymentController = PKPaymentAuthorizationController(paymentRequest: paymentRequest)
        paymentController?.delegate = self

        return await withCheckedContinuation { continuation in
            paymentContinuation = continuation

            paymentController?.present { presented in
                if !presented {
                    continuation.resume(returning: false)
                }
            }
        }
    }

    private func createPaymentRequest(
        for items: [CartItem],
        merchantID: String
    ) -> PKPaymentRequest {
        let request = PKPaymentRequest()

        // Merchant configuration
        request.merchantIdentifier = merchantID
        request.merchantCapabilities = .capability3DS
        request.countryCode = "US"
        request.currencyCode = "USD"
        request.supportedNetworks = Self.supportedNetworks

        // Payment summary items
        var summaryItems: [PKPaymentSummaryItem] = items.map { item in
            PKPaymentSummaryItem(
                label: item.name,
                amount: NSDecimalNumber(value: item.price),
                type: .final
            )
        }

        let total = items.reduce(0) { $0 + $1.price }
        summaryItems.append(
            PKPaymentSummaryItem(
                label: "Your Company Name",
                amount: NSDecimalNumber(value: total),
                type: .final
            )
        )

        request.paymentSummaryItems = summaryItems

        return request
    }
}

// MARK: - PKPaymentAuthorizationControllerDelegate

extension ApplePayHandler: PKPaymentAuthorizationControllerDelegate {

    func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didAuthorizePayment payment: PKPayment
    ) async -> PKPaymentAuthorizationResult {
        // Process payment with your payment processor
        do {
            let success = try await processPayment(payment)
            paymentStatus = success ? .success : .failure
            return PKPaymentAuthorizationResult(status: paymentStatus, errors: nil)
        } catch {
            paymentStatus = .failure
            return PKPaymentAuthorizationResult(
                status: .failure,
                errors: [error]
            )
        }
    }

    func paymentAuthorizationControllerDidFinish(
        _ controller: PKPaymentAuthorizationController
    ) {
        controller.dismiss {
            let success = self.paymentStatus == .success
            self.paymentContinuation?.resume(returning: success)
            self.paymentContinuation = nil
        }
    }

    private func processPayment(_ payment: PKPayment) async throws -> Bool {
        // Extract payment token data
        let paymentData = payment.token.paymentData

        // Send to your payment processor (Stripe, Braintree, etc.)
        // This is where you integrate with your backend
        let result = try await PaymentService.shared.processApplePayToken(paymentData)

        return result.success
    }
}
```

---

## SwiftUI PayWithApplePayButton

SwiftUI provides a native `PayWithApplePayButton` that follows Apple's Human Interface Guidelines automatically.

### Basic Usage

```swift
import SwiftUI
import PassKit

struct CheckoutView: View {

    // MARK: - Properties

    @State private var paymentRequest = PKPaymentRequest()
    @State private var paymentSucceeded = false
    @State private var showingError = false
    @State private var errorMessage = ""

    private let merchantID = "merchant.com.yourcompany.appname"

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            // Cart items display
            cartItemsList

            Divider()

            // Total
            totalSection

            Spacer()

            // Apple Pay Button
            applePayButton
        }
        .padding()
        .onAppear {
            configurePaymentRequest()
        }
        .alert("Payment Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Views

    @ViewBuilder
    private var applePayButton: some View {
        PayWithApplePayButton(
            .checkout,
            request: paymentRequest,
            onPaymentAuthorizationChange: handlePaymentAuthorization
        ) {
            // Fallback view when Apple Pay is unavailable
            Button("Pay with Card") {
                // Handle alternative payment
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(height: 50)
        .payWithApplePayButtonStyle(.automatic)
    }

    private var cartItemsList: some View {
        // Your cart items UI
        Text("Cart Items")
    }

    private var totalSection: some View {
        HStack {
            Text("Total")
                .font(.headline)
            Spacer()
            Text("$99.99")
                .font(.headline)
        }
    }

    // MARK: - Methods

    private func configurePaymentRequest() {
        paymentRequest.merchantIdentifier = merchantID
        paymentRequest.merchantCapabilities = .capability3DS
        paymentRequest.countryCode = "US"
        paymentRequest.currencyCode = "USD"
        paymentRequest.supportedNetworks = [.amex, .discover, .masterCard, .visa]

        paymentRequest.paymentSummaryItems = [
            PKPaymentSummaryItem(
                label: "Subtotal",
                amount: NSDecimalNumber(string: "89.99"),
                type: .final
            ),
            PKPaymentSummaryItem(
                label: "Tax",
                amount: NSDecimalNumber(string: "10.00"),
                type: .final
            ),
            PKPaymentSummaryItem(
                label: "Your Company",
                amount: NSDecimalNumber(string: "99.99"),
                type: .final
            )
        ]
    }

    private func handlePaymentAuthorization(
        phase: PayWithApplePayButtonPaymentAuthorizationPhase
    ) {
        switch phase {
        case .willAuthorize:
            // User is about to authorize
            break

        case .didAuthorize(let payment, let resultHandler):
            // Process the payment
            Task {
                do {
                    let success = try await processPayment(payment)
                    resultHandler(
                        PKPaymentAuthorizationResult(
                            status: success ? .success : .failure,
                            errors: nil
                        )
                    )
                    paymentSucceeded = success
                } catch {
                    resultHandler(
                        PKPaymentAuthorizationResult(
                            status: .failure,
                            errors: [error]
                        )
                    )
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }

        case .didFinish:
            // Payment flow completed
            if paymentSucceeded {
                // Navigate to success screen
            }

        @unknown default:
            break
        }
    }

    private func processPayment(_ payment: PKPayment) async throws -> Bool {
        // Send payment token to your server
        try await PaymentService.shared.processApplePayToken(
            payment.token.paymentData
        )
        return true
    }
}
```

### Button Label Options

`PayWithApplePayButtonLabel` provides various label options:

```swift
// Standard labels
PayWithApplePayButton(.plain, ...)      // Apple Pay logo only
PayWithApplePayButton(.buy, ...)        // "Buy with Apple Pay"
PayWithApplePayButton(.checkout, ...)   // "Check out with Apple Pay"
PayWithApplePayButton(.book, ...)       // "Book with Apple Pay"
PayWithApplePayButton(.donate, ...)     // "Donate with Apple Pay"
PayWithApplePayButton(.subscribe, ...)  // "Subscribe with Apple Pay"
PayWithApplePayButton(.order, ...)      // "Order with Apple Pay"
PayWithApplePayButton(.rent, ...)       // "Rent with Apple Pay"
PayWithApplePayButton(.continue, ...)   // "Continue with Apple Pay"
PayWithApplePayButton(.contribute, ...) // "Contribute with Apple Pay"
PayWithApplePayButton(.tip, ...)        // "Tip with Apple Pay"
PayWithApplePayButton(.support, ...)    // "Support with Apple Pay"
PayWithApplePayButton(.setUp, ...)      // "Set up Apple Pay"
PayWithApplePayButton(.inStore, ...)    // "Apple Pay"
PayWithApplePayButton(.reload, ...)     // "Reload with Apple Pay"
PayWithApplePayButton(.addMoney, ...)   // "Add Money with Apple Pay"
PayWithApplePayButton(.topUp, ...)      // "Top Up with Apple Pay"
```

### Button Style Options

```swift
.payWithApplePayButtonStyle(.automatic)    // Adapts to context
.payWithApplePayButtonStyle(.black)        // Black background
.payWithApplePayButtonStyle(.white)        // White background
.payWithApplePayButtonStyle(.whiteOutline) // White with black outline
```

---

## Payment Request Configuration

### Complete Payment Request Setup

```swift
import PassKit

struct PaymentConfiguration {
    let merchantID: String
    let countryCode: String
    let currencyCode: String
    let supportedNetworks: [PKPaymentNetwork]

    static let `default` = PaymentConfiguration(
        merchantID: "merchant.com.yourcompany.appname",
        countryCode: "US",
        currencyCode: "USD",
        supportedNetworks: [.amex, .discover, .masterCard, .visa]
    )
}

@Observable
final class PaymentRequestBuilder {

    // MARK: - Properties

    private let configuration: PaymentConfiguration

    // MARK: - Initialization

    init(configuration: PaymentConfiguration = .default) {
        self.configuration = configuration
    }

    // MARK: - Methods

    func buildRequest(
        items: [PKPaymentSummaryItem],
        shippingMethods: [PKShippingMethod]? = nil,
        requiredBillingFields: Set<PKContactField> = [],
        requiredShippingFields: Set<PKContactField> = [],
        supportsCouponCode: Bool = false
    ) -> PKPaymentRequest {
        let request = PKPaymentRequest()

        // Basic configuration
        request.merchantIdentifier = configuration.merchantID
        request.merchantCapabilities = [.capability3DS, .capabilityCredit, .capabilityDebit]
        request.countryCode = configuration.countryCode
        request.currencyCode = configuration.currencyCode
        request.supportedNetworks = configuration.supportedNetworks

        // Payment items
        request.paymentSummaryItems = items

        // Shipping configuration
        if let shippingMethods {
            request.shippingMethods = shippingMethods
            request.shippingType = .delivery
        }

        // Contact fields
        if !requiredBillingFields.isEmpty {
            request.requiredBillingContactFields = requiredBillingFields
        }

        if !requiredShippingFields.isEmpty {
            request.requiredShippingContactFields = requiredShippingFields
        }

        // Coupon code support (iOS 15+)
        #if !os(watchOS)
        request.supportsCouponCode = supportsCouponCode
        #endif

        return request
    }

    func buildShippingMethod(
        label: String,
        amount: Decimal,
        identifier: String,
        detail: String? = nil,
        deliveryDate: DateComponents? = nil
    ) -> PKShippingMethod {
        let method = PKShippingMethod(
            label: label,
            amount: NSDecimalNumber(decimal: amount)
        )
        method.identifier = identifier
        method.detail = detail

        if let deliveryDate {
            method.dateComponentsRange = PKDateComponentsRange(
                start: deliveryDate,
                end: deliveryDate
            )
        }

        return method
    }
}
```

### Payment Summary Items

```swift
// Creating payment summary items
func createSummaryItems(
    subtotal: Decimal,
    tax: Decimal,
    shipping: Decimal,
    discount: Decimal? = nil,
    companyName: String
) -> [PKPaymentSummaryItem] {
    var items: [PKPaymentSummaryItem] = []

    items.append(
        PKPaymentSummaryItem(
            label: "Subtotal",
            amount: NSDecimalNumber(decimal: subtotal),
            type: .final
        )
    )

    items.append(
        PKPaymentSummaryItem(
            label: "Tax",
            amount: NSDecimalNumber(decimal: tax),
            type: .final
        )
    )

    items.append(
        PKPaymentSummaryItem(
            label: "Shipping",
            amount: NSDecimalNumber(decimal: shipping),
            type: .final
        )
    )

    if let discount, discount > 0 {
        items.append(
            PKPaymentSummaryItem(
                label: "Discount",
                amount: NSDecimalNumber(decimal: -discount),
                type: .final
            )
        )
    }

    let total = subtotal + tax + shipping - (discount ?? 0)
    items.append(
        PKPaymentSummaryItem(
            label: companyName,
            amount: NSDecimalNumber(decimal: total),
            type: .final
        )
    )

    return items
}

// Pending items (for estimated totals)
let pendingItem = PKPaymentSummaryItem(
    label: "Estimated Tax",
    amount: NSDecimalNumber(string: "5.00"),
    type: .pending  // Shows as "pending" in payment sheet
)
```

### Shipping Methods

```swift
func createShippingMethods() -> [PKShippingMethod] {
    let standardShipping = PKShippingMethod(
        label: "Standard Shipping",
        amount: NSDecimalNumber(string: "5.99")
    )
    standardShipping.identifier = "standard"
    standardShipping.detail = "5-7 business days"

    let expressShipping = PKShippingMethod(
        label: "Express Shipping",
        amount: NSDecimalNumber(string: "12.99")
    )
    expressShipping.identifier = "express"
    expressShipping.detail = "2-3 business days"

    let overnightShipping = PKShippingMethod(
        label: "Overnight Shipping",
        amount: NSDecimalNumber(string: "24.99")
    )
    overnightShipping.identifier = "overnight"
    overnightShipping.detail = "Next business day"

    return [standardShipping, expressShipping, overnightShipping]
}
```

---

## Handling Payment Authorization

### Complete Delegate Implementation

```swift
import PassKit

@Observable
@MainActor
final class PaymentAuthorizationHandler: NSObject {

    // MARK: - Properties

    private var paymentController: PKPaymentAuthorizationController?
    private var paymentStatus: PKPaymentAuthorizationStatus = .failure
    private var continuation: CheckedContinuation<PaymentResult, Never>?

    private let paymentProcessor: PaymentProcessing
    private let shippingCalculator: ShippingCalculating

    // MARK: - Initialization

    init(
        paymentProcessor: PaymentProcessing,
        shippingCalculator: ShippingCalculating
    ) {
        self.paymentProcessor = paymentProcessor
        self.shippingCalculator = shippingCalculator
    }

    // MARK: - Methods

    func processPayment(request: PKPaymentRequest) async -> PaymentResult {
        paymentController = PKPaymentAuthorizationController(paymentRequest: request)
        paymentController?.delegate = self

        return await withCheckedContinuation { continuation in
            self.continuation = continuation

            paymentController?.present { presented in
                if !presented {
                    continuation.resume(returning: .failure(.presentationFailed))
                }
            }
        }
    }
}

// MARK: - PKPaymentAuthorizationControllerDelegate

extension PaymentAuthorizationHandler: PKPaymentAuthorizationControllerDelegate {

    // MARK: - Authorization

    nonisolated func paymentAuthorizationControllerWillAuthorizePayment(
        _ controller: PKPaymentAuthorizationController
    ) {
        // Called just before Face ID/Touch ID authentication
        // Good place for analytics
    }

    nonisolated func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didAuthorizePayment payment: PKPayment
    ) async -> PKPaymentAuthorizationResult {
        // Validate shipping address if required
        if let shippingContact = payment.shippingContact,
           let countryCode = shippingContact.postalAddress?.isoCountryCode {

            // Check if we ship to this country
            guard isValidShippingCountry(countryCode) else {
                return PKPaymentAuthorizationResult(
                    status: .failure,
                    errors: [
                        PKPaymentRequest.paymentShippingAddressUnserviceableError(
                            withLocalizedDescription: "We don't ship to this country"
                        )
                    ]
                )
            }
        }

        // Process the payment
        do {
            try await paymentProcessor.process(payment: payment)
            await MainActor.run {
                paymentStatus = .success
            }
            return PKPaymentAuthorizationResult(status: .success, errors: nil)
        } catch let error as PaymentError {
            await MainActor.run {
                paymentStatus = .failure
            }
            return PKPaymentAuthorizationResult(
                status: .failure,
                errors: [error.pkError]
            )
        } catch {
            await MainActor.run {
                paymentStatus = .failure
            }
            return PKPaymentAuthorizationResult(
                status: .failure,
                errors: [error]
            )
        }
    }

    nonisolated func paymentAuthorizationControllerDidFinish(
        _ controller: PKPaymentAuthorizationController
    ) {
        controller.dismiss {
            Task { @MainActor in
                let result: PaymentResult = self.paymentStatus == .success
                    ? .success
                    : .failure(.paymentFailed)

                self.continuation?.resume(returning: result)
                self.continuation = nil
            }
        }
    }

    // MARK: - Shipping Contact Changes

    nonisolated func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didSelectShippingContact contact: PKContact
    ) async -> PKPaymentRequestShippingContactUpdate {
        guard let postalAddress = contact.postalAddress else {
            return PKPaymentRequestShippingContactUpdate(
                errors: [
                    PKPaymentRequest.paymentShippingAddressInvalidError(
                        withKey: CNPostalAddressStreetKey,
                        localizedDescription: "Invalid address"
                    )
                ],
                paymentSummaryItems: [],
                shippingMethods: []
            )
        }

        // Calculate shipping options for this address
        let shippingMethods = await shippingCalculator.calculateShipping(
            for: postalAddress
        )

        // Update summary items with new shipping cost
        let summaryItems = await shippingCalculator.updateSummaryItems(
            shippingMethod: shippingMethods.first
        )

        return PKPaymentRequestShippingContactUpdate(
            errors: nil,
            paymentSummaryItems: summaryItems,
            shippingMethods: shippingMethods
        )
    }

    // MARK: - Shipping Method Changes

    nonisolated func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didSelectShippingMethod shippingMethod: PKShippingMethod
    ) async -> PKPaymentRequestShippingMethodUpdate {
        // Update summary items with selected shipping method
        let summaryItems = await shippingCalculator.updateSummaryItems(
            shippingMethod: shippingMethod
        )

        return PKPaymentRequestShippingMethodUpdate(
            paymentSummaryItems: summaryItems
        )
    }

    // MARK: - Coupon Code Changes

    #if !os(watchOS)
    nonisolated func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didChangeCouponCode couponCode: String
    ) async -> PKPaymentRequestCouponCodeUpdate {
        // Validate and apply coupon code
        do {
            let discount = try await validateCouponCode(couponCode)
            let summaryItems = await shippingCalculator.updateSummaryItems(
                discount: discount
            )

            return PKPaymentRequestCouponCodeUpdate(
                errors: nil,
                paymentSummaryItems: summaryItems,
                shippingMethods: []
            )
        } catch {
            return PKPaymentRequestCouponCodeUpdate(
                errors: [
                    PKPaymentRequest.paymentCouponCodeInvalidError(
                        localizedDescription: "Invalid coupon code"
                    )
                ],
                paymentSummaryItems: [],
                shippingMethods: []
            )
        }
    }
    #endif

    // MARK: - Helpers

    private nonisolated func isValidShippingCountry(_ countryCode: String) -> Bool {
        let supportedCountries = ["US", "CA", "GB", "AU", "DE", "FR"]
        return supportedCountries.contains(countryCode)
    }

    private nonisolated func validateCouponCode(_ code: String) async throws -> Decimal {
        // Validate with your backend
        return 10.00
    }
}

// MARK: - Supporting Types

enum PaymentResult {
    case success
    case failure(PaymentError)
}

enum PaymentError: Error {
    case presentationFailed
    case paymentFailed
    case invalidAddress
    case networkError

    var pkError: Error {
        NSError(
            domain: PKPaymentErrorDomain,
            code: PKPaymentError.unknownError.rawValue,
            userInfo: [NSLocalizedDescriptionKey: localizedDescription]
        )
    }

    var localizedDescription: String {
        switch self {
        case .presentationFailed:
            return "Unable to present payment sheet"
        case .paymentFailed:
            return "Payment processing failed"
        case .invalidAddress:
            return "Invalid shipping address"
        case .networkError:
            return "Network error occurred"
        }
    }
}

protocol PaymentProcessing {
    func process(payment: PKPayment) async throws
}

protocol ShippingCalculating {
    func calculateShipping(for address: CNPostalAddress) async -> [PKShippingMethod]
    func updateSummaryItems(shippingMethod: PKShippingMethod?) async -> [PKPaymentSummaryItem]
    func updateSummaryItems(discount: Decimal) async -> [PKPaymentSummaryItem]
}
```

### SwiftUI Payment Change Handlers

```swift
import SwiftUI
import PassKit

struct PaymentView: View {

    @State private var paymentRequest = PKPaymentRequest()

    var body: some View {
        PayWithApplePayButton(
            .checkout,
            request: paymentRequest,
            onPaymentAuthorizationChange: handleAuthorizationChange
        ) {
            Text("Apple Pay not available")
        }
        .onApplePayShippingContactChange { contact in
            // Handle shipping contact change
            await handleShippingContactChange(contact)
        }
        .onApplePayShippingMethodChange { method in
            // Handle shipping method change
            await handleShippingMethodChange(method)
        }
        .onApplePayPaymentMethodChange { method in
            // Handle payment method change (card selection)
            await handlePaymentMethodChange(method)
        }
        .onApplePayCouponCodeChange { couponCode in
            // Handle coupon code entry
            await handleCouponCodeChange(couponCode)
        }
    }

    private func handleAuthorizationChange(
        phase: PayWithApplePayButtonPaymentAuthorizationPhase
    ) {
        // Handle authorization phases
    }

    private func handleShippingContactChange(
        _ contact: PKContact
    ) async -> PKPaymentRequestShippingContactUpdate {
        // Return updated shipping options
        PKPaymentRequestShippingContactUpdate(
            errors: nil,
            paymentSummaryItems: [],
            shippingMethods: []
        )
    }

    private func handleShippingMethodChange(
        _ method: PKShippingMethod
    ) async -> PKPaymentRequestShippingMethodUpdate {
        // Return updated summary items
        PKPaymentRequestShippingMethodUpdate(paymentSummaryItems: [])
    }

    private func handlePaymentMethodChange(
        _ method: PKPaymentMethod
    ) async -> PKPaymentRequestPaymentMethodUpdate {
        // Return updated summary items if needed
        PKPaymentRequestPaymentMethodUpdate(paymentSummaryItems: [])
    }

    private func handleCouponCodeChange(
        _ couponCode: String
    ) async -> PKPaymentRequestCouponCodeUpdate {
        // Validate and return updated items
        PKPaymentRequestCouponCodeUpdate(
            errors: nil,
            paymentSummaryItems: [],
            shippingMethods: []
        )
    }
}
```

---

## Wallet Passes

### Understanding PKPass

`PKPass` represents a single pass in the Wallet app. Passes can be:

- **Boarding Passes** - Airline, train, bus tickets
- **Event Tickets** - Concert, sports, movie tickets
- **Coupons** - Store discounts and promotions
- **Store Cards** - Loyalty and membership cards
- **Generic Passes** - Any other type of pass

### PKPass Properties

```swift
import PassKit

func examinePass(_ pass: PKPass) {
    // Identification
    let passType = pass.passType
    let serialNumber = pass.serialNumber
    let passTypeIdentifier = pass.passTypeIdentifier
    let organizationName = pass.organizationName

    // Display
    let localizedName = pass.localizedName
    let localizedDescription = pass.localizedDescription
    let icon = pass.icon

    // Relevance
    let relevantDate = pass.relevantDate
    let relevantDates = pass.relevantDates

    // Web service
    let webServiceURL = pass.webServiceURL
    let authenticationToken = pass.authenticationToken

    // Wallet URL (opens pass in Wallet app)
    let passURL = pass.passURL

    // Custom data
    let userInfo = pass.userInfo

    // Get localized field value
    let fieldValue = pass.localizedValue(forFieldKey: "departure_time")

    // Check if remote (on paired Apple Watch)
    let isRemote = pass.isRemotePass
}
```

### Creating a PKPass from Data

```swift
import PassKit

@Observable
final class PassManager {

    // MARK: - Methods

    func createPass(from data: Data) throws -> PKPass {
        try PKPass(data: data)
    }

    func downloadAndCreatePass(from url: URL) async throws -> PKPass {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PassError.downloadFailed
        }

        return try PKPass(data: data)
    }
}

enum PassError: LocalizedError {
    case downloadFailed
    case invalidPassData
    case passNotFound

    var errorDescription: String? {
        switch self {
        case .downloadFailed:
            return "Failed to download pass"
        case .invalidPassData:
            return "Invalid pass data"
        case .passNotFound:
            return "Pass not found in library"
        }
    }
}
```

---

## Adding Passes to Wallet

### Using PKPassLibrary

```swift
import PassKit

@Observable
final class WalletManager {

    // MARK: - Properties

    private let passLibrary = PKPassLibrary()

    var isPassLibraryAvailable: Bool {
        PKPassLibrary.isPassLibraryAvailable()
    }

    // MARK: - Methods

    /// Check if a pass is already in the Wallet
    func containsPass(_ pass: PKPass) -> Bool {
        passLibrary.containsPass(pass)
    }

    /// Get all passes accessible by this app
    func getAllPasses() -> [PKPass] {
        passLibrary.passes()
    }

    /// Get passes of a specific type
    func getPasses(ofType passType: PKPassType) -> [PKPass] {
        passLibrary.passes(of: passType)
    }

    /// Get a specific pass by identifier
    func getPass(
        passTypeIdentifier: String,
        serialNumber: String
    ) -> PKPass? {
        passLibrary.pass(
            withPassTypeIdentifier: passTypeIdentifier,
            serialNumber: serialNumber
        )
    }

    /// Replace an existing pass
    func replacePass(_ pass: PKPass) -> Bool {
        passLibrary.replacePass(with: pass)
    }

    /// Remove a pass from Wallet
    func removePass(_ pass: PKPass) {
        passLibrary.removePass(pass)
    }
}
```

### SwiftUI AddPassToWalletButton

```swift
import SwiftUI
import PassKit

struct PassView: View {

    // MARK: - Properties

    @State private var pass: PKPass?
    @State private var addedToWallet = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let passLibrary = PKPassLibrary()

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            if isLoading {
                ProgressView("Loading pass...")
            } else if let pass {
                passPreview(pass)

                if !passLibrary.containsPass(pass) {
                    addToWalletButton(pass)
                } else {
                    passAddedView
                }
            } else {
                loadPassButton
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .padding()
    }

    // MARK: - Views

    private func passPreview(_ pass: PKPass) -> some View {
        VStack(spacing: 12) {
            Image(uiImage: pass.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)

            Text(pass.localizedName)
                .font(.headline)

            Text(pass.localizedDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(pass.organizationName)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func addToWalletButton(_ pass: PKPass) -> some View {
        AddPassToWalletButton([pass]) { added in
            addedToWallet = added
        } fallback: {
            Button("Add to Wallet") {
                // Manual add fallback
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(width: 250, height: 50)
        .addPassToWalletButtonStyle(.blackOutline)
    }

    private var passAddedView: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Added to Wallet")
        }
        .font(.headline)
    }

    private var loadPassButton: some View {
        Button("Load Pass") {
            Task {
                await loadPass()
            }
        }
        .buttonStyle(.borderedProminent)
    }

    // MARK: - Methods

    private func loadPass() async {
        isLoading = true
        errorMessage = nil

        do {
            let passURL = URL(string: "https://example.com/passes/mypass.pkpass")!
            let (data, _) = try await URLSession.shared.data(from: passURL)
            pass = try PKPass(data: data)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
```

### AddPassToWalletButton Styles

```swift
// Style options for AddPassToWalletButton
.addPassToWalletButtonStyle(.black)        // Black button
.addPassToWalletButtonStyle(.blackOutline) // Black outline
```

### Adding Multiple Passes

```swift
import SwiftUI
import PassKit

struct MultiplePassesView: View {

    @State private var passes: [PKPass] = []
    @State private var allAdded = false

    var body: some View {
        VStack {
            if !passes.isEmpty {
                AddPassToWalletButton(passes) { added in
                    allAdded = added
                } fallback: {
                    Text("Wallet not available")
                }
                .frame(width: 250, height: 50)
            }
        }
    }
}
```

### Presenting PKAddPassesViewController (UIKit Bridge)

For more control, you can use `UIViewControllerRepresentable`:

```swift
import SwiftUI
import PassKit

struct AddPassesViewControllerRepresentable: UIViewControllerRepresentable {

    let passes: [PKPass]
    let onCompletion: (Bool) -> Void

    func makeUIViewController(context: Context) -> PKAddPassesViewController {
        let controller = PKAddPassesViewController(passes: passes)!
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(
        _ uiViewController: PKAddPassesViewController,
        context: Context
    ) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCompletion: onCompletion)
    }

    class Coordinator: NSObject, PKAddPassesViewControllerDelegate {
        let onCompletion: (Bool) -> Void

        init(onCompletion: @escaping (Bool) -> Void) {
            self.onCompletion = onCompletion
        }

        func addPassesViewControllerDidFinish(
            _ controller: PKAddPassesViewController
        ) {
            // Note: This doesn't indicate whether passes were actually added
            onCompletion(true)
            controller.dismiss(animated: true)
        }
    }
}

// Usage in SwiftUI
struct PassDetailView: View {

    @State private var showingAddPass = false
    let pass: PKPass

    var body: some View {
        Button("Add to Wallet") {
            showingAddPass = true
        }
        .sheet(isPresented: $showingAddPass) {
            AddPassesViewControllerRepresentable(passes: [pass]) { added in
                showingAddPass = false
            }
        }
    }
}
```

---

## iOS 18/26 Specific Features

### iOS 18+ Features

#### Order Tracking in Wallet

iOS 18 introduced enhanced order tracking capabilities:

```swift
import PassKit

// Wallet Orders are managed through a separate framework
// Orders appear automatically when merchants send order emails
// Or can be added programmatically through Wallet Orders API

// Check if order tracking is available
func checkOrderTrackingAvailability() {
    // Order tracking is automatic for supported merchants
    // No additional code required in most cases
}
```

#### Tap to Pay Enhancements

```swift
import ProximityReader

@Observable
@MainActor
final class TapToPayManager {

    private let discovery = ProximityReaderDiscovery()

    func presentTapToPayEducation(from viewController: UIViewController) async throws {
        let content = try await discovery.content(
            for: .payment(.howToTap)
        )
        try await discovery.presentContent(content, from: viewController)
    }
}
```

### iOS 26+ Features

#### Enhanced Order Tracking

iOS 26 brings improved order tracking that automatically finds merchant and carrier emails:

```swift
// Order tracking is enhanced with AI-powered email parsing
// Available on Apple Intelligence enabled devices
// No developer action required - system handles automatically
```

#### Liquid Glass Design Considerations

When using PassKit buttons in iOS 26+ with Liquid Glass design:

```swift
import SwiftUI
import PassKit

struct PaymentViewiOS26: View {

    @State private var paymentRequest = PKPaymentRequest()

    var body: some View {
        VStack {
            // Apple Pay buttons automatically adapt to Liquid Glass
            PayWithApplePayButton(
                .checkout,
                request: paymentRequest,
                onPaymentAuthorizationChange: handlePayment
            ) {
                Text("Pay with Card")
            }
            .frame(height: 50)
            // Button style adapts automatically to system appearance
            .payWithApplePayButtonStyle(.automatic)
        }
        // Avoid placing Apple Pay buttons on glass-on-glass
        // Keep them on solid backgrounds for clarity
    }

    private func handlePayment(
        phase: PayWithApplePayButtonPaymentAuthorizationPhase
    ) { }
}
```

---

## Common Use Cases

### 1. E-Commerce Checkout

```swift
import SwiftUI
import PassKit

struct ECommerceCheckoutView: View {

    // MARK: - Properties

    @Environment(CartManager.self) private var cartManager
    @State private var paymentRequest = PKPaymentRequest()
    @State private var selectedShipping: PKShippingMethod?
    @State private var isProcessing = false
    @State private var orderComplete = false

    private let merchantID = "merchant.com.yourstore.app"

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    cartSummary

                    Divider()

                    shippingSection

                    Divider()

                    paymentSection
                }
                .padding()
            }
            .navigationTitle("Checkout")
            .navigationDestination(isPresented: $orderComplete) {
                OrderConfirmationView()
            }
        }
        .onAppear {
            configurePaymentRequest()
        }
    }

    // MARK: - Views

    private var cartSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Order Summary")
                .font(.headline)

            ForEach(cartManager.items) { item in
                HStack {
                    Text(item.name)
                    Spacer()
                    Text(item.formattedPrice)
                }
            }
        }
    }

    private var shippingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shipping")
                .font(.headline)

            // Shipping options
        }
    }

    private var paymentSection: some View {
        VStack(spacing: 16) {
            PayWithApplePayButton(
                .checkout,
                request: paymentRequest,
                onPaymentAuthorizationChange: handlePayment
            ) {
                Button("Pay with Card") {
                    // Alternative payment
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(height: 50)
            .payWithApplePayButtonStyle(.black)
            .disabled(isProcessing)

            if isProcessing {
                ProgressView()
            }
        }
    }

    // MARK: - Methods

    private func configurePaymentRequest() {
        paymentRequest.merchantIdentifier = merchantID
        paymentRequest.merchantCapabilities = .capability3DS
        paymentRequest.countryCode = "US"
        paymentRequest.currencyCode = "USD"
        paymentRequest.supportedNetworks = [.amex, .discover, .masterCard, .visa]
        paymentRequest.requiredShippingContactFields = [.name, .postalAddress, .emailAddress]
        paymentRequest.requiredBillingContactFields = [.postalAddress]
        paymentRequest.shippingType = .delivery
        paymentRequest.shippingMethods = createShippingMethods()
        paymentRequest.supportsCouponCode = true

        updatePaymentSummaryItems()
    }

    private func createShippingMethods() -> [PKShippingMethod] {
        // Return shipping options
        []
    }

    private func updatePaymentSummaryItems() {
        paymentRequest.paymentSummaryItems = cartManager.paymentSummaryItems
    }

    private func handlePayment(
        phase: PayWithApplePayButtonPaymentAuthorizationPhase
    ) {
        switch phase {
        case .willAuthorize:
            isProcessing = true

        case .didAuthorize(let payment, let handler):
            Task {
                do {
                    try await processOrder(payment: payment)
                    handler(PKPaymentAuthorizationResult(status: .success, errors: nil))
                    orderComplete = true
                } catch {
                    handler(PKPaymentAuthorizationResult(status: .failure, errors: [error]))
                }
            }

        case .didFinish:
            isProcessing = false

        @unknown default:
            break
        }
    }

    private func processOrder(payment: PKPayment) async throws {
        // Process with your backend
    }
}
```

### 2. Donation Flow

```swift
import SwiftUI
import PassKit

struct DonationView: View {

    // MARK: - Properties

    @State private var selectedAmount: Decimal = 25.00
    @State private var paymentRequest = PKPaymentRequest()

    private let amounts: [Decimal] = [10, 25, 50, 100]
    private let merchantID = "merchant.com.nonprofit.donations"

    // MARK: - Body

    var body: some View {
        VStack(spacing: 24) {
            Text("Support Our Cause")
                .font(.title)

            // Amount selection
            HStack(spacing: 12) {
                ForEach(amounts, id: \.self) { amount in
                    Button {
                        selectedAmount = amount
                        updatePaymentRequest()
                    } label: {
                        Text("$\(amount as NSDecimalNumber)")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                selectedAmount == amount
                                    ? Color.accentColor
                                    : Color.secondary.opacity(0.2)
                            )
                            .foregroundStyle(
                                selectedAmount == amount ? .white : .primary
                            )
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            PayWithApplePayButton(
                .donate,
                request: paymentRequest,
                onPaymentAuthorizationChange: handleDonation
            ) {
                Text("Donate")
            }
            .frame(height: 50)
            .payWithApplePayButtonStyle(.black)
        }
        .padding()
        .onAppear {
            configurePaymentRequest()
        }
    }

    // MARK: - Methods

    private func configurePaymentRequest() {
        paymentRequest.merchantIdentifier = merchantID
        paymentRequest.merchantCapabilities = .capability3DS
        paymentRequest.countryCode = "US"
        paymentRequest.currencyCode = "USD"
        paymentRequest.supportedNetworks = [.amex, .discover, .masterCard, .visa]

        updatePaymentRequest()
    }

    private func updatePaymentRequest() {
        paymentRequest.paymentSummaryItems = [
            PKPaymentSummaryItem(
                label: "Donation",
                amount: NSDecimalNumber(decimal: selectedAmount),
                type: .final
            ),
            PKPaymentSummaryItem(
                label: "Your Nonprofit",
                amount: NSDecimalNumber(decimal: selectedAmount),
                type: .final
            )
        ]
    }

    private func handleDonation(
        phase: PayWithApplePayButtonPaymentAuthorizationPhase
    ) {
        // Handle donation payment
    }
}
```

### 3. Event Ticket Pass

```swift
import SwiftUI
import PassKit

struct EventTicketView: View {

    // MARK: - Properties

    @State private var ticketPass: PKPass?
    @State private var isLoading = false
    @State private var addedToWallet = false

    let event: Event

    private let passLibrary = PKPassLibrary()

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            // Event details
            eventDetails

            Divider()

            // Ticket actions
            if let ticketPass {
                ticketActions(ticketPass)
            } else if isLoading {
                ProgressView("Loading ticket...")
            } else {
                Button("Download Ticket") {
                    Task {
                        await downloadTicket()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    // MARK: - Views

    private var eventDetails: some View {
        VStack(spacing: 8) {
            Text(event.name)
                .font(.title)

            Text(event.date.formatted(date: .long, time: .shortened))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(event.venue)
                .font(.subheadline)
        }
    }

    @ViewBuilder
    private func ticketActions(_ pass: PKPass) -> some View {
        VStack(spacing: 16) {
            // Pass preview
            Image(uiImage: pass.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)

            if passLibrary.containsPass(pass) {
                // Already in wallet - offer to open
                Button("View in Wallet") {
                    openPassInWallet(pass)
                }
                .buttonStyle(.borderedProminent)
            } else {
                // Add to wallet
                AddPassToWalletButton([pass]) { added in
                    addedToWallet = added
                }
                .frame(width: 250, height: 50)
                .addPassToWalletButtonStyle(.blackOutline)
            }
        }
    }

    // MARK: - Methods

    private func downloadTicket() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let passData = try await fetchTicketPass(for: event)
            ticketPass = try PKPass(data: passData)
        } catch {
            // Handle error
        }
    }

    private func fetchTicketPass(for event: Event) async throws -> Data {
        // Fetch from your server
        let url = URL(string: "https://api.example.com/tickets/\(event.id)/pass")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }

    private func openPassInWallet(_ pass: PKPass) {
        guard let passURL = pass.passURL else { return }
        UIApplication.shared.open(passURL)
    }
}

struct Event: Identifiable {
    let id: String
    let name: String
    let date: Date
    let venue: String
}
```

### 4. Loyalty Card

```swift
import SwiftUI
import PassKit

struct LoyaltyCardView: View {

    // MARK: - Properties

    @State private var loyaltyPass: PKPass?
    @State private var pointsBalance: Int = 0

    private let passLibrary = PKPassLibrary()

    // MARK: - Body

    var body: some View {
        VStack(spacing: 24) {
            // Points display
            VStack {
                Text("\(pointsBalance)")
                    .font(.system(size: 48, weight: .bold))

                Text("Reward Points")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Wallet integration
            walletSection
        }
        .padding()
        .task {
            await loadLoyaltyCard()
        }
    }

    // MARK: - Views

    @ViewBuilder
    private var walletSection: some View {
        if let pass = loyaltyPass {
            if passLibrary.containsPass(pass) {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Card in Wallet")
                    }

                    Button("Open in Wallet") {
                        if let url = pass.passURL {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            } else {
                AddPassToWalletButton([pass]) { _ in }
                    .frame(width: 250, height: 50)
            }
        } else {
            ProgressView()
        }
    }

    // MARK: - Methods

    private func loadLoyaltyCard() async {
        // Check if already exists in library
        if let existingPass = passLibrary.pass(
            withPassTypeIdentifier: "pass.com.yourapp.loyalty",
            serialNumber: "user-12345"
        ) {
            loyaltyPass = existingPass
            return
        }

        // Download from server
        do {
            let passData = try await fetchLoyaltyPass()
            loyaltyPass = try PKPass(data: passData)
        } catch {
            // Handle error
        }
    }

    private func fetchLoyaltyPass() async throws -> Data {
        // Fetch from your server
        let url = URL(string: "https://api.example.com/loyalty/pass")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
}
```

---

## Best Practices & Security

### Security Best Practices

#### 1. Payment Token Handling

```swift
// NEVER log or store payment tokens on device
func processPayment(_ payment: PKPayment) async throws {
    let paymentData = payment.token.paymentData

    // Send directly to your secure server
    // Do not store locally
    // Do not log the token data

    try await sendToSecureServer(paymentData)
}

private func sendToSecureServer(_ paymentData: Data) async throws {
    var request = URLRequest(url: serverURL)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    // Use HTTPS only
    guard serverURL.scheme == "https" else {
        throw SecurityError.insecureConnection
    }

    let payload = ["paymentToken": paymentData.base64EncodedString()]
    request.httpBody = try JSONEncoder().encode(payload)

    let (_, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
        throw PaymentError.serverError
    }
}
```

#### 2. Merchant ID Protection

```swift
// Store merchant ID in configuration, not hardcoded
struct AppConfiguration {
    static var merchantIdentifier: String {
        // Load from secure configuration
        // Never commit to source control
        Bundle.main.object(forInfoDictionaryKey: "MerchantIdentifier") as? String ?? ""
    }
}

// In Info.plist or xcconfig:
// MerchantIdentifier = $(MERCHANT_ID)
```

#### 3. Validate Server Responses

```swift
func validatePaymentResponse(_ response: PaymentResponse) throws {
    // Verify response signature
    guard response.isSignatureValid else {
        throw SecurityError.invalidSignature
    }

    // Check timestamp to prevent replay attacks
    let maxAge: TimeInterval = 300 // 5 minutes
    guard Date().timeIntervalSince(response.timestamp) < maxAge else {
        throw SecurityError.expiredResponse
    }

    // Verify amount matches
    guard response.amount == expectedAmount else {
        throw SecurityError.amountMismatch
    }
}
```

### UI/UX Best Practices

#### 1. Check Availability Before Showing Button

```swift
struct PaymentOptionsView: View {

    var canUseApplePay: Bool {
        PKPaymentAuthorizationController.canMakePayments(
            usingNetworks: [.amex, .discover, .masterCard, .visa]
        )
    }

    var body: some View {
        VStack {
            if canUseApplePay {
                // Show Apple Pay as primary option
                PayWithApplePayButton(...)

                // Alternative payment as secondary
                Button("Pay with Card") { }
            } else {
                // Only show card payment
                Button("Pay with Card") { }
                    .buttonStyle(.borderedProminent)

                // Optionally show setup option
                if PKPaymentAuthorizationController.canMakePayments() {
                    Button("Set Up Apple Pay") {
                        // Open Wallet app
                    }
                }
            }
        }
    }
}
```

#### 2. Proper Error Handling

```swift
func handlePaymentError(_ error: Error) {
    // Provide user-friendly messages
    let message: String

    if let pkError = error as? PKPaymentError {
        switch pkError.code {
        case .unknownError:
            message = "An unexpected error occurred. Please try again."
        case .shippingContactInvalidError:
            message = "Please check your shipping address."
        case .billingContactInvalidError:
            message = "Please check your billing address."
        case .shippingAddressUnserviceableError:
            message = "We cannot ship to this address."
        case .couponCodeInvalidError:
            message = "The coupon code is invalid."
        case .couponCodeExpiredError:
            message = "The coupon code has expired."
        @unknown default:
            message = "Payment could not be completed."
        }
    } else {
        message = "Payment could not be completed. Please try again."
    }

    // Show alert with message
}
```

#### 3. Loading States

```swift
struct CheckoutButton: View {

    @Binding var isProcessing: Bool
    let request: PKPaymentRequest
    let onPayment: (PayWithApplePayButtonPaymentAuthorizationPhase) -> Void

    var body: some View {
        ZStack {
            PayWithApplePayButton(
                .checkout,
                request: request,
                onPaymentAuthorizationChange: onPayment
            ) {
                Text("Checkout")
            }
            .opacity(isProcessing ? 0.5 : 1)
            .disabled(isProcessing)

            if isProcessing {
                ProgressView()
            }
        }
        .frame(height: 50)
    }
}
```

### Performance Best Practices

#### 1. Cache Pass Library Status

```swift
@Observable
final class WalletStatusCache {

    private var cachedPasses: [String: Bool] = [:]
    private let passLibrary = PKPassLibrary()

    func containsPass(
        passTypeIdentifier: String,
        serialNumber: String
    ) -> Bool {
        let key = "\(passTypeIdentifier)_\(serialNumber)"

        if let cached = cachedPasses[key] {
            return cached
        }

        let exists = passLibrary.pass(
            withPassTypeIdentifier: passTypeIdentifier,
            serialNumber: serialNumber
        ) != nil

        cachedPasses[key] = exists
        return exists
    }

    func invalidateCache() {
        cachedPasses.removeAll()
    }
}
```

#### 2. Lazy Pass Loading

```swift
struct PassListView: View {

    @State private var passes: [PKPass] = []

    var body: some View {
        List(passes, id: \.serialNumber) { pass in
            PassRow(pass: pass)
        }
        .task {
            // Load passes on background thread
            passes = await loadPasses()
        }
    }

    private func loadPasses() async -> [PKPass] {
        await Task.detached {
            PKPassLibrary().passes()
        }.value
    }
}
```

### Testing Best Practices

#### 1. Use Sandbox Environment

```swift
#if DEBUG
extension PaymentConfiguration {
    static let sandbox = PaymentConfiguration(
        merchantID: "merchant.com.yourcompany.sandbox",
        countryCode: "US",
        currencyCode: "USD",
        supportedNetworks: [.amex, .discover, .masterCard, .visa]
    )
}
#endif
```

#### 2. Mock Payment Handler for Testing

```swift
#if DEBUG
final class MockPaymentHandler: PaymentProcessing {
    var shouldSucceed = true
    var processedPayments: [PKPayment] = []

    func process(payment: PKPayment) async throws {
        processedPayments.append(payment)

        // Simulate network delay
        try await Task.sleep(for: .seconds(1))

        if !shouldSucceed {
            throw PaymentError.paymentFailed
        }
    }
}
#endif
```

#### 3. Simulator Limitations

Note: Apple Pay cannot be fully tested in the iOS Simulator. You need a physical device with:
- Apple Pay configured
- Test cards from your payment processor's sandbox
- Merchant ID properly configured

---

## Additional Resources

- [Apple Pay Programming Guide](https://developer.apple.com/apple-pay/)
- [Wallet Developer Guide](https://developer.apple.com/wallet/)
- [PassKit Framework Reference](https://developer.apple.com/documentation/passkit)
- [Human Interface Guidelines - Apple Pay](https://developer.apple.com/design/human-interface-guidelines/apple-pay)
- [Apple Pay Sandbox Testing](https://developer.apple.com/apple-pay/sandbox-testing/)

---

## Version History

| iOS Version | Notable PassKit Changes |
|-------------|------------------------|
| iOS 18 | Enhanced order tracking, improved Tap to Pay |
| iOS 26 | AI-powered order tracking from emails, Liquid Glass design adaptation |

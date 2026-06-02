# iOS 26 RevenueCat PaywallView - Product Cards Not Rendering

## Problem

On iOS 26, RevenueCat's `PaywallView` does not render product selection cards (subscription options). The paywall appears but shows empty space or "Missing Metadata" where the product cards should be.

**Symptoms:**
- PaywallView header/features display correctly
- Product cards (Weekly/Yearly/etc.) are invisible or show "Missing Metadata"
- Continue button appears but nothing to select
- Works fine on iOS 18 and earlier

## Root Cause

The issue is **NOT** iOS 26 Liquid Glass styling (despite initial suspicion).

The actual cause: **App Store Connect products with "Missing Metadata" status cannot be fetched by StoreKit**, even in development. RevenueCat's PaywallView fails silently when products can't be loaded.

Common reasons for "Missing Metadata":
1. Subscription products not in a subscription group
2. Missing localization (display name, description)
3. Missing pricing
4. Paid Applications Agreement not accepted
5. Products newly created and not yet propagated

## Solution: StoreKit Configuration File

Use a **StoreKit Configuration File** to simulate products locally during development, bypassing App Store Connect entirely.

### Step 1: Create StoreKit Configuration File

1. In Xcode: **File** → **New** → **File**
2. Search for "StoreKit Configuration File"
3. Name it `Products.storekit`
4. Save in your project directory

### Step 2: Add Products

**For Subscriptions:**
1. Click "+" → "Add Auto-Renewable Subscription Group"
2. Name the group (e.g., "App Subscriptions")
3. Click "+" on the group → "Add Auto-Renewable Subscription"
4. Fill in:
   - Reference Name (e.g., "Weekly")
   - Product ID (must match RevenueCat exactly, e.g., `app_weekly_299`)
   - Price (e.g., `2.99`)
   - Duration (e.g., `1 Week`)
   - Add localization with Display Name

**For Non-Consumables (Lifetime):**
1. Click "+" → "Add Non-Consumable In-App Purchase"
2. Fill in Product ID, Price, and localization

### Step 3: Enable in Scheme

1. **Product** → **Scheme** → **Edit Scheme** (⌘<)
2. Select **Run** on the left
3. Go to **Options** tab
4. Set **StoreKit Configuration** to your `.storekit` file

### Step 4: Run and Test

Products will now load from the local configuration file instead of App Store Connect.

## Example StoreKit Configuration

```json
{
  "subscriptionGroups": [
    {
      "name": "App Subscriptions",
      "subscriptions": [
        {
          "productID": "app_weekly_299",
          "displayPrice": "2.99",
          "recurringSubscriptionPeriod": "P1W",
          "localizations": [
            {
              "displayName": "Weekly",
              "locale": "en_US"
            }
          ]
        },
        {
          "productID": "app_yearly_1999",
          "displayPrice": "19.99",
          "recurringSubscriptionPeriod": "P1Y",
          "localizations": [
            {
              "displayName": "Yearly",
              "locale": "en_US"
            }
          ]
        }
      ]
    }
  ],
  "products": [
    {
      "productID": "app_lifetime",
      "displayPrice": "49.99",
      "type": "NonConsumable",
      "localizations": [
        {
          "displayName": "Lifetime Access",
          "locale": "en_US"
        }
      ]
    }
  ]
}
```

## Additional Tips

### Separate Offerings in RevenueCat

If you want to show only subscriptions (not lifetime) in the paywall:

1. Create a separate offering in RevenueCat (e.g., "subscriptions")
2. Add only subscription products to it
3. Fetch that specific offering in code:

```swift
let offerings = try await Purchases.shared.offerings()
let subscriptionOffering = offerings.offering(identifier: "subscriptions")
```

### Debug Logging

Add logging to see what offerings/packages are available:

```swift
#if DEBUG
print("Available offerings:")
for (id, offering) in offerings.all {
    print("  - \(id): \(offering.availablePackages.count) packages")
    for package in offering.availablePackages {
        print("    • \(package.identifier): \(package.storeProduct.productIdentifier)")
    }
}
#endif
```

### Console Warnings to Watch For

```
WARN: 🍎‼️ Could not find products with identifiers: ["product_id"]
```
This means StoreKit couldn't fetch the product - use StoreKit Configuration file.

```
Product Issues:
  ⚠️ product_id: This product's status (MISSING_METADATA) requires action
```
This confirms App Store Connect products aren't ready.

## When to Use This Solution

- During development when App Store Connect products aren't configured yet
- When testing on devices without sandbox accounts
- When you need screenshots of the paywall for App Store submission
- When App Store Connect is slow to propagate new products (can take 24-48 hours)

## References

- [RevenueCat: Configuring Products](https://errors.rev.cat/configuring-products)
- [Apple: Setting Up StoreKit Testing](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode)

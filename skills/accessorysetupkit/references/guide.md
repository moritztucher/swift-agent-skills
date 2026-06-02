# AccessorySetupKit Framework Guide for iOS Development

A comprehensive guide for discovering and pairing Bluetooth and WiFi accessories using AccessorySetupKit with modern Swift patterns (async/await, @Observable).

**Date Created:** February 2026
**iOS Version:** iOS 18.0+
**Framework Version:** AccessorySetupKit (introduced WWDC 2024)

---

## Table of Contents

1. [Overview and Use Cases](#overview-and-use-cases)
2. [Setup and Configuration](#setup-and-configuration)
3. [Core Concepts and APIs](#core-concepts-and-apis)
4. [Basic Implementation](#basic-implementation)
5. [Advanced Patterns](#advanced-patterns)
6. [Migration from CoreBluetooth](#migration-from-corebluetooth)
7. [WiFi Accessory Setup](#wifi-accessory-setup)
8. [SwiftUI Integration](#swiftui-integration)
9. [Best Practices](#best-practices)
10. [Common Pitfalls and Troubleshooting](#common-pitfalls-and-troubleshooting)
11. [iOS Version Compatibility](#ios-version-compatibility)

---

## Overview and Use Cases

AccessorySetupKit is Apple's framework for privacy-preserving discovery and configuration of Bluetooth and WiFi accessories. Introduced in iOS 18, it provides a streamlined pairing experience that eliminates complex permission prompts and custom device selection UI.

### Key Benefits

| Benefit | Description |
|---------|-------------|
| **Privacy-First** | Apps only get access to specific devices users explicitly approve |
| **One-Tap Pairing** | Unified picker UI with your custom accessory artwork |
| **No Permission Prompts** | Bluetooth/WiFi access granted per-accessory, not system-wide |
| **BLE Bond Control** | Programmatic control over BLE pairing and bonding lifecycle |
| **Automatic Reconnection** | System manages accessory persistence across app launches |
| **Background Support** | In iOS 26+, required for background Bluetooth servicing |

### Use Cases

- **IoT Device Pairing** - Smart home devices, sensors, wearables
- **Health Accessories** - Heart rate monitors, fitness trackers
- **Audio Devices** - Bluetooth speakers, headphones
- **Vehicle Accessories** - Car adapters, GPS trackers
- **Industrial Equipment** - Scanners, measurement tools

### How It Works

1. **Discovery** - Your app defines filter criteria (service UUIDs, name patterns)
2. **Authorization** - System displays a beautiful picker with your accessory artwork
3. **Communication** - After user selection, use CoreBluetooth/NetworkExtension as normal

---

## Setup and Configuration

### Entitlements

No special entitlements are required for AccessorySetupKit. The framework handles permissions at the accessory level.

### Info.plist Configuration

Add the following keys to your `Info.plist`:

```xml
<!-- Required: Specify supported connection types -->
<key>NSAccessorySetupKitSupports</key>
<array>
    <string>Bluetooth</string>
    <string>WiFi</string>
</array>

<!-- Required for Bluetooth: Service UUIDs your app will discover -->
<key>NSAccessorySetupBluetoothServices</key>
<array>
    <string>180D</string>  <!-- Heart Rate Service UUID (example) -->
    <string>YOUR-CUSTOM-UUID</string>
</array>

<!-- Optional: Bluetooth name substrings for discovery -->
<key>NSAccessorySetupBluetoothNames</key>
<array>
    <string>MyDevice</string>
    <string>Sensor</string>
</array>

<!-- Optional: Company identifiers for manufacturer-specific discovery -->
<key>NSAccessorySetupBluetoothCompanyIdentifiers</key>
<array>
    <integer>76</integer>  <!-- Apple's Company ID (example) -->
</array>

<!-- Optional: WiFi SSIDs your app will discover -->
<key>NSAccessorySetupWiFiSSIDs</key>
<array>
    <string>MyAccessory-Hotspot</string>
</array>
```

> **Important:** UUIDs must be UPPERCASE in Info.plist. Runtime discovery descriptors that don't match Info.plist declarations will cause the app to terminate.

### Do NOT Include Traditional Bluetooth Keys

When using AccessorySetupKit, do NOT add these keys to your Info.plist:

```xml
<!-- DO NOT ADD these when using AccessorySetupKit -->
<key>NSBluetoothAlwaysUsageDescription</key>
<key>NSBluetoothPeripheralUsageDescription</key>
```

By omitting these keys and declaring AccessorySetupKit support, your app gains access to CoreBluetooth functionality without standard permission prompts.

---

## Core Concepts and APIs

### ASAccessorySession

The central object for managing accessory discovery and lifecycle.

```swift
import AccessorySetupKit

@Observable
class AccessoryManager {
    private let session = ASAccessorySession()
    var accessories: [ASAccessory] = []
    var isSessionActive = false

    init() {
        activateSession()
    }
}
```

**Key Methods:**

| Method | Description |
|--------|-------------|
| `activate(on:eventHandler:)` | Activates the session on a dispatch queue |
| `showPicker(for:completionHandler:)` | Presents the accessory picker |
| `removeAccessory(_:completionHandler:)` | Removes an accessory and its bonds |
| `renameAccessory(_:options:completionHandler:)` | Displays the system rename UI for an accessory |
| `accessories` | Array of previously-selected accessories |

> **HID accessories (iOS 18.4+):** AccessorySetupKit can discover Bluetooth LE HID devices (keyboards, mice) that advertise a *custom* service alongside the HID service. Add `bluetoothHID` to the picker item's `setupOptions` and point the `ASDiscoveryDescriptor` at the custom service, not the HID service itself.

### ASPickerDisplayItem

Defines how an accessory appears in the picker UI.

```swift
import AccessorySetupKit
import CoreBluetooth

let displayItem: ASPickerDisplayItem = {
    // Create discovery descriptor
    let descriptor = ASDiscoveryDescriptor()
    descriptor.bluetoothServiceUUID = CBUUID(string: "180D")
    descriptor.bluetoothNameSubstring = "HeartSensor"

    // Create display item with your custom artwork
    return ASPickerDisplayItem(
        name: "Heart Rate Sensor",
        productImage: UIImage(named: "HeartRateSensor")!,
        descriptor: descriptor
    )
}()
```

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `name` | `String` | Display name shown in picker |
| `productImage` | `UIImage` | High-quality accessory image |
| `descriptor` | `ASDiscoveryDescriptor` | Discovery filter criteria |

### ASDiscoveryDescriptor

Defines the criteria used to discover accessories.

```swift
let descriptor = ASDiscoveryDescriptor()

// Bluetooth discovery options (use one or more)
descriptor.bluetoothServiceUUID = CBUUID(string: "180D")
descriptor.bluetoothNameSubstring = "MySensor"
descriptor.bluetoothCompanyIdentifier = ASBluetoothCompanyIdentifier(rawValue: 76)
descriptor.bluetoothManufacturerDataBlob = Data([0x01, 0x02])
descriptor.bluetoothServiceDataBlob = Data([0x03, 0x04])

// WiFi discovery options
descriptor.ssid = "MyAccessory-Hotspot"        // Exact match
// OR
descriptor.ssidPrefix = "MyAccessory-"          // Prefix match (not both!)
```

> **Note:** You cannot specify both `ssid` and `ssidPrefix` - the app will crash.

### ASAccessory

Represents a paired accessory with its connection identifiers.

```swift
let accessory: ASAccessory

// Bluetooth identifier for CoreBluetooth
if let bluetoothID = accessory.bluetoothIdentifier {
    let peripheral = centralManager.retrievePeripherals(withIdentifiers: [bluetoothID]).first
}

// WiFi SSID for NetworkExtension
if let ssid = accessory.ssid {
    // Use with NEHotspotConfiguration
}

// Other properties
let name = accessory.displayName
let state = accessory.state  // .authorized, .unauthorized
```

### ASAccessoryEvent and ASAccessoryEventType

Events delivered through the session's event handler.

```swift
enum ASAccessoryEventType {
    case activated          // Session activation completed
    case invalidated        // Session invalidated
    case migrationComplete  // Legacy accessories migrated
    case accessoryAdded     // New accessory paired
    case accessoryChanged   // Accessory properties changed
    case accessoryRemoved   // Accessory removed from system
    case pickerDidPresent   // Picker UI appeared
    case pickerDidDismiss   // Picker UI dismissed
}
```

### ASError

Error codes for AccessorySetupKit operations.

| Code | Name | Description |
|------|------|-------------|
| 0 | `success` | Operation completed successfully |
| 1 | `unknown` | Unknown error |
| 100 | `activationFailed` | Unable to activate session |
| 200 | `discoveryTimeout` | Discovery timed out |
| 300 | `extensionNotFound` | App Extension not found |
| 400 | `invalidated` | Session was invalidated |
| 700 | `userCancelled` | User dismissed the picker |
| 750 | `userRestricted` | Access restricted by user |

---

## Basic Implementation

### AccessoryManager with @Observable

```swift
import AccessorySetupKit
import CoreBluetooth
import OSLog

// MARK: - Accessory Errors

enum AccessoryError: LocalizedError {
    case sessionNotActive
    case pickerCancelled
    case discoveryFailed
    case noBluetoothIdentifier
    case peripheralNotFound

    var errorDescription: String? {
        switch self {
        case .sessionNotActive:
            return "Accessory session is not active"
        case .pickerCancelled:
            return "Accessory selection was cancelled"
        case .discoveryFailed:
            return "Failed to discover accessories"
        case .noBluetoothIdentifier:
            return "Accessory has no Bluetooth identifier"
        case .peripheralNotFound:
            return "Bluetooth peripheral not found"
        }
    }
}

// MARK: - AccessoryManager

@Observable
@MainActor
class AccessoryManager {
    private let session = ASAccessorySession()
    private let logger = Logger(subsystem: "com.example.app", category: "Accessories")

    // Published state
    var accessories: [ASAccessory] = []
    var isSessionActive = false
    var isPicking = false
    var error: AccessoryError?

    // Display items for picker
    private let heartRateSensorItem: ASPickerDisplayItem = {
        let descriptor = ASDiscoveryDescriptor()
        descriptor.bluetoothServiceUUID = CBUUID(string: "180D")
        descriptor.bluetoothNameSubstring = "HeartSensor"

        return ASPickerDisplayItem(
            name: "Heart Rate Sensor",
            productImage: UIImage(named: "HeartRateSensor")!,
            descriptor: descriptor
        )
    }()

    init() {
        activateSession()
    }

    // MARK: - Session Management

    private func activateSession() {
        session.activate(on: DispatchQueue.main) { [weak self] event in
            Task { @MainActor in
                self?.handleEvent(event)
            }
        }
    }

    private func handleEvent(_ event: ASAccessoryEvent) {
        logger.info("Received event: \(String(describing: event.eventType))")

        switch event.eventType {
        case .activated:
            isSessionActive = true
            accessories = session.accessories
            logger.info("Session activated with \(self.accessories.count) accessories")

        case .invalidated:
            isSessionActive = false
            logger.warning("Session invalidated")

        case .accessoryAdded:
            if let accessory = event.accessory {
                accessories.append(accessory)
                logger.info("Accessory added: \(accessory.displayName)")
            }

        case .accessoryChanged:
            if let accessory = event.accessory,
               let index = accessories.firstIndex(where: { $0.bluetoothIdentifier == accessory.bluetoothIdentifier }) {
                accessories[index] = accessory
                logger.info("Accessory changed: \(accessory.displayName)")
            }

        case .accessoryRemoved:
            if let accessory = event.accessory {
                accessories.removeAll { $0.bluetoothIdentifier == accessory.bluetoothIdentifier }
                logger.info("Accessory removed: \(accessory.displayName)")
            }

        case .pickerDidPresent:
            isPicking = true

        case .pickerDidDismiss:
            isPicking = false

        case .migrationComplete:
            accessories = session.accessories
            logger.info("Migration complete")

        @unknown default:
            logger.warning("Unknown event type")
        }
    }

    // MARK: - Picker

    func showAccessoryPicker() async throws {
        guard isSessionActive else {
            throw AccessoryError.sessionNotActive
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.showPicker(for: [heartRateSensorItem]) { error in
                if let error = error {
                    // Error code 700 = user cancelled
                    if (error as NSError).code == 700 {
                        continuation.resume(throwing: AccessoryError.pickerCancelled)
                    } else {
                        continuation.resume(throwing: error)
                    }
                } else {
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Accessory Management

    func removeAccessory(_ accessory: ASAccessory) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.removeAccessory(accessory) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
```

### Connecting with CoreBluetooth

After pairing, use the `bluetoothIdentifier` to get the `CBPeripheral`:

```swift
import CoreBluetooth

@Observable
class BluetoothAccessoryManager: NSObject {
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?

    var isConnected = false
    var connectionState: CBPeripheralState = .disconnected

    override init() {
        super.init()
        // Important: CBCentralManager state is .poweredOn only when you have paired accessories
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func connect(to accessory: ASAccessory) throws {
        guard let bluetoothID = accessory.bluetoothIdentifier else {
            throw AccessoryError.noBluetoothIdentifier
        }

        // Retrieve the peripheral using the identifier from AccessorySetupKit
        guard let peripheral = centralManager.retrievePeripherals(withIdentifiers: [bluetoothID]).first else {
            throw AccessoryError.peripheralNotFound
        }

        connectedPeripheral = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }

    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothAccessoryManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            // Ready to connect to paired accessories
            print("Bluetooth powered on")
        case .poweredOff:
            isConnected = false
            print("Bluetooth powered off")
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        connectionState = peripheral.state
        // Discover services
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        if let error = error {
            print("Failed to connect: \(error.localizedDescription)")
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        connectionState = .disconnected
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothAccessoryManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else { return }

        for service in peripheral.services ?? [] {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else { return }

        for characteristic in service.characteristics ?? [] {
            if characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
            if characteristic.properties.contains(.read) {
                peripheral.readValue(for: characteristic)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let data = characteristic.value else { return }
        // Process characteristic data
        print("Received data: \(data)")
    }
}
```

---

## Advanced Patterns

### Multiple Accessory Types

Support different accessory types with separate display items:

```swift
@Observable
@MainActor
class MultiAccessoryManager {
    private let session = ASAccessorySession()

    // Different accessory types
    private let heartRateSensor: ASPickerDisplayItem = {
        let descriptor = ASDiscoveryDescriptor()
        descriptor.bluetoothServiceUUID = CBUUID(string: "180D")
        return ASPickerDisplayItem(
            name: "Heart Rate Sensor",
            productImage: UIImage(named: "HeartRateSensor")!,
            descriptor: descriptor
        )
    }()

    private let temperatureSensor: ASPickerDisplayItem = {
        let descriptor = ASDiscoveryDescriptor()
        descriptor.bluetoothServiceUUID = CBUUID(string: "1809")
        return ASPickerDisplayItem(
            name: "Temperature Sensor",
            productImage: UIImage(named: "TempSensor")!,
            descriptor: descriptor
        )
    }()

    private let fitnessBand: ASPickerDisplayItem = {
        let descriptor = ASDiscoveryDescriptor()
        descriptor.bluetoothNameSubstring = "FitBand"
        descriptor.bluetoothServiceUUID = CBUUID(string: "180F") // Battery Service
        return ASPickerDisplayItem(
            name: "Fitness Band",
            productImage: UIImage(named: "FitnessBand")!,
            descriptor: descriptor
        )
    }()

    /// Show picker with all accessory types
    func showAllAccessoriesPicker() async throws {
        let items = [heartRateSensor, temperatureSensor, fitnessBand]

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.showPicker(for: items) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// Show picker for specific accessory type
    func showPicker(for type: AccessoryType) async throws {
        let item: ASPickerDisplayItem
        switch type {
        case .heartRate:
            item = heartRateSensor
        case .temperature:
            item = temperatureSensor
        case .fitness:
            item = fitnessBand
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.showPicker(for: [item]) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

enum AccessoryType {
    case heartRate
    case temperature
    case fitness
}
```

### Manufacturer Data Filtering

For more precise device discovery using manufacturer-specific data:

```swift
let descriptor = ASDiscoveryDescriptor()

// Filter by company identifier
descriptor.bluetoothCompanyIdentifier = ASBluetoothCompanyIdentifier(rawValue: 76) // Apple

// Filter by manufacturer data blob (specific bytes in advertising data)
descriptor.bluetoothManufacturerDataBlob = Data([0x01, 0x02, 0x03])

// Mask for partial matching (optional)
descriptor.bluetoothManufacturerDataMask = Data([0xFF, 0xFF, 0x00]) // Match first 2 bytes
```

### Reconnecting to Known Accessories

Handle app relaunch and reconnect to previously paired accessories:

```swift
@Observable
@MainActor
class PersistentAccessoryManager {
    private let session = ASAccessorySession()
    private var bluetoothManager: BluetoothAccessoryManager?

    var pairedAccessories: [ASAccessory] = []

    init() {
        activateSession()
    }

    private func activateSession() {
        session.activate(on: DispatchQueue.main) { [weak self] event in
            Task { @MainActor in
                self?.handleEvent(event)
            }
        }
    }

    private func handleEvent(_ event: ASAccessoryEvent) {
        switch event.eventType {
        case .activated:
            // Restore previously paired accessories
            pairedAccessories = session.accessories
            reconnectToAllAccessories()

        case .accessoryAdded:
            if let accessory = event.accessory {
                pairedAccessories.append(accessory)
                Task {
                    await reconnect(to: accessory)
                }
            }

        default:
            break
        }
    }

    private func reconnectToAllAccessories() {
        for accessory in pairedAccessories {
            Task {
                await reconnect(to: accessory)
            }
        }
    }

    private func reconnect(to accessory: ASAccessory) async {
        guard let bluetoothID = accessory.bluetoothIdentifier else { return }

        // Initialize Bluetooth manager if needed
        if bluetoothManager == nil {
            bluetoothManager = BluetoothAccessoryManager()
        }

        // Wait for Bluetooth to be ready
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        do {
            try bluetoothManager?.connect(to: accessory)
        } catch {
            print("Failed to reconnect to \(accessory.displayName): \(error)")
        }
    }
}
```

---

## Migration from CoreBluetooth

If your app already uses CoreBluetooth for accessory management, use `ASMigrationDisplayItem` to migrate existing devices:

```swift
import AccessorySetupKit
import CoreBluetooth

@Observable
@MainActor
class MigrationManager {
    private let session = ASAccessorySession()

    /// Migrate existing CoreBluetooth peripherals to AccessorySetupKit
    func migrateExistingAccessories(peripheralUUIDs: [UUID]) async throws {
        var migrationItems: [ASMigrationDisplayItem] = []

        for uuid in peripheralUUIDs {
            let descriptor = ASDiscoveryDescriptor()
            descriptor.bluetoothServiceUUID = CBUUID(string: "180D") // Your service UUID

            // Create migration item with existing peripheral UUID
            let migrationItem = ASMigrationDisplayItem(
                name: "Heart Rate Sensor",
                productImage: UIImage(named: "HeartRateSensor")!,
                descriptor: descriptor,
                peripheralIdentifier: uuid
            )

            migrationItems.append(migrationItem)
        }

        // Show picker with migration items
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.showPicker(for: migrationItems) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// Migrate WiFi accessory by SSID
    func migrateWiFiAccessory(ssid: String) async throws {
        let descriptor = ASDiscoveryDescriptor()
        descriptor.ssid = ssid

        let migrationItem = ASMigrationDisplayItem(
            name: "WiFi Accessory",
            productImage: UIImage(named: "WiFiAccessory")!,
            descriptor: descriptor,
            hotspotSSID: ssid
        )

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.showPicker(for: [migrationItem]) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
```

### Migration Workflow

1. **Identify Existing Devices** - Get peripheral UUIDs from your existing CoreBluetooth implementation
2. **Create Migration Items** - Use `ASMigrationDisplayItem` with the peripheral identifiers
3. **Show Picker** - User confirms migration in the picker UI
4. **Handle Migration Complete** - `migrationComplete` event indicates success
5. **Remove Legacy Code** - Update to use AccessorySetupKit-managed accessories

---

## WiFi Accessory Setup

For accessories that broadcast WiFi hotspots:

```swift
import AccessorySetupKit
import NetworkExtension

@Observable
@MainActor
class WiFiAccessoryManager {
    private let session = ASAccessorySession()

    private let wifiAccessoryItem: ASPickerDisplayItem = {
        let descriptor = ASDiscoveryDescriptor()
        // Exact SSID match
        descriptor.ssid = "MyAccessory-Hotspot"
        // OR prefix match (not both!)
        // descriptor.ssidPrefix = "MyAccessory-"

        return ASPickerDisplayItem(
            name: "WiFi Accessory",
            productImage: UIImage(named: "WiFiAccessory")!,
            descriptor: descriptor
        )
    }()

    func showWiFiAccessoryPicker() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.showPicker(for: [wifiAccessoryItem]) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// Connect to WiFi hotspot after pairing
    func connectToHotspot(_ accessory: ASAccessory, password: String) async throws {
        guard let ssid = accessory.ssid else {
            throw AccessoryError.noWiFiSSID
        }

        let configuration = NEHotspotConfiguration(ssid: ssid, passphrase: password, isWEP: false)

        try await NEHotspotConfigurationManager.shared.apply(configuration)
    }
}

extension AccessoryError {
    static let noWiFiSSID = AccessoryError.discoveryFailed
}
```

### Combined Bluetooth + WiFi Accessories

For accessories that use both Bluetooth and WiFi:

```swift
let combinedDescriptor = ASDiscoveryDescriptor()
combinedDescriptor.bluetoothServiceUUID = CBUUID(string: "180D")
combinedDescriptor.bluetoothNameSubstring = "SmartDevice"
combinedDescriptor.ssidPrefix = "SmartDevice-"  // WiFi hotspot prefix

let displayItem = ASPickerDisplayItem(
    name: "Smart Device",
    productImage: UIImage(named: "SmartDevice")!,
    descriptor: combinedDescriptor
)
```

> **Note:** The dynamic SSID challenge - if your WiFi SSID is only known after BLE pairing, you'll need to handle this in two steps: first BLE pairing, then WiFi connection using `NEHotspotConfiguration`.

---

## SwiftUI Integration

### AccessoryPairingView

```swift
import SwiftUI
import AccessorySetupKit

struct AccessoryPairingView: View {
    @State private var accessoryManager = AccessoryManager()
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Paired Accessories") {
                    if accessoryManager.accessories.isEmpty {
                        ContentUnavailableView(
                            "No Accessories",
                            systemImage: "antenna.radiowaves.left.and.right.slash",
                            description: Text("Tap the button below to add an accessory")
                        )
                    } else {
                        ForEach(accessoryManager.accessories, id: \.bluetoothIdentifier) { accessory in
                            AccessoryRow(accessory: accessory)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        removeAccessory(accessory)
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle("Accessories")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        addAccessory()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(!accessoryManager.isSessionActive || accessoryManager.isPicking)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func addAccessory() {
        Task {
            do {
                try await accessoryManager.showAccessoryPicker()
            } catch AccessoryError.pickerCancelled {
                // User cancelled, do nothing
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func removeAccessory(_ accessory: ASAccessory) {
        Task {
            do {
                try await accessoryManager.removeAccessory(accessory)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

struct AccessoryRow: View {
    let accessory: ASAccessory

    var body: some View {
        HStack {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .foregroundStyle(.blue)
                .font(.title2)

            VStack(alignment: .leading) {
                Text(accessory.displayName)
                    .font(.headline)

                Text(accessory.state == .authorized ? "Connected" : "Not Connected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Circle()
                .fill(accessory.state == .authorized ? .green : .gray)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    AccessoryPairingView()
}
```

### Environment Integration

```swift
import SwiftUI

@main
struct MyApp: App {
    @State private var accessoryManager = AccessoryManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(accessoryManager)
        }
    }
}

struct ContentView: View {
    @Environment(AccessoryManager.self) private var accessoryManager

    var body: some View {
        // Use accessoryManager
    }
}
```

---

## Best Practices

### 1. Session Lifecycle

```swift
// Activate session early (e.g., in init or app launch)
// Keep session alive for the app's lifetime
// Handle .activated and .invalidated events properly

@Observable
@MainActor
class AccessoryManager {
    private let session = ASAccessorySession()

    init() {
        // Activate immediately
        session.activate(on: DispatchQueue.main) { [weak self] event in
            Task { @MainActor in
                self?.handleEvent(event)
            }
        }
    }
}
```

### 2. High-Quality Artwork

- Use high-resolution images (at least 300x300 points)
- Provide @2x and @3x scale images
- Use transparent backgrounds
- Match your brand's visual identity

### 3. Descriptive Names

```swift
// Good - clear and descriptive
ASPickerDisplayItem(name: "Heart Rate Monitor Pro", ...)

// Bad - generic
ASPickerDisplayItem(name: "Device", ...)
```

### 4. Error Handling

```swift
func showPicker() async {
    do {
        try await accessoryManager.showAccessoryPicker()
    } catch AccessoryError.pickerCancelled {
        // User cancelled - silently ignore
    } catch AccessoryError.sessionNotActive {
        // Reactivate session
        activateSession()
    } catch {
        // Show error to user
        showError(error)
    }
}
```

### 5. Reconnection Strategy

```swift
// On .activated event, restore connections
private func handleEvent(_ event: ASAccessoryEvent) {
    switch event.eventType {
    case .activated:
        for accessory in session.accessories {
            reconnect(to: accessory)
        }
    // ...
    }
}
```

### 6. Discovery Descriptor Specificity

```swift
// More specific = fewer false positives
let descriptor = ASDiscoveryDescriptor()
descriptor.bluetoothServiceUUID = CBUUID(string: "YOUR-SPECIFIC-UUID")
descriptor.bluetoothNameSubstring = "YourProduct"
descriptor.bluetoothCompanyIdentifier = ASBluetoothCompanyIdentifier(rawValue: yourCompanyID)
```

---

## Common Pitfalls and Troubleshooting

### App Crashes on Picker Display

**Cause:** Info.plist doesn't match runtime discovery descriptors.

**Solution:** Ensure all UUIDs, names, and SSIDs in `ASDiscoveryDescriptor` are declared in Info.plist.

```xml
<!-- Must match descriptor.bluetoothServiceUUID -->
<key>NSAccessorySetupBluetoothServices</key>
<array>
    <string>180D</string>  <!-- Must be UPPERCASE -->
</array>
```

### CBCentralManager Never Powers On

**Cause:** No paired accessories exist yet.

**Solution:** With AccessorySetupKit, `CBCentralManager.state` only becomes `.poweredOn` when you have paired accessories. This is expected behavior.

```swift
func centralManagerDidUpdateState(_ central: CBCentralManager) {
    // .poweredOn only when paired accessories exist
    if central.state == .poweredOn {
        // Can now retrieve and connect to paired peripherals
    }
}
```

### Accessories Not Appearing in Picker

**Causes:**
1. Device not advertising the declared service UUID
2. Name substring doesn't match
3. Device already paired

**Solutions:**
1. Verify device advertising data matches your discovery descriptor
2. Check device name contains the substring (case-sensitive)
3. Remove existing pairing in Settings > Bluetooth

### scanForPeripherals Returns Nothing

**Cause:** AccessorySetupKit changes CoreBluetooth behavior.

**Solution:** With AccessorySetupKit, `scanForPeripherals` only returns previously authorized AND discoverable devices. Use the picker for new device discovery.

```swift
// Only for reconnecting to known devices
centralManager.scanForPeripherals(withServices: [serviceUUID])
```

### Cannot Connect After Factory Reset

**Cause:** BLE bond persists but device has new address.

**Solution:** In iOS 26+, `removeAccessory()` shows a confirmation dialog. Handle this gracefully:

```swift
func handleDeviceReset() async throws {
    // Remove old accessory
    if let oldAccessory = findAccessory(byName: "DeviceName") {
        try await accessoryManager.removeAccessory(oldAccessory)
    }

    // Re-pair the device
    try await accessoryManager.showAccessoryPicker()
}
```

### Picker Dismisses Immediately (Error 550)

**Cause:** Invalid display item configuration.

**Solution:** Ensure:
- Product image is non-nil and valid
- Discovery descriptor has required properties
- Name is non-empty

### Simulator Doesn't Work

**Note:** AccessorySetupKit does NOT work on the iOS Simulator. Test on physical devices only.

---

## iOS Version Compatibility

### iOS 18.0+

- AccessorySetupKit introduced
- Basic Bluetooth and WiFi accessory pairing
- `ASAccessorySession`, `ASPickerDisplayItem`, `ASDiscoveryDescriptor`

### iOS 26.0+ (Important Changes)

1. **Background Bluetooth Requirement**
   - Only apps using AccessorySetupKit can be relaunched for background Bluetooth servicing
   - Legacy CoreBluetooth-only apps lose background capabilities

2. **removeAccessory() Confirmation**
   - New confirmation dialog when calling `removeAccessory()`
   - May require UX adjustments for factory reset flows

3. **WiFiAware Support**
   - New `wifiAwareVendorNameMatch` property on `ASPropertyCompareString`
   - Integration with WiFiAware framework

### Migration Timeline

If you have an existing CoreBluetooth-based app:

1. **iOS 18-25:** Both AccessorySetupKit and legacy CoreBluetooth work
2. **iOS 26+:** Migrate to AccessorySetupKit for background Bluetooth support

```swift
@available(iOS 18.0, *)
func checkBackgroundSupport() -> Bool {
    if #available(iOS 26.0, *) {
        // Must use AccessorySetupKit for background Bluetooth
        return accessoryManager.isSessionActive && !accessoryManager.accessories.isEmpty
    } else {
        // Legacy CoreBluetooth still works
        return true
    }
}
```

---

## References

- [AccessorySetupKit - Apple Developer Documentation](https://developer.apple.com/documentation/accessorysetupkit)
- [Meet AccessorySetupKit - WWDC24](https://developer.apple.com/videos/play/wwdc2024/10203/)
- [Discovering and configuring accessories - Apple Developer](https://developer.apple.com/documentation/accessorysetupkit/discovering-and-configuring-accessories)
- [ASAccessorySession - Apple Developer Documentation](https://developer.apple.com/documentation/accessorysetupkit/asaccessorysession)
- [iOS 18 AccessorySetupKit: Everything BLE Developers Need To Know - Punch Through](https://punchthrough.com/ios18-accessorysetupkit-everything-ble-developers-need-to-know/)

---

## Related Documentation

- [CoreBluetooth Guide](../hardware/corebluetooth-guide.md) - For low-level BLE communication after pairing
- [WiFiAware Guide](../hardware/wifiaware-guide.md) - For peer-to-peer WiFi networking (iOS 26+)

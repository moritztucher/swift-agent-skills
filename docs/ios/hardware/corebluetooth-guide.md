# CoreBluetooth Framework Guide for iOS Development

A comprehensive guide to implementing Bluetooth Low Energy (BLE) communication in iOS apps using CoreBluetooth with modern Swift patterns.

---

## Table of Contents

1. [Overview and Purpose](#overview-and-purpose)
2. [Setup and Permissions](#setup-and-permissions)
3. [Core Concepts](#core-concepts)
4. [Central Role Implementation](#central-role-implementation)
5. [Peripheral Role Implementation](#peripheral-role-implementation)
6. [Services and Characteristics](#services-and-characteristics)
7. [Reading and Writing Characteristic Values](#reading-and-writing-characteristic-values)
8. [Notifications and Indications](#notifications-and-indications)
9. [SwiftUI Integration Patterns](#swiftui-integration-patterns)
10. [iOS 18/26 Specific Features](#ios-1826-specific-features)
11. [Common Use Cases](#common-use-cases)
12. [Best Practices and Battery Optimization](#best-practices-and-battery-optimization)

---

## Overview and Purpose

CoreBluetooth is Apple's framework for communicating with Bluetooth Low Energy (BLE) devices. It enables iOS apps to:

- **Discover** nearby BLE peripherals (sensors, wearables, IoT devices)
- **Connect** to peripherals and maintain connections
- **Read/Write** data to peripheral characteristics
- **Receive** real-time notifications from peripherals
- **Act as a peripheral** to broadcast data to other devices

### Key Components

| Component | Description |
|-----------|-------------|
| `CBCentralManager` | Scans for, discovers, connects to, and manages peripherals |
| `CBPeripheral` | Represents a remote peripheral device |
| `CBPeripheralManager` | Manages and advertises local peripheral services |
| `CBService` | A collection of data and behaviors for a peripheral feature |
| `CBCharacteristic` | A characteristic of a service containing actual data |
| `CBUUID` | Universally unique identifier for services and characteristics |

---

## Setup and Permissions

### Info.plist Configuration

Add these keys to your `Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to connect to nearby devices for data synchronization.</string>

<!-- Optional: For backward compatibility with iOS 12 and earlier -->
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app uses Bluetooth to connect to nearby devices for data synchronization.</string>
```

> **Note:** `NSBluetoothPeripheralUsageDescription` is deprecated for iOS 13+. Use `NSBluetoothAlwaysUsageDescription` for all new projects.

### Background Mode Configuration

For apps that need Bluetooth in the background, add to `Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>    <!-- For central role -->
    <string>bluetooth-peripheral</string> <!-- For peripheral role -->
</array>
```

Or in Xcode: Target > Signing & Capabilities > + Background Modes > Check "Uses Bluetooth LE accessories"

### Authorization Check

```swift
import CoreBluetooth

func checkBluetoothAuthorization() -> CBManagerAuthorization {
    return CBCentralManager.authorization
}

func isBluetoothAuthorized() -> Bool {
    switch CBCentralManager.authorization {
    case .allowedAlways:
        return true
    case .denied, .restricted:
        return false
    case .notDetermined:
        return false // Will prompt when CBCentralManager is initialized
    @unknown default:
        return false
    }
}
```

---

## Core Concepts

### CBCentralManager

The central manager is the main object for discovering and connecting to BLE peripherals.

**States:**

| State | Description |
|-------|-------------|
| `.poweredOn` | Bluetooth is enabled, authorized, and ready |
| `.poweredOff` | Bluetooth is turned off by the user |
| `.unauthorized` | App is not authorized to use Bluetooth |
| `.unsupported` | Device does not support BLE |
| `.resetting` | Bluetooth connection was momentarily lost |
| `.unknown` | State is unknown (initial state) |

### CBPeripheral

Represents a discovered remote BLE device. Key properties:

- `identifier`: UUID assigned by iOS (not the actual MAC address)
- `name`: Device's advertised name (optional)
- `state`: Connection state (`.disconnected`, `.connecting`, `.connected`, `.disconnecting`)
- `services`: Discovered services after connection

> **Important:** iOS obscures the actual MAC address for privacy. Use `identifier` (UUID) to identify peripherals, but note this UUID may change if the system is reset.

### CBPeripheralManager

Used when your app acts as a BLE peripheral (broadcaster). Manages:

- Local services and characteristics
- Advertising to other devices
- Responding to read/write requests from centrals

---

## Central Role Implementation

### BluetoothManager with @Observable

```swift
import CoreBluetooth
import Foundation

// MARK: - Bluetooth Errors

enum BluetoothError: LocalizedError {
    case bluetoothUnavailable
    case bluetoothUnauthorized
    case peripheralNotFound
    case connectionFailed
    case serviceNotFound
    case characteristicNotFound
    case readFailed
    case writeFailed
    case notificationFailed

    var errorDescription: String? {
        switch self {
        case .bluetoothUnavailable:
            return "Bluetooth is not available on this device"
        case .bluetoothUnauthorized:
            return "Bluetooth access is not authorized"
        case .peripheralNotFound:
            return "The requested peripheral was not found"
        case .connectionFailed:
            return "Failed to connect to the peripheral"
        case .serviceNotFound:
            return "The requested service was not found"
        case .characteristicNotFound:
            return "The requested characteristic was not found"
        case .readFailed:
            return "Failed to read characteristic value"
        case .writeFailed:
            return "Failed to write characteristic value"
        case .notificationFailed:
            return "Failed to enable notifications"
        }
    }
}

// MARK: - Discovered Peripheral Model

struct DiscoveredPeripheral: Identifiable, Hashable {
    let id: UUID
    let peripheral: CBPeripheral
    let advertisementData: [String: Any]
    let rssi: Int

    var name: String {
        peripheral.name ?? "Unknown Device"
    }

    static func == (lhs: DiscoveredPeripheral, rhs: DiscoveredPeripheral) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Bluetooth Manager

@Observable
final class BluetoothManager: NSObject {

    // MARK: - Properties

    private(set) var centralManager: CBCentralManager!
    private(set) var isBluetoothReady = false
    private(set) var isScanning = false
    private(set) var discoveredPeripherals: [DiscoveredPeripheral] = []
    private(set) var connectedPeripheral: CBPeripheral?
    private(set) var discoveredServices: [CBService] = []
    private(set) var discoveredCharacteristics: [CBUUID: [CBCharacteristic]] = [:]

    // Continuations for async/await
    private var stateReadyContinuation: CheckedContinuation<Void, Error>?
    private var connectionContinuation: CheckedContinuation<CBPeripheral, Error>?
    private var serviceDiscoveryContinuation: CheckedContinuation<[CBService], Error>?
    private var characteristicDiscoveryContinuation: CheckedContinuation<[CBCharacteristic], Error>?
    private var readValueContinuation: CheckedContinuation<Data, Error>?
    private var writeValueContinuation: CheckedContinuation<Void, Error>?
    private var notificationContinuation: CheckedContinuation<Void, Error>?

    // Service UUIDs to scan for (nil = scan for all)
    private var scanServiceUUIDs: [CBUUID]?

    // MARK: - Initialization

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    /// Initialize with state restoration support for background processing
    init(restoreIdentifier: String) {
        super.init()
        centralManager = CBCentralManager(
            delegate: self,
            queue: nil,
            options: [CBCentralManagerOptionRestoreIdentifierKey: restoreIdentifier]
        )
    }

    // MARK: - Public Methods

    /// Wait for Bluetooth to be ready
    func waitForBluetoothReady() async throws {
        if isBluetoothReady { return }

        try await withCheckedThrowingContinuation { continuation in
            stateReadyContinuation = continuation
        }
    }

    /// Start scanning for peripherals
    func startScanning(forServices serviceUUIDs: [CBUUID]? = nil) async throws {
        try await waitForBluetoothReady()

        scanServiceUUIDs = serviceUUIDs
        discoveredPeripherals.removeAll()

        centralManager.scanForPeripherals(
            withServices: serviceUUIDs,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        isScanning = true
    }

    /// Stop scanning for peripherals
    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
    }

    /// Connect to a peripheral
    func connect(to peripheral: CBPeripheral) async throws -> CBPeripheral {
        try await waitForBluetoothReady()

        return try await withCheckedThrowingContinuation { continuation in
            connectionContinuation = continuation
            centralManager.connect(peripheral, options: nil)
        }
    }

    /// Disconnect from a peripheral
    func disconnect(from peripheral: CBPeripheral) {
        centralManager.cancelPeripheralConnection(peripheral)
    }

    /// Discover services on a connected peripheral
    func discoverServices(_ serviceUUIDs: [CBUUID]? = nil, on peripheral: CBPeripheral) async throws -> [CBService] {
        peripheral.delegate = self

        return try await withCheckedThrowingContinuation { continuation in
            serviceDiscoveryContinuation = continuation
            peripheral.discoverServices(serviceUUIDs)
        }
    }

    /// Discover characteristics for a service
    func discoverCharacteristics(
        _ characteristicUUIDs: [CBUUID]? = nil,
        for service: CBService,
        on peripheral: CBPeripheral
    ) async throws -> [CBCharacteristic] {
        peripheral.delegate = self

        return try await withCheckedThrowingContinuation { continuation in
            characteristicDiscoveryContinuation = continuation
            peripheral.discoverCharacteristics(characteristicUUIDs, for: service)
        }
    }

    /// Read value from a characteristic
    func readValue(for characteristic: CBCharacteristic, on peripheral: CBPeripheral) async throws -> Data {
        peripheral.delegate = self

        return try await withCheckedThrowingContinuation { continuation in
            readValueContinuation = continuation
            peripheral.readValue(for: characteristic)
        }
    }

    /// Write value to a characteristic
    func writeValue(
        _ data: Data,
        for characteristic: CBCharacteristic,
        on peripheral: CBPeripheral,
        type: CBCharacteristicWriteType = .withResponse
    ) async throws {
        peripheral.delegate = self

        if type == .withResponse {
            try await withCheckedThrowingContinuation { continuation in
                writeValueContinuation = continuation
                peripheral.writeValue(data, for: characteristic, type: type)
            }
        } else {
            peripheral.writeValue(data, for: characteristic, type: type)
        }
    }

    /// Enable or disable notifications for a characteristic
    func setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristic, on peripheral: CBPeripheral) async throws {
        peripheral.delegate = self

        try await withCheckedThrowingContinuation { continuation in
            notificationContinuation = continuation
            peripheral.setNotifyValue(enabled, for: characteristic)
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            isBluetoothReady = true
            stateReadyContinuation?.resume()
            stateReadyContinuation = nil

        case .poweredOff:
            isBluetoothReady = false
            stateReadyContinuation?.resume(throwing: BluetoothError.bluetoothUnavailable)
            stateReadyContinuation = nil

        case .unauthorized:
            isBluetoothReady = false
            stateReadyContinuation?.resume(throwing: BluetoothError.bluetoothUnauthorized)
            stateReadyContinuation = nil

        case .unsupported:
            isBluetoothReady = false
            stateReadyContinuation?.resume(throwing: BluetoothError.bluetoothUnavailable)
            stateReadyContinuation = nil

        case .resetting, .unknown:
            isBluetoothReady = false

        @unknown default:
            isBluetoothReady = false
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let discovered = DiscoveredPeripheral(
            id: peripheral.identifier,
            peripheral: peripheral,
            advertisementData: advertisementData,
            rssi: RSSI.intValue
        )

        // Update existing or add new
        if let index = discoveredPeripherals.firstIndex(where: { $0.id == peripheral.identifier }) {
            discoveredPeripherals[index] = discovered
        } else {
            discoveredPeripherals.append(discovered)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        connectionContinuation?.resume(returning: peripheral)
        connectionContinuation = nil
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionContinuation?.resume(throwing: error ?? BluetoothError.connectionFailed)
        connectionContinuation = nil
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if connectedPeripheral?.identifier == peripheral.identifier {
            connectedPeripheral = nil
            discoveredServices.removeAll()
            discoveredCharacteristics.removeAll()
        }
    }

    // State restoration
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for peripheral in peripherals {
                peripheral.delegate = self
                if peripheral.state == .connected {
                    connectedPeripheral = peripheral
                }
            }
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            serviceDiscoveryContinuation?.resume(throwing: error)
        } else {
            let services = peripheral.services ?? []
            discoveredServices = services
            serviceDiscoveryContinuation?.resume(returning: services)
        }
        serviceDiscoveryContinuation = nil
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            characteristicDiscoveryContinuation?.resume(throwing: error)
        } else {
            let characteristics = service.characteristics ?? []
            discoveredCharacteristics[service.uuid] = characteristics
            characteristicDiscoveryContinuation?.resume(returning: characteristics)
        }
        characteristicDiscoveryContinuation = nil
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            readValueContinuation?.resume(throwing: error)
        } else if let data = characteristic.value {
            readValueContinuation?.resume(returning: data)
        } else {
            readValueContinuation?.resume(throwing: BluetoothError.readFailed)
        }
        readValueContinuation = nil
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            writeValueContinuation?.resume(throwing: error)
        } else {
            writeValueContinuation?.resume()
        }
        writeValueContinuation = nil
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            notificationContinuation?.resume(throwing: error)
        } else {
            notificationContinuation?.resume()
        }
        notificationContinuation = nil
    }
}
```

---

## Peripheral Role Implementation

### PeripheralManager with @Observable

```swift
import CoreBluetooth
import Foundation

// MARK: - Peripheral Manager

@Observable
final class PeripheralManager: NSObject {

    // MARK: - Properties

    private(set) var peripheralManager: CBPeripheralManager!
    private(set) var isAdvertising = false
    private(set) var isReady = false
    private(set) var subscribedCentrals: [CBCentral] = []

    private var services: [CBMutableService] = []
    private var characteristics: [CBUUID: CBMutableCharacteristic] = [:]

    // Continuations
    private var stateReadyContinuation: CheckedContinuation<Void, Error>?
    private var addServiceContinuation: CheckedContinuation<Void, Error>?

    // Callback for handling write requests
    var onWriteRequest: ((CBATTRequest) -> Data?)?
    var onReadRequest: ((CBATTRequest) -> Data?)?

    // MARK: - Initialization

    override init() {
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }

    // MARK: - Public Methods

    /// Wait for peripheral manager to be ready
    func waitForReady() async throws {
        if isReady { return }

        try await withCheckedThrowingContinuation { continuation in
            stateReadyContinuation = continuation
        }
    }

    /// Create and add a service with characteristics
    func addService(
        uuid: CBUUID,
        characteristics: [CharacteristicDefinition],
        isPrimary: Bool = true
    ) async throws {
        try await waitForReady()

        let service = CBMutableService(type: uuid, primary: isPrimary)

        var cbCharacteristics: [CBMutableCharacteristic] = []

        for definition in characteristics {
            let characteristic = CBMutableCharacteristic(
                type: definition.uuid,
                properties: definition.properties,
                value: nil, // Dynamic value
                permissions: definition.permissions
            )
            cbCharacteristics.append(characteristic)
            self.characteristics[definition.uuid] = characteristic
        }

        service.characteristics = cbCharacteristics
        services.append(service)

        try await withCheckedThrowingContinuation { continuation in
            addServiceContinuation = continuation
            peripheralManager.add(service)
        }
    }

    /// Start advertising
    func startAdvertising(localName: String? = nil, serviceUUIDs: [CBUUID]? = nil) async throws {
        try await waitForReady()

        var advertisementData: [String: Any] = [:]

        if let localName = localName {
            advertisementData[CBAdvertisementDataLocalNameKey] = localName
        }

        if let serviceUUIDs = serviceUUIDs {
            advertisementData[CBAdvertisementDataServiceUUIDsKey] = serviceUUIDs
        }

        peripheralManager.startAdvertising(advertisementData)
        isAdvertising = true
    }

    /// Stop advertising
    func stopAdvertising() {
        peripheralManager.stopAdvertising()
        isAdvertising = false
    }

    /// Update a characteristic value and notify subscribers
    func updateValue(_ data: Data, for characteristicUUID: CBUUID) -> Bool {
        guard let characteristic = characteristics[characteristicUUID] else {
            return false
        }

        return peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: nil)
    }
}

// MARK: - Characteristic Definition

struct CharacteristicDefinition {
    let uuid: CBUUID
    let properties: CBCharacteristicProperties
    let permissions: CBAttributePermissions

    static func readable(_ uuid: CBUUID) -> CharacteristicDefinition {
        CharacteristicDefinition(
            uuid: uuid,
            properties: [.read],
            permissions: [.readable]
        )
    }

    static func writable(_ uuid: CBUUID) -> CharacteristicDefinition {
        CharacteristicDefinition(
            uuid: uuid,
            properties: [.write],
            permissions: [.writeable]
        )
    }

    static func notifiable(_ uuid: CBUUID) -> CharacteristicDefinition {
        CharacteristicDefinition(
            uuid: uuid,
            properties: [.notify, .read],
            permissions: [.readable]
        )
    }

    static func readWriteNotify(_ uuid: CBUUID) -> CharacteristicDefinition {
        CharacteristicDefinition(
            uuid: uuid,
            properties: [.read, .write, .notify],
            permissions: [.readable, .writeable]
        )
    }
}

// MARK: - CBPeripheralManagerDelegate

extension PeripheralManager: CBPeripheralManagerDelegate {

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            isReady = true
            stateReadyContinuation?.resume()
            stateReadyContinuation = nil

        case .poweredOff, .unauthorized, .unsupported:
            isReady = false
            stateReadyContinuation?.resume(throwing: BluetoothError.bluetoothUnavailable)
            stateReadyContinuation = nil

        case .resetting, .unknown:
            isReady = false

        @unknown default:
            isReady = false
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            addServiceContinuation?.resume(throwing: error)
        } else {
            addServiceContinuation?.resume()
        }
        addServiceContinuation = nil
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            print("Failed to start advertising: \(error.localizedDescription)")
            isAdvertising = false
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        if !subscribedCentrals.contains(where: { $0.identifier == central.identifier }) {
            subscribedCentrals.append(central)
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        subscribedCentrals.removeAll { $0.identifier == central.identifier }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        if let data = onReadRequest?(request) {
            request.value = data
            peripheral.respond(to: request, withResult: .success)
        } else {
            peripheral.respond(to: request, withResult: .attributeNotFound)
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if let _ = onWriteRequest?(request) {
                peripheral.respond(to: request, withResult: .success)
            } else {
                peripheral.respond(to: request, withResult: .writeNotPermitted)
            }
        }
    }
}
```

---

## Services and Characteristics

### CBUUID Overview

UUIDs identify services and characteristics. There are two types:

| Type | Length | Usage |
|------|--------|-------|
| Standard (Bluetooth SIG) | 16-bit | Reserved by Bluetooth SIG (e.g., Battery Service) |
| Custom | 128-bit | Created by developers for custom services |

### Standard Service UUIDs

```swift
enum StandardServiceUUID {
    static let batteryService = CBUUID(string: "180F")
    static let deviceInformation = CBUUID(string: "180A")
    static let heartRate = CBUUID(string: "180D")
    static let healthThermometer = CBUUID(string: "1809")
    static let bloodPressure = CBUUID(string: "1810")
    static let glucose = CBUUID(string: "1808")
    static let runningSpeedAndCadence = CBUUID(string: "1814")
    static let cyclingSpeedAndCadence = CBUUID(string: "1816")
    static let cyclingPower = CBUUID(string: "1818")
    static let environmentalSensing = CBUUID(string: "181A")
}
```

### Standard Characteristic UUIDs

```swift
enum StandardCharacteristicUUID {
    // Battery Service
    static let batteryLevel = CBUUID(string: "2A19")

    // Device Information
    static let manufacturerName = CBUUID(string: "2A29")
    static let modelNumber = CBUUID(string: "2A24")
    static let serialNumber = CBUUID(string: "2A25")
    static let firmwareRevision = CBUUID(string: "2A26")
    static let softwareRevision = CBUUID(string: "2A28")

    // Heart Rate
    static let heartRateMeasurement = CBUUID(string: "2A37")
    static let bodySensorLocation = CBUUID(string: "2A38")
    static let heartRateControlPoint = CBUUID(string: "2A39")
}
```

### Custom UUID Example

```swift
enum MyAppServiceUUID {
    // Custom service and characteristics (use a UUID generator)
    static let customService = CBUUID(string: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")
    static let dataCharacteristic = CBUUID(string: "A1B2C3D4-E5F6-7890-ABCD-EF1234567891")
    static let controlCharacteristic = CBUUID(string: "A1B2C3D4-E5F6-7890-ABCD-EF1234567892")
    static let statusCharacteristic = CBUUID(string: "A1B2C3D4-E5F6-7890-ABCD-EF1234567893")
}
```

### Characteristic Properties

```swift
// Common property combinations
let readOnly: CBCharacteristicProperties = [.read]
let writeOnly: CBCharacteristicProperties = [.write]
let readWrite: CBCharacteristicProperties = [.read, .write]
let notify: CBCharacteristicProperties = [.notify]
let indicate: CBCharacteristicProperties = [.indicate]
let readNotify: CBCharacteristicProperties = [.read, .notify]
let fullAccess: CBCharacteristicProperties = [.read, .write, .notify]

// With encryption requirements
let secureRead: CBCharacteristicProperties = [.read, .notifyEncryptionRequired]
let secureWrite: CBCharacteristicProperties = [.write, .writeWithoutResponse]
```

---

## Reading and Writing Characteristic Values

### Reading Values

```swift
// Simple read
func readBatteryLevel(from peripheral: CBPeripheral, characteristic: CBCharacteristic) async throws -> Int {
    let data = try await bluetoothManager.readValue(for: characteristic, on: peripheral)
    guard let batteryLevel = data.first else {
        throw BluetoothError.readFailed
    }
    return Int(batteryLevel)
}

// Read with parsing
func readDeviceInfo(from peripheral: CBPeripheral, characteristic: CBCharacteristic) async throws -> String {
    let data = try await bluetoothManager.readValue(for: characteristic, on: peripheral)
    guard let string = String(data: data, encoding: .utf8) else {
        throw BluetoothError.readFailed
    }
    return string
}
```

### Writing Values

```swift
// Write with response (confirmed delivery)
func writeCommand(_ command: UInt8, to peripheral: CBPeripheral, characteristic: CBCharacteristic) async throws {
    let data = Data([command])
    try await bluetoothManager.writeValue(data, for: characteristic, on: peripheral, type: .withResponse)
}

// Write without response (faster, no confirmation)
func streamData(_ data: Data, to peripheral: CBPeripheral, characteristic: CBCharacteristic) async throws {
    try await bluetoothManager.writeValue(data, for: characteristic, on: peripheral, type: .withoutResponse)
}

// Write complex data
func writeConfiguration(_ config: DeviceConfiguration, to peripheral: CBPeripheral, characteristic: CBCharacteristic) async throws {
    let encoder = JSONEncoder()
    let data = try encoder.encode(config)
    try await bluetoothManager.writeValue(data, for: characteristic, on: peripheral, type: .withResponse)
}
```

### Data Conversion Helpers

```swift
extension Data {
    /// Convert to UInt8
    var uint8Value: UInt8? {
        guard count >= 1 else { return nil }
        return self[0]
    }

    /// Convert to UInt16 (little endian)
    var uint16Value: UInt16? {
        guard count >= 2 else { return nil }
        return UInt16(self[0]) | (UInt16(self[1]) << 8)
    }

    /// Convert to Int16 (little endian)
    var int16Value: Int16? {
        guard let uint16 = uint16Value else { return nil }
        return Int16(bitPattern: uint16)
    }

    /// Convert to Float (IEEE 754)
    var floatValue: Float? {
        guard count >= 4 else { return nil }
        return withUnsafeBytes { $0.load(as: Float.self) }
    }
}

extension UInt8 {
    var data: Data { Data([self]) }
}

extension UInt16 {
    var data: Data {
        var value = self
        return Data(bytes: &value, count: MemoryLayout<UInt16>.size)
    }
}
```

---

## Notifications and Indications

### Setting Up Notifications with AsyncStream

```swift
extension BluetoothManager {

    /// Subscribe to characteristic notifications as an AsyncStream
    func notifications(
        for characteristic: CBCharacteristic,
        on peripheral: CBPeripheral
    ) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            // Store the continuation for delegate callbacks
            self.notificationStreams[characteristic.uuid] = continuation

            // Enable notifications
            Task {
                do {
                    try await self.setNotifyValue(true, for: characteristic, on: peripheral)
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                Task { @MainActor in
                    self.notificationStreams.removeValue(forKey: characteristic.uuid)
                    peripheral.setNotifyValue(false, for: characteristic)
                }
            }
        }
    }

    // Store active notification streams
    private var notificationStreams: [CBUUID: AsyncThrowingStream<Data, Error>.Continuation] = [:]

    // Called from didUpdateValueFor when notification is enabled
    func handleNotification(for characteristic: CBCharacteristic) {
        guard let data = characteristic.value,
              let continuation = notificationStreams[characteristic.uuid] else {
            return
        }
        continuation.yield(data)
    }
}
```

### Using Notifications

```swift
// Subscribe to heart rate notifications
func monitorHeartRate(peripheral: CBPeripheral, characteristic: CBCharacteristic) async {
    let stream = bluetoothManager.notifications(for: characteristic, on: peripheral)

    do {
        for try await data in stream {
            let heartRate = parseHeartRate(data)
            print("Heart Rate: \(heartRate) BPM")
        }
    } catch {
        print("Notification error: \(error)")
    }
}

// Parse heart rate measurement characteristic
func parseHeartRate(_ data: Data) -> Int {
    guard !data.isEmpty else { return 0 }

    let flags = data[0]
    let isUInt16 = (flags & 0x01) != 0

    if isUInt16 && data.count >= 3 {
        return Int(UInt16(data[1]) | (UInt16(data[2]) << 8))
    } else if data.count >= 2 {
        return Int(data[1])
    }
    return 0
}
```

### Notifications vs Indications

| Feature | Notification | Indication |
|---------|--------------|------------|
| Acknowledgment | No | Yes |
| Reliability | Lower | Higher |
| Speed | Faster | Slower |
| Use case | Real-time data | Critical data |

> **Note:** CoreBluetooth handles both through the same `setNotifyValue` method. The peripheral determines whether to use notifications or indications based on the characteristic properties.

---

## SwiftUI Integration Patterns

### Environment-Based BluetoothManager

```swift
import SwiftUI

@main
struct MyBluetoothApp: App {
    @State private var bluetoothManager = BluetoothManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(bluetoothManager)
        }
    }
}
```

### Device Scanner View

```swift
struct DeviceScannerView: View {
    @Environment(BluetoothManager.self) private var bluetoothManager
    @State private var selectedPeripheral: DiscoveredPeripheral?
    @State private var isConnecting = false
    @State private var error: Error?

    var body: some View {
        NavigationStack {
            List(bluetoothManager.discoveredPeripherals) { peripheral in
                DeviceRow(peripheral: peripheral)
                    .onTapGesture {
                        Task {
                            await connectToDevice(peripheral)
                        }
                    }
            }
            .navigationTitle("Nearby Devices")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        toggleScanning()
                    } label: {
                        Image(systemName: bluetoothManager.isScanning ? "stop.circle" : "antenna.radiowaves.left.and.right")
                    }
                }
            }
            .overlay {
                if bluetoothManager.discoveredPeripherals.isEmpty && bluetoothManager.isScanning {
                    ContentUnavailableView(
                        "Scanning...",
                        systemImage: "antenna.radiowaves.left.and.right",
                        description: Text("Looking for nearby devices")
                    )
                }
            }
            .alert("Error", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: {
                if let error = error {
                    Text(error.localizedDescription)
                }
            }
        }
        .task {
            await startInitialScan()
        }
    }

    // MARK: - Methods

    private func startInitialScan() async {
        do {
            try await bluetoothManager.startScanning()
        } catch {
            self.error = error
        }
    }

    private func toggleScanning() {
        if bluetoothManager.isScanning {
            bluetoothManager.stopScanning()
        } else {
            Task {
                do {
                    try await bluetoothManager.startScanning()
                } catch {
                    self.error = error
                }
            }
        }
    }

    private func connectToDevice(_ discovered: DiscoveredPeripheral) async {
        isConnecting = true
        defer { isConnecting = false }

        do {
            bluetoothManager.stopScanning()
            _ = try await bluetoothManager.connect(to: discovered.peripheral)
            selectedPeripheral = discovered
        } catch {
            self.error = error
        }
    }
}

// MARK: - Device Row

struct DeviceRow: View {
    let peripheral: DiscoveredPeripheral

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(peripheral.name)
                    .font(.headline)

                Text(peripheral.id.uuidString.prefix(8) + "...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            SignalStrengthView(rssi: peripheral.rssi)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Signal Strength View

struct SignalStrengthView: View {
    let rssi: Int

    var signalLevel: Int {
        switch rssi {
        case -50...0: return 4
        case -60...(-51): return 3
        case -70...(-61): return 2
        case -80...(-71): return 1
        default: return 0
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index < signalLevel ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 4, height: CGFloat(8 + index * 4))
            }
        }
    }
}
```

### Connected Device View

```swift
struct ConnectedDeviceView: View {
    @Environment(BluetoothManager.self) private var bluetoothManager
    let peripheral: CBPeripheral

    @State private var services: [CBService] = []
    @State private var batteryLevel: Int?
    @State private var isLoading = true
    @State private var error: Error?

    var body: some View {
        List {
            Section("Device Info") {
                LabeledContent("Name", value: peripheral.name ?? "Unknown")
                LabeledContent("ID", value: String(peripheral.identifier.uuidString.prefix(8)))

                if let battery = batteryLevel {
                    LabeledContent("Battery", value: "\(battery)%")
                }
            }

            Section("Services") {
                if services.isEmpty && !isLoading {
                    Text("No services found")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(services, id: \.uuid) { service in
                        NavigationLink {
                            ServiceDetailView(peripheral: peripheral, service: service)
                        } label: {
                            ServiceRow(service: service)
                        }
                    }
                }
            }
        }
        .navigationTitle("Device")
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button("Disconnect") {
                    bluetoothManager.disconnect(from: peripheral)
                }
            }
        }
        .task {
            await discoverServices()
        }
    }

    private func discoverServices() async {
        isLoading = true
        defer { isLoading = false }

        do {
            services = try await bluetoothManager.discoverServices(nil, on: peripheral)

            // Try to read battery level if available
            if let batteryService = services.first(where: { $0.uuid == StandardServiceUUID.batteryService }) {
                let characteristics = try await bluetoothManager.discoverCharacteristics(
                    [StandardCharacteristicUUID.batteryLevel],
                    for: batteryService,
                    on: peripheral
                )

                if let batteryChar = characteristics.first {
                    let data = try await bluetoothManager.readValue(for: batteryChar, on: peripheral)
                    batteryLevel = data.first.map { Int($0) }
                }
            }
        } catch {
            self.error = error
        }
    }
}

struct ServiceRow: View {
    let service: CBService

    var serviceName: String {
        // Map known service UUIDs to names
        switch service.uuid {
        case StandardServiceUUID.batteryService:
            return "Battery Service"
        case StandardServiceUUID.deviceInformation:
            return "Device Information"
        case StandardServiceUUID.heartRate:
            return "Heart Rate"
        default:
            return service.uuid.uuidString
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(serviceName)
                .font(.headline)

            Text(service.uuid.uuidString)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
```

### Real-Time Data View with Notifications

```swift
struct HeartRateMonitorView: View {
    @Environment(BluetoothManager.self) private var bluetoothManager
    let peripheral: CBPeripheral
    let characteristic: CBCharacteristic

    @State private var currentHeartRate: Int = 0
    @State private var heartRateHistory: [Int] = []
    @State private var isMonitoring = false
    @State private var monitoringTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 24) {
            // Current heart rate display
            VStack {
                Image(systemName: "heart.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse, isActive: isMonitoring)

                Text("\(currentHeartRate)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))

                Text("BPM")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            // History chart placeholder
            if !heartRateHistory.isEmpty {
                HeartRateChartView(data: heartRateHistory)
                    .frame(height: 200)
            }

            // Control button
            Button {
                toggleMonitoring()
            } label: {
                Label(
                    isMonitoring ? "Stop Monitoring" : "Start Monitoring",
                    systemImage: isMonitoring ? "stop.circle" : "play.circle"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(isMonitoring ? .red : .green)
        }
        .padding()
        .navigationTitle("Heart Rate")
        .onDisappear {
            monitoringTask?.cancel()
        }
    }

    private func toggleMonitoring() {
        if isMonitoring {
            monitoringTask?.cancel()
            isMonitoring = false
        } else {
            isMonitoring = true
            monitoringTask = Task {
                await startMonitoring()
            }
        }
    }

    private func startMonitoring() async {
        let stream = bluetoothManager.notifications(for: characteristic, on: peripheral)

        do {
            for try await data in stream {
                let heartRate = parseHeartRate(data)
                currentHeartRate = heartRate

                heartRateHistory.append(heartRate)
                if heartRateHistory.count > 60 {
                    heartRateHistory.removeFirst()
                }
            }
        } catch {
            isMonitoring = false
        }
    }

    private func parseHeartRate(_ data: Data) -> Int {
        guard !data.isEmpty else { return 0 }
        let flags = data[0]
        let isUInt16 = (flags & 0x01) != 0

        if isUInt16 && data.count >= 3 {
            return Int(UInt16(data[1]) | (UInt16(data[2]) << 8))
        } else if data.count >= 2 {
            return Int(data[1])
        }
        return 0
    }
}

struct HeartRateChartView: View {
    let data: [Int]

    var body: some View {
        // Placeholder - use Swift Charts for actual implementation
        GeometryReader { geometry in
            Path { path in
                guard data.count > 1 else { return }

                let maxValue = CGFloat(data.max() ?? 200)
                let minValue = CGFloat(data.min() ?? 40)
                let range = maxValue - minValue

                let stepX = geometry.size.width / CGFloat(data.count - 1)

                for (index, value) in data.enumerated() {
                    let x = CGFloat(index) * stepX
                    let normalizedY = (CGFloat(value) - minValue) / range
                    let y = geometry.size.height * (1 - normalizedY)

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(Color.red, lineWidth: 2)
        }
    }
}
```

---

## iOS 18/26 Specific Features

### iOS 18+ Changes

iOS 18 continues to support CoreBluetooth with the same API surface. Key considerations:

1. **Privacy Enhancements**: iOS continues to require explicit Bluetooth permission requests
2. **Background Processing**: State restoration remains the recommended approach
3. **No Breaking Changes**: CoreBluetooth API is stable across iOS 18

### iOS 26 Considerations

Based on available information:

1. **SwiftUI Rendering Changes**: iOS 26 introduces a new layer-based rendering model. While this doesn't directly affect CoreBluetooth, your SwiftUI views displaying Bluetooth data benefit from these performance improvements.

2. **Liquid Glass Design**: For apps targeting iOS 26+, consider updating your Bluetooth device lists and connection UIs to use Liquid Glass styling:

```swift
struct DeviceListView: View {
    @Environment(BluetoothManager.self) private var bluetoothManager

    var body: some View {
        List(bluetoothManager.discoveredPeripherals) { peripheral in
            DeviceRow(peripheral: peripheral)
        }
        .listStyle(.insetGrouped)
        // Automatic Liquid Glass on iOS 26+
    }
}
```

3. **Known Issues**: There are reports of `CBPeripheralManager.didSubscribeToCharacteristic:` delegate method issues on iPhone 17 series devices running iOS 26.1+. Monitor Apple's release notes for fixes.

### Best Practice for Version Compatibility

```swift
// Check iOS version for any version-specific behavior
if #available(iOS 26, *) {
    // iOS 26+ specific handling if needed
} else if #available(iOS 18, *) {
    // iOS 18-25 handling
}
```

---

## Common Use Cases

### 1. Heart Rate Monitor

```swift
@Observable
final class HeartRateMonitor {
    private let bluetoothManager: BluetoothManager

    private(set) var currentHeartRate: Int = 0
    private(set) var isConnected = false

    init(bluetoothManager: BluetoothManager) {
        self.bluetoothManager = bluetoothManager
    }

    func connectAndMonitor() async throws {
        // Scan for heart rate monitors
        try await bluetoothManager.startScanning(
            forServices: [StandardServiceUUID.heartRate]
        )

        // Wait for a device
        try await Task.sleep(for: .seconds(5))

        guard let device = bluetoothManager.discoveredPeripherals.first else {
            throw BluetoothError.peripheralNotFound
        }

        bluetoothManager.stopScanning()

        // Connect
        let peripheral = try await bluetoothManager.connect(to: device.peripheral)
        isConnected = true

        // Discover services
        let services = try await bluetoothManager.discoverServices(
            [StandardServiceUUID.heartRate],
            on: peripheral
        )

        guard let hrService = services.first else {
            throw BluetoothError.serviceNotFound
        }

        // Discover characteristics
        let characteristics = try await bluetoothManager.discoverCharacteristics(
            [StandardCharacteristicUUID.heartRateMeasurement],
            for: hrService,
            on: peripheral
        )

        guard let hrChar = characteristics.first else {
            throw BluetoothError.characteristicNotFound
        }

        // Subscribe to notifications
        let stream = bluetoothManager.notifications(for: hrChar, on: peripheral)

        for try await data in stream {
            currentHeartRate = parseHeartRate(data)
        }
    }

    private func parseHeartRate(_ data: Data) -> Int {
        guard data.count >= 2 else { return 0 }
        let flags = data[0]
        let isUInt16 = (flags & 0x01) != 0

        if isUInt16 && data.count >= 3 {
            return Int(UInt16(data[1]) | (UInt16(data[2]) << 8))
        }
        return Int(data[1])
    }
}
```

### 2. IoT Device Controller

```swift
@Observable
final class SmartLightController {
    private let bluetoothManager: BluetoothManager

    // Custom UUIDs for smart light
    private let lightServiceUUID = CBUUID(string: "12345678-1234-1234-1234-123456789ABC")
    private let powerCharUUID = CBUUID(string: "12345678-1234-1234-1234-123456789001")
    private let brightnessCharUUID = CBUUID(string: "12345678-1234-1234-1234-123456789002")
    private let colorCharUUID = CBUUID(string: "12345678-1234-1234-1234-123456789003")

    private var peripheral: CBPeripheral?
    private var powerCharacteristic: CBCharacteristic?
    private var brightnessCharacteristic: CBCharacteristic?
    private var colorCharacteristic: CBCharacteristic?

    private(set) var isConnected = false
    private(set) var isOn = false
    private(set) var brightness: UInt8 = 100
    private(set) var color: (r: UInt8, g: UInt8, b: UInt8) = (255, 255, 255)

    init(bluetoothManager: BluetoothManager) {
        self.bluetoothManager = bluetoothManager
    }

    func connect() async throws {
        try await bluetoothManager.startScanning(forServices: [lightServiceUUID])

        try await Task.sleep(for: .seconds(3))

        guard let device = bluetoothManager.discoveredPeripherals.first else {
            throw BluetoothError.peripheralNotFound
        }

        bluetoothManager.stopScanning()

        peripheral = try await bluetoothManager.connect(to: device.peripheral)

        let services = try await bluetoothManager.discoverServices([lightServiceUUID], on: peripheral!)

        guard let service = services.first else {
            throw BluetoothError.serviceNotFound
        }

        let characteristics = try await bluetoothManager.discoverCharacteristics(
            [powerCharUUID, brightnessCharUUID, colorCharUUID],
            for: service,
            on: peripheral!
        )

        for char in characteristics {
            switch char.uuid {
            case powerCharUUID: powerCharacteristic = char
            case brightnessCharUUID: brightnessCharacteristic = char
            case colorCharUUID: colorCharacteristic = char
            default: break
            }
        }

        isConnected = true
    }

    func togglePower() async throws {
        guard let peripheral = peripheral,
              let char = powerCharacteristic else {
            throw BluetoothError.peripheralNotFound
        }

        isOn.toggle()
        let data = Data([isOn ? 0x01 : 0x00])
        try await bluetoothManager.writeValue(data, for: char, on: peripheral)
    }

    func setBrightness(_ level: UInt8) async throws {
        guard let peripheral = peripheral,
              let char = brightnessCharacteristic else {
            throw BluetoothError.peripheralNotFound
        }

        brightness = level
        let data = Data([level])
        try await bluetoothManager.writeValue(data, for: char, on: peripheral)
    }

    func setColor(r: UInt8, g: UInt8, b: UInt8) async throws {
        guard let peripheral = peripheral,
              let char = colorCharacteristic else {
            throw BluetoothError.peripheralNotFound
        }

        color = (r, g, b)
        let data = Data([r, g, b])
        try await bluetoothManager.writeValue(data, for: char, on: peripheral)
    }
}
```

### 3. Data Logger / Sensor

```swift
@Observable
final class SensorDataLogger {
    private let bluetoothManager: BluetoothManager

    private let sensorServiceUUID = CBUUID(string: "ABCD1234-1234-1234-1234-123456789ABC")
    private let temperatureCharUUID = CBUUID(string: "ABCD1234-1234-1234-1234-123456789001")
    private let humidityCharUUID = CBUUID(string: "ABCD1234-1234-1234-1234-123456789002")

    private(set) var temperature: Double = 0
    private(set) var humidity: Double = 0
    private(set) var readings: [SensorReading] = []

    init(bluetoothManager: BluetoothManager) {
        self.bluetoothManager = bluetoothManager
    }

    struct SensorReading: Identifiable {
        let id = UUID()
        let timestamp: Date
        let temperature: Double
        let humidity: Double
    }

    func startLogging(peripheral: CBPeripheral, interval: TimeInterval = 1.0) async throws {
        let services = try await bluetoothManager.discoverServices([sensorServiceUUID], on: peripheral)

        guard let service = services.first else {
            throw BluetoothError.serviceNotFound
        }

        let characteristics = try await bluetoothManager.discoverCharacteristics(nil, for: service, on: peripheral)

        var tempChar: CBCharacteristic?
        var humidityChar: CBCharacteristic?

        for char in characteristics {
            switch char.uuid {
            case temperatureCharUUID: tempChar = char
            case humidityCharUUID: humidityChar = char
            default: break
            }
        }

        // Continuous reading loop
        while !Task.isCancelled {
            if let tc = tempChar {
                let data = try await bluetoothManager.readValue(for: tc, on: peripheral)
                if let temp = data.int16Value {
                    temperature = Double(temp) / 100.0
                }
            }

            if let hc = humidityChar {
                let data = try await bluetoothManager.readValue(for: hc, on: peripheral)
                if let hum = data.uint16Value {
                    humidity = Double(hum) / 100.0
                }
            }

            let reading = SensorReading(
                timestamp: Date(),
                temperature: temperature,
                humidity: humidity
            )
            readings.append(reading)

            // Keep only last 1000 readings
            if readings.count > 1000 {
                readings.removeFirst()
            }

            try await Task.sleep(for: .seconds(interval))
        }
    }
}
```

### 4. Device-to-Device Communication

```swift
// Central side
@Observable
final class DeviceCommunicator {
    private let bluetoothManager: BluetoothManager
    private let peripheralManager: PeripheralManager

    private let messageServiceUUID = CBUUID(string: "COMM1234-1234-1234-1234-123456789ABC")
    private let txCharUUID = CBUUID(string: "COMM1234-1234-1234-1234-123456789001")
    private let rxCharUUID = CBUUID(string: "COMM1234-1234-1234-1234-123456789002")

    private(set) var receivedMessages: [String] = []

    init() {
        bluetoothManager = BluetoothManager()
        peripheralManager = PeripheralManager()
    }

    /// Set up as a peripheral to receive messages
    func startReceiving() async throws {
        // Add service with RX characteristic for receiving
        try await peripheralManager.addService(
            uuid: messageServiceUUID,
            characteristics: [
                CharacteristicDefinition(
                    uuid: rxCharUUID,
                    properties: [.write, .writeWithoutResponse],
                    permissions: [.writeable]
                )
            ]
        )

        // Handle incoming writes
        peripheralManager.onWriteRequest = { [weak self] request in
            if let data = request.value,
               let message = String(data: data, encoding: .utf8) {
                Task { @MainActor in
                    self?.receivedMessages.append(message)
                }
            }
            return Data()
        }

        // Start advertising
        try await peripheralManager.startAdvertising(
            localName: "MyDevice",
            serviceUUIDs: [messageServiceUUID]
        )
    }

    /// Connect to another device and send a message
    func sendMessage(_ message: String, to peripheral: CBPeripheral) async throws {
        let services = try await bluetoothManager.discoverServices([messageServiceUUID], on: peripheral)

        guard let service = services.first else {
            throw BluetoothError.serviceNotFound
        }

        let characteristics = try await bluetoothManager.discoverCharacteristics([rxCharUUID], for: service, on: peripheral)

        guard let rxChar = characteristics.first else {
            throw BluetoothError.characteristicNotFound
        }

        guard let data = message.data(using: .utf8) else { return }

        try await bluetoothManager.writeValue(data, for: rxChar, on: peripheral, type: .withoutResponse)
    }
}
```

---

## Best Practices and Battery Optimization

### Battery Optimization Guidelines

1. **Scan Efficiently**
   - Use specific service UUIDs instead of scanning for all devices
   - Set appropriate scan intervals
   - Stop scanning when you find your target device

```swift
// Good: Scan for specific services
try await bluetoothManager.startScanning(forServices: [myServiceUUID])

// Avoid: Scanning for all devices
try await bluetoothManager.startScanning(forServices: nil)
```

2. **Minimize Connection Time**
   - Disconnect when not actively communicating
   - Use notifications instead of polling

```swift
// Good: Subscribe to notifications
let stream = bluetoothManager.notifications(for: characteristic, on: peripheral)

// Avoid: Polling
while true {
    let data = try await bluetoothManager.readValue(for: characteristic, on: peripheral)
    try await Task.sleep(for: .seconds(1))
}
```

3. **Use Write Without Response When Appropriate**

```swift
// For non-critical, high-frequency data
try await bluetoothManager.writeValue(data, for: char, on: peripheral, type: .withoutResponse)

// For critical data that must be confirmed
try await bluetoothManager.writeValue(data, for: char, on: peripheral, type: .withResponse)
```

### Background Mode Best Practices

1. **State Restoration**

```swift
// Initialize with restore identifier
let manager = BluetoothManager(restoreIdentifier: "com.myapp.bluetooth")

// Handle restoration in delegate
func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
    if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
        for peripheral in peripherals {
            // Reconnect to previously connected devices
            peripheral.delegate = self
        }
    }
}
```

2. **Keep Background Processing Minimal**

```swift
// Process quickly and return
func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    guard let data = characteristic.value else { return }

    // Quick processing
    processData(data)

    // Return immediately - don't do heavy work
}
```

3. **Handle Reconnection**

```swift
func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
    // Automatically reconnect
    central.connect(peripheral, options: nil)
}
```

### Error Handling Best Practices

```swift
func handleBluetoothOperation() async {
    do {
        try await bluetoothManager.startScanning()
    } catch BluetoothError.bluetoothUnavailable {
        // Guide user to enable Bluetooth
        showBluetoothDisabledAlert()
    } catch BluetoothError.bluetoothUnauthorized {
        // Guide user to settings
        showAuthorizationAlert()
    } catch {
        // Generic error handling
        showErrorAlert(error)
    }
}
```

### Connection Management

1. **Implement Reconnection Logic**

```swift
func maintainConnection(to peripheral: CBPeripheral) async {
    var retryCount = 0
    let maxRetries = 5

    while retryCount < maxRetries {
        do {
            _ = try await bluetoothManager.connect(to: peripheral)
            retryCount = 0 // Reset on successful connection

            // Wait for disconnection
            // ... monitoring logic

        } catch {
            retryCount += 1
            let delay = min(pow(2.0, Double(retryCount)), 30.0) // Exponential backoff
            try? await Task.sleep(for: .seconds(delay))
        }
    }
}
```

2. **Clean Up Resources**

```swift
deinit {
    centralManager.stopScan()

    if let peripheral = connectedPeripheral {
        centralManager.cancelPeripheralConnection(peripheral)
    }
}
```

### Security Considerations

1. **Validate Data**

```swift
func parseData(_ data: Data) throws -> MyModel {
    guard data.count >= expectedMinLength else {
        throw BluetoothError.invalidData
    }

    // Validate checksum, format, etc.
    guard validateChecksum(data) else {
        throw BluetoothError.checksumFailed
    }

    return try decode(data)
}
```

2. **Use Encrypted Characteristics When Available**

```swift
// When creating peripheral characteristics
let secureCharacteristic = CBMutableCharacteristic(
    type: secureCharUUID,
    properties: [.read, .indicateEncryptionRequired],
    value: nil,
    permissions: [.readEncryptionRequired]
)
```

### Performance Tips

1. **Batch Operations When Possible**

```swift
// Read multiple characteristics in parallel
async let battery = bluetoothManager.readValue(for: batteryChar, on: peripheral)
async let firmware = bluetoothManager.readValue(for: firmwareChar, on: peripheral)
async let serial = bluetoothManager.readValue(for: serialChar, on: peripheral)

let (batteryData, firmwareData, serialData) = try await (battery, firmware, serial)
```

2. **Use Appropriate MTU Size**

```swift
// After connection, request larger MTU if needed
// (iOS handles this automatically, but be aware of peripheral limits)
let maxWriteLength = peripheral.maximumWriteValueLength(for: .withResponse)
```

3. **Profile and Monitor**

```swift
// Add logging for debugging
func logBluetoothEvent(_ event: String) {
    #if DEBUG
    print("[Bluetooth] \(Date()): \(event)")
    #endif
}
```

---

## Summary

CoreBluetooth provides a powerful framework for BLE communication on iOS. Key takeaways:

1. **Always use async/await** patterns with continuations for modern Swift code
2. **Use @Observable** for SwiftUI integration instead of ObservableObject
3. **Request only necessary permissions** and explain why in Info.plist
4. **Scan efficiently** using specific service UUIDs
5. **Prefer notifications** over polling for real-time data
6. **Implement state restoration** for background processing
7. **Handle errors gracefully** with user-friendly messages
8. **Optimize for battery** by minimizing scan time and connection duration

For the latest updates and detailed API documentation, refer to [Apple's CoreBluetooth Documentation](https://developer.apple.com/documentation/corebluetooth).

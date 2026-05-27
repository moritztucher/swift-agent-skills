# Wi-Fi Aware Framework Guide (iOS 26+)

> Comprehensive documentation for Apple's Wi-Fi Aware framework introduced at WWDC 2025

## Overview

Wi-Fi Aware is a peer-to-peer networking framework introduced in iOS 26 that enables direct device-to-device communication without requiring traditional infrastructure like routers or central servers. It is based on the Wi-Fi Alliance's Wi-Fi Aware standard (also known as Neighbor Awareness Networking or NAN).

### Key Features

- **Infrastructure-Free**: Direct device-to-device communication without routers or access points
- **Coexistence**: Operates alongside existing Wi-Fi connections without interruption
- **Cross-Platform**: Works with Apple devices, Android devices, and third-party accessories
- **Built-in Security**: Fully authenticated and encrypted connections at the Wi-Fi layer
- **Dynamic Discovery**: Devices can find and connect to each other at runtime

### Supported Devices

Most devices running iOS 26 support Wi-Fi Aware:
- iPhones from iPhone 8 onwards
- iPads compatible with iPadOS 26

---

## Framework Architecture

### Core Components

| Component | Description |
|-----------|-------------|
| **Services** | Define specific functionality that apps provide or consume |
| **Publishers** | Devices that host services and listen for connections |
| **Subscribers** | Devices that discover and connect to published services |
| **Pairing** | One-time setup process establishing device trust |
| **Connections** | Secure, authenticated links between paired devices |

### Related Frameworks

Wi-Fi Aware integrates with several Apple frameworks:

1. **WiFiAware** - Core framework for service configuration and device management
2. **DeviceDiscoveryUI** - SwiftUI views for app-to-app pairing
3. **AccessorySetupKit** - Hardware accessory pairing and setup
4. **Network** - Connection establishment and data transfer (NetworkListener, NetworkBrowser, NetworkConnection)

---

## Project Configuration

### 1. Add the Entitlement

Add the Wi-Fi Aware entitlement to your app's entitlements file:

```xml
<key>com.apple.developer.wifi-aware</key>
<true/>
```

> **Note**: You must request this entitlement from Apple. Provisioning profile errors will occur without proper approval.

### 2. Configure Info.plist

Declare your services in Info.plist using the `WiFiAwareServices` key:

```xml
<key>WiFiAwareServices</key>
<dict>
    <key>_file-service._tcp</key>
    <dict>
        <key>Publishable</key>
        <true/>
        <key>Subscribable</key>
        <true/>
    </dict>
    <key>_stream-service._udp</key>
    <dict>
        <key>Publishable</key>
        <false/>
        <key>Subscribable</key>
        <true/>
    </dict>
</dict>
```

### Service Naming Rules

Service names must conform to RFC 6763 and RFC 6335:
- Maximum 15 characters
- Alphanumeric characters and hyphens only (a-z, A-Z, 0-9, -)
- Must end with protocol suffix: `._tcp` or `._udp`
- Should be globally unique

---

## WiFiAware Framework APIs

### WACapabilities

Check device support before using Wi-Fi Aware:

```swift
import WiFiAware

func checkWiFiAwareSupport() -> Bool {
    guard WACapabilities.supportedFeatures.contains(.wifiAware) else {
        print("Wi-Fi Aware is not supported on this device")
        return false
    }
    return true
}
```

### WAPublishableService

Access publishable services declared in Info.plist:

```swift
import WiFiAware

extension WAPublishableService {
    /// File sharing service (publisher role)
    public static var fileService: WAPublishableService {
        allServices["_file-service._tcp"]!
    }
}
```

### WASubscribableService

Access subscribable services declared in Info.plist:

```swift
import WiFiAware

extension WASubscribableService {
    /// File sharing service (subscriber role)
    public static var fileService: WASubscribableService {
        allServices["_file-service._tcp"]!
    }

    /// Streaming service (subscriber only)
    public static var streamService: WASubscribableService {
        allServices["_stream-service._udp"]!
    }
}
```

### WAPairedDevice

Manage paired devices:

```swift
import WiFiAware

// MARK: - Fetch All Paired Devices

func fetchPairedDevices() async throws -> [WAPairedDevice] {
    var devices: [WAPairedDevice] = []
    for try await deviceList in WAPairedDevice.allDevices() {
        devices = deviceList
        break // Get initial snapshot
    }
    return devices
}

// MARK: - Fetch Filtered Devices

func fetchDevicesByVendor(_ vendorPrefix: String) async throws -> [WAPairedDevice] {
    let filter = #Predicate<WAPairedDevice> {
        $0.pairingInfo?.vendorName.starts(with: vendorPrefix) ?? false
    }

    var devices: [WAPairedDevice] = []
    for try await deviceList in WAPairedDevice.allDevices(matching: filter) {
        devices = deviceList
        break
    }
    return devices
}

// MARK: - Observe Device Changes

func observeDeviceChanges() async {
    do {
        for try await devices in WAPairedDevice.allDevices() {
            // Update UI with current device list
            await MainActor.run {
                updateDeviceList(devices)
            }
        }
    } catch {
        print("Error observing devices: \(error)")
    }
}

// MARK: - Access Device Properties

func printDeviceInfo(_ device: WAPairedDevice) {
    if let info = device.pairingInfo {
        print("Pairing Name: \(info.pairingName)")
        print("Vendor: \(info.vendorName)")
        print("Model: \(info.modelName)")
    }
}
```

---

## Pairing Methods

### Method 1: DeviceDiscoveryUI (App-to-App)

Best for peer-to-peer connections between apps with PIN-based authorization.

#### Publisher Side (DevicePairingView)

```swift
import SwiftUI
import DeviceDiscoveryUI

struct PublisherView: View {
    var body: some View {
        DevicePairingView(
            .wifiAware(.connecting(to: .fileService, from: .selected([])))
        ) {
            // Button label
            Label("Start Sharing", systemImage: "antenna.radiowaves.left.and.right")
        } fallback: {
            // Fallback when Wi-Fi Aware unavailable
            Text("Wi-Fi Aware is not available on this device")
        }
    }
}
```

#### Subscriber Side (DevicePicker)

```swift
import SwiftUI
import DeviceDiscoveryUI
import Network

struct SubscriberView: View {
    @State private var selectedEndpoint: NWEndpoint?

    var body: some View {
        DevicePicker(
            .wifiAware(.connecting(to: .selected([]), from: .fileService))
        ) { endpoint in
            // Handle the paired endpoint
            selectedEndpoint = endpoint
            connectToDevice(endpoint: endpoint)
        } label: {
            Label("Find Devices", systemImage: "magnifyingglass")
        } fallback: {
            Text("Wi-Fi Aware is not available")
        }
    }

    private func connectToDevice(endpoint: NWEndpoint) {
        // Establish connection using Network framework
    }
}
```

### Method 2: AccessorySetupKit (Hardware Accessories)

Recommended for hardware accessory manufacturers.

```swift
import AccessorySetupKit
import WiFiAware

// MARK: - Setup Session

class AccessorySetupManager {
    private let session = ASAccessorySession()
    private let sessionQueue = DispatchQueue(label: "com.app.accessory.session")

    func startDiscovery() {
        // Create discovery descriptor
        let descriptor = ASDiscoveryDescriptor()
        descriptor.wifiAwareServiceName = "_drone-service._udp"
        descriptor.wifiAwareServiceRole = .subscriber
        descriptor.wifiAwareModelNameMatch = ASPropertyCompareString(
            string: "DroneModel",
            compareOptions: .caseInsensitive
        )
        descriptor.wifiAwareVendorNameMatch = ASPropertyCompareString(
            string: "DroneVendor",
            compareOptions: .literal
        )

        // Create picker item
        let item = ASPickerDisplayItem(
            name: "My Drone",
            productImage: UIImage(systemName: "airplane")!,
            descriptor: descriptor
        )

        // Activate session
        session.activate(on: sessionQueue) { [weak self] event in
            self?.handleSessionEvent(event)
        }

        // Show picker
        session.showPicker(for: [item]) { error in
            if let error = error {
                print("Picker error: \(error)")
            }
        }
    }

    private func handleSessionEvent(_ event: ASAccessoryEvent) {
        switch event.eventType {
        case .accessoryAdded:
            if let accessory = event.accessory {
                handleNewAccessory(accessory)
            }
        case .accessoryRemoved:
            print("Accessory removed")
        case .activated:
            print("Session activated")
        case .invalidated:
            print("Session invalidated")
        @unknown default:
            break
        }
    }

    private func handleNewAccessory(_ accessory: ASAccessory) {
        // Get Wi-Fi Aware paired device ID
        if let deviceID = accessory.wifiAwarePairedDeviceID {
            // Use this ID to look up WAPairedDevice
            lookupPairedDevice(id: deviceID)
        }
    }

    private func lookupPairedDevice(id: ASAccessoryWiFiAwarePairedDeviceID) {
        // Look up the corresponding WAPairedDevice
        Task {
            for try await devices in WAPairedDevice.allDevices() {
                // Find device matching the ID
                // ...
                break
            }
        }
    }
}
```

### ASDiscoveryDescriptor Wi-Fi Aware Properties

| Property | Type | Description |
|----------|------|-------------|
| `wifiAwareServiceName` | `String?` | Service name (e.g., "_drone-service._udp") |
| `wifiAwareServiceRole` | `ASDiscoveryDescriptorWiFiAwareServiceRole` | Subscriber (default) or Publisher |
| `wifiAwareModelNameMatch` | `ASPropertyCompareString?` | Model name filter |
| `wifiAwareVendorNameMatch` | `ASPropertyCompareString?` | Vendor name filter |

### ASDiscoveryDescriptorWiFiAwareServiceRole

```swift
enum ASDiscoveryDescriptorWiFiAwareServiceRole: Int {
    case subscriber = 10  // Default - discover and connect to services
    case publisher = 20   // Advertise and accept connections
}
```

---

## Network Framework Integration

iOS 26 introduces new Network framework APIs with async/await support for Wi-Fi Aware.

### NetworkListener (Publisher/Server)

```swift
import Network
import WiFiAware

// MARK: - Create and Run Listener

class WiFiAwareServer {
    private var listener: NetworkListener?

    func startListening() async throws {
        // Create device filter for accepted connections
        let deviceFilter = #Predicate<WAPairedDevice> {
            $0.pairingInfo?.vendorName.starts(with: "TrustedVendor") ?? false
        }

        // Create listener with TLS
        listener = try NetworkListener(
            for: .wifiAware(.connecting(
                to: .fileService,
                from: .matching(deviceFilter)
            )),
            using: .parameters { TLS() }
        )

        // Handle state changes
        listener?.onStateUpdate { listener, state in
            switch state {
            case .ready:
                print("Listener ready")
            case .failed(let error):
                print("Listener failed: \(error)")
            case .cancelled:
                print("Listener cancelled")
            default:
                break
            }
        }

        // Run and handle incoming connections
        try await listener?.run { connection in
            await self.handleConnection(connection)
        }
    }

    private func handleConnection(_ connection: NetworkConnection) async {
        connection.onStateUpdate { connection, state in
            switch state {
            case .ready:
                print("Connection ready")
            case .failed(let error):
                print("Connection failed: \(error)")
            default:
                break
            }
        }

        // Process incoming messages
        do {
            for try await message in connection.messages {
                await processMessage(message, on: connection)
            }
        } catch {
            print("Error receiving messages: \(error)")
        }
    }

    private func processMessage(_ message: NetworkConnection.Message, on connection: NetworkConnection) async {
        // Handle received data
        if let content = message.content {
            print("Received \(content.count) bytes")
        }
    }

    func stopListening() {
        listener?.cancel()
    }
}
```

### NetworkBrowser (Subscriber/Client)

```swift
import Network
import WiFiAware

// MARK: - Create and Run Browser

class WiFiAwareClient {
    private var browser: NetworkBrowser?
    private var connection: NetworkConnection?

    func startBrowsing() async throws -> NWEndpoint? {
        // Create device filter
        let deviceFilter = #Predicate<WAPairedDevice> {
            $0.pairingInfo != nil
        }

        // Create browser
        browser = NetworkBrowser(
            for: .wifiAware(.connecting(
                to: .matching(deviceFilter),
                from: .fileService
            ))
        )

        // Handle state changes
        browser?.onStateUpdate { browser, state in
            switch state {
            case .ready:
                print("Browser ready")
            case .failed(let error):
                print("Browser failed: \(error)")
            default:
                break
            }
        }

        // Run and wait for endpoint
        let endpoint = try await browser?.run { endpoints in
            if let first = endpoints.first {
                return .finish(first)
            }
            return .continue
        }

        return endpoint
    }

    func connectTo(endpoint: NWEndpoint) async throws {
        // Create connection with TLS
        connection = NetworkConnection(
            to: endpoint,
            using: .parameters { TLS() }
        )

        // Handle state changes
        connection?.onStateUpdate { connection, state in
            print("Connection state: \(state)")
        }

        // Start connection
        try await connection?.start()
    }

    func send(data: Data) async throws {
        try await connection?.send(data)
    }

    func receive() async throws -> Data? {
        let result = try await connection?.receive(exactly: 1024)
        return result?.content
    }
}
```

### NetworkConnection (Data Transfer)

```swift
import Network

// MARK: - Send Data

func sendData(_ data: Data, over connection: NetworkConnection) async throws {
    try await connection.send(data)
}

// MARK: - Receive Data

func receiveData(from connection: NetworkConnection, length: Int) async throws -> Data? {
    let result = try await connection.receive(exactly: length)
    return result?.content
}

// MARK: - Stream Messages

func streamMessages(from connection: NetworkConnection) async {
    do {
        for try await message in connection.messages {
            if let content = message.content {
                // Process message content
                await handleReceivedData(content)
            }
        }
    } catch {
        print("Stream error: \(error)")
    }
}
```

---

## Performance Optimization

### Performance Modes

| Mode | Power | Latency | Use Case |
|------|-------|---------|----------|
| **Bulk** | Lower | Higher | File transfers, background sync |
| **Realtime** | Higher | Lower | Live streaming, real-time collaboration |

### Configure Performance Mode

```swift
import Network

// Bulk mode (default) - file transfers
let bulkListener = try NetworkListener(
    for: .wifiAware(.connecting(to: .fileService, from: .matching(deviceFilter))),
    using: .parameters { TLS() }
        .wifiAware { $0.performanceMode = .bulk }
        .serviceClass(.bestEffort)
)

// Realtime mode - live streaming
let realtimeListener = try NetworkListener(
    for: .wifiAware(.connecting(to: .streamService, from: .matching(deviceFilter))),
    using: .parameters { TLS() }
        .wifiAware { $0.performanceMode = .realtime }
        .serviceClass(.interactiveVideo)
)
```

### Service Classes

| Service Class | Description |
|---------------|-------------|
| `.bestEffort` | Default, no priority |
| `.background` | Low priority background transfers |
| `.interactiveVideo` | Video streaming priority |
| `.interactiveVoice` | Voice/audio streaming priority |

### Monitor Performance

```swift
import Network

func monitorConnectionPerformance(_ connection: NetworkConnection) async throws {
    if let performance = try await connection.currentPath?.wifiAware?.performance {
        print("Signal Strength: \(performance.signalStrength)")
        print("Throughput: \(performance.throughput)")
        print("Latency: \(performance.latency)")
        print("Connection Quality: \(performance.quality)")
    }
}
```

---

## Complete Example: File Sharing App

### FileShareService.swift

```swift
import Foundation
import WiFiAware
import Network
import DeviceDiscoveryUI

// MARK: - Service Extensions

extension WAPublishableService {
    static var fileShare: WAPublishableService {
        allServices["_fileshare._tcp"]!
    }
}

extension WASubscribableService {
    static var fileShare: WASubscribableService {
        allServices["_fileshare._tcp"]!
    }
}

// MARK: - File Share Manager

@Observable
class FileShareManager {
    var isSharing = false
    var isConnected = false
    var pairedDevices: [WAPairedDevice] = []
    var receivedFiles: [URL] = []

    private var listener: NetworkListener?
    private var browser: NetworkBrowser?
    private var connection: NetworkConnection?

    // MARK: - Capability Check

    var isSupported: Bool {
        WACapabilities.supportedFeatures.contains(.wifiAware)
    }

    // MARK: - Device Discovery

    func loadPairedDevices() async {
        do {
            for try await devices in WAPairedDevice.allDevices() {
                await MainActor.run {
                    self.pairedDevices = devices
                }
            }
        } catch {
            print("Failed to load devices: \(error)")
        }
    }

    // MARK: - Publisher (Host)

    func startSharing() async throws {
        guard isSupported else { return }

        listener = try NetworkListener(
            for: .wifiAware(.connecting(to: .fileShare, from: .selected([]))),
            using: .parameters { TLS() }
        )

        await MainActor.run { isSharing = true }

        try await listener?.run { [weak self] connection in
            await self?.handleIncomingConnection(connection)
        }
    }

    func stopSharing() {
        listener?.cancel()
        listener = nil
        Task { @MainActor in isSharing = false }
    }

    private func handleIncomingConnection(_ connection: NetworkConnection) async {
        await MainActor.run { isConnected = true }

        do {
            for try await message in connection.messages {
                if let data = message.content {
                    await processReceivedFile(data)
                }
            }
        } catch {
            print("Connection error: \(error)")
        }

        await MainActor.run { isConnected = false }
    }

    // MARK: - Subscriber (Client)

    func connectToDevice(_ device: WAPairedDevice) async throws {
        let filter = #Predicate<WAPairedDevice> { $0.id == device.id }

        browser = NetworkBrowser(
            for: .wifiAware(.connecting(to: .matching(filter), from: .fileShare))
        )

        if let endpoint = try await browser?.run({ endpoints in
            if let first = endpoints.first {
                return .finish(first)
            }
            return .continue
        }) {
            connection = NetworkConnection(
                to: endpoint,
                using: .parameters { TLS() }
            )
            try await connection?.start()
            await MainActor.run { isConnected = true }
        }
    }

    func sendFile(_ fileURL: URL) async throws {
        guard let connection = connection else { return }
        let data = try Data(contentsOf: fileURL)
        try await connection.send(data)
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        browser?.cancel()
        browser = nil
        Task { @MainActor in isConnected = false }
    }

    // MARK: - File Processing

    private func processReceivedFile(_ data: Data) async {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        do {
            try data.write(to: tempURL)
            await MainActor.run {
                receivedFiles.append(tempURL)
            }
        } catch {
            print("Failed to save file: \(error)")
        }
    }
}
```

### FileShareView.swift

```swift
import SwiftUI
import DeviceDiscoveryUI

struct FileShareView: View {
    @State private var manager = FileShareManager()
    @State private var showFilePicker = false

    var body: some View {
        NavigationStack {
            List {
                // Capability Section
                if !manager.isSupported {
                    Section {
                        Label("Wi-Fi Aware not supported", systemImage: "wifi.exclamationmark")
                            .foregroundStyle(.red)
                    }
                }

                // Sharing Section
                Section("Share Files") {
                    if manager.isSharing {
                        HStack {
                            ProgressView()
                            Text("Waiting for connections...")
                        }
                        Button("Stop Sharing") {
                            manager.stopSharing()
                        }
                    } else {
                        DevicePairingView(
                            .wifiAware(.connecting(to: .fileShare, from: .selected([])))
                        ) {
                            Label("Start Sharing", systemImage: "square.and.arrow.up")
                        } fallback: {
                            Text("Wi-Fi Aware unavailable")
                        }
                    }
                }

                // Browse Section
                Section("Receive Files") {
                    DevicePicker(
                        .wifiAware(.connecting(to: .selected([]), from: .fileShare))
                    ) { endpoint in
                        // Handle connection
                    } label: {
                        Label("Find Nearby Devices", systemImage: "magnifyingglass")
                    } fallback: {
                        Text("Wi-Fi Aware unavailable")
                    }
                }

                // Paired Devices Section
                Section("Paired Devices") {
                    ForEach(manager.pairedDevices, id: \.id) { device in
                        DeviceRow(device: device) {
                            Task {
                                try? await manager.connectToDevice(device)
                            }
                        }
                    }
                }

                // Received Files Section
                if !manager.receivedFiles.isEmpty {
                    Section("Received Files") {
                        ForEach(manager.receivedFiles, id: \.self) { url in
                            Text(url.lastPathComponent)
                        }
                    }
                }
            }
            .navigationTitle("File Share")
            .task {
                await manager.loadPairedDevices()
            }
        }
    }
}

struct DeviceRow: View {
    let device: WAPairedDevice
    let onConnect: () -> Void

    var body: some View {
        Button(action: onConnect) {
            HStack {
                VStack(alignment: .leading) {
                    Text(device.pairingInfo?.pairingName ?? "Unknown")
                        .font(.headline)
                    Text(device.pairingInfo?.vendorName ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
```

---

## Error Handling

### Common Issues and Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| Provisioning profile error | Missing entitlement | Request `com.apple.developer.wifi-aware` from Apple |
| Device not discoverable | Service not declared | Check Info.plist `WiFiAwareServices` configuration |
| Connection timeout | Idle connection cleanup | Implement keep-alive or reconnection logic |
| Pairing fails | Incompatible device | Verify device supports Wi-Fi Aware Specification 4.0 |

### Connection Timeouts

Wi-Fi Aware aggressively cleans up idle connections after a few minutes. Implement reconnection logic:

```swift
func connectWithRetry(to device: WAPairedDevice, maxAttempts: Int = 3) async throws {
    var attempts = 0
    var lastError: Error?

    while attempts < maxAttempts {
        do {
            try await connectToDevice(device)
            return
        } catch {
            lastError = error
            attempts += 1
            try await Task.sleep(for: .seconds(1))
        }
    }

    throw lastError ?? NSError(domain: "WiFiAware", code: -1)
}
```

### State Management

Monitor and handle connection state changes:

```swift
connection.onStateUpdate { connection, state in
    switch state {
    case .setup:
        print("Setting up connection")
    case .waiting(let error):
        print("Waiting: \(error)")
    case .preparing:
        print("Preparing connection")
    case .ready:
        print("Connection ready")
    case .failed(let error):
        print("Connection failed: \(error)")
        // Implement retry logic
    case .cancelled:
        print("Connection cancelled")
        // Clean up resources
    @unknown default:
        break
    }
}
```

---

## Best Practices

### Resource Management

1. **Start listeners/browsers only when needed**
2. **Stop connections immediately after use**
3. **Monitor connection state for graceful disconnection**
4. **Implement reconnection logic for seamless UX**
5. **Consider battery impact of realtime mode**

### Security

1. Always use TLS for connections
2. Validate paired device identities before sensitive operations
3. Monitor for unauthorized access attempts
4. System handles key exchange automatically

### Testing

1. Test multi-device scenarios
2. Simulate network interference
3. Benchmark against existing solutions
4. Validate pairing and connection flows
5. Test app lifecycle transitions (background/foreground)

### Cross-Platform Compatibility

1. Review Apple's Accessory Design Guidelines (Wi-Fi Aware chapter)
2. Devices must support Wi-Fi Aware Specification Version 4.0
3. Android interoperability may have limitations
4. Test with various device combinations

---

## Migration from Legacy APIs

### NWConnection to NetworkConnection

```swift
// Legacy (iOS 12-25)
let connection = NWConnection(host: host, port: port, using: .tls)
connection.stateUpdateHandler = { state in ... }
connection.start(queue: .main)

// New (iOS 26+)
let connection = NetworkConnection(to: .hostPort(host: host, port: port), using: .parameters { TLS() })
connection.onStateUpdate { connection, state in ... }
try await connection.start()
```

### NWListener to NetworkListener

```swift
// Legacy (iOS 12-25)
let listener = try NWListener(using: .tls)
listener.newConnectionHandler = { connection in ... }
listener.start(queue: .main)

// New (iOS 26+)
let listener = try NetworkListener(for: .service(type: "_myservice._tcp"), using: .parameters { TLS() })
try await listener.run { connection in ... }
```

---

## Additional Resources

- [Wi-Fi Aware | Apple Developer Documentation](https://developer.apple.com/documentation/WiFiAware)
- [WWDC25 Session 228: Supercharge device connectivity with Wi-Fi Aware](https://developer.apple.com/videos/play/wwdc2025/228/)
- [WWDC25 Session 250: Use structured concurrency with Network framework](https://developer.apple.com/videos/play/wwdc2025/250/)
- [Building peer-to-peer apps](https://developer.apple.com/documentation/wifiaware/building-peer-to-peer-apps)
- [Connecting paired devices](https://developer.apple.com/documentation/WiFiAware/Connecting-paired-devices)
- [Adopting Wi-Fi Aware](https://developer.apple.com/documentation/WiFiAware/Adopting-Wi-Fi-Aware)
- [Accessory Design Guidelines for Apple Devices](https://developer.apple.com/accessories/) (includes Wi-Fi Aware chapter)

---

## Version History

| iOS Version | Changes |
|-------------|---------|
| iOS 26.0 | Initial Wi-Fi Aware framework release |

---

*Last updated: February 2026*

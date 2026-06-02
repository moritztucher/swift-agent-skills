# CoreLocation Guide for SwiftUI

A comprehensive guide covering CoreLocation for iOS development with SwiftUI, async/await, and the @Observable pattern.

---

## Table of Contents

1. [Overview](#overview)
2. [Setup and Configuration](#setup-and-configuration)
3. [Authorization Flow](#authorization-flow)
4. [Location Manager with @Observable](#location-manager-with-observable)
5. [Getting User Location](#getting-user-location)
6. [Continuous Location Updates](#continuous-location-updates)
7. [Significant Location Changes](#significant-location-changes)
8. [Geocoding](#geocoding)
9. [Region Monitoring (Geofencing)](#region-monitoring-geofencing)
10. [Beacon Monitoring](#beacon-monitoring)
11. [Visit Monitoring](#visit-monitoring)
12. [Background Location](#background-location)
13. [LocationButton (One-Time Access)](#locationbutton-one-time-access)
14. [Battery Efficiency Best Practices](#battery-efficiency-best-practices)
15. [Accuracy vs Performance](#accuracy-vs-performance)
16. [Common Pitfalls](#common-pitfalls)
17. [iOS Version Compatibility](#ios-version-compatibility)
18. [Complete Example](#complete-example)

---

## Overview

CoreLocation is Apple's framework for determining the geographic location and orientation of a device. It provides:

- **GPS Location**: High-accuracy positioning using GPS, Wi-Fi, and cellular triangulation
- **Geofencing**: Monitor entry/exit from geographic regions
- **Beacon Monitoring**: Detect and range iBeacon devices
- **Visit Tracking**: Automatically detect when users visit places
- **Heading Information**: Compass direction and orientation
- **Geocoding**: Convert between addresses and coordinates

**Minimum Requirements:**
- iOS 18+ (this guide focuses on modern patterns)
- Some features require iOS 26+

**Import Statement:**
```swift
import CoreLocation
import CoreLocationUI  // For LocationButton
```

---

## Setup and Configuration

### Info.plist Keys

Add the appropriate usage description keys to your Info.plist:

```xml
<!-- Required for "When In Use" authorization -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to show nearby places and provide navigation.</string>

<!-- Required for "Always" authorization (must also include When In Use) -->
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>We need your location in the background for trip tracking and geofence alerts.</string>

<!-- Optional: For temporary full accuracy access -->
<key>NSLocationTemporaryUsageDescriptionDictionary</key>
<dict>
    <key>NavigationAccuracy</key>
    <string>We need precise location for turn-by-turn navigation.</string>
</dict>
```

### Background Modes

For background location updates, enable in your target's Signing & Capabilities:

1. Click "+ Capability"
2. Add "Background Modes"
3. Check "Location updates"

This adds to Info.plist:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
</array>
```

---

## Authorization Flow

### Authorization Status

```swift
enum CLAuthorizationStatus {
    case notDetermined      // User hasn't made a choice
    case restricted         // Parental controls or MDM prevent access
    case denied             // User denied access
    case authorizedAlways   // Background location allowed
    case authorizedWhenInUse // Foreground location only
}
```

### Accuracy Authorization (iOS 14+)

```swift
enum CLAccuracyAuthorization {
    case fullAccuracy       // Precise location (default when authorized)
    case reducedAccuracy    // Approximate location (~5km radius)
}
```

### Authorization Request Flow

```swift
@Observable
class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var accuracyAuthorization: CLAccuracyAuthorization = .reducedAccuracy

    override init() {
        super.init()
        manager.delegate = self
        authorizationStatus = manager.authorizationStatus
        accuracyAuthorization = manager.accuracyAuthorization
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func requestAlwaysAuthorization() {
        // Note: Must call requestWhenInUseAuthorization first
        // or user must already have "When In Use" permission
        manager.requestAlwaysAuthorization()
    }

    func requestTemporaryFullAccuracy(purposeKey: String) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            manager.requestTemporaryFullAccuracyAuthorization(
                withPurposeKey: purposeKey
            ) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: self.manager.accuracyAuthorization == .fullAccuracy)
                }
            }
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        accuracyAuthorization = manager.accuracyAuthorization
    }
}
```

### Authorization Status View

```swift
struct LocationPermissionView: View {
    @Environment(LocationManager.self) private var locationManager

    var body: some View {
        VStack(spacing: 20) {
            switch locationManager.authorizationStatus {
            case .notDetermined:
                Text("Location permission required")
                Button("Enable Location") {
                    locationManager.requestWhenInUseAuthorization()
                }
                .buttonStyle(.borderedProminent)

            case .restricted:
                Text("Location access is restricted")
                    .foregroundStyle(.secondary)

            case .denied:
                Text("Location access denied")
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }

            case .authorizedWhenInUse, .authorizedAlways:
                Text("Location access granted")
                    .foregroundStyle(.green)

            @unknown default:
                Text("Unknown authorization status")
            }
        }
    }
}
```

---

## Location Manager with @Observable

### Basic Location Manager

```swift
import CoreLocation

@Observable
class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    var location: CLLocation?
    var heading: CLHeading?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var isUpdatingLocation = false
    var errorMessage: String?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = manager.authorizationStatus
    }

    // MARK: - Public Methods

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func startUpdatingLocation() {
        guard authorizationStatus == .authorizedWhenInUse ||
              authorizationStatus == .authorizedAlways else {
            errorMessage = "Location not authorized"
            return
        }
        isUpdatingLocation = true
        manager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        isUpdatingLocation = false
        manager.stopUpdatingLocation()
    }

    func startUpdatingHeading() {
        guard CLLocationManager.headingAvailable() else {
            errorMessage = "Heading not available on this device"
            return
        }
        manager.startUpdatingHeading()
    }

    func stopUpdatingHeading() {
        manager.stopUpdatingHeading()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
        errorMessage = nil
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = error.localizedDescription
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
}
```

### Environment Integration

```swift
@main
struct MyApp: App {
    @State private var locationManager = LocationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(locationManager)
        }
    }
}

// Usage in views
struct ContentView: View {
    @Environment(LocationManager.self) private var locationManager

    var body: some View {
        VStack {
            if let location = locationManager.location {
                Text("Lat: \(location.coordinate.latitude, specifier: "%.4f")")
                Text("Lon: \(location.coordinate.longitude, specifier: "%.4f")")
            }
        }
        .task {
            locationManager.requestAuthorization()
        }
    }
}
```

---

## Getting User Location

### One-Time Location Request

```swift
@Observable
class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        authorizationStatus = manager.authorizationStatus
    }

    /// Request a single location update using async/await
    func requestLocation() async throws -> CLLocation {
        guard authorizationStatus == .authorizedWhenInUse ||
              authorizationStatus == .authorizedAlways else {
            throw LocationError.notAuthorized
        }

        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            locationContinuation?.resume(returning: location)
            locationContinuation = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(throwing: error)
        locationContinuation = nil
    }
}

enum LocationError: LocalizedError {
    case notAuthorized
    case locationUnavailable

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Location services not authorized"
        case .locationUnavailable:
            return "Unable to determine location"
        }
    }
}
```

### Usage in SwiftUI View

```swift
struct LocationRequestView: View {
    @Environment(LocationManager.self) private var locationManager
    @State private var currentLocation: CLLocation?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            if let location = currentLocation {
                Text("Location found!")
                Text("Lat: \(location.coordinate.latitude, specifier: "%.6f")")
                Text("Lon: \(location.coordinate.longitude, specifier: "%.6f")")
                Text("Accuracy: \(location.horizontalAccuracy, specifier: "%.1f")m")
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
            }

            Button("Get My Location") {
                Task {
                    await getLocation()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)
        }
    }

    private func getLocation() async {
        isLoading = true
        errorMessage = nil

        do {
            currentLocation = try await locationManager.requestLocation()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
```

---

## Continuous Location Updates

### CLLocationUpdate.liveUpdates() (iOS 17+, Preferred)

The modern, async-native way to receive continuous updates. No delegate, no manual `AsyncStream` bridging, no `startUpdatingLocation()`/`stopUpdatingLocation()` bookkeeping — the stream starts when you iterate and stops when the `Task` is cancelled or the loop exits. Prefer this over the delegate + `AsyncStream` pattern below for all new code.

```swift
import CoreLocation

@Observable
final class LiveLocationModel {
    var lastLocation: CLLocation?
    var isStationary = false
    var errorMessage: String?

    /// Iterate the system-provided async stream. Drive this from a `Task`
    /// (e.g. SwiftUI `.task {}`) so it cancels automatically.
    func track() async {
        do {
            for try await update in CLLocationUpdate.liveUpdates() {
                if update.authorizationDenied {
                    errorMessage = "Location access denied"
                    return
                }
                isStationary = update.stationary
                if let location = update.location {
                    lastLocation = location
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// Usage in SwiftUI — cancellation is handled by `.task`.
struct LiveLocationView: View {
    @State private var model = LiveLocationModel()

    var body: some View {
        VStack {
            if let location = model.lastLocation {
                Text("\(location.coordinate.latitude), \(location.coordinate.longitude)")
            }
        }
        .task { await model.track() }   // stops automatically when the view disappears
    }
}
```

`CLLocationUpdate.liveUpdates(_:)` also accepts a configuration (`.default`, `.automotiveNavigation`, `.fitness`, `.airborne`, `.otherNavigation`) to tune accuracy/power. Each `CLLocationUpdate` exposes `location`, `authorizationDenied`, `authorizationDeniedGlobally`, `authorizationRequestInProgress`, `insufficientlyInUse`, and `stationary` — branch on these rather than spinning a polling loop.

### AsyncStream for Location Updates (Legacy delegate bridge)

Use this only when targeting iOS < 17 or maintaining existing delegate-based code. For new iOS 17+ code, prefer `CLLocationUpdate.liveUpdates()` above.

```swift
@Observable
class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var locationStream: AsyncStream<CLLocation>.Continuation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    /// Returns an AsyncStream of location updates
    func locationUpdates() -> AsyncStream<CLLocation> {
        AsyncStream { continuation in
            locationStream = continuation
            manager.startUpdatingLocation()

            continuation.onTermination = { [weak self] _ in
                self?.manager.stopUpdatingLocation()
                self?.locationStream = nil
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            locationStream?.yield(location)
        }
    }
}
```

### Usage with SwiftUI

```swift
struct ContinuousLocationView: View {
    @Environment(LocationManager.self) private var locationManager
    @State private var currentLocation: CLLocation?
    @State private var isTracking = false
    @State private var trackingTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 20) {
            if let location = currentLocation {
                Text("Latitude: \(location.coordinate.latitude, specifier: "%.6f")")
                Text("Longitude: \(location.coordinate.longitude, specifier: "%.6f")")
                Text("Speed: \(max(0, location.speed), specifier: "%.1f") m/s")
                Text("Altitude: \(location.altitude, specifier: "%.1f") m")
            }

            Button(isTracking ? "Stop Tracking" : "Start Tracking") {
                toggleTracking()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func toggleTracking() {
        if isTracking {
            trackingTask?.cancel()
            trackingTask = nil
            isTracking = false
        } else {
            isTracking = true
            trackingTask = Task {
                for await location in locationManager.locationUpdates() {
                    currentLocation = location
                }
            }
        }
    }
}
```

---

## Significant Location Changes

Significant location monitoring is battery-efficient and continues in background even when app is terminated.

```swift
@Observable
class SignificantLocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    var lastSignificantLocation: CLLocation?
    var isMonitoring = false

    override init() {
        super.init()
        manager.delegate = self
    }

    func startMonitoring() {
        guard CLLocationManager.significantLocationChangeMonitoringAvailable() else {
            print("Significant location monitoring not available")
            return
        }

        manager.startMonitoringSignificantLocationChanges()
        isMonitoring = true
    }

    func stopMonitoring() {
        manager.stopMonitoringSignificantLocationChanges()
        isMonitoring = false
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastSignificantLocation = locations.last
        // Handle significant location change (typically 500m+ movement)
    }
}
```

**Key Points:**
- Updates occur every ~500 meters of movement
- Works with "When In Use" or "Always" authorization
- Automatically relaunches terminated app when location changes significantly
- Very battery efficient

---

## Geocoding

### Forward Geocoding (Address to Coordinates)

```swift
@Observable
class GeocodingManager {
    private let geocoder = CLGeocoder()

    var isGeocoding = false
    var errorMessage: String?

    /// Convert an address string to coordinates
    func geocode(address: String) async throws -> CLPlacemark? {
        isGeocoding = true
        defer { isGeocoding = false }

        let placemarks = try await geocoder.geocodeAddressString(address)
        return placemarks.first
    }

    /// Geocode with region bias
    func geocode(address: String, in region: CLRegion) async throws -> [CLPlacemark] {
        isGeocoding = true
        defer { isGeocoding = false }

        return try await geocoder.geocodeAddressString(address, in: region)
    }
}

// Usage
let manager = GeocodingManager()
let placemark = try await manager.geocode(address: "1 Infinite Loop, Cupertino, CA")
if let location = placemark?.location {
    print("Coordinates: \(location.coordinate)")
}
```

### Reverse Geocoding (Coordinates to Address)

```swift
extension GeocodingManager {
    /// Convert coordinates to an address
    func reverseGeocode(location: CLLocation) async throws -> CLPlacemark? {
        isGeocoding = true
        defer { isGeocoding = false }

        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        return placemarks.first
    }

    /// Get formatted address from placemark
    func formattedAddress(from placemark: CLPlacemark) -> String {
        var components: [String] = []

        if let name = placemark.name { components.append(name) }
        if let thoroughfare = placemark.thoroughfare { components.append(thoroughfare) }
        if let locality = placemark.locality { components.append(locality) }
        if let administrativeArea = placemark.administrativeArea { components.append(administrativeArea) }
        if let postalCode = placemark.postalCode { components.append(postalCode) }
        if let country = placemark.country { components.append(country) }

        return components.joined(separator: ", ")
    }
}

// Usage
let location = CLLocation(latitude: 37.3349, longitude: -122.0090)
let placemark = try await manager.reverseGeocode(location: location)
print(manager.formattedAddress(from: placemark!))
```

### CLPlacemark Properties

```swift
let placemark: CLPlacemark

// Address components
placemark.name                  // "Apple Park"
placemark.thoroughfare          // "Apple Park Way"
placemark.subThoroughfare       // "1" (street number)
placemark.locality              // "Cupertino" (city)
placemark.subLocality           // neighborhood
placemark.administrativeArea    // "CA" (state)
placemark.subAdministrativeArea // county
placemark.postalCode            // "95014"
placemark.country               // "United States"
placemark.isoCountryCode        // "US"

// Location data
placemark.location              // CLLocation
placemark.region                // CLRegion (if available)
placemark.timeZone              // TimeZone

// Points of interest
placemark.areasOfInterest       // ["Apple Park", "Silicon Valley"]
```

### iOS 26+ Geocoding (MapKit)

iOS 26 introduces new geocoding APIs in MapKit that will eventually replace CLGeocoder:

```swift
import MapKit

// Reverse geocoding (coordinate to address)
func reverseGeocode(location: CLLocation) async throws -> MKMapItem? {
    guard let request = MKReverseGeocodingRequest(location: location) else {
        return nil
    }
    let mapItems = try await request.mapItems
    return mapItems.first
}

// Forward geocoding (address to coordinate)
func geocode(address: String) async throws -> [MKMapItem] {
    let request = MKGeocodingRequest(address: address)
    return try await request.mapItems
}
```

---

## Region Monitoring (Geofencing)

### CLMonitor (iOS 17+, Preferred)

`CLMonitor` is an `actor` that supersedes the delegate-based `CLCircularRegion`/`CLBeaconRegion` + `startMonitoring(for:)` APIs. Conditions (`CLMonitor.CircularGeographicCondition`, `CLMonitor.BeaconIdentityCondition`) are added by identifier and events arrive through an async sequence (`monitor.events`). The monitor and its conditions persist across launches, so re-create the named monitor on launch and resume iterating its events. Prefer this for all new geofencing/beacon code.

```swift
import CoreLocation

func startGeofence() async throws {
    // A named monitor — its conditions survive app relaunch.
    let monitor = await CLMonitor("places_monitor")

    let center = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)
    let condition = CLMonitor.CircularGeographicCondition(center: center, radius: 200)
    await monitor.add(condition, identifier: "apple_park")

    // Resume on every launch by iterating the persisted events.
    for try await event in await monitor.events {
        switch event.state {
        case .satisfied:   handleEntry(event.identifier)
        case .unsatisfied: handleExit(event.identifier)
        case .unknown:     break
        @unknown default:  break
        }
    }
}
```

`monitor.streamDiagnosticProperties()` / `event` diagnostics explain *why* events aren't arriving (authorization, accuracy, connectivity) — reach for it before assuming a logic bug. The 20-region limit and accuracy caveats below still apply.

### Setting Up Geofences (Legacy delegate API)

Use this only for iOS < 17 or existing code. `CLCircularRegion` + `startMonitoring(for:)` is the older path; new code should use `CLMonitor` above.

```swift
@Observable
class GeofenceManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    var monitoredRegions: Set<CLRegion> { manager.monitoredRegions }
    var lastEvent: GeofenceEvent?

    struct GeofenceEvent {
        let region: CLRegion
        let type: EventType
        let timestamp: Date

        enum EventType {
            case entered
            case exited
        }
    }

    override init() {
        super.init()
        manager.delegate = self
    }

    /// Start monitoring a circular region
    func startMonitoring(
        identifier: String,
        center: CLLocationCoordinate2D,
        radius: CLLocationDistance,
        notifyOnEntry: Bool = true,
        notifyOnExit: Bool = true
    ) {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            print("Region monitoring not available")
            return
        }

        // Maximum radius is ~400km, but Apple recommends < 200m for accuracy
        let clampedRadius = min(radius, manager.maximumRegionMonitoringDistance)

        let region = CLCircularRegion(
            center: center,
            radius: clampedRadius,
            identifier: identifier
        )
        region.notifyOnEntry = notifyOnEntry
        region.notifyOnExit = notifyOnExit

        manager.startMonitoring(for: region)
    }

    /// Stop monitoring a specific region
    func stopMonitoring(identifier: String) {
        if let region = monitoredRegions.first(where: { $0.identifier == identifier }) {
            manager.stopMonitoring(for: region)
        }
    }

    /// Stop monitoring all regions
    func stopMonitoringAll() {
        for region in monitoredRegions {
            manager.stopMonitoring(for: region)
        }
    }

    /// Request current state for a region
    func requestState(for region: CLRegion) {
        manager.requestState(for: region)
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        lastEvent = GeofenceEvent(region: region, type: .entered, timestamp: Date())
        handleRegionEntry(region)
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        lastEvent = GeofenceEvent(region: region, type: .exited, timestamp: Date())
        handleRegionExit(region)
    }

    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        switch state {
        case .inside:
            print("Currently inside \(region.identifier)")
        case .outside:
            print("Currently outside \(region.identifier)")
        case .unknown:
            print("Unknown state for \(region.identifier)")
        }
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("Monitoring failed for region: \(region?.identifier ?? "unknown"): \(error)")
    }

    private func handleRegionEntry(_ region: CLRegion) {
        // Send local notification, update UI, etc.
    }

    private func handleRegionExit(_ region: CLRegion) {
        // Handle exit event
    }
}
```

### Geofencing Limitations

| Limit | Value |
|-------|-------|
| Maximum regions per app | 20 |
| Minimum radius | ~100m (below this, events may not trigger reliably) |
| Maximum radius | ~400km |
| Recommended radius | 100-200m for reliable triggering |

### SwiftUI Geofence Setup View

```swift
struct GeofenceSetupView: View {
    @Environment(GeofenceManager.self) private var geofenceManager
    @State private var locationName = ""
    @State private var radius: Double = 100
    @State private var selectedCoordinate: CLLocationCoordinate2D?

    var body: some View {
        Form {
            Section("Geofence Details") {
                TextField("Location Name", text: $locationName)

                Slider(value: $radius, in: 50...500, step: 50) {
                    Text("Radius: \(Int(radius))m")
                }
            }

            Section("Monitored Regions (\(geofenceManager.monitoredRegions.count)/20)") {
                ForEach(Array(geofenceManager.monitoredRegions), id: \.identifier) { region in
                    HStack {
                        Text(region.identifier)
                        Spacer()
                        Button("Remove") {
                            geofenceManager.stopMonitoring(identifier: region.identifier)
                        }
                        .foregroundStyle(.red)
                    }
                }
            }

            if let coordinate = selectedCoordinate {
                Section {
                    Button("Add Geofence") {
                        geofenceManager.startMonitoring(
                            identifier: locationName,
                            center: coordinate,
                            radius: radius
                        )
                    }
                    .disabled(locationName.isEmpty)
                }
            }
        }
    }
}
```

---

## Beacon Monitoring

### iBeacon Monitoring and Ranging

```swift
@Observable
class BeaconManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    var detectedBeacons: [CLBeacon] = []
    var isRanging = false

    override init() {
        super.init()
        manager.delegate = self
    }

    /// Start monitoring for beacon region (detects entry/exit)
    func startMonitoring(uuid: UUID, identifier: String) {
        let constraint = CLBeaconIdentityConstraint(uuid: uuid)
        let region = CLBeaconRegion(beaconIdentityConstraint: constraint, identifier: identifier)
        region.notifyEntryStateOnDisplay = true

        manager.startMonitoring(for: region)
    }

    /// Start ranging beacons (provides distance information)
    func startRanging(uuid: UUID) {
        let constraint = CLBeaconIdentityConstraint(uuid: uuid)
        manager.startRangingBeacons(satisfying: constraint)
        isRanging = true
    }

    /// Start ranging with major/minor values
    func startRanging(uuid: UUID, major: CLBeaconMajorValue, minor: CLBeaconMinorValue) {
        let constraint = CLBeaconIdentityConstraint(uuid: uuid, major: major, minor: minor)
        manager.startRangingBeacons(satisfying: constraint)
        isRanging = true
    }

    func stopRanging(uuid: UUID) {
        let constraint = CLBeaconIdentityConstraint(uuid: uuid)
        manager.stopRangingBeacons(satisfying: constraint)
        isRanging = false
        detectedBeacons = []
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didRange beacons: [CLBeacon], satisfying constraint: CLBeaconIdentityConstraint) {
        detectedBeacons = beacons.sorted { $0.accuracy < $1.accuracy }
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if let beaconRegion = region as? CLBeaconRegion {
            // Start ranging when entering beacon region
            startRanging(uuid: beaconRegion.uuid)
        }
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if let beaconRegion = region as? CLBeaconRegion {
            stopRanging(uuid: beaconRegion.uuid)
        }
    }
}
```

### Beacon Proximity

```swift
extension CLProximity {
    var description: String {
        switch self {
        case .unknown: return "Unknown"
        case .immediate: return "Immediate (<1m)"
        case .near: return "Near (1-3m)"
        case .far: return "Far (>3m)"
        @unknown default: return "Unknown"
        }
    }
}

// Display beacon information
struct BeaconView: View {
    let beacon: CLBeacon

    var body: some View {
        VStack(alignment: .leading) {
            Text("UUID: \(beacon.uuid.uuidString)")
                .font(.caption)
            Text("Major: \(beacon.major) Minor: \(beacon.minor)")
            Text("Proximity: \(beacon.proximity.description)")
            Text("Accuracy: \(beacon.accuracy, specifier: "%.2f")m")
            Text("RSSI: \(beacon.rssi) dBm")
        }
    }
}
```

---

## Visit Monitoring

Visit monitoring automatically detects when users arrive at or depart from places.

```swift
@Observable
class VisitManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    var recentVisits: [CLVisit] = []
    var isMonitoring = false

    override init() {
        super.init()
        manager.delegate = self
    }

    func startMonitoring() {
        manager.startMonitoringVisits()
        isMonitoring = true
    }

    func stopMonitoring() {
        manager.stopMonitoringVisits()
        isMonitoring = false
    }

    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        recentVisits.insert(visit, at: 0)
        handleVisit(visit)
    }

    private func handleVisit(_ visit: CLVisit) {
        let coordinate = visit.coordinate
        let arrivalDate = visit.arrivalDate
        let departureDate = visit.departureDate

        // departureDate == .distantFuture means user is still at location
        if departureDate == .distantFuture {
            print("Arrived at \(coordinate) at \(arrivalDate)")
        } else {
            let duration = departureDate.timeIntervalSince(arrivalDate)
            print("Visited \(coordinate) for \(Int(duration / 60)) minutes")
        }
    }
}
```

### CLVisit Properties

```swift
let visit: CLVisit

visit.coordinate           // CLLocationCoordinate2D
visit.horizontalAccuracy   // CLLocationAccuracy
visit.arrivalDate          // Date (when user arrived)
visit.departureDate        // Date (or .distantFuture if still there)
```

**Key Points:**
- Requires "Always" authorization
- Very battery efficient
- Visits are detected based on dwell time (~5-10 minutes)
- Works even when app is terminated

---

## Background Location

### Enabling Background Updates

```swift
@Observable
class BackgroundLocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    var locations: [CLLocation] = []

    override init() {
        super.init()
        manager.delegate = self
        configureForBackground()
    }

    private func configureForBackground() {
        // Allow background updates
        manager.allowsBackgroundLocationUpdates = true

        // Pause updates when user is stationary (saves battery)
        manager.pausesLocationUpdatesAutomatically = true

        // Activity type helps system optimize power
        manager.activityType = .fitness // or .automotiveNavigation, .other

        // Show indicator when using location in background
        manager.showsBackgroundLocationIndicator = true
    }

    func startBackgroundTracking() {
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        self.locations.append(contentsOf: locations)
    }

    func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        print("Location updates paused")
    }

    func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
        print("Location updates resumed")
    }
}
```

### Activity Types

| Activity Type | Description | Use Case |
|---------------|-------------|----------|
| `.other` | Default | General purpose |
| `.automotiveNavigation` | Optimized for driving | Turn-by-turn navigation |
| `.fitness` | Optimized for walking/running | Fitness tracking |
| `.otherNavigation` | Other navigation modes | Boat, train, etc. |
| `.airborne` | Airplane tracking | Flight tracking |

### Background Location Indicator

When `showsBackgroundLocationIndicator = true`, iOS shows a blue pill/bar indicating location usage. This is required by Apple guidelines for apps using background location.

---

## LocationButton (One-Time Access)

`LocationButton` provides a streamlined way to get one-time location access without persistent authorization.

```swift
import CoreLocationUI
import CoreLocation

struct LocationButtonExample: View {
    @Environment(LocationManager.self) private var locationManager
    @State private var currentLocation: CLLocation?

    var body: some View {
        VStack(spacing: 20) {
            if let location = currentLocation {
                Text("Location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            }

            // Standard location button
            LocationButton(.currentLocation) {
                Task {
                    do {
                        currentLocation = try await locationManager.requestLocation()
                    } catch {
                        print("Failed to get location: \(error)")
                    }
                }
            }
            .symbolVariant(.fill)
            .labelStyle(.titleAndIcon)
            .foregroundStyle(.white)
            .tint(.blue)
            .clipShape(Capsule())
        }
    }
}
```

### LocationButton Styles

```swift
// Different label options
LocationButton(.currentLocation) { }     // "Current Location"
LocationButton(.sendCurrentLocation) { } // "Send Current Location"
LocationButton(.sendMyCurrentLocation) { } // "Send My Current Location"
LocationButton(.shareCurrentLocation) { } // "Share Current Location"
LocationButton(.shareMyCurrentLocation) { } // "Share My Current Location"

// Customization
LocationButton {
    // action
}
.symbolVariant(.fill)        // Filled icon
.labelStyle(.iconOnly)       // Icon only
.labelStyle(.titleOnly)      // Title only
.labelStyle(.titleAndIcon)   // Both (default)
.foregroundStyle(.white)
.tint(.blue)
```

**Key Points:**
- Grants temporary full-accuracy authorization
- No permission dialog shown (implicit consent through button tap)
- Authorization lasts for one location request
- Great for "use my location" features without persistent access

---

## Battery Efficiency Best Practices

### 1. Use the Lowest Accuracy Needed

```swift
// Battery impact from lowest to highest
manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers // Lowest power
manager.desiredAccuracy = kCLLocationAccuracyKilometer
manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
manager.desiredAccuracy = kCLLocationAccuracyBest           // High power
manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation // Highest power
```

### 2. Use Distance Filter

```swift
// Only update when user moves significantly
manager.distanceFilter = 50 // meters

// For navigation (every location update)
manager.distanceFilter = kCLDistanceFilterNone
```

### 3. Stop Updates When Not Needed

```swift
struct LocationAwareView: View {
    @Environment(LocationManager.self) private var locationManager

    var body: some View {
        Text("Location View")
            .onAppear {
                locationManager.startUpdatingLocation()
            }
            .onDisappear {
                locationManager.stopUpdatingLocation()
            }
    }
}
```

### 4. Use Significant Location Changes for Background

```swift
// Much more battery efficient than continuous updates
manager.startMonitoringSignificantLocationChanges()
```

### 5. Use Appropriate Activity Type

```swift
// Helps system optimize power usage
manager.activityType = .fitness
manager.pausesLocationUpdatesAutomatically = true
```

### 6. Defer Updates When Possible

```swift
// Batch location updates (iOS 6+)
manager.allowDeferredLocationUpdates(
    untilTraveled: 1000, // meters
    timeout: 300         // seconds
)
```

### Battery Usage Comparison

| Method | Battery Impact | Use Case |
|--------|----------------|----------|
| Significant location changes | Very Low | Background presence, region-based features |
| Visit monitoring | Very Low | Check-in apps, place history |
| Region monitoring | Low | Geofencing (when outside regions) |
| Low accuracy updates | Low | Weather, general location |
| High accuracy updates | Medium-High | Turn-by-turn navigation |
| Best for navigation | High | Precise navigation |

---

## Accuracy vs Performance

### Accuracy Levels

| Accuracy Constant | Typical Accuracy | Use Case |
|-------------------|------------------|----------|
| `kCLLocationAccuracyBestForNavigation` | <5m | Driving navigation |
| `kCLLocationAccuracyBest` | ~5-10m | Walking directions, fitness |
| `kCLLocationAccuracyNearestTenMeters` | ~10m | Local search |
| `kCLLocationAccuracyHundredMeters` | ~100m | City-level features |
| `kCLLocationAccuracyKilometer` | ~1km | Regional weather |
| `kCLLocationAccuracyThreeKilometers` | ~3km | Country/region detection |
| `kCLLocationAccuracyReduced` | ~5km | Privacy-preserving approximate location |

### Checking Location Quality

```swift
func isLocationUsable(_ location: CLLocation, requiredAccuracy: CLLocationAccuracy) -> Bool {
    // Check horizontal accuracy
    guard location.horizontalAccuracy > 0 else { return false }
    guard location.horizontalAccuracy <= requiredAccuracy else { return false }

    // Check timestamp (reject old cached locations)
    let locationAge = -location.timestamp.timeIntervalSinceNow
    guard locationAge < 60 else { return false } // Less than 60 seconds old

    return true
}

func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last,
          isLocationUsable(location, requiredAccuracy: 50) else {
        return
    }

    // Use the location
    currentLocation = location
}
```

---

## Common Pitfalls

### 1. Not Handling Authorization Properly

**Problem:** Requesting location before checking authorization status.

```swift
// Bad
func getLocation() {
    manager.startUpdatingLocation() // May fail silently
}

// Good
func getLocation() {
    switch manager.authorizationStatus {
    case .notDetermined:
        manager.requestWhenInUseAuthorization()
    case .authorizedWhenInUse, .authorizedAlways:
        manager.startUpdatingLocation()
    case .denied, .restricted:
        showSettingsAlert()
    @unknown default:
        break
    }
}
```

### 2. Forgetting to Stop Updates

**Problem:** Location updates continue when not needed, draining battery.

```swift
// Bad - never stops
class ViewModel {
    func startTracking() {
        manager.startUpdatingLocation()
    }
}

// Good - clean up properly
class ViewModel {
    func startTracking() {
        manager.startUpdatingLocation()
    }

    func stopTracking() {
        manager.stopUpdatingLocation()
    }

    deinit {
        manager.stopUpdatingLocation()
    }
}
```

### 3. Using Completion Handlers Instead of Async/Await

**Problem:** Callback-based code is harder to read and maintain.

```swift
// Bad (old pattern)
func getLocation(completion: @escaping (CLLocation?) -> Void) {
    // ...
}

// Good (modern pattern)
func getLocation() async throws -> CLLocation {
    // ...
}
```

### 4. Not Handling Reduced Accuracy

**Problem:** Assuming full accuracy when user may have granted reduced accuracy.

```swift
// Check accuracy authorization
if manager.accuracyAuthorization == .reducedAccuracy {
    // Show UI indicating approximate location
    // Optionally request temporary full accuracy
    try await manager.requestTemporaryFullAccuracyAuthorization(
        withPurposeKey: "NavigationAccuracy"
    )
}
```

### 5. Background Location Without Proper Configuration

**Problem:** Background location stops working without proper setup.

**Checklist:**
1. Enable "Location updates" in Background Modes capability
2. Set `allowsBackgroundLocationUpdates = true`
3. Request "Always" authorization
4. Set `showsBackgroundLocationIndicator = true` (required)
5. Add proper Info.plist descriptions

### 6. Not Handling Location Errors

```swift
func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    let clError = error as? CLError

    switch clError?.code {
    case .denied:
        // User denied authorization
        handleAuthorizationDenied()
    case .locationUnknown:
        // Temporary failure, may recover
        // Don't stop updates, wait for next attempt
        break
    case .network:
        // Network unavailable
        handleNetworkError()
    default:
        print("Location error: \(error.localizedDescription)")
    }
}
```

### 7. Region Monitoring Limits

**Problem:** Trying to monitor more than 20 regions.

```swift
// Check before adding
if manager.monitoredRegions.count >= 20 {
    // Remove least important region first
    if let oldestRegion = findLeastImportantRegion() {
        manager.stopMonitoring(for: oldestRegion)
    }
}
manager.startMonitoring(for: newRegion)
```

---

## iOS Version Compatibility

### Feature Availability

| Feature | Minimum iOS | Notes |
|---------|-------------|-------|
| Basic location | iOS 2+ | Core functionality |
| Region monitoring | iOS 4+ | Geofencing |
| Significant location changes | iOS 4+ | Battery efficient background |
| Visit monitoring | iOS 8+ | Automatic place detection |
| Request authorization | iOS 8+ | Explicit permission requests |
| LocationButton | iOS 15+ | One-time location access |
| Reduced accuracy | iOS 14+ | Privacy feature |
| Temporary full accuracy | iOS 14+ | Request upgrade from reduced |
| MKGeocodingRequest | iOS 26+ | New geocoding API |
| MKReverseGeocodingRequest | iOS 26+ | New reverse geocoding API |

### Availability Checks

```swift
// Check if region monitoring is available
if CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) {
    // Safe to use region monitoring
}

// Check if beacon ranging is available
if CLLocationManager.isRangingAvailable() {
    // Safe to range beacons
}

// Check if heading is available
if CLLocationManager.headingAvailable() {
    // Device has compass
}

// Check if significant location monitoring is available
if CLLocationManager.significantLocationChangeMonitoringAvailable() {
    // Safe to use significant changes
}
```

### iOS 26+ Deprecations

- `CLGeocoder` is deprecated in favor of `MKGeocodingRequest` and `MKReverseGeocodingRequest`
- Consider migrating geocoding code when targeting iOS 26+

---

## Complete Example

### Full Location Manager Implementation

```swift
import CoreLocation
import Combine

@Observable
class AppLocationManager: NSObject, CLLocationManagerDelegate {
    // MARK: - Properties

    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var locationStream: AsyncStream<CLLocation>.Continuation?

    var currentLocation: CLLocation?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var accuracyAuthorization: CLAccuracyAuthorization = .reducedAccuracy
    var isUpdatingLocation = false
    var errorMessage: String?

    // MARK: - Initialization

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
        authorizationStatus = manager.authorizationStatus
        accuracyAuthorization = manager.accuracyAuthorization
    }

    // MARK: - Authorization

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    // MARK: - One-Time Location

    func requestLocation() async throws -> CLLocation {
        guard isAuthorized else {
            throw LocationError.notAuthorized
        }

        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    // MARK: - Continuous Updates

    func startUpdatingLocation() {
        guard isAuthorized else {
            errorMessage = "Location not authorized"
            return
        }
        isUpdatingLocation = true
        manager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        isUpdatingLocation = false
        manager.stopUpdatingLocation()
    }

    func locationUpdates() -> AsyncStream<CLLocation> {
        AsyncStream { continuation in
            locationStream = continuation
            manager.startUpdatingLocation()

            continuation.onTermination = { [weak self] _ in
                self?.manager.stopUpdatingLocation()
                self?.locationStream = nil
            }
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        currentLocation = location
        errorMessage = nil

        // Handle one-time request
        if let continuation = locationContinuation {
            continuation.resume(returning: location)
            locationContinuation = nil
        }

        // Handle stream
        locationStream?.yield(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = error.localizedDescription

        if let continuation = locationContinuation {
            continuation.resume(throwing: error)
            locationContinuation = nil
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        accuracyAuthorization = manager.accuracyAuthorization
    }
}

// MARK: - Error Types

enum LocationError: LocalizedError {
    case notAuthorized
    case locationUnavailable
    case timeout

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Location services not authorized. Please enable in Settings."
        case .locationUnavailable:
            return "Unable to determine your location."
        case .timeout:
            return "Location request timed out."
        }
    }
}
```

### SwiftUI Integration

```swift
import SwiftUI
import CoreLocation
import CoreLocationUI

struct LocationDemoView: View {
    @Environment(AppLocationManager.self) private var locationManager
    @State private var isTracking = false
    @State private var trackingTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                authorizationSection
                locationSection
                actionsSection
            }
            .navigationTitle("Location Demo")
        }
    }

    // MARK: - Sections

    private var authorizationSection: some View {
        Section("Authorization") {
            HStack {
                Text("Status")
                Spacer()
                Text(authorizationText)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Accuracy")
                Spacer()
                Text(accuracyText)
                    .foregroundStyle(.secondary)
            }

            if locationManager.authorizationStatus == .notDetermined {
                Button("Request Permission") {
                    locationManager.requestWhenInUseAuthorization()
                }
            }
        }
    }

    private var locationSection: some View {
        Section("Current Location") {
            if let location = locationManager.currentLocation {
                LabeledContent("Latitude", value: String(format: "%.6f", location.coordinate.latitude))
                LabeledContent("Longitude", value: String(format: "%.6f", location.coordinate.longitude))
                LabeledContent("Accuracy", value: String(format: "%.1fm", location.horizontalAccuracy))
                LabeledContent("Altitude", value: String(format: "%.1fm", location.altitude))
                LabeledContent("Speed", value: String(format: "%.1f m/s", max(0, location.speed)))
            } else {
                Text("No location data")
                    .foregroundStyle(.secondary)
            }

            if let error = locationManager.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
            }
        }
    }

    private var actionsSection: some View {
        Section("Actions") {
            // One-time location with LocationButton
            LocationButton(.currentLocation) {
                Task {
                    _ = try? await locationManager.requestLocation()
                }
            }
            .symbolVariant(.fill)
            .labelStyle(.titleAndIcon)
            .frame(maxWidth: .infinity)

            // One-time location with regular button
            Button("Get Location Once") {
                Task {
                    _ = try? await locationManager.requestLocation()
                }
            }
            .disabled(!locationManager.isAuthorized)

            // Continuous tracking toggle
            Button(isTracking ? "Stop Tracking" : "Start Continuous Tracking") {
                toggleTracking()
            }
            .disabled(!locationManager.isAuthorized)
        }
    }

    // MARK: - Helpers

    private var authorizationText: String {
        switch locationManager.authorizationStatus {
        case .notDetermined: return "Not Determined"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorizedWhenInUse: return "When In Use"
        case .authorizedAlways: return "Always"
        @unknown default: return "Unknown"
        }
    }

    private var accuracyText: String {
        switch locationManager.accuracyAuthorization {
        case .fullAccuracy: return "Full"
        case .reducedAccuracy: return "Reduced"
        @unknown default: return "Unknown"
        }
    }

    private func toggleTracking() {
        if isTracking {
            trackingTask?.cancel()
            trackingTask = nil
            isTracking = false
        } else {
            isTracking = true
            trackingTask = Task {
                for await _ in locationManager.locationUpdates() {
                    // Location updates are automatically stored in currentLocation
                }
            }
        }
    }
}

// MARK: - App Entry Point

@main
struct LocationDemoApp: App {
    @State private var locationManager = AppLocationManager()

    var body: some Scene {
        WindowGroup {
            LocationDemoView()
                .environment(locationManager)
        }
    }
}
```

---

## References

### Official Documentation
- [CoreLocation Framework](https://developer.apple.com/documentation/corelocation)
- [CLLocationManager](https://developer.apple.com/documentation/corelocation/cllocationmanager)
- [Requesting Authorization for Location Services](https://developer.apple.com/documentation/corelocation/requesting_authorization_for_location_services)
- [Monitoring the User's Proximity to Geographic Regions](https://developer.apple.com/documentation/corelocation/monitoring_the_user_s_proximity_to_geographic_regions)
- [Ranging for Beacons](https://developer.apple.com/documentation/corelocation/ranging_for_beacons)
- [LocationButton](https://developer.apple.com/documentation/corelocationui/locationbutton)

### WWDC Sessions
- [What's New in Location (WWDC20)](https://developer.apple.com/videos/play/wwdc2020/10660/)
- [Meet the Location Button (WWDC21)](https://developer.apple.com/videos/play/wwdc2021/10102/)
- [What's New in CoreLocation (WWDC19)](https://developer.apple.com/videos/play/wwdc2019/705/)

### Human Interface Guidelines
- [Accessing Private Data](https://developer.apple.com/design/human-interface-guidelines/accessing-private-data)

---

*Last updated: February 2026*

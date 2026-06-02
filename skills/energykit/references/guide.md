# EnergyKit Framework Guide for iOS 26

> **Version:** iOS 26 / iPadOS 26 Beta
> **Last Updated:** February 2026
> **Availability:** Contiguous United States only

## Overview

EnergyKit is Apple's new framework introduced at WWDC 2025 that provides grid electricity forecasts to help apps optimize when users consume electricity by identifying times when cleaner energy is available on the grid. It is designed to help reduce or shift the two largest home electric loads: HVAC (heating, ventilation, and air conditioning) and electric vehicle (EV) charging.

### Key Features

- **Grid Forecast**: Personalized forecast based on user's Home location
- **Clean Energy Identification**: Identifies times when cleaner electricity is available
- **Utility Rate Integration**: Incorporates time-of-use rate plans when users connect their utility account
- **Privacy-First Design**: End-to-end encryption with on-device storage

### Target Use Cases

EnergyKit is currently designed for:
- **EV Charging Apps**: Shift charging to cleaner/cheaper electricity periods — report usage via `ElectricVehicleLoadEvent`.
- **Smart Thermostat Apps**: Reduce HVAC usage during peak/dirty energy periods — report usage via `ElectricHVACLoadEvent` (the HVAC counterpart to `ElectricVehicleLoadEvent`; same submission pattern via `EnergyVenue.submitEvents`).

> EnergyKit is for residential, behind-the-meter use only (household devices, appliances, EV charging) — not commercial or industrial applications.

---

## Platform Requirements

| Requirement | Details |
|-------------|---------|
| iOS/iPadOS | 26.0 or later |
| Geographic Availability | Contiguous United States only (excludes Alaska, Hawaii, and U.S. territories) |
| Home Hub | Required (Apple TV or HomePod) for some features |
| Entitlement | `com.apple.developer.energykit` required |

### Beta Limitations

- Currently limited to development builds and Ad Hoc testing
- TestFlight and App Store submissions coming later in 2025
- Limited to car manufacturers and thermostat OEMs for production releases
- Development-only entitlement available for testing/experimentation

---

## Project Setup

### 1. Add the Entitlement

Add the EnergyKit entitlement to your app's entitlements file:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.energykit</key>
    <true/>
</dict>
</plist>
```

### 2. Import the Framework

```swift
import EnergyKit
```

### 3. Request User Authorization

Users control access to their energy data in system Privacy settings. When your app wants to access energy data, the system prompts the user for approval (similar to Home data, Contacts, Photos, etc.).

---

## Core Types and APIs

### EnergyVenue

An `EnergyVenue` represents a physical site where devices controlled by your app consume electricity from the grid, where the owner has established a Home via the Home app or the EnergyKit onboarding flow.

```swift
import EnergyKit

// Retrieve an EnergyVenue by ID
func retrieveVenue(venueID: UUID) async -> EnergyVenue? {
    return await EnergyVenue.venue(for: venueID)
}

// EnergyVenue properties
let venue: EnergyVenue
let venueID: UUID = venue.id  // Unique identifier
```

#### Key Methods

| Method | Description |
|--------|-------------|
| `venue(for: UUID) async -> EnergyVenue?` | Retrieve a venue by its identifier |
| `submitEvents([ElectricVehicleLoadEvent]) async throws` | Submit charging events for the venue |

---

### ElectricityGuidance

`ElectricityGuidance` provides grid forecast information to help determine optimal times for electricity usage.

#### Query Creation

```swift
import EnergyKit

// Create a guidance query
// .shift - For devices that can relocate electricity usage (EVs)
// .reduce - For devices that reduce usage (smart thermostats)
let query = ElectricityGuidance.Query(suggestedAction: .shift)
```

#### Suggested Action Types

| Action | Use Case |
|--------|----------|
| `.shift` | EV charging - relocate usage to cleaner/cheaper times |
| `.reduce` | Smart thermostats - reduce overall usage during peak/dirty periods |

#### Streaming Guidance Updates

```swift
import EnergyKit

func streamGuidance(
    venueID: UUID,
    update: (_ guidance: ElectricityGuidance) -> Void
) async throws {
    let query = ElectricityGuidance.Query(suggestedAction: .shift)

    // ElectricityGuidance.sharedService returns an AsyncSequence
    for try await currentGuidance in ElectricityGuidance.sharedService.guidance(
        using: query,
        at: venueID
    ) {
        update(currentGuidance)

        // Break after first fetch if continuous updates not needed
        // break
    }
}
```

#### Key Properties

| Property | Type | Description |
|----------|------|-------------|
| `guidanceToken` | `UUID` | Unique token identifying the guidance instance; pass it into the load event you create while following this guidance |
| `energyVenueID` | `UUID` | Identifier for the venue the guidance applies to |
| `interval` | `DateInterval` | Time range the guidance covers |
| `values` | `[ElectricityGuidance.Value]` | Weighted values per time interval describing when to shift/reduce |

---

### ElectricVehicleLoadEvent

Represents an EV charging event with electrical measurements and session information.

#### ElectricalMeasurement

```swift
import EnergyKit

func createChargingMeasurement(
    stateOfCharge: Double,
    chargingPowerKW: Double,
    cumulativeEnergyKWh: Double
) -> ElectricVehicleLoadEvent.ElectricalMeasurement {

    let soc = Int(stateOfCharge.rounded(.down))

    let power = Measurement<UnitPower>(
        value: chargingPowerKW * 1000000,  // Convert to milliwatts
        unit: .milliwatts
    )

    let energy = Measurement<UnitEnergy>(
        value: cumulativeEnergyKWh * 1000000,  // Convert to milliwatt-hours
        unit: .EnergyKit.milliwattHours
    )

    return ElectricVehicleLoadEvent.ElectricalMeasurement(
        stateOfCharge: soc,
        direction: .imported,  // .imported for charging
        power: power,
        energy: energy
    )
}
```

#### ElectricalMeasurement Properties

| Property | Type | Description |
|----------|------|-------------|
| `stateOfCharge` | `Int` | Battery charge percentage (0-100) |
| `direction` | `ElectricityFlowDirection` | `.imported` for charging |
| `power` | `Measurement<UnitPower>` | Current power in milliwatts |
| `energy` | `Measurement<UnitEnergy>` | Cumulative energy in milliwatt-hours |

#### Session Management

```swift
import EnergyKit

class ChargingSessionManager {
    var session: ElectricVehicleLoadEvent.Session?
    var currentGuidance: ElectricityGuidance
    var isFollowingGuidance: Bool = true

    // Begin a new charging session
    func beginSession() {
        session = ElectricVehicleLoadEvent.Session(
            id: UUID(),
            state: .begin,
            guidanceState: .init(
                wasFollowingGuidance: isFollowingGuidance,
                guidanceToken: currentGuidance.guidanceToken
            )
        )
    }

    // Update an active session
    func updateSession() {
        guard let existingSession = session else { return }

        session = ElectricVehicleLoadEvent.Session(
            id: existingSession.id,
            state: .active,
            guidanceState: .init(
                wasFollowingGuidance: isFollowingGuidance,
                guidanceToken: currentGuidance.guidanceToken
            )
        )
    }

    // End the charging session
    func endSession() {
        guard let existingSession = session else { return }

        session = ElectricVehicleLoadEvent.Session(
            id: existingSession.id,
            state: .end,
            guidanceState: .init(
                wasFollowingGuidance: isFollowingGuidance,
                guidanceToken: currentGuidance.guidanceToken
            )
        )
    }
}
```

#### Session States

| State | Description |
|-------|-------------|
| `.begin` | Session start |
| `.active` | Session in progress |
| `.end` | Session completion |

#### Creating and Submitting Events

```swift
import EnergyKit

class EVChargingController {
    var session: ElectricVehicleLoadEvent.Session?
    var events = [ElectricVehicleLoadEvent]()
    var currentVenue: EnergyVenue
    var currentGuidance: ElectricityGuidance
    var isFollowingGuidance: Bool = true

    func createLoadEvent(
        sessionState: ElectricVehicleLoadEvent.Session.State,
        timestamp: Date,
        measurement: ElectricVehicleLoadEvent.ElectricalMeasurement,
        vehicleID: String
    ) {
        // Update session state
        switch sessionState {
        case .begin:
            beginSession()
        case .active:
            updateSession()
        case .end:
            endSession()
        @unknown default:
            fatalError("Unknown session state")
        }

        // Create the event
        guard let session = session else { return }

        let event = ElectricVehicleLoadEvent(
            timestamp: timestamp,
            measurement: measurement,
            session: session,
            deviceID: vehicleID
        )

        events.append(event)
    }

    // Submit batched events to the venue
    func submitEvents() async throws {
        try await currentVenue.submitEvents(events)
        events.removeAll()
    }

    // Session management helpers
    private func beginSession() { /* ... */ }
    private func updateSession() { /* ... */ }
    private func endSession() { /* ... */ }
}
```

---

### ElectricityInsight

Provides environmental impact information and electricity usage insights.

#### ElectricityInsightQuery

```swift
import EnergyKit

func createInsightsQuery(for date: Date) -> ElectricityInsightQuery {
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: date)
    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

    return ElectricityInsightQuery(
        options: .cleanliness.union(.tariff),  // Request both cleanliness and tariff data
        range: DateInterval(start: startOfDay, end: endOfDay),
        granularity: .daily,
        flowDirection: .imported  // For consumption data
    )
}
```

#### Query Options

| Option | Description |
|--------|-------------|
| `.cleanliness` | Carbon intensity / clean energy data |
| `.tariff` | Electricity rate/pricing data |
| `.cleanliness.union(.tariff)` | Both cleanliness and tariff data |

#### Query Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `options` | `InsightOptions` | Type of data to retrieve |
| `range` | `DateInterval` | Time period for insights |
| `granularity` | `Granularity` | Data granularity (e.g., `.daily`) |
| `flowDirection` | `ElectricityFlowDirection` | `.imported` for consumption |

#### Fetching Insights

```swift
import EnergyKit

class InsightsManager {
    let venue: EnergyVenue

    func generateInsights(
        for vehicleIdentifier: String,
        on date: Date
    ) async throws -> ElectricityInsightRecord<Measurement<UnitEnergy>>? {
        let query = createInsightsQuery(for: date)

        // Fetch insights from the shared service
        return try await ElectricityInsightService.shared.energyInsights(
            forDeviceID: vehicleIdentifier,
            using: query,
            atVenue: venue.id
        ).first { record in
            return record.range.start == query.range.start
        }
    }
}
```

#### Cleanliness Categories

| Category | Description |
|----------|-------------|
| `clean` | Electricity from renewable sources |
| `reduce` | Mixed sources |
| `avoid` | Primarily fossil fuels |

#### Rate Plan Categories (Time-of-Use)

| Category | Description |
|----------|-------------|
| `superOffPeak` | Lowest rates |
| `offPeak` | Below average rates |
| `partialPeak` | Moderate rates |
| `onPeak` | Higher rates |
| `criticalPeak` | Highest rates |

---

## Complete Implementation Example

### EnergyVenueManager

```swift
import EnergyKit
import SwiftUI

@Observable
final class EnergyVenueManager {
    // MARK: - Properties

    let venue: EnergyVenue
    var guidance: ElectricityGuidance?
    var isLoading = false
    var error: Error?

    private var streamGuidanceTask: Task<(), Error>?

    // MARK: - Initialization

    init?(venueID: UUID) async {
        guard let energyVenue = await EnergyVenue.venue(for: venueID) else {
            return nil
        }
        venue = energyVenue
    }

    // MARK: - Guidance Monitoring

    func startGuidanceMonitoring() {
        streamGuidanceTask?.cancel()
        streamGuidanceTask = Task.detached { [weak self] in
            guard let venueID = self?.venue.id else { return }

            try? await self?.streamGuidance(venueID: venueID) { guidance in
                self?.guidance = guidance

                if Task.isCancelled {
                    return
                }
            }
        }
    }

    func stopGuidanceMonitoring() {
        streamGuidanceTask?.cancel()
        streamGuidanceTask = nil
    }

    // MARK: - Private Methods

    private func streamGuidance(
        venueID: UUID,
        update: @escaping (_ guidance: ElectricityGuidance) -> Void
    ) async throws {
        let query = ElectricityGuidance.Query(suggestedAction: .shift)

        for try await currentGuidance in ElectricityGuidance.sharedService.guidance(
            using: query,
            at: venueID
        ) {
            await MainActor.run {
                update(currentGuidance)
            }
        }
    }
}
```

### EVChargingController

```swift
import EnergyKit

@Observable
final class EVChargingController {
    // MARK: - Properties

    var session: ElectricVehicleLoadEvent.Session?
    var currentGuidance: ElectricityGuidance
    var isFollowingGuidance: Bool = true
    var events = [ElectricVehicleLoadEvent]()

    private let currentVenue: EnergyVenue
    private let vehicleID: String

    // MARK: - Initialization

    init(venue: EnergyVenue, guidance: ElectricityGuidance, vehicleID: String) {
        self.currentVenue = venue
        self.currentGuidance = guidance
        self.vehicleID = vehicleID
    }

    // MARK: - Charging Session Management

    func startCharging(
        stateOfCharge: Double,
        power: Double,
        energy: Double
    ) {
        let measurement = createMeasurement(
            stateOfCharge: stateOfCharge,
            power: power,
            energy: energy
        )

        createLoadEvent(
            sessionState: .begin,
            timestamp: Date(),
            measurement: measurement
        )
    }

    func updateCharging(
        stateOfCharge: Double,
        power: Double,
        energy: Double
    ) {
        let measurement = createMeasurement(
            stateOfCharge: stateOfCharge,
            power: power,
            energy: energy
        )

        createLoadEvent(
            sessionState: .active,
            timestamp: Date(),
            measurement: measurement
        )
    }

    func stopCharging(
        stateOfCharge: Double,
        power: Double,
        energy: Double
    ) {
        let measurement = createMeasurement(
            stateOfCharge: stateOfCharge,
            power: power,
            energy: energy
        )

        createLoadEvent(
            sessionState: .end,
            timestamp: Date(),
            measurement: measurement
        )
    }

    func submitEvents() async throws {
        guard !events.isEmpty else { return }
        try await currentVenue.submitEvents(events)
        events.removeAll()
    }

    // MARK: - Private Methods

    private func createMeasurement(
        stateOfCharge: Double,
        power: Double,
        energy: Double
    ) -> ElectricVehicleLoadEvent.ElectricalMeasurement {
        let soc = Int(stateOfCharge.rounded(.down))
        let powerMeasurement = Measurement<UnitPower>(
            value: power * 1_000_000,
            unit: .milliwatts
        )
        let energyMeasurement = Measurement<UnitEnergy>(
            value: energy * 1_000_000,
            unit: .EnergyKit.milliwattHours
        )

        return ElectricVehicleLoadEvent.ElectricalMeasurement(
            stateOfCharge: soc,
            direction: .imported,
            power: powerMeasurement,
            energy: energyMeasurement
        )
    }

    private func createLoadEvent(
        sessionState: ElectricVehicleLoadEvent.Session.State,
        timestamp: Date,
        measurement: ElectricVehicleLoadEvent.ElectricalMeasurement
    ) {
        switch sessionState {
        case .begin:
            session = ElectricVehicleLoadEvent.Session(
                id: UUID(),
                state: .begin,
                guidanceState: .init(
                    wasFollowingGuidance: isFollowingGuidance,
                    guidanceToken: currentGuidance.guidanceToken
                )
            )
        case .active:
            guard let existingSession = session else { return }
            session = ElectricVehicleLoadEvent.Session(
                id: existingSession.id,
                state: .active,
                guidanceState: .init(
                    wasFollowingGuidance: isFollowingGuidance,
                    guidanceToken: currentGuidance.guidanceToken
                )
            )
        case .end:
            guard let existingSession = session else { return }
            session = ElectricVehicleLoadEvent.Session(
                id: existingSession.id,
                state: .end,
                guidanceState: .init(
                    wasFollowingGuidance: isFollowingGuidance,
                    guidanceToken: currentGuidance.guidanceToken
                )
            )
        @unknown default:
            return
        }

        guard let session = session else { return }

        let event = ElectricVehicleLoadEvent(
            timestamp: timestamp,
            measurement: measurement,
            session: session,
            deviceID: vehicleID
        )

        events.append(event)
    }
}
```

### SwiftUI Integration

```swift
import SwiftUI
import EnergyKit

struct ChargingView: View {
    @State private var venueManager: EnergyVenueManager?
    @State private var chargingController: EVChargingController?

    let venueID: UUID
    let vehicleID: String

    var body: some View {
        VStack {
            if let guidance = venueManager?.guidance {
                GuidanceStatusView(guidance: guidance)
            } else {
                ProgressView("Loading guidance...")
            }

            ChargingControlsView(
                onStart: startCharging,
                onStop: stopCharging
            )
        }
        .task {
            await setupManagers()
        }
        .onDisappear {
            venueManager?.stopGuidanceMonitoring()
        }
    }

    private func setupManagers() async {
        venueManager = await EnergyVenueManager(venueID: venueID)
        venueManager?.startGuidanceMonitoring()

        if let venue = venueManager?.venue,
           let guidance = venueManager?.guidance {
            chargingController = EVChargingController(
                venue: venue,
                guidance: guidance,
                vehicleID: vehicleID
            )
        }
    }

    private func startCharging() {
        chargingController?.startCharging(
            stateOfCharge: 50.0,
            power: 7.2,  // kW
            energy: 0.0  // kWh
        )
    }

    private func stopCharging() {
        chargingController?.stopCharging(
            stateOfCharge: 80.0,
            power: 0.0,
            energy: 21.6  // kWh
        )

        Task {
            try? await chargingController?.submitEvents()
        }
    }
}
```

---

## Best Practices

### Event Submission

1. **Batch Events**: Submit events in batches for better performance
2. **Recommended Frequency**: Submit every 15 minutes during steady charging
3. **Always Include Guidance Token**: Include the current guidance token when creating events

### Data Storage

1. **Persist Venue ID**: Store the venue identifier locally using UUID
2. **On-Device Storage**: Events are stored in Core Data on-device
3. **End-to-End Encryption**: Data synced via CloudKit with full encryption

### Background Updates

```swift
// Use background tasks for continuous monitoring
func scheduleBackgroundGuidanceUpdate() {
    // Call streamGuidance from a Background Task handler
    // for updates while app is not running
}

// Or use interactive charging widgets
// to keep guidance up to date
```

### Error Handling

```swift
enum EnergyKitError: LocalizedError {
    case venueNotFound
    case guidanceUnavailable
    case submissionFailed(underlying: Error)
    case regionNotSupported

    var errorDescription: String? {
        switch self {
        case .venueNotFound:
            return "Energy venue could not be found"
        case .guidanceUnavailable:
            return "Grid guidance is currently unavailable"
        case .submissionFailed(let error):
            return "Failed to submit events: \(error.localizedDescription)"
        case .regionNotSupported:
            return "EnergyKit is only available in the contiguous United States"
        }
    }
}
```

---

## Onboarding Flow

### User Opt-In Process

1. **Display Charging Locations**: Show a list of charging locations in your app
2. **Clean Energy Toggle**: Add a toggle to allow users to opt in to Clean Energy Charging
3. **Venue Selection**: When enabled, retrieve nearby EnergyVenues and let users select one
4. **Persist Mapping**: Store the mapping of selected venue to charging location

### Example Onboarding UI

```swift
struct EnergyKitOnboardingView: View {
    @State private var isCleanEnergyEnabled = false
    @State private var selectedVenue: EnergyVenue?
    @State private var availableVenues: [EnergyVenue] = []

    var body: some View {
        Form {
            Section {
                Toggle("Clean Energy Charging", isOn: $isCleanEnergyEnabled)
            } footer: {
                Text("Optimize charging times for cleaner, cheaper electricity")
            }

            if isCleanEnergyEnabled {
                Section("Select Charging Location") {
                    ForEach(availableVenues, id: \.id) { venue in
                        Button {
                            selectedVenue = venue
                        } label: {
                            HStack {
                                Text(venue.id.uuidString)
                                Spacer()
                                if selectedVenue?.id == venue.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: isCleanEnergyEnabled) { _, newValue in
            if newValue {
                Task {
                    await loadAvailableVenues()
                }
            }
        }
    }

    private func loadAvailableVenues() async {
        // Retrieve EnergyVenues near the user's location
        // This typically requires the user to have set up a Home
    }
}
```

---

## Privacy and Security

### Data Protection

- **On-Device Storage**: EnergyKit stores data on users' Apple devices
- **Data Protection Class**: Uses "Protected Until First User Authentication"
- **Data Vault**: Additional security layer for sensitive data
- **End-to-End Encryption**: iCloud/CloudKit sync with full encryption

### User Control

- Users can control app access in **Settings > Privacy > Energy Data**
- Users can delete their EnergyKit data at any time
- Data is inaccessible to Apple

### Attribution Guidelines

> Note: Attribution guidelines for using EnergyKit data will be available later in Fall 2025. Consult official guidelines before release.

---

## Resources

### Official Documentation

- [EnergyKit Framework](https://developer.apple.com/energykit/)
- [EnergyKit Documentation](https://developer.apple.com/documentation/energykit)
- [Optimizing Home Electricity Usage](https://developer.apple.com/documentation/EnergyKit/optimizing-home-electricity-usage)
- [EnergyKit Entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.energykit)

### WWDC Sessions

- [Optimize home electricity usage with EnergyKit (WWDC25)](https://developer.apple.com/videos/play/wwdc2025/257/)
- Demystify concurrency in SwiftUI
- Finish tasks in the background

### Developer Forums

- [EnergyKit Forums](https://developer.apple.com/forums/tags/energykit)

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| EnergyKit not available | Ensure you're in the contiguous US and using iOS 26+ |
| Entitlement error | Add `com.apple.developer.energykit` to your entitlements |
| No venues found | User must have a Home set up via Home app |
| Guidance not updating | Check network connectivity and background task setup |

### Testing Requirements

- **Device**: Physical iPhone with iOS 26 beta
- **Xcode**: Xcode 26 (latest beta)
- **Build Type**: Development or Ad Hoc builds only (TestFlight coming later)

---

## API Quick Reference

### Core Types

| Type | Description |
|------|-------------|
| `EnergyVenue` | Physical site for electricity consumption |
| `ElectricityGuidance` | Grid forecast for optimal usage times |
| `ElectricityGuidance.Query` | Query configuration for guidance |
| `ElectricVehicleLoadEvent` | EV charging event record |
| `ElectricVehicleLoadEvent.Session` | Charging session information |
| `ElectricVehicleLoadEvent.ElectricalMeasurement` | Power/energy measurements |
| `ElectricityInsightQuery` | Query for electricity insights |
| `ElectricityInsightRecord` | Environmental impact data |
| `ElectricityInsightService` | Service for fetching insights |

### Key Services

| Service | Description |
|---------|-------------|
| `ElectricityGuidance.sharedService` | Shared service for streaming guidance |
| `ElectricityInsightService.shared` | Shared service for fetching insights |

### Suggested Actions

| Action | Use Case |
|--------|----------|
| `.shift` | EV charging (relocate usage) |
| `.reduce` | Thermostats (reduce usage) |

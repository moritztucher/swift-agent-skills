# HealthKit Guide - iOS/Swift

Comprehensive guide for reading, writing, and querying health and fitness data in iOS/Swift using the HealthKit framework.

---

## Overview

**HealthKit** is Apple's framework for managing health and fitness data on iOS devices. It provides a centralized, secure repository for health data that users can share across apps.

### Key Use Cases

- **Health Data** - Read/write heart rate, blood pressure, weight, sleep, nutrition
- **Fitness Tracking** - Steps, distance, calories burned, exercise minutes
- **Workouts** - Create and query workout sessions with detailed metrics
- **Activity Rings** - Access Move, Exercise, and Stand ring data
- **Clinical Records** - Read medical records (with user authorization)
- **Background Delivery** - Receive updates when new health data is available

---

## Import

```swift
import HealthKit
```

---

## Setup & Configuration

### 1. Add HealthKit Capability

In Xcode:
1. Select your target
2. Go to **Signing & Capabilities**
3. Click **+ Capability**
4. Add **HealthKit**

For background delivery, also enable **Background Delivery** in the HealthKit capability.

### 2. Add Info.plist Keys

Add usage description keys explaining why your app needs access to health data:

```xml
<!-- Required for reading health data -->
<key>NSHealthShareUsageDescription</key>
<string>We need access to your health data to track your fitness progress.</string>

<!-- Required for writing health data -->
<key>NSHealthUpdateUsageDescription</key>
<string>We need to save your workout data to the Health app.</string>

<!-- Required for clinical records (if applicable) -->
<key>NSHealthClinicalHealthRecordsShareUsageDescription</key>
<string>We need access to your clinical records to provide health insights.</string>
```

### 3. Add Entitlements

Your app's entitlements file should include:

```xml
<key>com.apple.developer.healthkit</key>
<true/>
<key>com.apple.developer.healthkit.access</key>
<array>
    <string>health-records</string>  <!-- Only if accessing clinical records -->
</array>
<key>com.apple.developer.healthkit.background-delivery</key>
<true/>  <!-- Only if using background delivery -->
```

---

## Core Concepts

### HKHealthStore

The central object for all HealthKit operations. Create a single instance and reuse it throughout your app.

```swift
import HealthKit

@Observable
class HealthManager {
    private let healthStore = HKHealthStore()

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
}
```

### Data Types

HealthKit organizes data into several type categories:

| Type | Description | Examples |
|------|-------------|----------|
| `HKQuantityType` | Numeric measurements | Heart rate, steps, weight |
| `HKCategoryType` | Categorical data | Sleep analysis, mindful minutes |
| `HKWorkoutType` | Workout sessions | Running, cycling, swimming |
| `HKActivitySummaryType` | Daily activity summary | Activity rings data |
| `HKCharacteristicType` | User characteristics | Date of birth, blood type |
| `HKCorrelationType` | Related data grouped together | Blood pressure (systolic + diastolic) |
| `HKDocumentType` | Clinical documents | CDA documents |

### Common Quantity Type Identifiers

```swift
// Fitness
HKQuantityType(.stepCount)
HKQuantityType(.distanceWalkingRunning)
HKQuantityType(.distanceCycling)
HKQuantityType(.activeEnergyBurned)
HKQuantityType(.basalEnergyBurned)
HKQuantityType(.flightsClimbed)
HKQuantityType(.appleExerciseTime)
HKQuantityType(.appleStandTime)
HKQuantityType(.appleMoveTime)

// Body Measurements
HKQuantityType(.bodyMass)
HKQuantityType(.height)
HKQuantityType(.bodyMassIndex)
HKQuantityType(.bodyFatPercentage)
HKQuantityType(.leanBodyMass)

// Heart
HKQuantityType(.heartRate)
HKQuantityType(.restingHeartRate)
HKQuantityType(.walkingHeartRateAverage)
HKQuantityType(.heartRateVariabilitySDNN)

// Vitals
HKQuantityType(.bloodPressureSystolic)
HKQuantityType(.bloodPressureDiastolic)
HKQuantityType(.respiratoryRate)
HKQuantityType(.bodyTemperature)
HKQuantityType(.oxygenSaturation)
HKQuantityType(.bloodGlucose)

// Nutrition
HKQuantityType(.dietaryEnergyConsumed)
HKQuantityType(.dietaryProtein)
HKQuantityType(.dietaryCarbohydrates)
HKQuantityType(.dietaryFatTotal)
HKQuantityType(.dietaryWater)
```

### Common Category Type Identifiers

```swift
HKCategoryType(.sleepAnalysis)
HKCategoryType(.mindfulSession)
HKCategoryType(.appleStandHour)
HKCategoryType(.lowHeartRateEvent)
HKCategoryType(.highHeartRateEvent)
HKCategoryType(.irregularHeartRhythmEvent)
```

---

## Authorization

### Defining Data Types

Create sets of types your app needs to read and write:

```swift
@Observable
class HealthManager {
    private let healthStore = HKHealthStore()

    // Types to read from HealthKit
    private var typesToRead: Set<HKObjectType> {
        [
            HKQuantityType(.heartRate),
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.bodyMass),
            HKCategoryType(.sleepAnalysis),
            HKObjectType.activitySummaryType(),
            HKObjectType.workoutType()
        ]
    }

    // Types to write to HealthKit
    private var typesToWrite: Set<HKSampleType> {
        [
            HKQuantityType(.bodyMass),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKObjectType.workoutType()
        ]
    }
}
```

### Requesting Authorization (Async/Await)

```swift
@Observable
class HealthManager {
    private let healthStore = HKHealthStore()
    var authorizationStatus: AuthorizationStatus = .notDetermined

    enum AuthorizationStatus {
        case notDetermined
        case authorized
        case denied
        case unavailable
    }

    func requestAuthorization() async throws {
        // Check if HealthKit is available on this device
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationStatus = .unavailable
            throw HealthError.healthDataUnavailable
        }

        // Request authorization
        try await healthStore.requestAuthorization(
            toShare: typesToWrite,
            read: typesToRead
        )

        // Note: We cannot determine if the user actually granted permission
        // for reading. Authorization status for reads is always .notDetermined
        // to protect user privacy.
        authorizationStatus = .authorized
    }
}

enum HealthError: LocalizedError {
    case healthDataUnavailable
    case authorizationFailed
    case queryFailed
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            return "Health data is not available on this device"
        case .authorizationFailed:
            return "Failed to authorize HealthKit access"
        case .queryFailed:
            return "Failed to query health data"
        case .saveFailed:
            return "Failed to save health data"
        }
    }
}
```

### Checking Authorization Status

```swift
extension HealthManager {
    /// Check if the user has authorized sharing a specific type
    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        healthStore.authorizationStatus(for: type)
    }

    /// Check if authorization needs to be requested
    func shouldRequestAuthorization() async -> Bool {
        do {
            let status = try await healthStore.statusForAuthorizationRequest(
                toShare: typesToWrite,
                read: typesToRead
            )
            return status == .shouldRequest
        } catch {
            return true
        }
    }
}
```

---

## Reading Health Data

### Sample Query (One-Time Fetch)

Use `HKSampleQuery` to fetch a collection of samples:

```swift
extension HealthManager {
    /// Fetch heart rate samples for the last 24 hours
    func fetchHeartRateSamples() async throws -> [HKQuantitySample] {
        let heartRateType = HKQuantityType(.heartRate)

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: now,
            options: .strictStartDate
        )

        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let heartRateSamples = samples as? [HKQuantitySample] ?? []
                continuation.resume(returning: heartRateSamples)
            }

            healthStore.execute(query)
        }
    }
}
```

### Statistics Query (Aggregated Data)

Use `HKStatisticsQuery` for aggregated statistics:

```swift
extension HealthManager {
    /// Get total steps for today
    func fetchTodaySteps() async throws -> Double {
        let stepsType = HKQuantityType(.stepCount)

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: now,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepsType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let steps = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: steps)
            }

            healthStore.execute(query)
        }
    }

    /// Get average heart rate for today
    func fetchAverageHeartRate() async throws -> Double {
        let heartRateType = HKQuantityType(.heartRate)

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: now,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: heartRateType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let unit = HKUnit.count().unitDivided(by: .minute())
                let avgHeartRate = statistics?.averageQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: avgHeartRate)
            }

            healthStore.execute(query)
        }
    }
}
```

### Statistics Collection Query (Time Series Data)

Use `HKStatisticsCollectionQuery` for data grouped by time intervals:

```swift
extension HealthManager {
    /// Fetch daily step counts for the past week
    func fetchWeeklySteps() async throws -> [(date: Date, steps: Double)] {
        let stepsType = HKQuantityType(.stepCount)
        let calendar = Calendar.current

        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -7, to: now) else {
            throw HealthError.queryFailed
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: now,
            options: .strictStartDate
        )

        // Anchor at midnight
        let anchorDate = calendar.startOfDay(for: now)
        let daily = DateComponents(day: 1)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepsType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: anchorDate,
                intervalComponents: daily
            )

            query.initialResultsHandler = { _, collection, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                var results: [(date: Date, steps: Double)] = []

                collection?.enumerateStatistics(from: startDate, to: now) { statistics, _ in
                    let steps = statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0
                    results.append((date: statistics.startDate, steps: steps))
                }

                continuation.resume(returning: results)
            }

            healthStore.execute(query)
        }
    }
}
```

### Anchored Object Query (Incremental Updates)

Use `HKAnchoredObjectQuery` to track changes and receive updates:

```swift
extension HealthManager {
    private var anchor: HKQueryAnchor?

    /// Fetch new samples since the last query
    func fetchNewSamples(for type: HKSampleType) async throws -> [HKSample] {
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: type,
                predicate: nil,
                anchor: anchor,
                limit: HKObjectQueryNoLimit
            ) { [weak self] _, samples, deletedObjects, newAnchor, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                // Store the new anchor for the next query
                self?.anchor = newAnchor

                continuation.resume(returning: samples ?? [])
            }

            healthStore.execute(query)
        }
    }
}
```

### Observer Query (Real-Time Monitoring)

Use `HKObserverQuery` to monitor for changes:

```swift
extension HealthManager {
    private var observerQuery: HKObserverQuery?

    /// Start observing changes to a specific type
    func startObserving(_ type: HKSampleType, handler: @escaping () -> Void) {
        let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completionHandler, error in
            if error == nil {
                handler()
            }
            completionHandler()
        }

        observerQuery = query
        healthStore.execute(query)
    }

    /// Stop observing
    func stopObserving() {
        if let query = observerQuery {
            healthStore.stop(query)
            observerQuery = nil
        }
    }
}
```

---

## Writing Health Data

### Saving Quantity Samples

```swift
extension HealthManager {
    /// Save a weight measurement
    func saveWeight(_ weightInKg: Double, date: Date = Date()) async throws {
        let weightType = HKQuantityType(.bodyMass)
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: weightInKg)

        let sample = HKQuantitySample(
            type: weightType,
            quantity: quantity,
            start: date,
            end: date
        )

        try await healthStore.save(sample)
    }

    /// Save active energy burned
    func saveActiveEnergy(_ calories: Double, start: Date, end: Date) async throws {
        let energyType = HKQuantityType(.activeEnergyBurned)
        let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: calories)

        let sample = HKQuantitySample(
            type: energyType,
            quantity: quantity,
            start: start,
            end: end
        )

        try await healthStore.save(sample)
    }
}
```

### Saving Category Samples

```swift
extension HealthManager {
    /// Save a sleep analysis sample
    func saveSleep(start: Date, end: Date, sleepValue: HKCategoryValueSleepAnalysis) async throws {
        let sleepType = HKCategoryType(.sleepAnalysis)

        let sample = HKCategorySample(
            type: sleepType,
            value: sleepValue.rawValue,
            start: start,
            end: end
        )

        try await healthStore.save(sample)
    }

    /// Save a mindful session
    func saveMindfulSession(start: Date, end: Date) async throws {
        let mindfulType = HKCategoryType(.mindfulSession)

        let sample = HKCategorySample(
            type: mindfulType,
            value: HKCategoryValue.notApplicable.rawValue,
            start: start,
            end: end
        )

        try await healthStore.save(sample)
    }
}
```

### Deleting Samples

```swift
extension HealthManager {
    /// Delete samples by object
    func deleteSamples(_ samples: [HKSample]) async throws {
        try await healthStore.delete(samples)
    }

    /// Delete samples by predicate
    func deleteSamples(of type: HKSampleType, predicate: NSPredicate) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.deleteObjects(of: type, predicate: predicate) { success, _, error in
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

---

## Workouts

### Creating Workouts with HKWorkoutBuilder

```swift
extension HealthManager {
    /// Build and save a workout
    func saveWorkout(
        activityType: HKWorkoutActivityType,
        start: Date,
        end: Date,
        energyBurned: Double,
        distance: Double?
    ) async throws -> HKWorkout {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.locationType = .outdoor

        let builder = HKWorkoutBuilder(
            healthStore: healthStore,
            configuration: configuration,
            device: .local()
        )

        try await builder.beginCollection(at: start)

        // Add energy burned
        let energyType = HKQuantityType(.activeEnergyBurned)
        let energyQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: energyBurned)
        let energySample = HKQuantitySample(
            type: energyType,
            quantity: energyQuantity,
            start: start,
            end: end
        )
        try await builder.addSamples([energySample])

        // Add distance if available
        if let distance = distance {
            let distanceType = HKQuantityType(.distanceWalkingRunning)
            let distanceQuantity = HKQuantity(unit: .meter(), doubleValue: distance)
            let distanceSample = HKQuantitySample(
                type: distanceType,
                quantity: distanceQuantity,
                start: start,
                end: end
            )
            try await builder.addSamples([distanceSample])
        }

        try await builder.endCollection(at: end)

        guard let workout = try await builder.finishWorkout() else {
            throw HealthError.saveFailed
        }

        return workout
    }
}
```

### Querying Workouts

```swift
extension HealthManager {
    /// Fetch workouts for a specific activity type
    func fetchWorkouts(
        activityType: HKWorkoutActivityType? = nil,
        startDate: Date,
        endDate: Date
    ) async throws -> [HKWorkout] {
        var predicates: [NSPredicate] = []

        // Date predicate
        let datePredicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        predicates.append(datePredicate)

        // Activity type predicate (if specified)
        if let activityType = activityType {
            let activityPredicate = HKQuery.predicateForWorkouts(with: activityType)
            predicates.append(activityPredicate)
        }

        let compound = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: compound,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let workouts = samples as? [HKWorkout] ?? []
                continuation.resume(returning: workouts)
            }

            healthStore.execute(query)
        }
    }

    /// Get workout statistics
    func getWorkoutStatistics(_ workout: HKWorkout) -> WorkoutStatistics {
        let duration = workout.duration

        let energyBurned = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
        let distance = workout.totalDistance?.doubleValue(for: .meter())

        let avgHeartRate = workout.statistics(for: HKQuantityType(.heartRate))?
            .averageQuantity()?
            .doubleValue(for: HKUnit.count().unitDivided(by: .minute()))

        return WorkoutStatistics(
            duration: duration,
            energyBurned: energyBurned,
            distance: distance,
            averageHeartRate: avgHeartRate
        )
    }
}

struct WorkoutStatistics {
    let duration: TimeInterval
    let energyBurned: Double?
    let distance: Double?
    let averageHeartRate: Double?
}
```

---

## Activity Rings

### Fetching Activity Summary

```swift
extension HealthManager {
    /// Fetch today's activity summary (rings data)
    func fetchTodayActivitySummary() async throws -> HKActivitySummary? {
        let calendar = Calendar.current
        let now = Date()

        var dateComponents = calendar.dateComponents([.year, .month, .day], from: now)
        dateComponents.calendar = calendar

        let predicate = HKQuery.predicateForActivitySummary(with: dateComponents)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKActivitySummaryQuery(predicate: predicate) { _, summaries, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: summaries?.first)
            }

            healthStore.execute(query)
        }
    }

    /// Fetch activity summaries for a date range
    func fetchActivitySummaries(from startDate: Date, to endDate: Date) async throws -> [HKActivitySummary] {
        let calendar = Calendar.current

        let startComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
        let endComponents = calendar.dateComponents([.year, .month, .day], from: endDate)

        let predicate = HKQuery.predicate(
            forActivitySummariesBetweenStart: startComponents,
            end: endComponents
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKActivitySummaryQuery(predicate: predicate) { _, summaries, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: summaries ?? [])
            }

            healthStore.execute(query)
        }
    }
}

// MARK: - Activity Summary Helpers
extension HKActivitySummary {
    /// Move ring progress (0.0 to 1.0+)
    var moveProgress: Double {
        guard activeEnergyBurnedGoal.doubleValue(for: .kilocalorie()) > 0 else { return 0 }
        return activeEnergyBurned.doubleValue(for: .kilocalorie()) /
               activeEnergyBurnedGoal.doubleValue(for: .kilocalorie())
    }

    /// Exercise ring progress (0.0 to 1.0+)
    var exerciseProgress: Double {
        guard appleExerciseTimeGoal.doubleValue(for: .minute()) > 0 else { return 0 }
        return appleExerciseTime.doubleValue(for: .minute()) /
               appleExerciseTimeGoal.doubleValue(for: .minute())
    }

    /// Stand ring progress (0.0 to 1.0+)
    var standProgress: Double {
        guard appleStandHoursGoal.doubleValue(for: .count()) > 0 else { return 0 }
        return appleStandHours.doubleValue(for: .count()) /
               appleStandHoursGoal.doubleValue(for: .count())
    }
}
```

---

## Background Delivery

Enable your app to receive health data updates in the background:

```swift
extension HealthManager {
    /// Enable background delivery for a type
    func enableBackgroundDelivery(for type: HKObjectType, frequency: HKUpdateFrequency = .immediate) async throws {
        guard let sampleType = type as? HKSampleType else { return }

        try await healthStore.enableBackgroundDelivery(for: sampleType, frequency: frequency)
    }

    /// Disable background delivery for a type
    func disableBackgroundDelivery(for type: HKObjectType) async throws {
        guard let sampleType = type as? HKSampleType else { return }

        try await healthStore.disableBackgroundDelivery(for: sampleType)
    }

    /// Disable all background deliveries
    func disableAllBackgroundDelivery() async throws {
        try await healthStore.disableAllBackgroundDelivery()
    }
}
```

**Note:** Background delivery requires:
1. HealthKit background capability enabled
2. Observer query registered for the type
3. User authorization granted

---

## SwiftUI Integration

### Complete HealthManager Example

```swift
import HealthKit
import SwiftUI

@Observable
class HealthManager {
    private let healthStore = HKHealthStore()

    // MARK: - Published State
    var isAuthorized = false
    var todaySteps: Double = 0
    var todayCalories: Double = 0
    var currentHeartRate: Double = 0
    var activitySummary: HKActivitySummary?
    var isLoading = false
    var error: Error?

    // MARK: - Authorization Types
    private var typesToRead: Set<HKObjectType> {
        [
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.heartRate),
            HKObjectType.activitySummaryType(),
            HKObjectType.workoutType()
        ]
    }

    private var typesToWrite: Set<HKSampleType> {
        [
            HKQuantityType(.activeEnergyBurned),
            HKObjectType.workoutType()
        ]
    }

    // MARK: - Initialization
    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Authorization
    func requestAuthorization() async {
        guard isHealthDataAvailable else {
            error = HealthError.healthDataUnavailable
            return
        }

        do {
            try await healthStore.requestAuthorization(
                toShare: typesToWrite,
                read: typesToRead
            )
            isAuthorized = true
        } catch {
            self.error = error
        }
    }

    // MARK: - Data Fetching
    @MainActor
    func refreshData() async {
        isLoading = true
        defer { isLoading = false }

        async let steps = fetchTodaySteps()
        async let calories = fetchTodayCalories()
        async let heartRate = fetchLatestHeartRate()
        async let activity = fetchTodayActivitySummary()

        do {
            todaySteps = try await steps
            todayCalories = try await calories
            currentHeartRate = try await heartRate
            activitySummary = try await activity
        } catch {
            self.error = error
        }
    }

    private func fetchTodaySteps() async throws -> Double {
        let stepsType = HKQuantityType(.stepCount)
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: now,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepsType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let steps = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: steps)
            }
            healthStore.execute(query)
        }
    }

    private func fetchTodayCalories() async throws -> Double {
        let caloriesType = HKQuantityType(.activeEnergyBurned)
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: now,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: caloriesType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let calories = statistics?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                continuation.resume(returning: calories)
            }
            healthStore.execute(query)
        }
    }

    private func fetchLatestHeartRate() async throws -> Double {
        let heartRateType = HKQuantityType(.heartRate)
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let unit = HKUnit.count().unitDivided(by: .minute())
                let heartRate = (samples?.first as? HKQuantitySample)?
                    .quantity.doubleValue(for: unit) ?? 0
                continuation.resume(returning: heartRate)
            }
            healthStore.execute(query)
        }
    }

    private func fetchTodayActivitySummary() async throws -> HKActivitySummary? {
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        dateComponents.calendar = calendar
        let predicate = HKQuery.predicateForActivitySummary(with: dateComponents)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKActivitySummaryQuery(predicate: predicate) { _, summaries, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: summaries?.first)
            }
            healthStore.execute(query)
        }
    }
}
```

### SwiftUI Views

```swift
struct HealthDashboardView: View {
    @Environment(HealthManager.self) private var healthManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if !healthManager.isAuthorized {
                        AuthorizationCard()
                    } else {
                        StatsGrid()

                        if let summary = healthManager.activitySummary {
                            ActivityRingsCard(summary: summary)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Health")
            .refreshable {
                await healthManager.refreshData()
            }
            .task {
                if !healthManager.isAuthorized {
                    await healthManager.requestAuthorization()
                }
                if healthManager.isAuthorized {
                    await healthManager.refreshData()
                }
            }
        }
    }
}

struct AuthorizationCard: View {
    @Environment(HealthManager.self) private var healthManager

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)

            Text("Health Access Required")
                .font(.headline)

            Text("Grant access to view your health data")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Authorize") {
                Task {
                    await healthManager.requestAuthorization()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct StatsGrid: View {
    @Environment(HealthManager.self) private var healthManager

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(
                title: "Steps",
                value: "\(Int(healthManager.todaySteps))",
                icon: "figure.walk",
                color: .green
            )

            StatCard(
                title: "Calories",
                value: "\(Int(healthManager.todayCalories)) kcal",
                icon: "flame.fill",
                color: .orange
            )

            StatCard(
                title: "Heart Rate",
                value: "\(Int(healthManager.currentHeartRate)) BPM",
                icon: "heart.fill",
                color: .red
            )
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ActivityRingsCard: View {
    let summary: HKActivitySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Activity Rings")
                .font(.headline)

            HStack(spacing: 24) {
                RingView(
                    progress: summary.moveProgress,
                    color: .red,
                    label: "Move"
                )

                RingView(
                    progress: summary.exerciseProgress,
                    color: .green,
                    label: "Exercise"
                )

                RingView(
                    progress: summary.standProgress,
                    color: .cyan,
                    label: "Stand"
                )
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct RingView: View {
    let progress: Double
    let color: Color
    let label: String

    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.3), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: min(progress, 1.0))
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text("\(Int(progress * 100))%")
                    .font(.caption2)
                    .fontWeight(.semibold)
            }
            .frame(width: 60, height: 60)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
```

### App Setup

```swift
import SwiftUI

@main
struct HealthApp: App {
    @State private var healthManager = HealthManager()

    var body: some Scene {
        WindowGroup {
            HealthDashboardView()
                .environment(healthManager)
        }
    }
}
```

---

## Best Practices

### Privacy & Authorization

1. **Request Only What You Need** - Only request authorization for data types your app actually uses
2. **Explain Why** - Provide clear, user-friendly descriptions in Info.plist
3. **Handle Denial Gracefully** - Design your app to work with limited or no health data access
4. **Respect Privacy** - Never assume authorization status for reads (always `.notDetermined`)

### Performance

1. **Reuse HKHealthStore** - Create one instance and share it across your app
2. **Use Appropriate Queries** - Choose the right query type for your needs:
   - `HKSampleQuery` for one-time fetches
   - `HKStatisticsQuery` for aggregated data
   - `HKStatisticsCollectionQuery` for time-series data
   - `HKAnchoredObjectQuery` for incremental updates
3. **Limit Results** - Use predicates and limits to reduce data transfer
4. **Background Threading** - HealthKit queries run on background threads; dispatch to main for UI updates

### Data Handling

1. **Use Correct Units** - Always specify units when reading/writing quantities
2. **Validate Data** - Check for nil values and invalid quantities
3. **Handle Missing Data** - Not all users have all data types available
4. **Source Attribution** - HealthKit tracks which app/device recorded each sample

---

## Common Pitfalls

### Authorization Issues

| Problem | Solution |
|---------|----------|
| Authorization always fails | Check Info.plist has usage description keys |
| Can't determine read authorization | This is by design - read status is always `.notDetermined` |
| Authorization sheet doesn't appear | Ensure HealthKit capability is added and entitlements are correct |
| Device doesn't support HealthKit | Check `HKHealthStore.isHealthDataAvailable()` first |

### Query Issues

| Problem | Solution |
|---------|----------|
| Query returns no data | Check predicate dates, user may not have data for that period |
| Query fails silently | Always handle the error parameter in query callbacks |
| Duplicate samples | Use predicates to filter by source or date range |
| Wrong unit values | Ensure you're using the correct HKUnit for the quantity type |

### Data Availability

| Problem | Solution |
|---------|----------|
| Data types not available | Some types require specific hardware (e.g., ECG requires Apple Watch) |
| Clinical records not available | Requires special entitlement and user enrollment |
| Background delivery not working | Enable capability, register observer query, request background delivery |

---

## iOS Version Compatibility

| Feature | Minimum iOS |
|---------|-------------|
| Basic HealthKit | iOS 8.0 |
| Workout Builder | iOS 12.0 |
| Activity Rings | iOS 9.3 |
| Clinical Records | iOS 12.0 |
| Background Delivery | iOS 8.0 |
| async/await APIs | iOS 15.0 |
| Vision prescriptions | iOS 16.0 |
| State of Mind | iOS 17.0 |
| Sleep schedule | iOS 17.0 |

---

## Related Frameworks

- **WorkoutKit** - Schedule and plan workouts (iOS 17+)
- **HealthKitUI** - Activity rings visualization
- **SensorKit** - Additional sensor data
- **CoreMotion** - Motion and activity data

---

## References

- [Apple HealthKit Documentation](https://developer.apple.com/documentation/healthkit)
- [Authorizing Access to Health Data](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data)
- [Reading Data from HealthKit](https://developer.apple.com/documentation/healthkit/reading_data_from_healthkit)
- [Workouts and Activity Rings](https://developer.apple.com/documentation/healthkit/workouts-and-activity-rings)
- [WWDC Sessions on HealthKit](https://developer.apple.com/videos/health-fitness)

---

*Last updated: February 2026*
*iOS versions: iOS 18+*
*Swift: 5.9+*

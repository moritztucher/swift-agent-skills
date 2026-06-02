---
name: healthkit
description: Read, write, and query health and fitness data on Apple platforms with HealthKit — HKHealthStore setup, authorization and usage strings, sample/statistics/anchored queries, HKWorkout, activity rings, background delivery, and the iOS 18 mental-health types. Use when the user mentions HealthKit, health data, HKHealthStore, workout, steps, heart rate, sleep, activity rings, or health permissions.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple HealthKit docs via Context7 (/websites/developer_apple)
---

# HealthKit

Reading, writing, and querying health and fitness data on Apple platforms. The deep API reference — setup, every type category, all query types, workouts, activity rings, background delivery, the full SwiftUI manager, and version compatibility — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `ACCESS` — `read` (consume existing data: steps, heart rate, sleep) · `write` (save your app's samples back to Health) · `both`. Each direction needs its own usage string and its own type set (`typesToRead` vs `typesToWrite`); requesting one does not grant the other.
2. `QUERY_SHAPE` — `snapshot` (`HKSampleQuery`/`HKStatisticsQuery`, one-time fetch) · `time-series` (`HKStatisticsCollectionQuery`, bucketed by interval) · `live` (`HKObserverQuery` + `HKAnchoredObjectQuery`, incremental updates and deletions). Live is the only shape that survives across launches and feeds background delivery.
3. `BACKGROUND` — `none` (foreground-only refresh) · `enabled` (`enableBackgroundDelivery` + observer query + the `com.apple.developer.healthkit.background-delivery` entitlement). Enabling background changes your entitlements, your query lifecycle, and your testing surface.

## When to use

Building or reviewing any code that touches `HKHealthStore` — authorization, reading samples or statistics, writing quantity/category/workout samples, activity rings, or background delivery. Not for WorkoutKit scheduling (separate framework) or for ResearchKit surveys.

## Core rules

- Gate everything on `HKHealthStore.isHealthDataAvailable()` first — iPad and many devices return `false`, and HealthKit calls there throw.
- One `HKHealthStore` instance for the whole app; inject it, don't recreate per call.
- Declare every usage string you need in Info.plist before requesting: `NSHealthShareUsageDescription` (read), `NSHealthUpdateUsageDescription` (write), `NSHealthClinicalHealthRecordsShareUsageDescription` (clinical). A missing string makes `requestAuthorization` throw, not prompt.
- Use the async/await APIs (`requestAuthorization`, `save`, `delete`, `enableBackgroundDelivery`); wrap the callback-only queries in `withCheckedThrowingContinuation`. Always handle the `error` parameter — query failures are silent otherwise.
- Never infer read permission from authorization status. For reads, status is intentionally `.notDetermined` even after the user grants. Decide whether to re-prompt with `statusForAuthorizationRequest(toShare:read:)`, and detect denial by getting back empty results.
- Always pair a quantity with its correct `HKUnit` (BPM is `.count()/.minute()`, energy is `.kilocalorie()`, mass is `.gramUnit(with: .kilo)`). Wrong unit = silently wrong numbers, not a crash.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "`requestAuthorization` succeeded, so I can read their heart rate." | Success only means the sheet was shown without error. Read grants are privacy-opaque: `authorizationStatus(for:)` stays `.notDetermined`, and a denied read returns empty results, not an error. Design for "no data" as a normal state. |
| "I'll check `authorizationStatus(for:)` to see if reading is allowed." | That status reflects *sharing/write* permission only. It tells you nothing about reads by design. Use `statusForAuthorizationRequest` to decide whether to re-prompt, and treat empty query results as "denied or no data." |
| "Usage strings are optional polish, I'll add them later." | A missing `NSHealthShareUsageDescription`/`NSHealthUpdateUsageDescription` makes `requestAuthorization` *throw* — the sheet never appears. Both the right string and the HealthKit capability must exist before the first request. |
| "I enabled background delivery, so my app will wake on new samples." | Background delivery needs the `com.apple.developer.healthkit.background-delivery` entitlement (without it `enableBackgroundDelivery` fails with `errorAuthorizationDenied`), AND a live `HKObserverQuery` registered for the type, AND you must call the observer's `completionHandler`. Also `HKCorrelationType` can't be observed, and many types are capped at `.hourly` regardless of what you request. |
| "I'll read the latest sample and update `self.value` right in the callback." | Query handlers run on a background thread. Touching `@Observable`/UI state there is a data race — hop to `@MainActor` (or `MainActor.run`) before mutating published state. |
| "Steps are steps — I'll just read the `doubleValue`." | A `doubleValue` without the right `HKUnit` is meaningless: heart rate needs `.count()/.minute()`, distance `.meter()`, energy `.kilocalorie()`. And the same step can appear from multiple sources (phone + watch), so de-dupe or use `HKStatisticsQuery`/`HKStatisticsCollectionQuery` which merges sources for you. |

## Verification gate

Before shipping HealthKit code, confirm every line:

- [ ] `HKHealthStore.isHealthDataAvailable()` checked before any store call; unavailable devices handled gracefully.
- [ ] Every required usage string in Info.plist (`NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription` / clinical) and the HealthKit capability enabled.
- [ ] Read paths treat empty results as "denied or no data," never assume permission from authorization status.
- [ ] Each quantity read/written uses the correct `HKUnit`; statistics queries used where source de-duplication matters.
- [ ] All query callbacks handle the `error` parameter; UI/state mutations hop to `@MainActor`.
- [ ] Writes only request types in `typesToWrite`; reads only types the app actually consumes (request the minimum).
- [ ] If background: `com.apple.developer.healthkit.background-delivery` entitlement present, observer query registered, `completionHandler` always called, frequency limits understood.
- [ ] Tested on a real device or a simulator seeded with Health data — empty-store and denied-permission paths exercised.

## Deep reference

`references/guide.md` — full setup and entitlements, all type categories with common identifiers, authorization, every query type (sample, statistics, statistics-collection, anchored, observer), reading/writing/deleting samples, `HKWorkoutBuilder`, activity rings, background delivery, a complete `@Observable` SwiftUI `HealthManager`, best practices, common pitfalls, and version compatibility (including iOS 18 `HKStateOfMind` and mental-health assessments). Load it for any concrete API question.

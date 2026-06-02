---
name: corebluetooth
description: Implement and review Bluetooth Low Energy on Apple platforms with Core Bluetooth — central scanning/connecting, GATT service & characteristic discovery, read/write/notify, and the CBPeripheralManager peripheral role with advertising, background modes, and state restoration. Use when the user mentions Core Bluetooth, BLE, CBCentralManager, CBPeripheral, peripheral, characteristic, GATT, advertising, or a bluetooth accessory. For the modern system pairing/onboarding UX (wireless accessory discovery sheet), use the `accessorysetupkit` skill instead.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple Core Bluetooth docs via Context7 (/websites/developer_apple_corebluetooth)
---

# Core Bluetooth

Bluetooth Low Energy on Apple platforms: discovering and talking to BLE peripherals (central role) and advertising your own services (peripheral role). The deep API reference — full central/peripheral managers, GATT, async/await wrappers, notifications via `AsyncStream`, SwiftUI patterns, background/state-restoration, and battery/security practices — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `ROLE` — `central` (default; you scan for and drive remote peripherals) · `peripheral` (`CBPeripheralManager`; your device advertises services and answers reads/writes) · `both` (device-to-device).
2. `LIFECYCLE` — `foreground` (default; scan/connect only while the app is active) · `background` (`UIBackgroundModes` = `bluetooth-central`/`bluetooth-peripheral` + state preservation/restoration with a restore identifier).
3. `PAIRING_UX` — `manual` (your own scan list + connect flow, full control) · `accessorysetupkit` (iOS 18+ system discovery sheet for a known accessory — better UX, scoped permission; see the `accessorysetupkit` skill).

## When to use

Building or reviewing any BLE code that talks to Core Bluetooth directly: scanning, connecting, discovering services/characteristics, reading/writing/notifying, or advertising as a peripheral. If the task is purely the *onboarding/pairing UX* for a specific accessory, prefer `accessorysetupkit` and only drop to raw Core Bluetooth for the data plane.

## Core rules

- **Wait for `.poweredOn` before any operation.** Bluetooth state is asynchronous; the manager starts in `.unknown`. Scanning/connecting before `centralManagerDidUpdateState` reports `.poweredOn` silently does nothing.
- **Hold a strong reference to every `CBPeripheral` you care about.** Core Bluetooth does not retain them. A peripheral that goes out of scope deallocates and the connection drops mid-flight.
- **`NSBluetoothAlwaysUsageDescription` is mandatory.** Without it the app crashes the first time a manager initializes. `NSBluetoothPeripheralUsageDescription` is deprecated (iOS 13+) and only for back-compat.
- **Discover top-down: services first, then characteristics, then act.** You cannot read/write/subscribe a characteristic you haven't discovered for a discovered service. Each step is a separate async round-trip.
- Use `@Observable` managers (not `ObservableObject`); bridge delegate callbacks to async/await with continuations as in the guide. iOS 26 is the default target.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll scan right after `CBCentralManager(...)`." | The manager boots in `.unknown` and powers on asynchronously. Gate every scan/connect on `.poweredOn` via `centralManagerDidUpdateState` (or an `await waitForBluetoothReady()`). Calls made earlier are dropped silently. |
| "I connected, so I can drop the `CBPeripheral` reference." | Core Bluetooth holds only a weak reference. Drop yours and it deallocs, killing the connection. Keep it in your `@Observable` manager for the whole session. |
| "Bluetooth works in the simulator, I'll test there." | There is no Bluetooth radio in the Simulator — `state` never reaches `.poweredOn`. Test on a real device (or a mock layer like Core Bluetooth Mock). |
| "I'll read the characteristic right after connecting." | Connection only gives you a peripheral. You must `discoverServices` → `discoverCharacteristics` first; acting on an undiscovered characteristic throws/does nothing. |
| "Write-without-response is just a faster write." | It has no flow control or error: a payload over the ATT MTU is silently truncated, and writes queued when `canSendWriteWithoutResponse` is `false` are dropped. Chunk to `maximumWriteValueLength(for:)` and resume on `peripheralIsReady(toSendWriteWithoutResponse:)`. Use `.withResponse` when delivery must be confirmed. |
| "I added `bluetooth-central` so it scans in the background." | Background scanning is heavily constrained: you *must* pass explicit service UUIDs (a `nil`/wildcard scan returns nothing in background), `CBCentralManagerScanOptionAllowDuplicatesKey` is ignored, scan intervals stretch, and you need state preservation/restoration (restore identifier + `willRestoreState`) to survive relaunch. |
| "I'll build my own scan-and-pair screen for this accessory." | For a single known accessory, AccessorySetupKit gives a system pairing sheet, scoped Bluetooth/Wi-Fi access, and no always-on Bluetooth permission prompt. Use the `accessorysetupkit` skill for the pairing UX, then Core Bluetooth for data. |

## Verification gate

Before shipping BLE, confirm every line:

- [ ] `Info.plist` has `NSBluetoothAlwaysUsageDescription` with a real, user-facing reason.
- [ ] No scan/connect/advertise call runs before the manager reports `.poweredOn`; all manager states (`.poweredOff`, `.unauthorized`, `.unsupported`, `.resetting`) are handled.
- [ ] Every active `CBPeripheral` is retained by a long-lived owner; its `delegate` is set before discovery.
- [ ] Discovery is ordered services → characteristics; reads/writes/notifies only touch discovered characteristics.
- [ ] Writes choose `.withResponse` vs `.withoutResponse` deliberately; `.withoutResponse` respects `canSendWriteWithoutResponse` and chunks to `maximumWriteValueLength(for:)`.
- [ ] Disconnects clear cached services/characteristics and (if desired) trigger reconnect with backoff.
- [ ] Background apps: `UIBackgroundModes` set, scans pass explicit service UUIDs, restore identifier + `willRestoreState` implemented, background work is minimal and returns fast.
- [ ] Tested on a physical device (Simulator has no BLE radio).
- [ ] Considered AccessorySetupKit for the pairing UX (single known accessory) before hand-rolling a scan list.

## Deep reference

`references/guide.md` — full central + peripheral implementations, permissions & background config, GATT/CBUUID, read/write, notifications via `AsyncStream`, SwiftUI integration, iOS 18/26 notes, common use cases (heart-rate monitor, IoT controller, sensor logger, device-to-device), and battery/security/connection-management best practices. Load it for any concrete API question.

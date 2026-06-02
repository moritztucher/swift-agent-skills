---
name: accessorysetupkit
description: Discover and pair Bluetooth and Wi-Fi accessories with AccessorySetupKit (iOS 18+) — privacy-preserving pairing via ASAccessorySession, ASDiscoveryDescriptor, and the system picker, without a full Bluetooth permission prompt. Use when the user mentions AccessorySetupKit, ASK, accessory pairing, ASAccessorySession, Bluetooth accessory setup, Wi-Fi accessory, the accessory picker, or scoped per-device Bluetooth access. For low-level BLE communication after pairing, use the `corebluetooth` skill.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple AccessorySetupKit docs via Context7 (/websites/developer_apple_accessorysetupkit)
---

# AccessorySetupKit

Privacy-preserving discovery and pairing of Bluetooth/Wi-Fi accessories on iOS 18+. The deep API reference — session lifecycle, discovery descriptors, the picker, Core Bluetooth handoff, Wi-Fi/`NEHotspotConfiguration`, migration, SwiftUI integration, pitfalls, and version notes — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `TRANSPORT` — `bluetooth` (default; BLE peripherals via `bluetoothServiceUUID` / `bluetoothCompanyIdentifier` / name substring) · `wifi` (hotspot accessories via `ssid` or `ssidPrefix`) · `both` (set Bluetooth and Wi-Fi traits on one descriptor for dual-radio devices).
2. `EXISTING_USERS` — `none` (greenfield, picker-only pairing) · `migrate` (app already pairs via Core Bluetooth/`NEHotspotConfiguration`; bring known devices in with `ASMigrationDisplayItem` so users don't re-pair).
3. `POST_PAIR` — `corebluetooth` (default for BLE; use `accessory.bluetoothIdentifier` with `retrievePeripherals(withIdentifiers:)`) · `networkextension` (Wi-Fi; build `NEHotspotConfiguration` from `accessory.ssid`).

## When to use

Building or reviewing any flow that lets a user pick and pair a physical accessory on iOS 18+: the system picker, discovery descriptors, the paired-accessory list, removal/rename, or reconnection on launch. After pairing you talk to a BLE device through Core Bluetooth as usual — use the `corebluetooth` skill for that layer. If you only need generic central-scanning of arbitrary devices without a curated picker, that's plain Core Bluetooth, not ASK.

## Core rules

- iOS 18.0+ only. `ASAccessorySession`, `ASDiscoveryDescriptor`, `ASPickerDisplayItem`, `ASAccessory` are all 18.0+. Gate with `@available(iOS 18.0, *)` and have a fallback (or a hard minimum) if the app supports older OSes.
- Activate one long-lived `ASAccessorySession` early (app launch / manager `init`) via `activate(on:eventHandler:)`, and keep it alive for the app's lifetime. On `.activated`, repopulate from `session.accessories`.
- The picker is the only way to add a new accessory. `session.showPicker(for:)` takes your `ASPickerDisplayItem`s; the chosen device arrives **through the event handler** as `.accessoryAdded`, not as a return value of the completion handler.
- Every runtime descriptor trait (service UUID, name, company ID, SSID) MUST be pre-declared in Info.plist or the app **terminates** when the picker opens.
- Does **not** run on the iOS Simulator — test on a physical device.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll set the deployment target wherever and call `ASAccessorySession`." | Every ASK symbol is iOS 18.0+ (HID setup is 18.4+). On a lower target it won't compile/run without `@available` gating — decide up front: hard 18.0 minimum or a non-ASK fallback path. |
| "Pairing just works once I write the Swift." | The picker reads Info.plist. Without `NSAccessorySetupKitSupports` (`Bluetooth`/`WiFi`) **and** the matching `NSAccessorySetupBluetoothServices`/`Names`/`CompanyIdentifiers` (or Wi-Fi SSID) declarations, `showPicker` crashes the app. UUIDs must be uppercase and match the descriptor exactly. |
| "I still need `NSBluetoothAlwaysUsageDescription` for BLE." | With ASK you **omit** the classic Bluetooth usage keys. ASK grants scoped, per-accessory access with no system-wide Bluetooth permission prompt — that's the whole point. Adding the legacy key reintroduces the prompt you're trying to avoid. Prefer ASK over raw Core Bluetooth permission for user-pairable accessories. |
| "ASK pairs it, so ASK also reads my characteristics." | ASK only does discovery + authorization. **You still use Core Bluetooth** for actual GATT communication — take `accessory.bluetoothIdentifier`, call `retrievePeripherals(withIdentifiers:)`, connect, discover services. See the `corebluetooth` skill. Note `CBCentralManager` only reaches `.poweredOn` once a paired accessory exists, and `scanForPeripherals` returns only authorized devices. |
| "My app already pairs over Core Bluetooth; users can just re-pair." | Forcing re-pairing is a regression. Use `ASMigrationDisplayItem` with the existing `peripheralIdentifier` (or `hotspotSSID`) so previously-paired devices migrate silently; handle the `.migrationComplete` event. On iOS 26+, ASK-managed accessories are also what's required for background Bluetooth relaunch. |
| "Any matching device shows up in the picker." | The accessory must actively advertise exactly what the descriptor specifies. A wrong/missing service UUID, a case-mismatched name substring, an already-paired device, or specifying both `ssid` and `ssidPrefix` (crash) all produce an empty picker or a hard failure. Make the descriptor match the real advertisement. |

## Verification gate

Before shipping ASK pairing, confirm every line:

- [ ] Deployment gated for iOS 18.0+ (18.4+ if using HID), with a fallback or a hard minimum decided.
- [ ] `Info.plist` has `NSAccessorySetupKitSupports` with the right transport(s), plus the matching Bluetooth (services/names/company IDs) and/or Wi-Fi SSID declarations — and every descriptor trait used at runtime is declared there.
- [ ] Classic Bluetooth usage keys (`NSBluetoothAlwaysUsageDescription`, …) are **absent** when ASK is the pairing path.
- [ ] A single `ASAccessorySession` is activated at launch, lives for the app lifetime, and repopulates `accessories` on `.activated`.
- [ ] New accessories are handled via the `.accessoryAdded` **event**, not the `showPicker` completion handler; `.userCancelled` (error 700) is silent, not an error UI.
- [ ] Post-pairing communication goes through Core Bluetooth (`bluetoothIdentifier` → `retrievePeripherals`) or `NEHotspotConfiguration` (`ssid`) — see the `corebluetooth` skill for the BLE side.
- [ ] Existing-user accessories migrated via `ASMigrationDisplayItem` (if the app had prior pairing); `.migrationComplete` handled.
- [ ] `.accessoryRemoved`/`.accessoryChanged` update the list; removal/rename flows handle the iOS 26+ confirmation dialog.
- [ ] Verified on a **physical device** (ASK does not work in the Simulator).

## Deep reference

`references/guide.md` — full setup, Info.plist configuration, core APIs (`ASAccessorySession`, `ASPickerDisplayItem`, `ASDiscoveryDescriptor`, `ASAccessory`, events, errors), basic + multi-accessory implementation, Core Bluetooth handoff, Wi-Fi/`NEHotspotConfiguration`, migration, SwiftUI integration, best practices, troubleshooting, and iOS 18/26 version notes. Load it for any concrete API question.

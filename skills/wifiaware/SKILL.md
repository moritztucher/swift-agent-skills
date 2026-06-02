---
name: wifiaware
description: Build peer-to-peer, device-to-device connectivity on iOS 26+ with Apple's WiFiAware framework — declaring services, pairing, and high-throughput data paths over the new async Network APIs (NetworkListener/NetworkBrowser). Use when the user mentions Wi-Fi Aware, WiFiAware, NAN, peer-to-peer, device-to-device, local high-throughput, infrastructure-free connection, or a nearby-device data link with no access point. For hardware-accessory pairing/setup, see the `accessorysetupkit` skill.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple Developer docs via Context7 (/websites/developer_apple — no dedicated WiFiAware library exists; verified against the broad Apple library)
---

# Wi-Fi Aware (WiFiAware)

Direct device-to-device networking on iOS 26+ with no router or access point — publish/subscribe service discovery, one-time pairing, then authenticated, encrypted, high-throughput connections carried over the iOS 26 async Network framework (`NetworkListener`/`NetworkBrowser`/`NetworkConnection`). The deep API reference — capabilities, services, pairing UIs, data paths, performance modes, the full file-share example, and migration from `NWConnection`/`NWListener` — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `PAIRING_UI` — `device-discovery-ui` (default; app-to-app PIN pairing via `DevicePairingView` publisher + `DevicePicker` subscriber) · `accessory-setup-kit` (hardware accessories; pair through `ASAccessorySession`, then bridge `accessory.wifiAwarePairedDeviceID` to a `WAPairedDevice` — use the `accessorysetupkit` skill for the setup half).
2. `ROLE` — `publisher` (hosts a service, `NetworkListener.run`) · `subscriber` (discovers + connects, `NetworkBrowser.run`) · `both` (one app plays each side; each role must be declared in Info.plist **and** in the entitlement array).
3. `PERFORMANCE_MODE` — `bulk` (default; lower power, higher latency — file transfer, sync) · `realtime` (higher power, lower latency — live streaming, control). Pair with the matching `serviceClass` (`.bestEffort`/`.background` vs `.interactiveVideo`/`.interactiveVoice`).

## When to use

Building or reviewing any nearby peer-to-peer or device-to-device data link on iOS 26+ where there is no shared Wi-Fi network or central server — file transfer, live streaming, control channels, large local sync. If you're pairing/configuring a *hardware accessory*, the discovery/pairing half belongs to `accessorysetupkit`; this skill owns the WiFiAware service declaration and the data path. If you only need small-payload nearby messaging across a mix of older OS versions, Multipeer Connectivity or plain Network-framework Bonjour is the simpler tool — reach for Wi-Fi Aware specifically when you need its high throughput and infrastructure-free guarantee.

## Core rules

- **iOS 26+ and hardware support, both required.** The API is iOS 26-only; even then `WACapabilities.supportedFeatures.contains(.wifiAware)` must be true. Gate every entry point on the capability check and provide a real `fallback`.
- **Declare services in two places.** Each service goes in Info.plist under `WiFiAwareServices` (role keyed to an empty `<dict/>`, presence = enabled) **and** the role must be granted in the `com.apple.developer.wifi-aware` entitlement **array** (`Publish` / `Subscribe`). Missing either side fails to provision or to discover.
- **The entitlement must be approved by Apple.** It is not self-grantable — request it before you expect device builds to work.
- **Always TLS the data path.** Construct listeners/connections `using: .parameters { TLS() }`. Wi-Fi Aware authenticates the pairing; you still encrypt the transport.
- **Connections are ephemeral.** Wi-Fi Aware aggressively reaps idle links after minutes — own reconnection/keep-alive, don't assume a connection survives a pause.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "It builds on my Mac/sim, so it's fine." | Wi-Fi Aware needs **real iOS 26 hardware** that reports `.wifiAware` in `WACapabilities.supportedFeatures`. No capability gate + fallback = a dead button for a large share of users. You cannot exercise the radio in the simulator. |
| "I set the entitlement to `<true/>` like other capabilities." | `com.apple.developer.wifi-aware` is an **array of role strings** (`Publish`/`Subscribe`), and it's **Apple-approval-gated**. A boolean value (or an unapproved profile) fails to provision — it won't just silently degrade. |
| "I declared the service in the entitlement, that's enough." | You must **also** declare it in Info.plist under `WiFiAwareServices`, with each role keyed to an empty `<dict/>` (not `<true/>`/`<false/>`). Both halves, matching role names, or the peer never discovers you. |
| "Wi-Fi Aware should replace my Multipeer / Bonjour code everywhere." | It's the right tool for **high-throughput, infrastructure-free** links on iOS 26+ only. For small-payload messaging, mixed/older OS support, or internet-routed connections, Multipeer Connectivity or standard Network-framework Bonjour is simpler and broader. Wrong-tool adoption buys you an Apple-gated entitlement for no gain. |
| "Realtime mode is faster, so I'll always use it." | `realtime` raises **power draw** and radio contention; it's for live streaming/control. Bulk transfers belong in `bulk` + a background/best-effort `serviceClass`. Defaulting everything to realtime drains battery and starves other traffic. |
| "Connection opened once, I'll hold the reference forever." | Wi-Fi Aware **reaps idle connections after a few minutes** and links drop on range/interference. Without `onStateUpdate` handling + reconnect-with-retry, the channel silently dies and your UI lies about being connected. |

## Verification gate

Before shipping a Wi-Fi Aware feature, confirm every line:

- [ ] Every entry point gated on `WACapabilities.supportedFeatures.contains(.wifiAware)` with a real `fallback` UI.
- [ ] Each service declared in **both** Info.plist `WiFiAwareServices` (role → empty `<dict/>`) **and** the `com.apple.developer.wifi-aware` entitlement **array**, with matching role names.
- [ ] Entitlement approved by Apple for the bundle ID; device build provisions cleanly.
- [ ] Pairing path chosen and wired: `DevicePairingView`/`DevicePicker` (app-to-app) or `accessorysetupkit` bridge for accessories — not a half-built mix.
- [ ] Listener and connection built `using: .parameters { TLS() }`; never plaintext.
- [ ] `performanceMode` + `serviceClass` match the workload (bulk vs realtime), chosen deliberately for power.
- [ ] `onStateUpdate` handled on listener/browser/connection, with reconnect-with-retry for idle-reap and range drops.
- [ ] Paired-device reads use the verified `WAPairedDevice.allDevices` **property** + `Array(.values)`, and member-name accessors confirmed against live Xcode autocomplete (Apple docs confirm `device.name`).

## Deep reference

`references/guide.md` — full framework architecture, project configuration, `WACapabilities`/`WAPublishableService`/`WASubscribableService`/`WAPairedDevice` APIs, both pairing methods (DeviceDiscoveryUI + AccessorySetupKit), Network-framework integration (`NetworkListener`/`NetworkBrowser`/`NetworkConnection`), performance modes, a complete file-sharing app, error handling, best practices, and migration from `NWConnection`/`NWListener`. Load it for any concrete API question. Note the inline `verified 2026-06-02` markers flagging where current Apple docs differ from earlier draft API shapes.

---
name: energykit
description: Integrate EnergyKit (iOS 26) for grid-aware, clean-energy scheduling — query the personalized grid forecast, shift or reduce power-hungry work (EV charging, HVAC) to greener/cheaper windows, and report usage as load events. Use when the user mentions EnergyKit, clean energy, clean-energy charging, grid-aware, energy forecast, green charging, ElectricityGuidance, EnergyVenue, or deferring work to clean energy. For executing the deferred work in the background once a green window is known, see the `backgroundtasks` skill.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple Developer docs via Context7 (/websites/developer_apple — no dedicated EnergyKit library; verified against the broad Apple library)
---

# EnergyKit

Grid-aware clean-energy scheduling on iOS 26: a personalized grid forecast per Home location that identifies when electricity is cleaner and (with a connected utility account) cheaper, so apps can shift or reduce the two biggest home loads — EV charging and HVAC. The deep API reference — entitlement, `EnergyVenue`, `ElectricityGuidance`, load events, insights, onboarding, privacy — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

> Currency note: Context7 has no standalone EnergyKit library. APIs below were verified against the broad Apple Developer library (`/websites/developer_apple`), which mirrors `developer.apple.com/documentation/energykit`. Treat any API not listed there as unverified and confirm against Xcode 26 headers.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `SUGGESTED_ACTION` — `shift` (default; relocatable loads like EV charging — move usage to clean/cheap windows) · `reduce` (non-relocatable loads like HVAC — trim usage during dirty/peak periods). This is the `ElectricityGuidance.Query(suggestedAction:)` value and dictates how you act on the forecast.
2. `LOAD_TYPE` — `ev` (`ElectricVehicleLoadEvent`, default) · `hvac` (`ElectricHVACLoadEvent`). Picks which load-event struct you submit and pairs with the action above.
3. `INSIGHTS` — `off` (default; forecast + scheduling only) · `on` (also pull `ElectricityInsightService` records for cleanliness/tariff history and environmental impact — requires you to be submitting load events first).

## When to use

Building or reviewing any feature that reads the grid forecast to time power-hungry work — clean-energy EV charging, grid-aware thermostat setbacks, "charge when green" toggles — or that reports device electricity usage back to EnergyKit. Once a green window is identified, the actual deferred work (waking to charge, syncing, processing) is scheduled with `BGTaskScheduler` — see the `backgroundtasks` skill; EnergyKit tells you *when*, BackgroundTasks runs it.

Not for: commercial/industrial energy management (EnergyKit is residential, behind-the-meter only), or any region outside the contiguous United States.

## Core rules

- iOS 26+ only. Requires the `com.apple.developer.energykit` entitlement (enable the EnergyKit capability in Xcode); without it every call fails.
- Everything hangs off an `EnergyVenue` — a Home the user established via the Home app / EnergyKit onboarding. No Home, no venue, no guidance. Persist the venue `UUID`, never the `EnergyVenue` object.
- Read guidance from `ElectricityGuidance.sharedService` as an async sequence; act on the latest value, and carry the current `guidanceToken` (a `UUID`) into every load event so EnergyKit can score adherence.
- Submit load events on the device that requested the guidance, batched (~every 15 min during steady operation, plus on significant power-state changes), via `EnergyVenue.submitEvents(_:)`.
- Clean-energy behavior must be user opt-in (a toggle), and energy data access is a system privacy permission the user can revoke in Settings — design for "denied / revoked / no venue" as normal states, not errors.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll cache the forecast at launch and charge on that schedule all day." | The forecast is a live async sequence from `sharedService` and updates as grid conditions change. A stale snapshot schedules charging into a now-dirty window. Keep consuming the stream (or refresh on a background wake) and act on the current value. |
| "EnergyKit knows the green window, so it'll wake my app to charge." | EnergyKit only *provides guidance*. It does not run your work. You must schedule the deferred work yourself with `BGTaskScheduler` (see `backgroundtasks`) against the window the guidance identifies. No scheduling = nothing happens while backgrounded. |
| "`guidanceToken` is just an opaque string I can stash as text." | It's a `UUID`, not a `String`, and it's load-bearing: it links each load event back to the guidance you followed so EnergyKit can measure adherence. Drop it (or mistype the type) and your events can't be scored. |
| "I'll fall back to a default forecast when there's no Home set up." | There is no default. Without an `EnergyVenue` (user has no Home, denied permission, or revoked it) `venue(for:)` returns nil and guidance is unavailable. Treat missing venue / denied access as a first-class state with a graceful non-clean-energy path — don't crash or fake data. |
| "Sandbox/simulator is fine for testing this." | EnergyKit is contiguous-US-only and (in this release) limited to development/Ad Hoc builds on a physical iPhone running iOS 26 — no simulator, no TestFlight yet. Region and device gating will silently yield no venues/guidance if you ignore them. |
| "Power is in kW and energy in kWh, the API takes Measurements, so I'll pass the raw value." | The load-event measurements expect base-scale units — power as `Measurement<UnitPower>` in milliwatts and energy as `Measurement<UnitEnergy>` in milliwatt-hours (`.EnergyKit.milliwattHours`). Passing 7.2 instead of 7_200_000 under-reports usage by a million-fold and corrupts insights. |

## Verification gate

Before shipping EnergyKit work, confirm every line:

- [ ] `com.apple.developer.energykit` entitlement present; EnergyKit capability enabled on the target.
- [ ] Clean-energy behavior is behind an explicit user opt-in toggle, not on by default.
- [ ] An `EnergyVenue` is obtained from a user-established Home; the venue `UUID` is persisted (not the object), and "no venue / permission denied / revoked" is handled as a normal non-error state.
- [ ] Guidance is read from `ElectricityGuidance.sharedService` as a live stream (or refreshed on background wake) — no single cached snapshot driving an all-day schedule.
- [ ] `SUGGESTED_ACTION` matches the load: `shift` for relocatable (EV), `reduce` for non-relocatable (HVAC).
- [ ] The current `guidanceToken` (`UUID`) is attached to every load event; events are submitted from the requesting device, batched (~15 min + on significant changes) via `submitEvents(_:)`.
- [ ] Load-event measurements use the right struct (`ElectricVehicleLoadEvent` vs `ElectricHVACLoadEvent`), `ElectricityFlowDirection` (`.imported` for consumption), and base-scale units (milliwatts / milliwatt-hours).
- [ ] Deferred work is actually scheduled into the green window via `BGTaskScheduler` (`backgroundtasks`) — EnergyKit's role ends at "when".
- [ ] Verified on a physical iOS 26 device in the contiguous US (dev/Ad Hoc build); region/availability gating handled.

## Deep reference

`references/guide.md` — full setup and entitlement, `EnergyVenue` retrieval, `ElectricityGuidance` queries and streaming, `ElectricVehicleLoadEvent`/`ElectricHVACLoadEvent` measurements and sessions, `ElectricityInsightService`, complete SwiftUI integration, onboarding flow, privacy/security, troubleshooting, and an API quick reference. Load it for any concrete API question.

---
name: corehaptics
description: Implement and review custom haptic feedback with Core Haptics — CHHapticEngine lifecycle, transient/continuous CHHapticEvents, intensity/sharpness, dynamic parameters and parameter curves, AHAP files, and audio-haptic sync. Use when the user mentions Core Haptics, haptic feedback, CHHapticEngine, vibration, haptic pattern, Taptic Engine, or AHAP. For simple taps/selections/notification feedback, use SwiftUI `.sensoryFeedback()` or `UIFeedbackGenerator` instead — don't reach for this.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple Core Haptics docs via Context7 (/websites/developer_apple)
---

# Core Haptics

Custom, event-based haptic (and synced audio) playback on the Taptic Engine. The deep API reference — capability checks, engine setup, transient/continuous events, parameter curves, AHAP files, audio-haptic sync, SwiftUI integration, and use-case recipes — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `PLAYBACK` — `pattern-player` (default; `makePlayer(with:)`, fire-and-forget one-shot) · `advanced` (`makeAdvancedPlayer(with:)` for loop/pause/resume/seek and live parameter updates) · `ahap` (`playPattern(from:)` with an `.ahap` file or `Data`, content authored outside code).
2. `EVENT_KIND` — `transient` (instantaneous tap/click, no duration) · `continuous` (sustained, duration up to 30 s, shapeable with parameter curves) · `mixed` (both, plus optional audio events for synced experiences).
3. `FALLBACK` — `silent` (default; do nothing when `supportsHaptics` is false) · `sensory-feedback` (degrade simple cases to SwiftUI `.sensoryFeedback()` / `UIFeedbackGenerator` on unsupported hardware).

## When to use

Building or reviewing custom haptic patterns, audio-haptic sync, real-time parameter modulation, or AHAP playback that talks to `CHHapticEngine` directly. If all you need is a success/error/selection buzz or a button tap, use SwiftUI `.sensoryFeedback()` (iOS 17+) or `UIFeedbackGenerator` — they're one line, need no engine, and work without lifecycle plumbing.

## Core rules

- iOS 13+ for the API; iOS 26 is the default target. SwiftUI `.sensoryFeedback()` (the recommended simple path) needs iOS 17+.
- **Always gate on `CHHapticEngine.capabilitiesForHardware().supportsHaptics` before creating the engine.** Many devices (most iPads, all simulators) return false.
- One long-lived engine per app (e.g. a single `@Observable HapticManager`), created once and reused — never one engine per buzz.
- Wire `resetHandler` (restart the engine after a server reset) and `stoppedHandler` (mark unavailable / restart) at setup. Without them the engine silently dies and never recovers.
- `start()` before playing for lowest latency; treat both creation and start as failable and degrade per the `FALLBACK` dial — never force-try.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll just create the engine and play." | Creating `CHHapticEngine` on hardware without a Taptic Engine throws, and most iPads / every simulator report `supportsHaptics == false`. Check `capabilitiesForHardware().supportsHaptics` first; if false, skip silently or fall back. |
| "I set it up once, it'll stay running." | The haptic server resets (audio-session interruptions, backgrounding, errors) and the engine stops. You must implement `resetHandler` to restart and `stoppedHandler` to react — otherwise haptics just stop firing with no error. |
| "`try engine.start()` — done." | Start is failable and `start(completionHandler:)` is async; it can fail (server init, interruption). Force-trying crashes; ignoring the error leaves you "playing" into a dead engine. Handle the error and set availability accordingly. |
| "I need a custom CHHapticEngine for this success buzz." | For taps, selections, success/error, and impacts, SwiftUI `.sensoryFeedback()` or `UIFeedbackGenerator` is one line, needs no engine, no capability dance, no lifecycle. Reach for Core Haptics only for custom patterns, audio sync, live modulation, or AHAP. |
| "Haptics will play whenever I call start." | Haptics require a foreground, user-initiated context and an appropriate audio session; they're suppressed when the app is backgrounded or in silent/Do-Not-Disturb-style contexts. Don't rely on them firing from background work or as the only feedback channel. |
| "I'll stop the engine right after firing to save battery." | Stopping/recreating per playback adds latency and races. Keep the engine alive while patterns play (let `isAutoShutdownEnabled` handle idle shutdown), and rely on `resetHandler` to recover — don't manually thrash start/stop around each event. |

## Verification gate

Before shipping Core Haptics code, confirm every line:

- [ ] `capabilitiesForHardware().supportsHaptics` checked before the engine is created; unsupported devices degrade per the `FALLBACK` dial.
- [ ] Exactly one long-lived engine, created once and reused — not per playback.
- [ ] `resetHandler` restarts the engine; `stoppedHandler` updates availability (and restarts if appropriate).
- [ ] Engine creation and `start()` are handled as failable — no force-`try`; failures flip availability instead of crashing.
- [ ] Engine stays alive while patterns play; idle shutdown left to `isAutoShutdownEnabled` rather than manual stop-per-event.
- [ ] Continuous events stay within the 30 s cap; intensity/sharpness clamped to 0.0–1.0.
- [ ] Simple feedback (tap/success/error/selection) uses `.sensoryFeedback()` / `UIFeedbackGenerator`, not a hand-rolled engine.
- [ ] Reduce-Motion / user haptic preference respected; tested on a physical device (haptics don't fire in the simulator).

## Deep reference

`references/guide.md` — full capability checks, the `HapticManager` engine pattern, transient/continuous events, multi-event patterns, parameter curves, audio-haptic sync, the AHAP file format and loading, SwiftUI integration (`.sensoryFeedback()` and gesture-driven haptics), use-case recipes (collision, success/error, progress, texture), and battery/error-handling guidance. Load it for any concrete API question.

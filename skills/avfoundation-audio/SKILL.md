---
name: avfoundation-audio
description: Implement and review audio playback, recording, and processing on iOS with AVFoundation/AVFAudio — AVAudioSession setup, AVAudioPlayer, AVAudioRecorder, AVAudioEngine, interruption and route-change handling, background audio, and microphone permission. Use when the user mentions audio playback, audio recording, AVAudioSession, AVAudioPlayer, AVAudioEngine, sound effects, playing a sound, the microphone, recording the mic, or background audio. For AVPlayer video/HLS streaming, this is not the right skill.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple AVFAudio docs via Context7 (/websites/developer_apple_avfaudio)
---

# AVFoundation Audio

Playback, recording, and real-time processing on Apple platforms via AVFAudio. The deep reference — every category/mode/option, AVAudioPlayer, AVAudioRecorder, AVAudioEngine node graphs, AVSpeechSynthesizer, Now Playing / remote commands, recording settings, full examples — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `ROLE` — `playback` (`.playback` category; music/podcast/sound) · `record` (`.record`; capture only) · `play-and-record` (`.playAndRecord`; VoIP, voice memo, live monitoring). Picks the AVAudioSession category and what permissions/Info.plist keys you need.
2. `ENGINE` — `simple` (`AVAudioPlayer`/`AVAudioRecorder` — files, sound effects, basic record; default) · `engine` (`AVAudioEngine` node graph — effects, mixing, taps, real-time DSP). Don't reach for `AVAudioEngine` unless you need the graph.
3. `BACKGROUND` — `foreground-only` (default) · `background` (audio keeps playing when backgrounded — requires the `audio` UIBackgroundMode **and** an active non-mixing session like `.playback`).

## When to use

Building or reviewing any code that plays audio, records from the mic, processes audio in real time, configures `AVAudioSession`, or wires lock-screen / Control Center playback. Not for `AVPlayer`-based video or HLS streaming, and not for MusicKit / Apple Music catalog playback.

## Core rules

- iOS 17+ default target. Microphone permission is `AVAudioApplication.requestRecordPermission()` (async) and `AVAudioApplication.shared.recordPermission` — **not** the deprecated `AVAudioSession` equivalents.
- Configure **and** activate the session before any playback/record: `setCategory(_:mode:options:)` then `setActive(true)`. Category is the single biggest determinant of behavior.
- Hold a **strong reference** to every `AVAudioPlayer`, `AVAudioRecorder`, and `AVAudioEngine`. A local that goes out of scope stops/deallocs mid-sound.
- Subscribe to `AVAudioSession.interruptionNotification` and `routeChangeNotification` for anything that plays for more than an instant. Without them audio dies silently on a phone call or unplugged headphones and never resumes.
- One session is shared process-wide (`AVAudioSession.sharedInstance()`). Centralize config; don't let two managers fight over the category.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I created the player and called `play()` — good enough." | No `AVAudioSession` category set + `setActive(true)` means you inherit `.soloAmbient`: silenced by the mute switch, killed in background, wrong routing. Configure + activate the session first, with the category the use case needs. |
| "`AVAudioSession.requestRecordPermission` is what I learned." | Deprecated since iOS 17. Use `AVAudioApplication.requestRecordPermission()` (async `-> Bool`) and read `AVAudioApplication.shared.recordPermission`. The old `AVAudioSession` calls still compile but are the wrong API on the current target. |
| "Permission prompt will appear, so I don't need Info.plist." | Without `NSMicrophoneUsageDescription` the app **crashes** on first record attempt — no prompt, no recording. The string is mandatory, not optional. |
| "I'll make the player a `let` inside the function that plays it." | The player deallocates when the function returns and the sound cuts off (or never starts). Player/recorder/engine must be stored properties living as long as the audio. |
| "Interruptions are an edge case I'll skip." | A phone call, Siri, or an alarm pauses your session; headphones unplugged triggers a route change. Without handling `.interruptionNotification` (resume only on `.shouldResume`) and `.routeChangeNotification` (pause on `.oldDeviceUnavailable`), audio silently stops and blasts the speaker on reconnect. |
| "Background audio just needs the UIBackgroundMode." | The `audio` UIBackgroundMode is necessary but not sufficient — you also need an **active** session with a non-mixing category (`.playback`) actually playing. Mode without an active playing session = silence on backgrounding. |

## Verification gate

Before shipping audio, confirm every line:

- [ ] `AVAudioSession` category/mode/options set for the use case, then `setActive(true)` — before any play/record.
- [ ] Player / recorder / engine held as a strong stored property, not a local.
- [ ] Recording path: `NSMicrophoneUsageDescription` in Info.plist **and** `AVAudioApplication.requestRecordPermission()` gated before record (no deprecated `AVAudioSession` permission API).
- [ ] `interruptionNotification` handled: pause on `.began`, resume only when `.ended` options contain `.shouldResume`.
- [ ] `routeChangeNotification` handled: pause on `.oldDeviceUnavailable` (don't keep playing out the speaker).
- [ ] Session deactivated with `.notifyOthersOnDeactivation` when audio is done, so other apps resume.
- [ ] Background audio (if used): `audio` in `UIBackgroundModes` **and** an active `.playback` session that's actually playing.
- [ ] `AVAudioEngine` graph (if used): every node `attach`-ed before `connect`, engine `start()` wrapped in `do/catch`, taps removed on stop.

## Deep reference

`references/guide.md` — full AVAudioSession categories/modes/options tables, AVAudioPlayer (controls, delegate, multi-sound), AVAudioRecorder (settings presets, metering), AVAudioEngine (effects chains, input taps, engine recording), AVSpeechSynthesizer, background audio, Now Playing / `MPRemoteCommandCenter`, a complete player service, and a class quick-reference. Load it for any concrete API question.

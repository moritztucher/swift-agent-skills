---
name: avkit-videoplayer
description: Implement and review video playback on Apple platforms with AVKit/AVFoundation — SwiftUI VideoPlayer, AVPlayer/AVPlayerItem/AVAsset, AVPlayerViewController, HLS streaming, time observation, Picture in Picture, and the audio session for video. Use when the user mentions video playback, VideoPlayer, AVPlayer, AVPlayerViewController, AVPlayerLayer, play video, HLS, streaming video, .m3u8, Picture in Picture, PiP, or AVKit. For audio-only playback/recording and the deeper AVAudioSession rules (interruptions, route changes), use the `avfoundation-audio` skill.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple AVKit/AVFoundation docs via Context7 (/websites/developer_apple)
---

# AVKit Video Player

Video playback on Apple platforms via AVKit + AVFoundation. The deep reference — `VideoPlayer` vs `AVPlayerViewController` vs custom `AVPlayerLayer`, async asset loading, HLS, time/status observation, PiP wiring, the audio session, queue/looping players, lifecycle — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `UI` — `swiftui-VideoPlayer` (SwiftUI `VideoPlayer(player:)`, system chrome, least code; default) · `AVPlayerViewController` (UIKit/tvOS, system controls + PiP + AirPlay + full-screen for free) · `custom-layer` (`AVPlayerLayer`, you draw every control — only when system chrome genuinely doesn't fit).
2. `SOURCE` — `local` (bundled/file URL via `AVURLAsset`; load `.duration` async) · `hls-stream` (remote `.m3u8` over http(s); duration is `indefinite` for live, observe `.status` instead).
3. `PIP` — `off` (default) · `on` (requires the `audio` UIBackgroundMode **and** an active `.playback` session; auto/manual via `AVPlayerViewController` or `AVPictureInPictureController`).

## When to use

Building or reviewing any code that plays video, streams HLS, observes playback time/status, wires Picture in Picture, or sets the audio session for video. Not for audio-only playback/recording (`avfoundation-audio`), not for `AVCaptureSession` camera capture, not for MusicKit catalog playback.

## Core rules

- iOS 17+ default target (iOS 26 current default). Async `AVAsset.load(_:)` for all asset properties — synchronous `asset.duration`/`.tracks` is deprecated.
- **Build the `AVPlayer` once and reuse it** — in SwiftUI create it in `.task` and hold it in `@State` (`@State private var player: AVPlayer?`), never inline in `body`/`init`. Swap content with `replaceCurrentItem(with:)`, don't recreate the player.
- Set `AVAudioSession` to `.playback` (mode `.moviePlayback`) and `setActive(true)` before playing, or the video is silent in silent mode and dies on backgrounding.
- Every observer you add must be removed: `removeTimeObserver` for time observers, release the stored `NSKeyValueObservation` for KVO, remove `NotificationCenter` observers on teardown. Use `[weak self]` in observer closures.
- PiP is opt-in: `audio` background mode + active `.playback` session + a player UI or `AVPictureInPictureController` that enables it. It is never automatic.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "It plays, so the sound just works." | With no `AVAudioSession` set you inherit `.soloAmbient`: the video is **silent in silent/ringer-off mode** and pauses the moment the app backgrounds. Set `.playback` + `.moviePlayback` and `setActive(true)` before playing. |
| "I'll read `asset.duration` (or build the scrubber) right after creating the player." | Asset properties load asynchronously — synchronous `asset.duration` returns garbage/zero and is deprecated. `await asset.load(.duration)`, or observe `AVPlayerItem.status` and read duration once it's `.readyToPlay`. For live HLS, duration is `indefinite` — don't compute progress from it. |
| "I added a periodic time observer; the closure will clean itself up." | A registered time observer not removed with `removeTimeObserver` **crashes on dealloc**, and capturing `self` strongly makes self → player → closure → self — a retain cycle the player never releases. Store the token, remove it on teardown, capture `[weak self]`. Same for KVO: hold the `NSKeyValueObservation`, don't let it leak or cycle. |
| "I set `allowsPictureInPicturePlayback = true`, so PiP works." | Not by itself. PiP needs the `audio` UIBackgroundMode in Info.plist **and** an active `.playback` audio session; a custom player additionally needs you to drive `AVPictureInPictureController` (it isn't created for you). Miss any piece and video just pauses on backgrounding. |
| "HLS is just another URL — I'll point it at the local `.m3u8`." | HLS streams **only over http(s)** with correctly-MIME'd playlist/segments; a `file://` `.m3u8` won't stream, and plain `http` needs an ATS exception. Use `https`, serve `application/vnd.apple.mpegurl`, and branch on `duration.isIndefinite` for live. |
| "I'll just make a new `AVPlayer` each time the view redraws / for each feed cell." | Recreating the player per `body` evaluation or per cell stutters playback and leaks decoders. Create it once, hold it, and use `replaceCurrentItem(with:)` to change videos. In SwiftUI, defer creation to `.task` so it's built exactly once. |

## Verification gate

Before shipping video, confirm every line:

- [ ] `AVPlayer` created once and held (SwiftUI: `@State` + `.task`); content swapped via `replaceCurrentItem(with:)`, not recreated.
- [ ] `AVAudioSession` set to `.playback` / `.moviePlayback` and `setActive(true)` before play.
- [ ] Asset properties loaded with async `load(_:)`; no synchronous `asset.duration`/`.tracks`; playback gated on `AVPlayerItem.status == .readyToPlay`.
- [ ] Every time observer removed (`removeTimeObserver`), every KVO token stored and released, notifications removed on teardown — all observer closures `[weak self]`.
- [ ] HLS (if used): `https` `.m3u8`, correct server MIME types, live streams branch on `duration.isIndefinite`.
- [ ] PiP (if used): `audio` in `UIBackgroundModes`, active `.playback` session, and `AVPlayerViewController.allowsPictureInPicturePlayback` or a wired `AVPictureInPictureController` (+ restore-UI delegate).
- [ ] Player paused off-screen (`.onDisappear` / cell scrolled away) so audio doesn't play from a hidden view.
- [ ] No deprecated APIs: `loadValuesAsynchronously`, key-path `addObserver`/`observeValue` KVO, `AVAsset(url:)` (use `AVURLAsset`).

## Deep reference

`references/guide.md` — presentation-layer comparison, SwiftUI `VideoPlayer` (with overlay), `AVPlayerViewController` (UIKit + SwiftUI bridge), async asset loading, HLS/streaming, transport + seeking + periodic/boundary time observers, status observation (Combine/KVO/async), Picture in Picture (system + custom), the audio session for video, custom `AVPlayerLayer`, `AVQueuePlayer`/`AVPlayerLooper`, lifecycle/retain-cycle rules, and a type + deprecation quick-reference. Load it for any concrete API question.

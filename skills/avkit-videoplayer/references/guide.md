# AVKit Video Player — Deep Reference

Video playback on Apple platforms (iOS 17+/iOS 26 default target). Covers the three presentation layers — SwiftUI `VideoPlayer`, UIKit `AVPlayerViewController`, and a custom `AVPlayerLayer` — plus the shared playback engine (`AVPlayer` / `AVPlayerItem` / `AVAsset`), local and HLS streaming, playback control and time observation, Picture in Picture, and the audio session.

`VideoPlayer`, `AVPlayerViewController`, and `AVPictureInPictureController` live in **AVKit**. `AVPlayer`, `AVPlayerItem`, `AVAsset`/`AVURLAsset`, and `AVPlayerLayer` live in **AVFoundation**. `AVAudioSession` lives in **AVFAudio** — for anything beyond the one `.playback` recipe here, use the `avfoundation-audio` skill.

---

## 1. The mental model

There is exactly one playback engine, three ways to put pixels on screen:

```
AVAsset  ── timed media (file or stream), loads properties async
   │
AVPlayerItem  ── one playback session over an asset: status, buffering, tracks
   │
AVPlayer  ── the transport: play/pause/rate/seek/time. Reusable. Swap items into it.
   │
   ├── VideoPlayer(player:)         ── SwiftUI, system controls, least code
   ├── AVPlayerViewController        ── UIKit, full-screen + PiP + tvOS/visionOS, most features
   └── AVPlayerLayer                 ── raw CALayer, you build every control yourself
```

Key principle: **the player is the expensive, reusable part.** Create one `AVPlayer`, hold it, and feed it `AVPlayerItem`s with `replaceCurrentItem(with:)`. Never recreate a player per view update.

---

## 2. SwiftUI — `VideoPlayer`

The least-code path. iOS 14+, but treat iOS 17+ as the floor for the `Observable` `AVPlayer` ergonomics below. Gives you the system transport controls for free.

```swift
import SwiftUI
import AVKit

struct ContentView: View {
    // Optional, created in .task — NOT in the initializer.
    @State private var player: AVPlayer?

    var body: some View {
        VStack {
            if let player {
                VideoPlayer(player: player)
                    .frame(height: 220)
            } else {
                ProgressView()
            }
        }
        .task {
            // Deferring creation to .task ensures SwiftUI builds the player
            // exactly once, not on every body re-evaluation.
            let url = URL(string: "https://example.com/movie.m3u8")!
            player = AVPlayer(url: url)
        }
    }
}
```

Why `.task` and `@State private var player: AVPlayer?` instead of `VideoPlayer(player: AVPlayer(url:))` inline: a fresh `AVPlayer(url:)` in `body` allocates a new player on every re-render, tears down playback, and leaks. Apple's own sample defers creation to `.task` for this reason.

### Overlay content

```swift
VideoPlayer(player: player) {
    // Drawn on top of the video, below the system transport controls.
    VStack {
        Spacer()
        Text("Live").padding(6).background(.red, in: Capsule())
    }
}
```

### Custom controls in SwiftUI

`VideoPlayer` always shows system controls; you can't hide them. If you need a fully custom control surface, drop to `AVPlayerViewController` (`showsPlaybackControls = false`) wrapped in `UIViewControllerRepresentable`, or to `AVPlayerLayer`. A bare play/pause button driven off the player still works because `AVPlayer` is `Observable` on iOS 17+:

```swift
struct TransportView: View {
    let player: AVPlayer                       // passed in, owned by the parent

    private var isPlaying: Bool { player.timeControlStatus == .playing }

    var body: some View {
        Button {
            isPlaying ? player.pause() : player.play()
        } label: {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
        }
        .disabled(player.currentItem?.status != .readyToPlay)
    }
}
```

---

## 3. UIKit — `AVPlayerViewController`

The full-featured player: system transport UI, full-screen presentation, AirPlay, subtitle/audio track selection, contextual actions (tvOS), and **built-in Picture in Picture** with no extra controller. Use it whenever you want Apple's complete player UI.

```swift
import AVKit

let item = AVPlayerItem(url: videoURL)
let controller = AVPlayerViewController()
controller.player = AVPlayer(playerItem: item)
controller.allowsPictureInPicturePlayback = true        // PiP for free
controller.videoGravity = .resizeAspect
present(controller, animated: true) {
    controller.player?.play()
}
```

### Wrapped for SwiftUI

```swift
struct SystemVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = player
        vc.allowsPictureInPicturePlayback = true
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {
        // Reassign only if the player actually changed; don't churn every update.
        if vc.player !== player { vc.player = player }
    }
}
```

Useful properties:

| Property | Effect |
|---|---|
| `showsPlaybackControls` | Hide the system controls to build your own on top. |
| `videoGravity` | `.resizeAspect` (letterbox, default) · `.resizeAspectFill` (crop to fill) · `.resize` (stretch). |
| `allowsPictureInPicturePlayback` | Enables PiP without an `AVPictureInPictureController`. |
| `canStartPictureInPictureAutomaticallyFromInline` | Start PiP automatically when the app backgrounds (iOS 14.2+). |
| `entersFullScreenWhenPlaybackBegins` / `exitsFullScreenWhenPlaybackEnds` | Auto full-screen behavior. |
| `requiresLinearPlayback` | Disable scrubbing/skip (ads). |

`AVPlayerViewControllerDelegate` gives full-screen transition and PiP lifecycle callbacks (`playerViewControllerWillStartPictureInPicture(_:)`, `...restoreUserInterfaceForPictureInPictureStop...`).

---

## 4. Custom — `AVPlayerLayer`

Raw pixels, zero UI. You own every control, the scrubber, the time labels. Use when the design can't tolerate any system chrome, or you're compositing video into a larger scene.

```swift
final class VideoContainerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }
}
```

Backing the view's `layerClass` with `AVPlayerLayer` is the correct approach — the layer resizes with the view automatically, so you never hand-sync `frame` on rotation. (If you instead `addSublayer`, you must update `playerLayer.frame` yourself in `layoutSubviews`.) Set `videoGravity` on the layer the same way as the view controller.

---

## 5. Loading media — `AVAsset` is asynchronous

Modern AVFoundation loads asset properties **asynchronously**. Synchronous accessors (`asset.duration`, `asset.tracks`, `asset.isPlayable`) are deprecated and block. Always `await asset.load(...)`:

```swift
let asset = AVURLAsset(url: url)

// Load one property.
let duration = try await asset.load(.duration)        // CMTime

// Load several at once.
let (playable, tracks) = try await asset.load(.isPlayable, .tracks)
guard playable else { throw PlaybackError.notPlayable }
```

`AVURLAsset` (a concrete `AVAsset`) is what you build from a URL. You can pass options, e.g. for HTTP headers:

```swift
let asset = AVURLAsset(url: url, options: [
    "AVURLAssetHTTPHeaderFieldsKey": ["Authorization": "Bearer \(token)"]
])
```

### Building the item and player

```swift
func makePlayer(url: URL) async throws -> AVPlayer {
    let asset = AVURLAsset(url: url)
    // Validate before handing to a player so failures surface here, not as a silent stall.
    guard try await asset.load(.isPlayable) else { throw PlaybackError.notPlayable }
    let item = AVPlayerItem(asset: asset)
    return AVPlayer(playerItem: item)
}
```

You can attach a custom `videoComposition` to the item (filters, spatial video, watermarks); set `item.seekingWaitsForVideoCompositionRendering = true` when compositing so scrubs land on a rendered frame.

### Local files

Local files (bundle or Documents) work identically — just a `file://` URL. There's no buffering, but `AVAsset` loading is still async; don't read `duration` synchronously off a local asset either.

```swift
let url = Bundle.main.url(forResource: "intro", withExtension: "mp4")!
let player = AVPlayer(url: url)
```

---

## 6. HLS streaming (`.m3u8`)

HLS is the first-class Apple streaming format and the only correct way to stream adaptive video. You don't do anything special in code — point an `AVURLAsset`/`AVPlayer` at the `.m3u8` playlist URL and AVFoundation handles segment fetching, bitrate adaptation, and live edge:

```swift
let url = URL(string: "https://cdn.example.com/master.m3u8")!
let player = AVPlayer(url: url)
```

Requirements and knobs:

- **Must be served over HTTP(S)** with the correct MIME type (`application/vnd.apple.mpegurl` or `application/x-mpegURL`). A `file://` HLS playlist will not stream — package it as a remote URL or use the offline `AVAssetDownloadURLSession` path.
- For **plaintext HTTP** you need an ATS exception (`NSAppTransportSecurity`). Prefer HTTPS.
- Cap bitrate (cellular, data saver) with `playerItem.preferredPeakBitRate` (bits/sec) or `playerItem.preferredMaximumResolution`.
- `playerItem.preferredForwardBufferDuration` controls how far ahead to buffer.
- **Live vs VOD:** for a live `.m3u8`, `duration` is `CMTime.indefinite` — never treat it as a finite number for a progress bar. Use `player.currentItem?.seekableTimeRanges` to find the seekable window and the live edge.
- DRM (FairPlay) is handled via `AVContentKeySession`; out of scope here.

### Offline / downloaded HLS

Download HLS for offline playback with `AVAssetDownloadURLSession` + `AVAggregateAssetDownloadTask`; play back the resulting local asset. Do **not** copy `.ts`/`.m3u8` files manually — use the download API so keys and segments stay consistent.

---

## 7. Playback control

```swift
player.play()                                   // sets rate to 1.0
player.pause()                                   // sets rate to 0.0
player.rate = 1.5                                // trick play / speed
await player.seek(to: CMTime(seconds: 30, preferredTimescale: 600))
// Frame-accurate seek (slower):
await player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
```

- Prefer the `async` `seek(to:)`; the completion-handler variant is fine too. A new seek cancels the previous pending one.
- `player.actionAtItemEnd` = `.pause` (default), `.advance` (queue player), or `.none`.
- Loop a single item by observing `AVPlayerItemDidPlayToEndTime` and seeking to `.zero`, or use `AVPlayerLooper` with an `AVQueuePlayer`.

### `timeControlStatus` vs `rate`

`timeControlStatus` is the source of truth for "is it actually playing": `.playing`, `.paused`, `.waitingToPlayAtSpecifiedRate` (buffering / stalled). `rate > 0` does **not** mean frames are moving — a stalled stream has `rate == 1` but `timeControlStatus == .waitingToPlayAtSpecifiedRate`. Drive your play/pause icon off `timeControlStatus`.

---

## 8. Observing state and time

### Time updates — `addPeriodicTimeObserver`

The right way to drive a scrubber/clock. It fires on your queue at the interval you ask for and is throttled to actual playback.

```swift
final class PlayerModel: ObservableObject {
    let player = AVPlayer()
    @Published var currentTime = 0.0
    @Published var duration = 0.0
    private var timeObserver: Any?

    func addPeriodicTimeObserver() {
        let interval = CMTime(value: 1, timescale: 2)            // every 0.5s
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: interval, queue: .main
        ) { [weak self] time in                                  // [weak self] — required
            guard let self else { return }
            currentTime = time.seconds
            duration = player.currentItem?.duration.seconds ?? 0
        }
    }

    func removePeriodicTimeObserver() {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
    }

    deinit { removePeriodicTimeObserver() }
}
```

Two non-negotiables: capture `[weak self]` in the block, and **`removeTimeObserver` exactly once** before the player or the observer's owner is deallocated. The returned token is opaque; store it. Removing twice, or never, crashes / leaks.

### Status / readiness — prefer async or Combine over manual KVO

`AVPlayerItem.status` (`.unknown` → `.readyToPlay` / `.failed`) tells you when playback can begin. On iOS 17+ `AVPlayer` is `Observable`, so in SwiftUI you can read `player.currentItem?.status` and `player.timeControlStatus` directly and the view updates. Outside SwiftUI, the Combine publisher is the clean path:

```swift
player.publisher(for: \.timeControlStatus)
    .receive(on: DispatchQueue.main)
    .map { $0 == .playing }
    .assign(to: &$isPlaying)
```

If you use classic KVO (`observe(\.status)`), **hold the returned `NSKeyValueObservation` token** and let it deinit with the owner — dropping it on the floor stops the observation; a strong ref cycle through the player leaks it. The async-sequence / Combine / `Observable` routes avoid the manual token bookkeeping entirely and are preferred on the current target.

### End of playback

```swift
NotificationCenter.default.addObserver(
    forName: .AVPlayerItemDidPlayToEndTime,
    object: player.currentItem, queue: .main
) { [weak self] _ in self?.handleEnd() }
```

`.AVPlayerItemFailedToPlayToEndTime` carries the error in `userInfo` when a stream dies mid-play.

---

## 9. Audio session for video

Video is silent or behaves wrong without the right `AVAudioSession`. The standard recipe for movie playback:

```swift
import AVFoundation

func configureAudioSession() {
    let session = AVAudioSession.sharedInstance()
    do {
        try session.setCategory(.playback, mode: .moviePlayback)
        try session.setActive(true)
    } catch {
        print("Audio session error: \(error)")
    }
}
```

- `.playback` makes audio play **even when the ring/silent switch is on** and is the prerequisite for background audio, PiP audio, and AirPlay. With the default `.soloAmbient` category, video is muted by the silent switch and stops on background.
- `.moviePlayback` mode tunes routing/signal processing for long-form video.
- Call this **once, early** (e.g. app launch or before the first play), not per frame. The session is process-wide and shared.
- For interruption (`interruptionNotification`) and route-change (`routeChangeNotification`) handling — required for anything that plays more than a moment — use the `avfoundation-audio` skill. They apply identically to video.

---

## 10. Picture in Picture

PiP keeps the video playing in a floating window when the user leaves your player. Two paths:

### Path A — `AVPlayerViewController` (recommended)

PiP is built in. You only need:

1. `controller.allowsPictureInPicturePlayback = true`
2. The **`audio` background mode** in `UIBackgroundModes` (Info.plist / Signing & Capabilities → Background Modes → "Audio, AirPlay, and Picture in Picture").
3. An active `.playback` audio session (section 9).

Optionally `canStartPictureInPictureAutomaticallyFromInline = true` to enter PiP when the app backgrounds during inline playback.

### Path B — `AVPictureInPictureController` (custom player)

For an `AVPlayerLayer`-based player you drive PiP yourself:

```swift
import AVKit

guard AVPictureInPictureController.isPictureInPictureSupported() else { return }

let pipController = AVPictureInPictureController(
    playerLayer: myView.playerLayer            // your AVPlayerLayer
)
pipController?.delegate = self                  // hold a strong reference!
// To start: pipController?.startPictureInPicture()
```

PiP requirements (both paths):

- **`audio` UIBackgroundMode is mandatory** — without it PiP silently never starts. This is the same key background audio uses.
- **Active `.playback` audio session.** A muted/`.soloAmbient` session won't sustain PiP.
- Hold a **strong reference** to the `AVPictureInPictureController` and its delegate — a local is deallocated and PiP dies instantly.
- `isPictureInPicturePossible` (KVO-observable) tells you when the button should be enabled; it's only possible once the item is ready and on-screen.
- PiP is **not automatic** — even with the entitlement you must either set `allowsPictureInPicturePlayback` (Path A) or call `startPictureInPicture()` (Path B).
- Implement `pictureInPictureController(_:restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:)` to bring your player UI back when the user taps to return, and call the completion handler.

---

## 11. `AVQueuePlayer` and looping

`AVQueuePlayer` is an `AVPlayer` subclass that plays a sequence of items back-to-back.

```swift
let items = urls.map { AVPlayerItem(url: $0) }
let queue = AVQueuePlayer(items: items)
queue.advanceToNextItem()                       // skip current
queue.insert(newItem, after: nil)               // append
```

Seamless looping of a single clip uses `AVPlayerLooper` (don't hand-roll it with seeks — the looper pre-rolls for a gapless boundary):

```swift
let queue = AVQueuePlayer()
let looper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: url))
// Keep `looper` alive as long as you want looping.
queue.play()
```

Hold the `AVPlayerLooper` strongly; if it deallocs, looping stops.

---

## 12. Common pitfalls

- **Recreating the player.** `VideoPlayer(player: AVPlayer(url:))` inline, or `AVPlayer(url:)` in `body`/`updateUIViewController`, allocates a new engine each render. Create once, hold in `@State`/a model, swap items with `replaceCurrentItem(with:)`.
- **Reading `duration` synchronously.** `asset.duration` is deprecated and returns `.indefinite`/blocks. `await asset.load(.duration)`. For live HLS, duration is `.indefinite` by design.
- **Forgetting `removeTimeObserver`.** Leaks the player and the closure; a missed `[weak self]` retains the model. Remove the observer in `deinit`/teardown.
- **Manual KVO leaks.** A dropped `NSKeyValueObservation` token silently stops observing; a captured-`self` cycle leaks. Prefer `Observable`/Combine/async sequences on iOS 17+.
- **No audio session / wrong category.** Video plays but is muted by the silent switch, stops on background, and can't do PiP. Set `.playback` + activate.
- **Expecting PiP without the background mode.** No `audio` UIBackgroundMode → PiP never starts, no error. Add the capability.
- **`file://` HLS.** HLS only streams over HTTP(S) with the right MIME type. Local `.m3u8` won't play as a stream.
- **Treating `rate > 0` as "playing."** A buffering stream has `rate == 1` but isn't rendering. Use `timeControlStatus`.

---

## 13. Quick reference

| Type | Framework | Role |
|---|---|---|
| `VideoPlayer` | AVKit (SwiftUI) | System player view, least code. |
| `AVPlayerViewController` | AVKit (UIKit) | Full player UI + built-in PiP, full-screen, AirPlay. |
| `AVPlayerLayer` | AVFoundation | Raw video layer for fully custom players. |
| `AVPlayer` | AVFoundation | Transport: play/pause/rate/seek/time. Reusable. |
| `AVQueuePlayer` | AVFoundation | `AVPlayer` subclass that plays a queue. |
| `AVPlayerItem` | AVFoundation | One playback session: status, buffer, tracks. |
| `AVAsset` / `AVURLAsset` | AVFoundation | Media source; async property loading. |
| `AVPlayerLooper` | AVFoundation | Gapless single-item loop over a queue player. |
| `AVPictureInPictureController` | AVKit | Manual PiP for custom (`AVPlayerLayer`) players. |
| `AVAudioSession` | AVFAudio | `.playback` + `.moviePlayback` for video. |

Key async/observable APIs: `asset.load(_:)`, `player.seek(to:)` (async), `addPeriodicTimeObserver(forInterval:queue:)` / `removeTimeObserver(_:)`, `player.publisher(for: \.timeControlStatus)`, `AVPlayer`/`AVPlayerItem` `Observable` (iOS 17+).

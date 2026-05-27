# AVFoundation Audio Guide - iOS/Swift

Comprehensive guide for audio playback, recording, and processing in iOS/Swift using AVFoundation and AVFAudio frameworks.

---

## Overview

The **AVFAudio** framework (part of AVFoundation) provides APIs for:

- **AVAudioPlayer** - Simple audio file playback
- **AVAudioRecorder** - Basic audio recording
- **AVAudioSession** - Audio session configuration and routing
- **AVAudioEngine** - Advanced real-time audio processing
- **AVSpeechSynthesizer** - Text-to-speech synthesis

---

## Import

```swift
import AVFoundation
// or specifically:
import AVFAudio
```

---

## AVAudioSession

The audio session manages how your app interacts with the system audio. Configure it before playing or recording audio.

### Get Shared Instance

```swift
let audioSession = AVAudioSession.sharedInstance()
```

### Categories

| Category | Description | Use Case |
|----------|-------------|----------|
| `.ambient` | Mixes with other audio, silenced by mute switch | Background music in games |
| `.soloAmbient` | Default. Silences other audio, silenced by mute switch | Media player (default) |
| `.playback` | Silences other audio, ignores mute switch | Music/podcast player |
| `.record` | Recording only, silences playback | Voice recorder |
| `.playAndRecord` | Simultaneous playback and recording | VoIP, voice chat |
| `.multiRoute` | Multiple audio routes simultaneously | DJ apps |

### Category Options

| Option | Description |
|--------|-------------|
| `.mixWithOthers` | Allow mixing with other apps' audio |
| `.duckOthers` | Lower other apps' audio volume |
| `.allowBluetooth` | Allow Bluetooth audio devices |
| `.allowBluetoothA2DP` | Allow high-quality Bluetooth playback |
| `.allowAirPlay` | Allow AirPlay audio |
| `.defaultToSpeaker` | Route to speaker instead of receiver |

### Modes

| Mode | Description |
|------|-------------|
| `.default` | Default audio behavior |
| `.voiceChat` | Optimized for voice chat (VoIP) |
| `.gameChat` | Optimized for game chat |
| `.videoRecording` | Optimized for video recording |
| `.measurement` | Minimal signal processing |
| `.moviePlayback` | Optimized for movie playback |
| `.spokenAudio` | Optimized for spoken content (podcasts, audiobooks) |

### Configure Audio Session

```swift
func configureAudioSession() {
    let audioSession = AVAudioSession.sharedInstance()

    do {
        // For playback only
        try audioSession.setCategory(.playback, mode: .default)

        // For playback that mixes with other apps
        try audioSession.setCategory(.playback, options: [.mixWithOthers])

        // For recording and playback (VoIP)
        try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])

        // Activate the session
        try audioSession.setActive(true)
    } catch {
        print("Failed to configure audio session: \(error)")
    }
}
```

### Deactivate Audio Session

```swift
func deactivateAudioSession() {
    do {
        try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    } catch {
        print("Failed to deactivate audio session: \(error)")
    }
}
```

### Handle Interruptions

```swift
@Observable
class AudioManager {
    init() {
        setupInterruptionHandling()
    }

    private func setupInterruptionHandling() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            self?.handleInterruption(notification)
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            // Interruption began (e.g., phone call)
            pausePlayback()
        case .ended:
            // Interruption ended
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                resumePlayback()
            }
        @unknown default:
            break
        }
    }

    private func pausePlayback() { /* ... */ }
    private func resumePlayback() { /* ... */ }
}
```

### Handle Route Changes

```swift
private func setupRouteChangeHandling() {
    NotificationCenter.default.addObserver(
        forName: AVAudioSession.routeChangeNotification,
        object: AVAudioSession.sharedInstance(),
        queue: .main
    ) { [weak self] notification in
        self?.handleRouteChange(notification)
    }
}

private func handleRouteChange(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
          let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
          let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
        return
    }

    switch reason {
    case .oldDeviceUnavailable:
        // Headphones unplugged - pause playback
        pausePlayback()
    case .newDeviceAvailable:
        // New device connected (headphones, Bluetooth)
        print("New audio device available")
    case .categoryChange:
        print("Audio category changed")
    default:
        break
    }
}
```

---

## AVAudioPlayer

Simple API for playing audio files. Best for sound effects, background music, and basic audio playback.

### Basic Playback

```swift
import AVFoundation

@Observable
class AudioPlayerManager {
    private var audioPlayer: AVAudioPlayer?
    var isPlaying: Bool { audioPlayer?.isPlaying ?? false }
    var currentTime: TimeInterval { audioPlayer?.currentTime ?? 0 }
    var duration: TimeInterval { audioPlayer?.duration ?? 0 }

    func playSound(named filename: String, extension ext: String = "mp3") {
        guard let url = Bundle.main.url(forResource: filename, withExtension: ext) else {
            print("Audio file not found: \(filename).\(ext)")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("Failed to play audio: \(error)")
        }
    }

    func pause() {
        audioPlayer?.pause()
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
    }

    func resume() {
        audioPlayer?.play()
    }
}
```

### Play from URL

```swift
func playAudio(from url: URL) {
    do {
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.play()
    } catch {
        print("Error playing audio: \(error)")
    }
}
```

### Play from Data

```swift
func playAudio(data: Data) {
    do {
        audioPlayer = try AVAudioPlayer(data: data)
        audioPlayer?.play()
    } catch {
        print("Error playing audio data: \(error)")
    }
}
```

### Playback Controls

```swift
@Observable
class AudioPlayerManager {
    private var audioPlayer: AVAudioPlayer?

    // Volume (0.0 to 1.0)
    var volume: Float {
        get { audioPlayer?.volume ?? 1.0 }
        set { audioPlayer?.volume = newValue }
    }

    // Playback rate (0.5 to 2.0)
    var rate: Float {
        get { audioPlayer?.rate ?? 1.0 }
        set { audioPlayer?.rate = newValue }
    }

    // Enable rate adjustment
    func enableRateAdjustment() {
        audioPlayer?.enableRate = true
    }

    // Looping (-1 = infinite, 0 = no loop, n = loop n times)
    var numberOfLoops: Int {
        get { audioPlayer?.numberOfLoops ?? 0 }
        set { audioPlayer?.numberOfLoops = newValue }
    }

    // Seek to position
    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
    }

    // Pan (-1.0 left to 1.0 right)
    var pan: Float {
        get { audioPlayer?.pan ?? 0 }
        set { audioPlayer?.pan = newValue }
    }
}
```

### AVAudioPlayerDelegate

```swift
@Observable
class AudioPlayerManager: NSObject, AVAudioPlayerDelegate {
    private var audioPlayer: AVAudioPlayer?
    var didFinishPlaying: (() -> Void)?
    var decodingError: Error?

    func play(url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.play()
        } catch {
            print("Error: \(error)")
        }
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            didFinishPlaying?()
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        decodingError = error
        print("Decode error: \(error?.localizedDescription ?? "Unknown")")
    }
}
```

### Play Multiple Sounds Simultaneously

```swift
@Observable
class MultiAudioPlayer {
    private var players: [String: AVAudioPlayer] = [:]

    func loadSound(named name: String, fileExtension: String = "mp3") {
        guard let url = Bundle.main.url(forResource: name, withExtension: fileExtension) else { return }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            players[name] = player
        } catch {
            print("Failed to load \(name): \(error)")
        }
    }

    func play(_ name: String) {
        players[name]?.play()
    }

    func stop(_ name: String) {
        players[name]?.stop()
        players[name]?.currentTime = 0
    }

    func stopAll() {
        players.values.forEach { $0.stop() }
    }
}
```

---

## AVAudioRecorder

Records audio from the microphone. Requires microphone permission.

### Info.plist Configuration

Add to your Info.plist:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access to record audio.</string>
```

### Request Microphone Permission

```swift
import AVFoundation

func requestMicrophonePermission() async -> Bool {
    await AVAudioApplication.requestRecordPermission()
}

// Check current status
func checkMicrophonePermission() -> Bool {
    AVAudioApplication.shared.recordPermission == .granted
}
```

### Basic Recording

```swift
@Observable
class AudioRecorderManager: NSObject, AVAudioRecorderDelegate {
    private var audioRecorder: AVAudioRecorder?
    var isRecording: Bool { audioRecorder?.isRecording ?? false }
    var recordingURL: URL?

    func startRecording() async throws {
        // Request permission
        guard await requestMicrophonePermission() else {
            throw RecordingError.permissionDenied
        }

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default)
        try audioSession.setActive(true)

        // Create recording URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")
        recordingURL = audioFilename

        // Recording settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        // Create recorder
        audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.prepareToRecord()
        audioRecorder?.record()
    }

    func stopRecording() {
        audioRecorder?.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func pauseRecording() {
        audioRecorder?.pause()
    }

    func resumeRecording() {
        audioRecorder?.record()
    }

    // MARK: - AVAudioRecorderDelegate

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            print("Recording finished successfully at: \(recorder.url)")
        } else {
            print("Recording failed")
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("Recording encode error: \(error?.localizedDescription ?? "Unknown")")
    }
}

enum RecordingError: LocalizedError {
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Microphone permission denied"
        }
    }
}
```

### Recording Settings

```swift
// High quality AAC (recommended for voice/music)
let aacSettings: [String: Any] = [
    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
    AVSampleRateKey: 44100.0,
    AVNumberOfChannelsKey: 2,
    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
    AVEncoderBitRateKey: 128000
]

// WAV (uncompressed, larger files)
let wavSettings: [String: Any] = [
    AVFormatIDKey: Int(kAudioFormatLinearPCM),
    AVSampleRateKey: 44100.0,
    AVNumberOfChannelsKey: 2,
    AVLinearPCMBitDepthKey: 16,
    AVLinearPCMIsFloatKey: false,
    AVLinearPCMIsBigEndianKey: false
]

// Voice memo quality (smaller files)
let voiceMemoSettings: [String: Any] = [
    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
    AVSampleRateKey: 22050.0,
    AVNumberOfChannelsKey: 1,
    AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
]
```

### Audio Metering

```swift
@Observable
class AudioRecorderManager {
    private var audioRecorder: AVAudioRecorder?
    private var meterTimer: Timer?
    var averagePower: Float = 0
    var peakPower: Float = 0

    func startMetering() {
        audioRecorder?.isMeteringEnabled = true
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateMeters()
        }
    }

    private func updateMeters() {
        audioRecorder?.updateMeters()
        averagePower = audioRecorder?.averagePower(forChannel: 0) ?? -160
        peakPower = audioRecorder?.peakPower(forChannel: 0) ?? -160
    }

    func stopMetering() {
        meterTimer?.invalidate()
        meterTimer = nil
    }

    // Convert to 0-1 range for UI
    var normalizedPower: Float {
        // Power is in dB, typically -160 (silence) to 0 (max)
        let minDb: Float = -60
        let clampedPower = max(averagePower, minDb)
        return (clampedPower - minDb) / abs(minDb)
    }
}
```

---

## AVAudioEngine

Advanced audio processing with a node-based graph architecture. Use for real-time audio effects, mixing, and processing.

### Basic File Playback

```swift
@Observable
class AudioEngineManager {
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    var isPlaying: Bool { playerNode.isPlaying }

    init() {
        setupEngine()
    }

    private func setupEngine() {
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: nil)
    }

    func play(url: URL) throws {
        let audioFile = try AVAudioFile(forReading: url)

        // Connect with the file's format
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: audioFile.processingFormat)

        // Schedule the file
        playerNode.scheduleFile(audioFile, at: nil) {
            print("Playback completed")
        }

        // Start engine and player
        try audioEngine.start()
        playerNode.play()
    }

    func stop() {
        playerNode.stop()
        audioEngine.stop()
    }

    func pause() {
        playerNode.pause()
    }

    func resume() {
        playerNode.play()
    }
}
```

### Audio Effects Chain

```swift
@Observable
class AudioEffectsManager {
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let reverbNode = AVAudioUnitReverb()
    private let eqNode = AVAudioUnitEQ(numberOfBands: 3)
    private let distortionNode = AVAudioUnitDistortion()

    var reverbWetDryMix: Float = 50 {
        didSet { reverbNode.wetDryMix = reverbWetDryMix }
    }

    init() {
        setupEffectsChain()
    }

    private func setupEffectsChain() {
        // Configure reverb
        reverbNode.loadFactoryPreset(.largeHall)
        reverbNode.wetDryMix = reverbWetDryMix

        // Configure EQ
        if let lowBand = eqNode.bands.first {
            lowBand.frequency = 100
            lowBand.gain = 0
            lowBand.bandwidth = 1
            lowBand.filterType = .lowShelf
        }

        // Attach nodes
        audioEngine.attach(playerNode)
        audioEngine.attach(reverbNode)
        audioEngine.attach(eqNode)

        // Connect: Player -> EQ -> Reverb -> Output
        let format = audioEngine.mainMixerNode.outputFormat(forBus: 0)
        audioEngine.connect(playerNode, to: eqNode, format: format)
        audioEngine.connect(eqNode, to: reverbNode, format: format)
        audioEngine.connect(reverbNode, to: audioEngine.mainMixerNode, format: format)
    }

    func play(url: URL) throws {
        let audioFile = try AVAudioFile(forReading: url)
        playerNode.scheduleFile(audioFile, at: nil)
        try audioEngine.start()
        playerNode.play()
    }
}
```

### Real-Time Audio Input Processing

```swift
@Observable
class AudioInputProcessor {
    private let audioEngine = AVAudioEngine()
    var inputLevel: Float = 0

    func startProcessing() async throws {
        // Request microphone permission
        guard await AVAudioApplication.requestRecordPermission() else {
            throw AudioError.permissionDenied
        }

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: .defaultToSpeaker)
        try audioSession.setActive(true)

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer)
        }

        try audioEngine.start()
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)

        // Calculate RMS (root mean square) for level metering
        var sum: Float = 0
        for i in 0..<frameLength {
            sum += channelData[i] * channelData[i]
        }
        let rms = sqrt(sum / Float(frameLength))

        DispatchQueue.main.async {
            self.inputLevel = rms
        }
    }

    func stopProcessing() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
    }
}

enum AudioError: LocalizedError {
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Microphone permission denied"
        }
    }
}
```

### Recording with AVAudioEngine

```swift
@Observable
class EngineRecorder {
    private let audioEngine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    var isRecording = false

    func startRecording(to url: URL) async throws {
        guard await AVAudioApplication.requestRecordPermission() else {
            throw AudioError.permissionDenied
        }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default)
        try audioSession.setActive(true)

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        // Create audio file for writing
        audioFile = try AVAudioFile(forWriting: url, settings: format.settings)

        // Install tap to write audio
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, time in
            try? self?.audioFile?.write(from: buffer)
        }

        try audioEngine.start()
        isRecording = true
    }

    func stopRecording() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        audioFile = nil
        isRecording = false
    }
}
```

---

## AVSpeechSynthesizer

Text-to-speech synthesis for reading text aloud.

### Basic Speech

```swift
import AVFoundation

@Observable
class SpeechManager {
    private let synthesizer = AVSpeechSynthesizer()
    var isSpeaking: Bool { synthesizer.isSpeaking }

    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    func pause() {
        synthesizer.pauseSpeaking(at: .word)
    }

    func resume() {
        synthesizer.continueSpeaking()
    }
}
```

### Configure Speech Properties

```swift
func speak(_ text: String, language: String = "en-US") {
    let utterance = AVSpeechUtterance(string: text)

    // Voice selection
    utterance.voice = AVSpeechSynthesisVoice(language: language)

    // Speed (0.0 to 1.0, default ~0.5)
    utterance.rate = AVSpeechUtteranceDefaultSpeechRate

    // Pitch (0.5 to 2.0, default 1.0)
    utterance.pitchMultiplier = 1.0

    // Volume (0.0 to 1.0)
    utterance.volume = 1.0

    // Delays
    utterance.preUtteranceDelay = 0.0
    utterance.postUtteranceDelay = 0.0

    synthesizer.speak(utterance)
}
```

### Available Voices

```swift
func getAvailableVoices() -> [AVSpeechSynthesisVoice] {
    return AVSpeechSynthesisVoice.speechVoices()
}

func getVoices(for language: String) -> [AVSpeechSynthesisVoice] {
    return AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix(language) }
}

func printAvailableVoices() {
    for voice in AVSpeechSynthesisVoice.speechVoices() {
        print("\(voice.name) - \(voice.language) - \(voice.quality.rawValue)")
    }
}

// Use a specific voice
func speakWithVoice(_ text: String, voiceIdentifier: String) {
    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier)
    synthesizer.speak(utterance)
}
```

### Speech Delegate

```swift
@Observable
class SpeechManager: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    var currentWord: String = ""
    var progress: Double = 0
    var didFinish: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        synthesizer.speak(utterance)
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("Started speaking")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("Finished speaking")
        didFinish?()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        let text = utterance.speechString as NSString
        currentWord = text.substring(with: characterRange)
        progress = Double(characterRange.location) / Double(text.length)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        print("Paused")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        print("Continued")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("Cancelled")
    }
}
```

### Configure Audio Session for Speech

```swift
func configureSpeechAudioSession() {
    let audioSession = AVAudioSession.sharedInstance()
    do {
        // Use spokenAudio mode for audiobooks/podcasts
        try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try audioSession.setActive(true)
    } catch {
        print("Failed to configure audio session: \(error)")
    }
}
```

---

## Background Audio

### Enable Background Audio

Add to Info.plist:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

Or in Xcode: Target > Signing & Capabilities > + Capability > Background Modes > Audio, AirPlay, and Picture in Picture

### Configure for Background Playback

```swift
func configureForBackgroundPlayback() {
    let audioSession = AVAudioSession.sharedInstance()
    do {
        try audioSession.setCategory(.playback, mode: .default)
        try audioSession.setActive(true)
    } catch {
        print("Failed to configure: \(error)")
    }
}
```

---

## Now Playing Info (Lock Screen/Control Center)

```swift
import MediaPlayer

@Observable
class NowPlayingManager {
    func updateNowPlayingInfo(title: String, artist: String, duration: TimeInterval, currentTime: TimeInterval, artwork: UIImage? = nil) {
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: 1.0
        ]

        if let artwork = artwork {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
```

### Handle Remote Commands

```swift
func setupRemoteCommands(
    playHandler: @escaping () -> Void,
    pauseHandler: @escaping () -> Void,
    skipForwardHandler: @escaping () -> Void,
    skipBackwardHandler: @escaping () -> Void
) {
    let commandCenter = MPRemoteCommandCenter.shared()

    commandCenter.playCommand.addTarget { _ in
        playHandler()
        return .success
    }

    commandCenter.pauseCommand.addTarget { _ in
        pauseHandler()
        return .success
    }

    commandCenter.skipForwardCommand.preferredIntervals = [15]
    commandCenter.skipForwardCommand.addTarget { _ in
        skipForwardHandler()
        return .success
    }

    commandCenter.skipBackwardCommand.preferredIntervals = [15]
    commandCenter.skipBackwardCommand.addTarget { _ in
        skipBackwardHandler()
        return .success
    }
}
```

---

## Complete Audio Player Example

```swift
import AVFoundation
import MediaPlayer

@Observable
class AudioPlayerService: NSObject, AVAudioPlayerDelegate {
    private var audioPlayer: AVAudioPlayer?

    var isPlaying: Bool { audioPlayer?.isPlaying ?? false }
    var currentTime: TimeInterval { audioPlayer?.currentTime ?? 0 }
    var duration: TimeInterval { audioPlayer?.duration ?? 0 }
    var progress: Double { duration > 0 ? currentTime / duration : 0 }

    var volume: Float = 1.0 {
        didSet { audioPlayer?.volume = volume }
    }

    var didFinishPlaying: (() -> Void)?

    // MARK: - Setup

    func configure() {
        configureAudioSession()
        setupRemoteCommands()
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
    }

    // MARK: - Playback

    func load(url: URL) throws {
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.delegate = self
        audioPlayer?.prepareToPlay()
    }

    func play() {
        audioPlayer?.play()
        updateNowPlaying()
    }

    func pause() {
        audioPlayer?.pause()
        updateNowPlaying()
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        updateNowPlaying()
    }

    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        updateNowPlaying()
    }

    // MARK: - Now Playing

    private func updateNowPlaying() {
        var info: [String: Any] = [
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        didFinishPlaying?()
    }
}
```

---

## Best Practices

### 1. Always Configure Audio Session

```swift
// Configure before any audio operation
func prepareForAudio() {
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback)
    try? session.setActive(true)
}
```

### 2. Handle Interruptions Gracefully

```swift
// Always pause on interruption began
// Only resume if shouldResume option is present
```

### 3. Deactivate Session When Done

```swift
// Notify other apps when your audio ends
try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
```

### 4. Use Appropriate Categories

| Use Case | Category | Mode |
|----------|----------|------|
| Music player | `.playback` | `.default` |
| Podcast | `.playback` | `.spokenAudio` |
| Game with music | `.ambient` | `.default` |
| Voice recording | `.playAndRecord` | `.default` |
| VoIP | `.playAndRecord` | `.voiceChat` |

### 5. Prepare Audio Before Playing

```swift
// Reduces latency when play() is called
audioPlayer.prepareToPlay()
```

---

## Common Issues & Solutions

### Issue: Audio doesn't play when app is in background

Enable Background Modes capability and use `.playback` category.

### Issue: Audio interrupts other apps

Use `.ambient` category or `.mixWithOthers` option.

### Issue: Recording permission not requested

Ensure `NSMicrophoneUsageDescription` is in Info.plist.

### Issue: Audio plays through earpiece instead of speaker

Use `.defaultToSpeaker` option with `.playAndRecord` category:
```swift
try session.setCategory(.playAndRecord, options: .defaultToSpeaker)
```

### Issue: Audio quality is poor during recording

Use higher sample rate and bit rate in recording settings.

---

## Quick Reference

| Task | Class |
|------|-------|
| Simple playback | `AVAudioPlayer` |
| Recording | `AVAudioRecorder` |
| Real-time processing | `AVAudioEngine` |
| Text-to-speech | `AVSpeechSynthesizer` |
| Session config | `AVAudioSession` |
| Lock screen controls | `MPRemoteCommandCenter` |
| Now playing info | `MPNowPlayingInfoCenter` |

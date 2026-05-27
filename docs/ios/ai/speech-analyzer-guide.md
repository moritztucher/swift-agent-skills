# SpeechAnalyzer Framework Guide

A comprehensive guide for using Apple's SpeechAnalyzer framework to integrate advanced speech-to-text capabilities into iOS 26+, macOS 26+, and tvOS 26+ applications.

---

## Table of Contents

1. [Overview](#overview)
2. [Getting Started](#getting-started)
3. [Core Architecture](#core-architecture)
4. [SpeechTranscriber](#speechtranscriber)
5. [SpeechDetector](#speechdetector)
6. [DictationTranscriber](#dictationtranscriber)
7. [Audio Input Sources](#audio-input-sources)
8. [Real-Time Transcription](#real-time-transcription)
9. [File-Based Transcription](#file-based-transcription)
10. [Result Handling](#result-handling)
11. [Language Model Management](#language-model-management)
12. [SwiftUI Integration](#swiftui-integration)
13. [Error Handling](#error-handling)
14. [Migration from SFSpeechRecognizer](#migration-from-sfspeechrecognizer)
15. [Best Practices](#best-practices)

---

## Overview

The SpeechAnalyzer framework is Apple's next-generation speech-to-text API, introduced in iOS 26 to replace the aging SFSpeechRecognizer. Key benefits:

- **On-Device Processing**: All processing happens locally; data never leaves the device
- **Full Offline Support**: Works without internet connection
- **Modular Architecture**: Attach different modules for specific analysis tasks
- **Swift Concurrency**: Built with async/await and AsyncSequence support
- **Improved Accuracy**: Enhanced model performance for distant audio and long-form content
- **Zero App Memory Impact**: Model runs outside your app's memory space

### Requirements

- iOS 26.0+, macOS 26.0+, tvOS 26.0+ (watchOS not supported)
- Apple Silicon device (SpeechTranscriber requires newer hardware)
- Speech Recognition permission

### Supported Devices

SpeechTranscriber works on:
- iPhone 12 and newer
- iPhone SE 3rd generation and newer
- Mac with Apple Silicon

**Not supported:**
- iPhone 11 and earlier
- iPhone SE 2nd generation
- Simulator (use DictationTranscriber as fallback)

### Import

```swift
import Speech
```

---

## Getting Started

### Minimal Example

```swift
import Speech

// Create transcriber and analyzer
let transcriber = SpeechTranscriber(locale: .current, preset: .offlineTranscription)
let analyzer = SpeechAnalyzer(modules: [transcriber])

// Transcribe an audio file
try await analyzer.start(inputAudioFile: audioFileURL, finishAfterFile: true)

for try await result in transcriber.results {
    print(result.text)
}
```

### Request Permission

```swift
func requestSpeechPermission() async -> Bool {
    await withCheckedContinuation { continuation in
        SFSpeechRecognizer.requestAuthorization { status in
            continuation.resume(returning: status == .authorized)
        }
    }
}
```

### Check Availability

```swift
// Check if SpeechTranscriber is available on this device
if SpeechTranscriber.supportsDevice() {
    // Use SpeechTranscriber
    let transcriber = SpeechTranscriber(locale: .current, preset: .progressiveLiveTranscription)
} else {
    // Fall back to DictationTranscriber
    let transcriber = DictationTranscriber(locale: .current)
}
```

---

## Core Architecture

SpeechAnalyzer uses a modular architecture with three main components:

### SpeechAnalyzer

The central coordinator that manages analysis sessions and routes audio to attached modules.

```swift
// Create analyzer with modules
let transcriber = SpeechTranscriber(locale: .current)
let analyzer = SpeechAnalyzer(modules: [transcriber])
```

### Modules

Modules perform specific analysis tasks. iOS 26 provides two modules:

| Module | Purpose |
|--------|---------|
| `SpeechTranscriber` | Converts speech to text |
| `SpeechDetector` | Detects voice activity (VAD) |

### Timeline-Based Operations

All operations use audio timecodes for:
- Sample-accurate timing precision
- Predictable operation ordering
- Non-overlapping result sequences

```swift
// Results include timing information when attributeOptions includes .audioTimeRange
for try await result in transcriber.results {
    if let timeRange = result.audioTimeRange {
        print("Speech at \(timeRange.start) - \(timeRange.end)")
    }
}
```

---

## SpeechTranscriber

SpeechTranscriber performs speech-to-text conversion, suitable for normal conversation and general purposes.

### Initialization with Preset

```swift
// For offline/file transcription
let transcriber = SpeechTranscriber(
    locale: Locale.current,
    preset: .offlineTranscription
)

// For real-time live transcription
let transcriber = SpeechTranscriber(
    locale: Locale.current,
    preset: .progressiveLiveTranscription
)
```

### Initialization with Full Control

```swift
let transcriber = SpeechTranscriber(
    locale: Locale.current,
    transcriptionOptions: [],
    reportingOptions: [.volatileResults],
    attributeOptions: [.audioTimeRange]
)
```

### Configuration Options

#### Presets

| Preset | Use Case |
|--------|----------|
| `.offlineTranscription` | File-based transcription, optimized for accuracy |
| `.progressiveLiveTranscription` | Real-time feedback with volatile results |

#### Reporting Options

| Option | Description |
|--------|-------------|
| `.volatileResults` | Enable real-time interim results that get refined |

#### Attribute Options

| Option | Description |
|--------|-------------|
| `.audioTimeRange` | Include timing information for syncing text to audio |

### Accessing Results

```swift
// Create a task to process results
let resultsTask = Task {
    for try await result in transcriber.results {
        let text = String(result.text.characters)
        let isFinal = result.isFinal

        if isFinal {
            print("Final: \(text)")
        } else {
            print("Interim: \(text)")
        }
    }
}
```

---

## SpeechDetector

SpeechDetector performs Voice Activity Detection (VAD) to identify when speech is present in an audio stream without transcribing it.

### Use Cases

- Audio trimming to remove silence
- Indexing long recordings
- Determining when to start/stop transcription
- Audio analysis and segmentation

### Usage

```swift
let detector = SpeechDetector()
let analyzer = SpeechAnalyzer(modules: [detector])

// Start analysis
try await analyzer.start(inputAudioFile: audioURL, finishAfterFile: true)

// Process detection results
for try await segment in detector.results {
    if segment.containsSpeech {
        print("Speech detected at \(segment.timeRange)")
    }
}
```

### Known Issue (iOS 26 Beta)

In the initial iOS 26 SDK, SpeechDetector does not conform to `SpeechModule`. Apple has confirmed this will be fixed in a future point release. The API shown above reflects the intended usage.

---

## DictationTranscriber

DictationTranscriber is a fallback transcriber for devices that don't support SpeechTranscriber. It supports the same languages as iOS 10's on-device SFSpeechRecognizer but with improved UX (no need to enable Siri or keyboard dictation in Settings).

### When to Use

```swift
func createTranscriber(locale: Locale) -> any SpeechModule {
    if SpeechTranscriber.supportsDevice() {
        return SpeechTranscriber(locale: locale, preset: .progressiveLiveTranscription)
    } else {
        // Fallback for older devices or simulator
        return DictationTranscriber(locale: locale)
    }
}
```

### Differences from SpeechTranscriber

| Feature | SpeechTranscriber | DictationTranscriber |
|---------|-------------------|----------------------|
| Device Support | Newer Apple Silicon | All iOS 26 devices |
| Model Quality | Enhanced accuracy | Legacy model |
| Simulator Support | No | Yes |
| Long-form Audio | Optimized | Limited |

---

## Audio Input Sources

SpeechAnalyzer supports multiple audio input methods.

### File-Based Input

```swift
let analyzer = SpeechAnalyzer(modules: [transcriber])

// Transcribe entire file
try await analyzer.start(inputAudioFile: audioFileURL, finishAfterFile: true)

// Or allow continuing with more input after file
try await analyzer.start(inputAudioFile: audioFileURL, finishAfterFile: false)
```

### Streaming Input (AsyncSequence)

```swift
// Create input stream
let (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()

// Start analyzer with stream
try await analyzer.start(inputSequence: inputSequence)

// Feed audio buffers
func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
    let input = AnalyzerInput(buffer: buffer)
    inputBuilder.yield(input)
}

// Signal end of input
inputBuilder.finish()
```

### Get Best Audio Format

```swift
// Get the optimal format for the analyzer
let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
    compatibleWith: [transcriber]
)

// Configure your audio engine to use this format
```

---

## Real-Time Transcription

Complete implementation for live microphone transcription.

### AudioManager

```swift
import AVFoundation

@Observable
class AudioManager {
    private var audioEngine: AVAudioEngine?
    private var onBufferCallback: ((AVAudioPCMBuffer) -> Void)?

    func setupAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement)
        try session.setActive(true)
    }

    func requestMicrophonePermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func startAudioStream(onBuffer: @escaping (AVAudioPCMBuffer) -> Void) throws {
        onBufferCallback = onBuffer

        audioEngine = AVAudioEngine()
        guard let audioEngine else { return }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, _ in
            self?.onBufferCallback?(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    func stopAudioStream() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
    }
}
```

### BufferConverter

```swift
import AVFoundation

class BufferConverter {
    private var converter: AVAudioConverter?
    private let targetFormat: AVAudioFormat

    init(targetFormat: AVAudioFormat) {
        self.targetFormat = targetFormat
    }

    func convert(_ buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer? {
        let sourceFormat = buffer.format

        // Check if conversion needed
        guard sourceFormat != targetFormat else {
            return buffer
        }

        // Create converter if needed
        if converter == nil {
            converter = AVAudioConverter(from: sourceFormat, to: targetFormat)
        }

        guard let converter else { return nil }

        // Calculate output buffer size
        let ratio = targetFormat.sampleRate / sourceFormat.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: outputFrameCapacity
        ) else {
            return nil
        }

        var error: NSError?
        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        if let error {
            throw error
        }

        return outputBuffer
    }
}
```

### TranscriptionManager

```swift
import Speech

@Observable
class TranscriptionManager {
    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var analyzerFormat: AVAudioFormat?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Error>?
    private var bufferConverter: BufferConverter?

    func requestSpeechPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func startTranscription(onResult: @escaping (String, Bool) -> Void) async throws {
        // Create transcriber
        transcriber = SpeechTranscriber(
            locale: Locale.current,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )

        guard let transcriber else { return }

        // Create analyzer
        analyzer = SpeechAnalyzer(modules: [transcriber])

        // Get best format
        analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])

        if let format = analyzerFormat {
            bufferConverter = BufferConverter(targetFormat: format)
        }

        // Create input stream
        let (inputSequence, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        inputBuilder = continuation

        // Start results processing
        resultsTask = Task {
            for try await result in transcriber.results {
                let text = String(result.text.characters)
                onResult(text, result.isFinal)
            }
        }

        // Start analyzer
        try await analyzer?.start(inputSequence: inputSequence)
    }

    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let converted = try? bufferConverter?.convert(buffer) ?? buffer else { return }
        let input = AnalyzerInput(buffer: converted)
        inputBuilder?.yield(input)
    }

    func stopTranscription() async {
        inputBuilder?.finish()
        await analyzer?.finalizeAndFinishThroughEndOfInput()
        resultsTask?.cancel()

        transcriber = nil
        analyzer = nil
        inputBuilder = nil
        resultsTask = nil
    }
}
```

---

## File-Based Transcription

Transcribe pre-recorded audio files.

### Basic File Transcription

```swift
func transcribeFile(at url: URL) async throws -> String {
    let transcriber = SpeechTranscriber(
        locale: Locale.current,
        preset: .offlineTranscription
    )

    let analyzer = SpeechAnalyzer(modules: [transcriber])

    try await analyzer.start(inputAudioFile: url, finishAfterFile: true)

    var fullTranscript = ""

    for try await result in transcriber.results {
        if result.isFinal {
            fullTranscript += String(result.text.characters) + " "
        }
    }

    return fullTranscript.trimmingCharacters(in: .whitespaces)
}
```

### Transcription with Progress

```swift
func transcribeWithProgress(
    url: URL,
    onProgress: @escaping (String) -> Void,
    onComplete: @escaping (String) -> Void
) async throws {
    let transcriber = SpeechTranscriber(
        locale: Locale.current,
        transcriptionOptions: [],
        reportingOptions: [.volatileResults],
        attributeOptions: [.audioTimeRange]
    )

    let analyzer = SpeechAnalyzer(modules: [transcriber])

    try await analyzer.start(inputAudioFile: url, finishAfterFile: true)

    var finalText = ""

    for try await result in transcriber.results {
        let text = String(result.text.characters)

        if result.isFinal {
            finalText += text + " "
            onProgress(finalText)
        } else {
            // Show volatile results for progress
            onProgress(finalText + text)
        }
    }

    onComplete(finalText.trimmingCharacters(in: .whitespaces))
}
```

---

## Result Handling

### Volatile vs Final Results

When `reportingOptions: [.volatileResults]` is enabled:

- **Volatile Results**: Real-time guesses, less accurate, continuously replaced
- **Final Results**: High accuracy, immutable, delivered when confidence is high

```swift
for try await result in transcriber.results {
    if result.isFinal {
        // Commit this text - it won't change
        appendToTranscript(result.text)
    } else {
        // Show as preview - will be replaced
        updatePreview(result.text)
    }
}
```

### Result Properties

```swift
for try await result in transcriber.results {
    // The transcribed text
    let text = result.text

    // Whether this is a final or volatile result
    let isFinal = result.isFinal

    // Audio time range (if attributeOptions includes .audioTimeRange)
    if let timeRange = result.audioTimeRange {
        let start = timeRange.start
        let duration = timeRange.duration
    }
}
```

---

## Language Model Management

SpeechAnalyzer requires language-specific models to be downloaded to the device.

### Check Supported Locales

```swift
// Get all supported locales
let supported = await SpeechTranscriber.supportedLocales

// Check if specific locale is supported
func isLocaleSupported(_ locale: Locale) async -> Bool {
    let supported = await SpeechTranscriber.supportedLocales
    return supported.contains {
        $0.identifier(.bcp47) == locale.identifier(.bcp47)
    }
}
```

### Check Installed Locales

```swift
// Get installed locales
let installed = await SpeechTranscriber.installedLocales

// Check if model is already downloaded
func isModelInstalled(for locale: Locale) async -> Bool {
    let installed = await SpeechTranscriber.installedLocales
    return installed.contains {
        $0.identifier(.bcp47) == locale.identifier(.bcp47)
    }
}
```

### Download Model

```swift
func ensureModelAvailable(for transcriber: SpeechTranscriber, locale: Locale) async throws {
    // Check if supported
    guard await isLocaleSupported(locale) else {
        throw TranscriptionError.localeNotSupported
    }

    // Check if already installed
    if await isModelInstalled(for: locale) {
        return
    }

    // Download if needed
    if let downloader = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
        try await downloader.downloadAndInstall()
    }
}
```

### Model Management Notes

- Models are stored in a system-wide asset catalog (not in your app bundle)
- Zero impact on your app's download size
- Apple automatically updates models with system updates
- Models are shared across all apps using SpeechAnalyzer

---

## SwiftUI Integration

### Basic Speech-to-Text View

```swift
import SwiftUI
import Speech

struct SpeechToTextView: View {
    @State private var audioManager = AudioManager()
    @State private var transcriptionManager = TranscriptionManager()

    @State private var isRecording = false
    @State private var transcript = ""
    @State private var volatileText = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            // Transcript display
            ScrollView {
                Text(transcript + volatileText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Record button
            Button {
                Task { await toggleRecording() }
            } label: {
                Label(
                    isRecording ? "Stop" : "Start Recording",
                    systemImage: isRecording ? "stop.circle.fill" : "mic.circle.fill"
                )
                .font(.title2)
                .foregroundStyle(isRecording ? .red : .blue)
            }

            // Error display
            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .padding()
    }

    private func toggleRecording() async {
        if isRecording {
            await stopRecording()
        } else {
            await startRecording()
        }
    }

    private func startRecording() async {
        errorMessage = nil

        // Request permissions
        guard await audioManager.requestMicrophonePermission() else {
            errorMessage = "Microphone permission denied"
            return
        }

        guard await transcriptionManager.requestSpeechPermission() else {
            errorMessage = "Speech recognition permission denied"
            return
        }

        do {
            // Setup audio
            try audioManager.setupAudioSession()

            // Start transcription
            try await transcriptionManager.startTranscription { text, isFinal in
                if isFinal {
                    transcript += text + " "
                    volatileText = ""
                } else {
                    volatileText = text
                }
            }

            // Start audio capture
            try audioManager.startAudioStream { buffer in
                transcriptionManager.processAudioBuffer(buffer)
            }

            isRecording = true

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func stopRecording() async {
        audioManager.stopAudioStream()
        await transcriptionManager.stopTranscription()
        isRecording = false
    }
}
```

### Observable ViewModel Pattern

```swift
import Speech
import Observation

@Observable
@MainActor
class SpeechToTextViewModel {
    private let audioManager = AudioManager()
    private let transcriptionManager = TranscriptionManager()

    private(set) var isRecording = false
    private(set) var transcript = ""
    private(set) var volatileText = ""
    var errorMessage: String?

    var displayText: String {
        transcript + volatileText
    }

    func toggleRecording() async {
        if isRecording {
            await stop()
        } else {
            await start()
        }
    }

    private func start() async {
        errorMessage = nil

        guard await audioManager.requestMicrophonePermission(),
              await transcriptionManager.requestSpeechPermission() else {
            errorMessage = "Permissions required"
            return
        }

        do {
            try audioManager.setupAudioSession()

            try await transcriptionManager.startTranscription { [weak self] text, isFinal in
                Task { @MainActor in
                    if isFinal {
                        self?.transcript += text + " "
                        self?.volatileText = ""
                    } else {
                        self?.volatileText = text
                    }
                }
            }

            try audioManager.startAudioStream { [weak self] buffer in
                self?.transcriptionManager.processAudioBuffer(buffer)
            }

            isRecording = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func stop() async {
        audioManager.stopAudioStream()
        await transcriptionManager.stopTranscription()
        isRecording = false
    }

    func clear() {
        transcript = ""
        volatileText = ""
    }
}
```

---

## Error Handling

### Common Errors

```swift
enum SpeechAnalyzerError: LocalizedError {
    case deviceNotSupported
    case localeNotSupported
    case modelNotInstalled
    case modelDownloadFailed
    case permissionDenied
    case audioSessionFailed
    case analyzerFailed(Error)

    var errorDescription: String? {
        switch self {
        case .deviceNotSupported:
            return "This device does not support SpeechTranscriber"
        case .localeNotSupported:
            return "The selected language is not supported"
        case .modelNotInstalled:
            return "Language model not installed"
        case .modelDownloadFailed:
            return "Failed to download language model"
        case .permissionDenied:
            return "Speech recognition permission denied"
        case .audioSessionFailed:
            return "Failed to configure audio session"
        case .analyzerFailed(let error):
            return "Transcription failed: \(error.localizedDescription)"
        }
    }
}
```

### Error Handling Pattern

```swift
func startTranscription() async {
    do {
        // Check device support
        guard SpeechTranscriber.supportsDevice() else {
            throw SpeechAnalyzerError.deviceNotSupported
        }

        // Check locale support
        guard await isLocaleSupported(Locale.current) else {
            throw SpeechAnalyzerError.localeNotSupported
        }

        // Ensure model is available
        try await ensureModelAvailable(for: transcriber, locale: Locale.current)

        // Start transcription
        try await transcriber.start()

    } catch let error as SpeechAnalyzerError {
        handleError(error)
    } catch {
        handleError(.analyzerFailed(error))
    }
}
```

---

## Migration from SFSpeechRecognizer

### Comparison

| Feature | SFSpeechRecognizer | SpeechAnalyzer |
|---------|-------------------|----------------|
| Architecture | Monolithic | Modular |
| Concurrency | Delegates/callbacks | async/await, AsyncSequence |
| Long-form Audio | Limited | Optimized |
| Distant Audio | Poor accuracy | Enhanced accuracy |
| Offline Support | Partial | Full |
| Memory | In-app memory | System process |
| Custom Vocabulary | Supported | Not supported |

### Migration Example

**Before (SFSpeechRecognizer):**

```swift
let recognizer = SFSpeechRecognizer(locale: locale)
let request = SFSpeechAudioBufferRecognitionRequest()

recognizer?.recognitionTask(with: request) { result, error in
    if let result = result {
        let text = result.bestTranscription.formattedString
        let isFinal = result.isFinal
        // Handle result
    }
}
```

**After (SpeechAnalyzer):**

```swift
let transcriber = SpeechTranscriber(
    locale: locale,
    preset: .progressiveLiveTranscription
)
let analyzer = SpeechAnalyzer(modules: [transcriber])

let (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()
try await analyzer.start(inputSequence: inputSequence)

for try await result in transcriber.results {
    let text = String(result.text.characters)
    let isFinal = result.isFinal
    // Handle result
}
```

### What's New in SpeechAnalyzer

1. **Modular Design**: Add multiple modules for different analysis types
2. **Better Long-form Support**: Optimized for lectures, meetings, podcasts
3. **Timeline-Based**: Precise audio-to-text synchronization
4. **Improved Accuracy**: Enhanced model for distant and noisy audio
5. **System-Level Processing**: No impact on app memory limits

### What's Missing

- **Custom Vocabulary**: SpeechAnalyzer does not support custom vocabulary hints
- **watchOS**: Not available on Apple Watch

---

## Best Practices

### 1. Use Appropriate Preset

```swift
// For file transcription - prioritize accuracy
let transcriber = SpeechTranscriber(locale: locale, preset: .offlineTranscription)

// For live transcription - prioritize responsiveness
let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveLiveTranscription)
```

### 2. Handle Device Compatibility

```swift
func createTranscriber() -> any SpeechModule {
    if SpeechTranscriber.supportsDevice() {
        return SpeechTranscriber(locale: .current, preset: .progressiveLiveTranscription)
    } else {
        return DictationTranscriber(locale: .current)
    }
}
```

### 3. Pre-Download Language Models

```swift
// Download model during onboarding or settings
func prepareLanguageModel(for locale: Locale) async throws {
    let transcriber = SpeechTranscriber(locale: locale)
    if let downloader = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
        try await downloader.downloadAndInstall()
    }
}
```

### 4. Use Volatile Results for Better UX

```swift
// Enable volatile results for real-time feedback
let transcriber = SpeechTranscriber(
    locale: locale,
    reportingOptions: [.volatileResults]
)

// Display volatile results differently
for try await result in transcriber.results {
    if result.isFinal {
        commitText(result.text)
    } else {
        showPreview(result.text)
    }
}
```

### 5. Properly Clean Up Resources

```swift
func stopTranscription() async {
    // Signal end of input
    inputBuilder?.finish()

    // Wait for finalization
    await analyzer?.finalizeAndFinishThroughEndOfInput()

    // Cancel result processing
    resultsTask?.cancel()

    // Release resources
    transcriber = nil
    analyzer = nil
}
```

### 6. Convert Audio to Correct Format

```swift
// Always get the best format from the analyzer
let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])

// Convert incoming audio to match
let converter = BufferConverter(targetFormat: format)
```

---

## Quick Reference

### Key Types

| Type | Purpose |
|------|---------|
| `SpeechAnalyzer` | Central coordinator for analysis sessions |
| `SpeechTranscriber` | Speech-to-text transcription module |
| `SpeechDetector` | Voice activity detection module |
| `DictationTranscriber` | Fallback transcriber for older devices |
| `AnalyzerInput` | Wrapper for audio buffers |

### SpeechTranscriber.Preset

| Preset | Description |
|--------|-------------|
| `.offlineTranscription` | Optimized for accuracy, file-based |
| `.progressiveLiveTranscription` | Optimized for real-time feedback |

### SpeechTranscriber Options

| Option Type | Values |
|-------------|--------|
| `reportingOptions` | `.volatileResults` |
| `attributeOptions` | `.audioTimeRange` |

### SpeechAnalyzer Methods

```swift
// Start with audio file
try await analyzer.start(inputAudioFile: url, finishAfterFile: true)

// Start with stream
try await analyzer.start(inputSequence: asyncSequence)

// Finalize session
await analyzer.finalizeAndFinishThroughEndOfInput()

// Get best audio format
let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: modules)
```

### SpeechTranscriber Methods

```swift
// Check device support
SpeechTranscriber.supportsDevice()

// Check supported locales
await SpeechTranscriber.supportedLocales

// Check installed locales
await SpeechTranscriber.installedLocales

// Access results
for try await result in transcriber.results { }
```

---

## Resources

- [SpeechAnalyzer | Apple Developer Documentation](https://developer.apple.com/documentation/speech/speechanalyzer)
- [SpeechTranscriber | Apple Developer Documentation](https://developer.apple.com/documentation/speech/speechtranscriber)
- [SpeechDetector | Apple Developer Documentation](https://developer.apple.com/documentation/speech/speechdetector)
- [Bring advanced speech-to-text to your app with SpeechAnalyzer - WWDC25](https://developer.apple.com/videos/play/wwdc2025/277/)
- [Bringing advanced speech-to-text capabilities to your app | Apple Developer Documentation](https://developer.apple.com/documentation/Speech/bringing-advanced-speech-to-text-capabilities-to-your-app)
- [Swift Scribe - Example Project](https://github.com/FluidInference/swift-scribe)

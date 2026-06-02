---
name: speech-analyzer
description: Implement and review on-device speech-to-text on iOS 26+ with SpeechAnalyzer and SpeechTranscriber — file and live transcription, model/asset download, locale support, volatile vs final result streaming, and migration from SFSpeechRecognizer. Use when the user mentions speech to text, transcription, SpeechAnalyzer, SpeechTranscriber, speech recognition, dictation, transcribe audio, or live captions. For capturing the microphone audio you feed in, use the `avfoundation-audio` skill.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple Speech docs via Context7 (/websites/developer_apple — no dedicated SpeechAnalyzer library; verified against the broad Apple library)
---

# SpeechAnalyzer

On-device speech-to-text on Apple platforms via the iOS 26 Speech framework (`SpeechAnalyzer` + `SpeechTranscriber`), the modular async/await successor to `SFSpeechRecognizer` built for long-form and live transcription. The deep API reference — architecture, every module, file and live pipelines, asset/locale management, result handling, SwiftUI integration, SFSpeechRecognizer migration — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

This skill covers turning audio into text. It does **not** cover capturing that audio — the mic tap, `AVAudioEngine`, session category, and format wiring belong to `avfoundation-audio`. SpeechAnalyzer consumes `AVAudioPCMBuffer`s; getting them is that skill's job.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `SOURCE` — `file` (pre-recorded `AVAudioFile`; prefer the structured `analyzeSequence(from:)` and `.offlineTranscription` preset) · `live` (mic buffers fed through an `AsyncStream<AnalyzerInput>`; autonomous `start(inputSequence:)` + `.progressiveLiveTranscription`).
2. `RESULTS` — `final-only` (commit only `result.isFinal`; simplest, no flicker) · `volatile` (enable `.volatileResults`, show interim guesses as a replaceable preview, commit on final). Add `attributeOptions: [.audioTimeRange]` only if you need word/segment timing.
3. `LOCALE_STRATEGY` — `current-only` (resolve `supportedLocale(equivalentTo: .current)`, download on demand) · `reserved` (pin specific languages with `AssetInventory.reserve(locale:)` so the system won't reclaim the model; bounded by `maximumReservedLocales`).

## When to use

Building or reviewing any transcription, dictation, live-caption, or audio-to-text feature on an iOS 26+ target. If the target must support iOS 25 or earlier, or watchOS, SpeechAnalyzer is unavailable — fall back to `SFSpeechRecognizer`. If you only need to *capture* audio (not transcribe it), use `avfoundation-audio`.

## Core rules

- iOS 26+ only. `SpeechAnalyzer`/`SpeechTranscriber` do not exist before iOS 26 and are absent on watchOS. Gate with availability and keep an `SFSpeechRecognizer` path if you support older OSes.
- **`SpeechTranscriber` is not on every device.** Check `SpeechTranscriber.supportsDevice()`; on unsupported hardware and the Simulator, fall back to `DictationTranscriber` (legacy model, but runs everywhere).
- **Models are downloaded assets, not bundled.** Before transcribing, resolve a supported locale and run `AssetInventory.assetInstallationRequest(supporting:)` → `downloadAndInstall()`. A model being installed once is not permanent — the system can reclaim it; `reserve(locale:)` the languages you depend on.
- Request Speech authorization (`SFSpeechRecognizer.requestAuthorization`) **and** microphone permission for live input — they are two separate grants. Add `NSSpeechRecognitionUsageDescription` (and `NSMicrophoneUsageDescription` for live) to Info.plist.
- `result.text` is an `AttributedString`, not a `String` — read plain text with `String(result.text.characters)`.
- One driving style per session: structured (`analyzeSequence(_:)`/`from:`) **or** autonomous (`start(...)`) — never both. End autonomous sessions with `finalizeAndFinishThroughEndOfInput()`; end structured ones with `finalizeAndFinish(through:)` using the returned `CMTime`.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "Works in the Simulator, ship it." | `SpeechTranscriber.supportsDevice()` is `false` on the Simulator and older iPhones — there you get `DictationTranscriber`, a different (weaker) model. Test the real `SpeechTranscriber` path on supported hardware, or your "working" code crashes/degrades in the field. |
| "I'll just call `start()` / `transcribe()` and read results." | Nothing transcribes until the model asset is installed. Resolve the locale and run `AssetInventory.assetInstallationRequest(supporting:)` first, or you get silent empty results / a locale-unsupported error. |
| "I installed the model once, so it's there forever." | Models are a shared, system-managed resource the OS can reclaim. If a language must stay available, `AssetInventory.reserve(locale:)` it (and respect `maximumReservedLocales`) — installation alone is no guarantee. |
| "`result.text` is the transcript string." | It's an `AttributedString`. Concatenating it as text, or comparing it as a `String`, misbehaves — use `String(result.text.characters)`. The attributes carry timing/confidence you'd otherwise lose. |
| "I'll append every result to the transcript." | With `.volatileResults` on, most results are interim guesses that get *replaced*. Append only when `result.isFinal`; render non-final text as a transient preview, or the transcript fills with duplicated, half-formed phrases. |
| "I'll feed the mic buffer straight into `AnalyzerInput`." | The mic's format rarely matches `SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith:)`. Convert with `AVAudioConverter` to the analyzer's format first, or transcription quality collapses. (Capture + conversion is `avfoundation-audio`'s domain.) |
| "I'll port my SFSpeechRecognizer vocabulary hints over." | SpeechAnalyzer has **no** custom-vocabulary API. Code relying on contextual strings / `SFSpeechRecognitionRequest.contextualStrings` has no direct equivalent — don't assume parity. |

## Verification gate

Before shipping a transcription feature, confirm every line:

- [ ] Deployment target is iOS 26+; an `SFSpeechRecognizer` fallback exists if older OSes or watchOS are supported.
- [ ] `SpeechTranscriber.supportsDevice()` checked; `DictationTranscriber` fallback wired for unsupported devices and the Simulator.
- [ ] Locale resolved via `supportedLocale(equivalentTo:)`; unsupported language handled gracefully (not a crash).
- [ ] Model presence ensured (`AssetInventory.assetInstallationRequest` → `downloadAndInstall()`) before analysis; download failure surfaced to the user. Depended-on locales reserved.
- [ ] Speech authorization requested; microphone permission requested for live; both Info.plist usage strings present.
- [ ] Audio converted to `bestAvailableAudioFormat(compatibleWith:)` before yielding `AnalyzerInput` (live) — see `avfoundation-audio` for capture.
- [ ] Results read as `String(result.text.characters)`; only `isFinal` results committed, volatile shown as replaceable preview.
- [ ] Session ends correctly — `finalizeAndFinishThroughEndOfInput()` (autonomous) or `finalizeAndFinish(through:)` (structured); the input stream is `finish()`ed and tasks cancelled on stop.

## Deep reference

`references/guide.md` — full architecture, `SpeechTranscriber`/`SpeechDetector`/`DictationTranscriber`, file vs streaming input (structured vs autonomous), real-time mic pipeline with buffer conversion, result handling, asset/locale management and reservations, SwiftUI integration, error handling, SFSpeechRecognizer migration, and a key-types quick reference. Load it for any concrete API question.

# Translation Framework Guide

A comprehensive guide for implementing Apple's Translation framework in iOS applications using SwiftUI and async/await patterns.

---

## Table of Contents

1. [Overview](#overview)
2. [Setup and Configuration](#setup-and-configuration)
3. [Core Concepts](#core-concepts)
4. [SwiftUI Integration](#swiftui-integration)
5. [Programmatic Translation](#programmatic-translation)
6. [Batch Translations](#batch-translations)
7. [Language Availability and Downloading](#language-availability-and-downloading)
8. [Overlay vs Inline Translation](#overlay-vs-inline-translation)
9. [iOS 18/26 Specific Features](#ios-1826-specific-features)
10. [Common Use Cases](#common-use-cases)
11. [Best Practices](#best-practices)

---

## Overview

The Translation framework provides on-device text translation capabilities for iOS, iPadOS, and macOS applications. Introduced with iOS 17.4 and significantly expanded in iOS 18, this framework enables developers to integrate translation features using Apple's Core ML models.

### Key Features

- **On-Device Processing**: All translations occur locally using Core ML models, ensuring privacy
- **Shared Language Models**: Models downloaded by the user are shared across all apps, including Apple's Translate app
- **Free to Use**: No API costs or rate limits
- **Offline Support**: Once language models are downloaded, translation works without internet connectivity
- **SwiftUI Native**: Designed specifically for SwiftUI with view modifiers and async/await patterns

### Platform Requirements

| Platform | Minimum Version |
|----------|-----------------|
| iOS | 17.4+ (basic), 18.0+ (full API) |
| iPadOS | 17.4+ (basic), 18.0+ (full API) |
| macOS | 14.4+ (basic), 15.0+ (full API) |

### Important Limitations

- Translation APIs are **SwiftUI-only** and cannot be used directly in UIKit
- APIs **do not function in the Simulator** - must test on physical devices
- Does not support dialect conversion (e.g., Traditional Chinese to Simplified Chinese)
- Cannot translate between variants of the same language (e.g., US English to UK English)

---

## Setup and Configuration

### Import the Framework

```swift
import Translation
import SwiftUI
```

### Basic Project Setup

No additional configuration or entitlements are required. The Translation framework is available to all apps targeting the supported platform versions.

### Testing Requirements

Always test translation features on a physical device:

```swift
#if targetEnvironment(simulator)
// Translation APIs don't work in simulator
Text("Please test on a physical device")
#else
// Your translation implementation
#endif
```

---

## Core Concepts

### TranslationSession

`TranslationSession` is the core class for performing programmatic translations. Key characteristics:

- Translates one or more strings asynchronously
- Uses Swift async/await syntax
- Anchored to views (tied to view lifetime)
- Cannot be instantiated directly - must use `.translationTask` modifier

### TranslationSession.Configuration

Configuration object that specifies source and target languages:

```swift
@State private var configuration: TranslationSession.Configuration?

// Create configuration with explicit languages
configuration = TranslationSession.Configuration(
    source: Locale.Language(identifier: "de"),
    target: Locale.Language(identifier: "en")
)

// Create configuration with automatic detection
configuration = TranslationSession.Configuration(
    source: nil,  // Auto-detect source language
    target: nil   // Use user's preferred language
)
```

#### Invalidating Configuration

To trigger a new translation with the same configuration:

```swift
configuration?.invalidate()
```

### TranslationSession.Request

Represents a single translation request with optional tracking:

```swift
let request = TranslationSession.Request(
    sourceText: "Hallo, Welt!",
    clientIdentifier: "unique-id-001"  // Optional identifier for tracking
)
```

### TranslationSession.Response

Contains the translation result:

```swift
struct Response {
    let sourceText: String        // Original text
    let targetText: String        // Translated text
    let sourceLanguage: Locale.Language
    let targetLanguage: Locale.Language
    let clientIdentifier: String? // Matches request identifier
}
```

### LanguageAvailability

Checks language support and download status:

```swift
let availability = LanguageAvailability()

// Get all supported languages
let languages = await availability.supportedLanguages

// Check status for a language pair
let status = await availability.status(
    from: Locale.Language(identifier: "de"),
    to: Locale.Language(identifier: "en")
)
```

#### Status Values

| Status | Description |
|--------|-------------|
| `.installed` | Language pair supported and models downloaded |
| `.supported` | Language pair supported but models need download |
| `.unsupported` | Language pair not supported |

---

## SwiftUI Integration

### Translation Presentation (Overlay)

The simplest way to add translation - shows system UI overlay:

```swift
struct SimpleTranslationView: View {
    @State private var showTranslation = false
    private let textToTranslate = "Hallo, Welt!"

    var body: some View {
        VStack(spacing: 20) {
            Text(verbatim: textToTranslate)
                .font(.title)

            Button("Translate") {
                showTranslation = true
            }
        }
        .translationPresentation(
            isPresented: $showTranslation,
            text: textToTranslate
        )
    }
}
```

### Translation Presentation with Replacement

Allow users to replace original text with translation:

```swift
struct ReplaceableTranslationView: View {
    @State private var showTranslation = false
    @State private var displayText = "Hallo, Welt!"

    var body: some View {
        VStack(spacing: 20) {
            TextField("Text", text: $displayText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .translationPresentation(
                    isPresented: $showTranslation,
                    text: displayText
                ) { translatedString in
                    // Replace original with translation
                    displayText = translatedString
                }

            Button("Translate") {
                showTranslation = true
            }
        }
        .padding()
    }
}
```

### Translation Task Modifier

For programmatic control without system UI:

```swift
struct ProgrammaticTranslationView: View {
    @State private var sourceText = "Hallo, Welt!"
    @State private var translatedText: String?
    @State private var configuration: TranslationSession.Configuration?

    var body: some View {
        VStack(spacing: 20) {
            Text(translatedText ?? sourceText)
                .font(.title)

            Button("Translate") {
                if configuration == nil {
                    configuration = TranslationSession.Configuration(
                        source: Locale.Language(identifier: "de"),
                        target: Locale.Language(identifier: "en")
                    )
                } else {
                    configuration?.invalidate()
                }
            }
        }
        .translationTask(configuration) { session in
            do {
                let response = try await session.translate(sourceText)
                await MainActor.run {
                    translatedText = response.targetText
                }
            } catch {
                print("Translation failed: \(error)")
            }
        }
    }
}
```

### Translation Task with Language Parameters

Simpler syntax when languages are known:

```swift
struct LanguageSpecificTranslationView: View {
    let sourceText = "Hallo, Welt!"
    @State private var translatedText: String?

    var body: some View {
        Text(translatedText ?? sourceText)
            .translationTask(
                source: Locale.Language(identifier: "de"),
                target: Locale.Language(identifier: "en")
            ) { session in
                do {
                    let response = try await session.translate(sourceText)
                    await MainActor.run {
                        translatedText = response.targetText
                    }
                } catch {
                    print("Translation failed: \(error)")
                }
            }
    }
}
```

---

## Programmatic Translation

### Single String Translation

```swift
struct SingleTranslationExample: View {
    @State private var sourceText = "Bonjour le monde"
    @State private var translatedText: String?
    @State private var isTranslating = false
    @State private var configuration: TranslationSession.Configuration?

    var body: some View {
        VStack(spacing: 16) {
            TextField("Enter text", text: $sourceText, axis: .vertical)
                .textFieldStyle(.roundedBorder)

            if let translated = translatedText {
                Text(translated)
                    .foregroundStyle(.secondary)
            }

            Button(isTranslating ? "Translating..." : "Translate") {
                triggerTranslation()
            }
            .disabled(isTranslating || sourceText.isEmpty)
        }
        .padding()
        .translationTask(configuration) { session in
            await performTranslation(session: session)
        }
    }

    private func triggerTranslation() {
        guard !isTranslating else { return }

        if configuration == nil {
            configuration = TranslationSession.Configuration(
                source: nil,  // Auto-detect
                target: Locale.Language(identifier: "en")
            )
        } else {
            configuration?.invalidate()
        }
    }

    private func performTranslation(session: TranslationSession) async {
        await MainActor.run { isTranslating = true }

        do {
            let response = try await session.translate(sourceText)
            await MainActor.run {
                translatedText = response.targetText
                isTranslating = false
            }
        } catch {
            await MainActor.run {
                isTranslating = false
            }
            print("Translation error: \(error)")
        }
    }
}
```

### Handling Translation Errors

```swift
enum TranslationError: LocalizedError {
    case sessionUnavailable
    case translationFailed(String)
    case languageUnsupported

    var errorDescription: String? {
        switch self {
        case .sessionUnavailable:
            return "Translation session is not available"
        case .translationFailed(let message):
            return "Translation failed: \(message)"
        case .languageUnsupported:
            return "Language pair is not supported"
        }
    }
}

func translateWithErrorHandling(
    session: TranslationSession,
    text: String
) async throws -> String {
    do {
        let response = try await session.translate(text)
        return response.targetText
    } catch {
        throw TranslationError.translationFailed(error.localizedDescription)
    }
}
```

---

## Batch Translations

### Method 1: translations(from:) - All Results at Once

Returns all translations together after completion, maintaining original order:

```swift
struct BatchTranslationAllAtOnce: View {
    @State private var items = [
        "Guten Morgen",
        "Guten Tag",
        "Guten Abend",
        "Gute Nacht"
    ]
    @State private var translatedItems: [String] = []
    @State private var configuration: TranslationSession.Configuration?

    var body: some View {
        List {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                VStack(alignment: .leading) {
                    Text(item)
                    if index < translatedItems.count {
                        Text(translatedItems[index])
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .toolbar {
            Button("Translate All") {
                configuration = TranslationSession.Configuration(
                    source: Locale.Language(identifier: "de"),
                    target: Locale.Language(identifier: "en")
                )
            }
        }
        .translationTask(configuration) { session in
            await translateBatch(session: session)
        }
    }

    private func translateBatch(session: TranslationSession) async {
        let requests = items.enumerated().map { index, text in
            TranslationSession.Request(
                sourceText: text,
                clientIdentifier: "\(index)"
            )
        }

        do {
            let responses = try await session.translations(from: requests)
            await MainActor.run {
                translatedItems = responses.map { $0.targetText }
            }
        } catch {
            print("Batch translation failed: \(error)")
        }
    }
}
```

### Method 2: translate(batch:) - Streaming Results

Returns translations as AsyncSequence, providing results as they complete:

```swift
struct BatchTranslationStreaming: View {
    @State private var items = [
        "Das ist ein langer Text",
        "Ein weiterer Satz",
        "Noch ein Beispiel",
        "Der letzte Satz"
    ]
    @State private var translations: [String: String] = [:]
    @State private var configuration: TranslationSession.Configuration?

    var body: some View {
        List {
            ForEach(items, id: \.self) { item in
                VStack(alignment: .leading) {
                    Text(item)
                    if let translated = translations[item] {
                        Text(translated)
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView()
                    }
                }
            }
        }
        .toolbar {
            Button("Translate") {
                translations = [:]
                configuration = TranslationSession.Configuration(
                    source: Locale.Language(identifier: "de"),
                    target: Locale.Language(identifier: "en")
                )
            }
        }
        .translationTask(configuration) { session in
            await translateStreaming(session: session)
        }
    }

    private func translateStreaming(session: TranslationSession) async {
        let requests = items.map { text in
            TranslationSession.Request(
                sourceText: text,
                clientIdentifier: text  // Use source text as identifier
            )
        }

        do {
            for try await response in session.translate(batch: requests) {
                if let identifier = response.clientIdentifier {
                    await MainActor.run {
                        translations[identifier] = response.targetText
                    }
                }
            }
        } catch {
            print("Streaming translation failed: \(error)")
        }
    }
}
```

### Batch Translation with Data Models

```swift
struct Article: Identifiable {
    let id = UUID()
    let title: String
    let content: String
    var translatedTitle: String?
    var translatedContent: String?
}

@Observable
class ArticleTranslationViewModel {
    var articles: [Article] = []
    var isTranslating = false

    func translateArticles(session: TranslationSession) async {
        await MainActor.run { isTranslating = true }

        // Create requests for titles
        let titleRequests = articles.map { article in
            TranslationSession.Request(
                sourceText: article.title,
                clientIdentifier: "title-\(article.id)"
            )
        }

        // Create requests for content
        let contentRequests = articles.map { article in
            TranslationSession.Request(
                sourceText: article.content,
                clientIdentifier: "content-\(article.id)"
            )
        }

        let allRequests = titleRequests + contentRequests

        do {
            let responses = try await session.translations(from: allRequests)

            await MainActor.run {
                for response in responses {
                    guard let identifier = response.clientIdentifier else { continue }

                    let components = identifier.split(separator: "-")
                    guard components.count == 2,
                          let uuid = UUID(uuidString: String(components[1])) else { continue }

                    if let index = articles.firstIndex(where: { $0.id == uuid }) {
                        if components[0] == "title" {
                            articles[index].translatedTitle = response.targetText
                        } else if components[0] == "content" {
                            articles[index].translatedContent = response.targetText
                        }
                    }
                }
                isTranslating = false
            }
        } catch {
            await MainActor.run { isTranslating = false }
            print("Article translation failed: \(error)")
        }
    }
}
```

---

## Language Availability and Downloading

### Checking Supported Languages

```swift
struct LanguageListView: View {
    @State private var supportedLanguages: [Locale.Language] = []
    private let availability = LanguageAvailability()

    var body: some View {
        List(supportedLanguages, id: \.self) { language in
            HStack {
                Text(language.localizedName())
                Spacer()
                Text(language.languageCode?.identifier ?? "")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Supported Languages")
        .task {
            supportedLanguages = await availability.supportedLanguages
        }
    }
}

extension Locale.Language {
    func localizedName() -> String {
        let identifier = self.languageCode?.identifier ?? ""
        return Locale.current.localizedString(forLanguageCode: identifier) ?? identifier
    }
}
```

### Checking Language Pair Status

```swift
struct LanguageStatusChecker: View {
    @State private var status: LanguageAvailability.Status?
    @State private var sourceLanguage = Locale.Language(identifier: "es")
    @State private var targetLanguage = Locale.Language(identifier: "en")

    private let availability = LanguageAvailability()

    var body: some View {
        VStack(spacing: 20) {
            if let status {
                statusView(for: status)
            }

            Button("Check Availability") {
                Task {
                    status = await availability.status(
                        from: sourceLanguage,
                        to: targetLanguage
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func statusView(for status: LanguageAvailability.Status) -> some View {
        switch status {
        case .installed:
            Label("Ready to translate", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .supported:
            Label("Download required", systemImage: "arrow.down.circle")
                .foregroundStyle(.orange)
        case .unsupported:
            Label("Not supported", systemImage: "xmark.circle")
                .foregroundStyle(.red)
        @unknown default:
            Label("Unknown status", systemImage: "questionmark.circle")
        }
    }
}
```

### Proactive Language Download

Use `prepareTranslation()` to prompt users to download languages before translation:

```swift
struct ProactiveDownloadView: View {
    @State private var configuration: TranslationSession.Configuration?
    @State private var isReady = false

    var body: some View {
        VStack(spacing: 20) {
            if isReady {
                Text("Languages ready for offline use!")
                    .foregroundStyle(.green)
            } else {
                Text("Tap to download languages for offline translation")
            }

            Button("Prepare Languages") {
                configuration = TranslationSession.Configuration(
                    source: Locale.Language(identifier: "ja"),
                    target: Locale.Language(identifier: "en")
                )
            }
            .disabled(isReady)
        }
        .translationTask(configuration) { session in
            do {
                // This will prompt user to download if needed
                try await session.prepareTranslation()
                await MainActor.run { isReady = true }
            } catch {
                print("Preparation failed: \(error)")
            }
        }
    }
}
```

### Building a Language Selector

```swift
struct LanguageSelectorView: View {
    @Binding var selectedLanguage: Locale.Language?
    @State private var languages: [Locale.Language] = []
    @State private var languageStatuses: [Locale.Language: LanguageAvailability.Status] = [:]

    private let availability = LanguageAvailability()
    private let targetLanguage = Locale.Language(identifier: "en")

    var body: some View {
        List(languages, id: \.self) { language in
            Button {
                selectedLanguage = language
            } label: {
                HStack {
                    Text(language.localizedName())
                    Spacer()

                    if let status = languageStatuses[language] {
                        statusIcon(for: status)
                    }

                    if selectedLanguage == language {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .foregroundStyle(.primary)
        }
        .task {
            await loadLanguages()
        }
    }

    @ViewBuilder
    private func statusIcon(for status: LanguageAvailability.Status) -> some View {
        switch status {
        case .installed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .supported:
            Image(systemName: "arrow.down.circle")
                .foregroundStyle(.orange)
        case .unsupported:
            Image(systemName: "xmark.circle")
                .foregroundStyle(.red)
        @unknown default:
            EmptyView()
        }
    }

    private func loadLanguages() async {
        languages = await availability.supportedLanguages

        // Check status for each language
        for language in languages {
            let status = await availability.status(
                from: language,
                to: targetLanguage
            )
            await MainActor.run {
                languageStatuses[language] = status
            }
        }
    }
}
```

---

## Overlay vs Inline Translation

### Overlay Translation (System UI)

**When to Use:**
- Single text translations
- User-initiated translations
- When you want consistent system appearance
- Simple translation needs without custom UI

**Implementation:**

```swift
struct OverlayTranslationExample: View {
    @State private var showTranslation = false
    let text = "Bonjour, comment allez-vous?"

    var body: some View {
        VStack {
            Text(text)
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                showTranslation = true
            } label: {
                Label("Translate", systemImage: "translate")
            }
        }
        .translationPresentation(
            isPresented: $showTranslation,
            text: text,
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .bottom
        )
    }
}
```

### Inline Translation (Custom UI)

**When to Use:**
- Batch translations
- Background translations
- Custom translation UI
- Real-time translation features
- Integration with existing UI components

**Implementation:**

```swift
struct InlineTranslationExample: View {
    @State private var messages: [Message] = []
    @State private var configuration: TranslationSession.Configuration?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(messages) { message in
                    MessageBubble(message: message)
                }
            }
            .padding()
        }
        .toolbar {
            Button("Translate All") {
                configuration = TranslationSession.Configuration(
                    source: nil,
                    target: Locale.current.language
                )
            }
        }
        .translationTask(configuration) { session in
            await translateAllMessages(session: session)
        }
    }

    private func translateAllMessages(session: TranslationSession) async {
        let requests = messages.map { message in
            TranslationSession.Request(
                sourceText: message.text,
                clientIdentifier: message.id.uuidString
            )
        }

        do {
            let responses = try await session.translations(from: requests)

            await MainActor.run {
                for response in responses {
                    if let id = response.clientIdentifier,
                       let uuid = UUID(uuidString: id),
                       let index = messages.firstIndex(where: { $0.id == uuid }) {
                        messages[index].translatedText = response.targetText
                    }
                }
            }
        } catch {
            print("Translation failed: \(error)")
        }
    }
}

struct Message: Identifiable {
    let id = UUID()
    let text: String
    var translatedText: String?
}

struct MessageBubble: View {
    let message: Message

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.text)

            if let translated = message.translatedText {
                Text(translated)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

---

## iOS 18/26 Specific Features

### iOS 18 Features

iOS 18 introduced the full Translation API with:

- **TranslationSession** class for programmatic translation
- **Batch translation** methods
- **.translationTask** view modifier
- **LanguageAvailability** API
- **prepareTranslation()** for proactive downloads

### iOS 26 Features

iOS 26 expands translation capabilities with:

#### Live Translation Integration

Live Translation is integrated into system apps and available via API:

```swift
// Live Translation is available in Messages, FaceTime, and Phone
// Developers can link to live translation through an API
```

#### Enhanced Multilingual Support

- **Language Discovery**: Surfaces users' preferred languages at the top of selection lists
- **Enhanced bidirectional text handling**: Better RTL language support
- **Expanded calendar support**: More locale-aware formatting

#### Foundation Models Framework

On-device LLM capabilities for text processing:

```swift
// Use Foundation Models for advanced text processing
// Combined with Translation for comprehensive language features
```

### Version-Specific Implementation

```swift
struct VersionAwareTranslation: View {
    @State private var showTranslation = false
    let text = "Hello, World!"

    var body: some View {
        VStack {
            Text(text)

            if #available(iOS 18, *) {
                // Use full Translation API
                advancedTranslationButton
            } else if #available(iOS 17.4, *) {
                // Use basic translation presentation
                basicTranslationButton
            } else {
                Text("Translation not available")
                    .foregroundStyle(.secondary)
            }
        }
        .translationPresentation(isPresented: $showTranslation, text: text)
    }

    @available(iOS 18, *)
    private var advancedTranslationButton: some View {
        Button("Translate") {
            showTranslation = true
        }
    }

    @available(iOS 17.4, *)
    private var basicTranslationButton: some View {
        Button("Translate") {
            showTranslation = true
        }
    }
}
```

---

## Common Use Cases

### 1. Chat Message Translation

```swift
@Observable
class ChatTranslationManager {
    var isAutoTranslateEnabled = false
    private var configuration: TranslationSession.Configuration?

    func translateMessage(_ message: String) async throws -> String {
        // Implementation requires TranslationSession from view
        fatalError("Must be called within translationTask context")
    }
}

struct ChatView: View {
    @State private var messages: [ChatMessage] = []
    @State private var configuration: TranslationSession.Configuration?
    @State private var messageToTranslate: ChatMessage?

    var body: some View {
        List(messages) { message in
            ChatMessageRow(message: message) {
                messageToTranslate = message
                configuration = TranslationSession.Configuration(
                    source: nil,
                    target: Locale.current.language
                )
            }
        }
        .translationTask(configuration) { session in
            guard let message = messageToTranslate else { return }

            do {
                let response = try await session.translate(message.text)
                await MainActor.run {
                    if let index = messages.firstIndex(where: { $0.id == message.id }) {
                        messages[index].translatedText = response.targetText
                    }
                }
            } catch {
                print("Translation failed: \(error)")
            }
        }
    }
}
```

### 2. Product Description Translation (E-commerce)

```swift
struct ProductDetailView: View {
    let product: Product
    @State private var translatedDescription: String?
    @State private var configuration: TranslationSession.Configuration?
    @State private var showLanguagePicker = false
    @State private var targetLanguage: Locale.Language?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Product image and title

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Description")
                            .font(.headline)
                        Spacer()
                        Button {
                            showLanguagePicker = true
                        } label: {
                            Label("Translate", systemImage: "translate")
                        }
                    }

                    Text(translatedDescription ?? product.description)
                        .foregroundStyle(translatedDescription != nil ? .secondary : .primary)
                }
            }
            .padding()
        }
        .sheet(isPresented: $showLanguagePicker) {
            LanguageSelectorView(selectedLanguage: $targetLanguage)
                .onChange(of: targetLanguage) { _, newLanguage in
                    if let language = newLanguage {
                        showLanguagePicker = false
                        configuration = TranslationSession.Configuration(
                            source: nil,
                            target: language
                        )
                    }
                }
        }
        .translationTask(configuration) { session in
            do {
                let response = try await session.translate(product.description)
                await MainActor.run {
                    translatedDescription = response.targetText
                }
            } catch {
                print("Translation failed: \(error)")
            }
        }
    }
}
```

### 3. Document Translation

```swift
struct DocumentTranslationView: View {
    @State private var paragraphs: [Paragraph] = []
    @State private var configuration: TranslationSession.Configuration?
    @State private var translationProgress: Double = 0

    var body: some View {
        VStack {
            ProgressView(value: translationProgress)
                .padding()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(paragraphs) { paragraph in
                        ParagraphView(paragraph: paragraph)
                    }
                }
                .padding()
            }
        }
        .toolbar {
            Button("Translate Document") {
                configuration = TranslationSession.Configuration(
                    source: nil,
                    target: Locale.Language(identifier: "en")
                )
            }
        }
        .translationTask(configuration) { session in
            await translateDocument(session: session)
        }
    }

    private func translateDocument(session: TranslationSession) async {
        let requests = paragraphs.enumerated().map { index, paragraph in
            TranslationSession.Request(
                sourceText: paragraph.text,
                clientIdentifier: "\(index)"
            )
        }

        do {
            var completedCount = 0

            for try await response in session.translate(batch: requests) {
                if let indexString = response.clientIdentifier,
                   let index = Int(indexString) {
                    await MainActor.run {
                        paragraphs[index].translatedText = response.targetText
                        completedCount += 1
                        translationProgress = Double(completedCount) / Double(paragraphs.count)
                    }
                }
            }
        } catch {
            print("Document translation failed: \(error)")
        }
    }
}

struct Paragraph: Identifiable {
    let id = UUID()
    let text: String
    var translatedText: String?
}
```

### 4. Offline-First Translation

```swift
struct OfflineTranslationView: View {
    @State private var sourceLanguage = Locale.Language(identifier: "es")
    @State private var targetLanguage = Locale.Language(identifier: "en")
    @State private var isReady = false
    @State private var configuration: TranslationSession.Configuration?
    @State private var sourceText = ""
    @State private var translatedText: String?

    private let availability = LanguageAvailability()

    var body: some View {
        VStack(spacing: 20) {
            // Status indicator
            HStack {
                Circle()
                    .fill(isReady ? .green : .orange)
                    .frame(width: 12, height: 12)
                Text(isReady ? "Ready for offline use" : "Requires download")
            }

            // Prepare languages button
            if !isReady {
                Button("Download Languages") {
                    prepareLanguages()
                }
            }

            // Translation UI
            TextField("Enter text", text: $sourceText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .disabled(!isReady)

            if let translated = translatedText {
                Text(translated)
                    .foregroundStyle(.secondary)
            }

            Button("Translate") {
                translate()
            }
            .disabled(!isReady || sourceText.isEmpty)
        }
        .padding()
        .task {
            await checkAvailability()
        }
        .translationTask(configuration) { session in
            if !isReady {
                // Prepare for download
                do {
                    try await session.prepareTranslation()
                    await MainActor.run { isReady = true }
                } catch {
                    print("Preparation failed: \(error)")
                }
            } else {
                // Perform translation
                do {
                    let response = try await session.translate(sourceText)
                    await MainActor.run {
                        translatedText = response.targetText
                    }
                } catch {
                    print("Translation failed: \(error)")
                }
            }
        }
    }

    private func checkAvailability() async {
        let status = await availability.status(
            from: sourceLanguage,
            to: targetLanguage
        )
        await MainActor.run {
            isReady = status == .installed
        }
    }

    private func prepareLanguages() {
        configuration = TranslationSession.Configuration(
            source: sourceLanguage,
            target: targetLanguage
        )
    }

    private func translate() {
        if configuration == nil {
            configuration = TranslationSession.Configuration(
                source: sourceLanguage,
                target: targetLanguage
            )
        } else {
            configuration?.invalidate()
        }
    }
}
```

---

## Best Practices

### 1. Session Lifetime Management

```swift
// CORRECT: Keep session tied to view lifetime
struct CorrectSessionUsage: View {
    @State private var configuration: TranslationSession.Configuration?

    var body: some View {
        ContentView()
            .translationTask(configuration) { session in
                // Use session here - it's tied to this view
            }
    }
}

// INCORRECT: Don't store session outside view
class IncorrectUsage {
    var storedSession: TranslationSession? // DON'T DO THIS
}
```

### 2. Modifier Placement

```swift
// CORRECT: Attach to content container
struct CorrectPlacement: View {
    @State private var showTranslation = false
    let text = "Hello"

    var body: some View {
        VStack {
            Text(text)
            Button("Translate") {
                showTranslation = true
            }
        }
        .translationPresentation(isPresented: $showTranslation, text: text)
    }
}

// INCORRECT: Attached to button (popover blocks content on iPad/Mac)
struct IncorrectPlacement: View {
    @State private var showTranslation = false
    let text = "Hello"

    var body: some View {
        Button("Translate") {
            showTranslation = true
        }
        .translationPresentation(isPresented: $showTranslation, text: text) // DON'T
    }
}
```

### 3. Language Batching

```swift
// CORRECT: Separate batches by language
func translateMultiLanguageContent(
    germanTexts: [String],
    spanishTexts: [String],
    session: TranslationSession
) async throws -> ([String], [String]) {

    let germanRequests = germanTexts.enumerated().map { index, text in
        TranslationSession.Request(sourceText: text, clientIdentifier: "de-\(index)")
    }

    let spanishRequests = spanishTexts.enumerated().map { index, text in
        TranslationSession.Request(sourceText: text, clientIdentifier: "es-\(index)")
    }

    // Translate each batch separately
    async let germanResponses = session.translations(from: germanRequests)
    async let spanishResponses = session.translations(from: spanishRequests)

    let (german, spanish) = try await (germanResponses, spanishResponses)

    return (german.map { $0.targetText }, spanish.map { $0.targetText })
}

// INCORRECT: Mixing languages in same batch
func incorrectMixedBatch(mixedTexts: [String], session: TranslationSession) async throws {
    let requests = mixedTexts.map { TranslationSession.Request(sourceText: $0) }
    // DON'T: This produces poor results with mixed languages
    _ = try await session.translations(from: requests)
}
```

### 4. Error Handling

```swift
struct RobustTranslationView: View {
    @State private var configuration: TranslationSession.Configuration?
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        ContentView()
            .translationTask(configuration) { session in
                do {
                    try await performTranslation(session: session)
                } catch {
                    await handleError(error)
                }
            }
            .alert("Translation Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "Unknown error occurred")
            }
    }

    private func handleError(_ error: Error) async {
        await MainActor.run {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
```

### 5. Use Supported Languages Only

```swift
struct SafeLanguageSelection: View {
    @State private var selectedSource: Locale.Language?
    @State private var selectedTarget: Locale.Language?
    @State private var supportedLanguages: [Locale.Language] = []

    private let availability = LanguageAvailability()

    var body: some View {
        Form {
            Picker("Source", selection: $selectedSource) {
                ForEach(supportedLanguages, id: \.self) { language in
                    Text(language.localizedName())
                        .tag(language as Locale.Language?)
                }
            }

            Picker("Target", selection: $selectedTarget) {
                ForEach(supportedLanguages, id: \.self) { language in
                    Text(language.localizedName())
                        .tag(language as Locale.Language?)
                }
            }
        }
        .task {
            // Only use languages from supportedLanguages
            supportedLanguages = await availability.supportedLanguages
        }
    }
}
```

### 6. Testing on Physical Devices

```swift
#if DEBUG
struct TranslationDebugView: View {
    var body: some View {
        #if targetEnvironment(simulator)
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("Translation APIs require a physical device")
                .multilineTextAlignment(.center)
        }
        .padding()
        #else
        ActualTranslationView()
        #endif
    }
}
#endif
```

### 7. Performance Considerations

```swift
struct PerformantTranslation: View {
    @State private var configuration: TranslationSession.Configuration?
    @State private var pendingTexts: [String] = []
    @State private var translations: [String: String] = [:]

    // Debounce translation requests
    private let debounceTask = Task<Void, Never>?.none

    var body: some View {
        // View content
        EmptyView()
            .translationTask(configuration) { session in
                // Batch similar requests together
                if pendingTexts.count > 1 {
                    await batchTranslate(texts: pendingTexts, session: session)
                } else if let text = pendingTexts.first {
                    await singleTranslate(text: text, session: session)
                }
            }
    }

    private func batchTranslate(texts: [String], session: TranslationSession) async {
        let requests = texts.map { TranslationSession.Request(sourceText: $0, clientIdentifier: $0) }

        do {
            // Use streaming for large batches to show progress
            if texts.count > 10 {
                for try await response in session.translate(batch: requests) {
                    if let id = response.clientIdentifier {
                        await MainActor.run {
                            translations[id] = response.targetText
                        }
                    }
                }
            } else {
                // Use all-at-once for small batches
                let responses = try await session.translations(from: requests)
                await MainActor.run {
                    for response in responses {
                        if let id = response.clientIdentifier {
                            translations[id] = response.targetText
                        }
                    }
                }
            }
        } catch {
            print("Batch translation failed: \(error)")
        }
    }

    private func singleTranslate(text: String, session: TranslationSession) async {
        do {
            let response = try await session.translate(text)
            await MainActor.run {
                translations[text] = response.targetText
            }
        } catch {
            print("Single translation failed: \(error)")
        }
    }
}
```

---

## Summary

The Translation framework provides a powerful, privacy-focused solution for adding translation capabilities to iOS apps. Key takeaways:

1. **Choose the right approach**: Use `.translationPresentation` for simple overlay translations, `.translationTask` for programmatic control
2. **Batch efficiently**: Group translations by language and use appropriate batch methods
3. **Prepare for offline**: Use `prepareTranslation()` to download languages proactively
4. **Handle errors gracefully**: Implement proper error handling for network and availability issues
5. **Test on devices**: Always test on physical devices as APIs don't work in the Simulator
6. **Respect session lifetime**: Keep TranslationSession tied to view lifecycle

---

## References

- [Meet the Translation API - WWDC24](https://developer.apple.com/videos/play/wwdc2024/10117/)
- [Translation Framework Documentation](https://developer.apple.com/documentation/translation/)
- [TranslationSession Documentation](https://developer.apple.com/documentation/translation/translationsession)
- [LanguageAvailability Documentation](https://developer.apple.com/documentation/translation/languageavailability)

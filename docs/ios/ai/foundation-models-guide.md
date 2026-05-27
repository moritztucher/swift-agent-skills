# Foundation Models Framework Guide

A comprehensive guide for using Apple's Foundation Models framework to integrate on-device AI into iOS 26+, iPadOS 26+, macOS 26+, and visionOS 26+ applications.

---

## Table of Contents

1. [Overview](#overview)
2. [Getting Started](#getting-started)
3. [Basic Text Generation](#basic-text-generation)
4. [Guided Generation](#guided-generation)
5. [The @Generable Macro](#the-generable-macro)
6. [The @Guide Macro](#the-guide-macro)
7. [Tool Calling](#tool-calling)
8. [Streaming Responses](#streaming-responses)
9. [Session Management](#session-management)
10. [Instructions](#instructions)
11. [Error Handling](#error-handling)
12. [Guardrails and Safety](#guardrails-and-safety)
13. [SwiftUI Integration](#swiftui-integration)
14. [Best Practices](#best-practices)

---

## Overview

The Foundation Models framework provides access to Apple's on-device large language model that powers Apple Intelligence. Key benefits:

- **Privacy**: All processing happens on-device; data never leaves the device
- **Offline**: Works without internet connection
- **Zero App Size Impact**: Model is built into the OS
- **Native Swift API**: Designed for Swift with macros and async/await

### Requirements

- iOS 26.0+, iPadOS 26.0+, macOS 26.0+, visionOS 26.0+
- Apple Intelligence-compatible device (A17 Pro+ / M1+)
- Apple Intelligence enabled on device
- **No entitlement required** for basic usage
- Only `com.apple.developer.foundation-model-adapter` entitlement is needed for **custom adapters**
- **Simulator**: Not supported — Foundation Models requires a physical device. Sandbox errors in the simulator console are expected.

### Import

```swift
import FoundationModels
```

---

## Getting Started

### Minimal Example (3 Lines)

```swift
import FoundationModels

let session = LanguageModelSession()
let response = try await session.respond(to: "Tell me a fun fact about cats")
print(response.content)
```

### Check Availability

The `availability` property is an enum, not a boolean:

```swift
let model = SystemLanguageModel.default

switch model.availability {
case .available:
    // Use Foundation Models
case .unavailable(.appleIntelligenceNotEnabled):
    // Apple Intelligence is not turned on
case .unavailable(.modelNotReady):
    // Model assets not yet downloaded — try again later
}
```

---

## Basic Text Generation

### Simple Text Response

```swift
let session = LanguageModelSession()

let response = try await session.respond(to: "Write a haiku about Swift programming")
print(response.content)  // The generated text
```

### With Generation Options

```swift
let options = GenerationOptions(
    temperature: 0.7,  // Controls randomness (0.0 = deterministic, 1.0 = creative)
    topK: 50           // Limits token selection to top K options
)

let response = try await session.respond(
    to: "Write a creative story opening",
    options: options
)
```

### Using PromptBuilder

```swift
let session = LanguageModelSession()

let response = try await session.respond {
    "You are a helpful assistant."
    "The user wants to know about: Swift programming"
    "Provide a brief, informative response."
}
```

---

## Guided Generation

Guided generation ensures the model outputs structured Swift data types instead of free-form text.

### Basic Structured Output

```swift
@Generable
struct MovieRecommendation {
    var title: String
    var year: Int
    var reason: String
}

let session = LanguageModelSession()
let response = try await session.respond(
    to: "Recommend a sci-fi movie from the 1980s",
    generating: MovieRecommendation.self
)

print(response.content.title)   // "Blade Runner"
print(response.content.year)    // 1982
print(response.content.reason)  // "A masterpiece of..."
```

### Arrays of Structured Data

```swift
@Generable
struct Task {
    var id: GenerationID  // Use GenerationID for unique identifiers
    var title: String
    var priority: Int
}

@Generable
struct TaskList {
    @Guide(.count(5))  // Generate exactly 5 tasks
    var tasks: [Task]
}

let response = try await session.respond(
    to: "Generate a to-do list for learning Swift",
    generating: TaskList.self
)
```

---

## The @Generable Macro

The `@Generable` macro conforms types to the `Generable` protocol, enabling guided generation.

### Structs

```swift
@Generable(description: "A recipe with ingredients and steps")
struct Recipe {
    var name: String
    var servings: Int
    var ingredients: [String]
    var steps: [String]
}
```

### Enums

```swift
@Generable
enum Difficulty {
    case easy
    case medium
    case hard
}

@Generable
struct Challenge {
    var title: String
    var difficulty: Difficulty  // Model picks from enum cases
}
```

### Nested Types

```swift
@Generable
struct Itinerary {
    var title: String
    var days: [DayPlan]

    @Generable
    struct DayPlan {
        var dayNumber: Int
        var activities: [Activity]
    }

    @Generable
    struct Activity {
        var name: String
        var duration: String
        var type: ActivityType
    }

    @Generable
    enum ActivityType {
        case sightseeing
        case dining
        case shopping
        case relaxation
    }
}
```

### Supported Property Types

| Type | Notes |
|------|-------|
| `String` | Text content |
| `Int` | Integer numbers |
| `Double` | Decimal numbers |
| `Bool` | Boolean values |
| `[T]` | Arrays of Generable types |
| `T?` | Optional Generable types |
| `GenerationID` | Unique identifier for generated items |
| Enums | Must also be `@Generable` |
| Nested structs | Must also be `@Generable` |

---

## The @Guide Macro

The `@Guide` macro provides hints and constraints to guide generation.

### Description

```swift
@Generable
struct Profile {
    @Guide(description: "A creative username, 3-15 characters")
    var username: String

    @Guide(description: "A brief bio in one sentence")
    var bio: String
}
```

### Range Constraint

```swift
@Generable
struct Character {
    var name: String

    @Guide(description: "Character age", .range(18...100))
    var age: Int

    @Guide(description: "Health points", .range(0.0...100.0))
    var health: Double
}
```

### Count Constraint (Arrays)

```swift
@Generable
struct Quiz {
    @Guide(description: "Quiz questions", .count(10))
    var questions: [Question]
}

// Range of counts
@Generable
struct Playlist {
    @Guide(.count(5...10))  // 5 to 10 songs
    var songs: [Song]
}
```

### Enum/AnyOf Constraint

```swift
@Generable
struct Destination {
    @Guide(.anyOf(["Paris", "Tokyo", "New York", "London"]))
    var city: String
}

// From static data
@Generable
struct Trip {
    @Guide(.anyOf(ModelData.availableDestinations))
    var destination: String
}
```

### Combining Constraints

```swift
@Generable
struct SearchResult {
    @Guide(description: "Search suggestions for the user", .count(4))
    var suggestions: [Suggestion]

    @Generable
    struct Suggestion {
        var id: GenerationID

        @Guide(description: "A 2-3 word search term")
        var term: String

        @Guide(description: "Relevance score", .range(0.0...1.0))
        var relevance: Double
    }
}
```

---

## Tool Calling

Tools extend the model's capabilities by allowing it to call your code.

### Defining a Tool

```swift
struct WeatherTool: Tool {
    let name = "getWeather"
    let description = "Gets the current weather for a location"

    @Generable
    struct Arguments {
        @Guide(description: "The city name")
        var city: String

        @Guide(description: "Temperature unit", .anyOf(["celsius", "fahrenheit"]))
        var unit: String
    }

    func call(arguments: Arguments) async throws -> String {
        // Fetch actual weather data
        let weather = await WeatherService.fetch(city: arguments.city)
        return "The weather in \(arguments.city) is \(weather.temperature)° \(arguments.unit)"
    }
}
```

### Using Tools in a Session

```swift
let session = LanguageModelSession(
    tools: [WeatherTool()]
)

let response = try await session.respond(
    to: "What's the weather like in Tokyo?"
)
// Model automatically calls WeatherTool and incorporates result
```

### Multiple Tools

```swift
let session = LanguageModelSession(
    tools: [
        WeatherTool(),
        CalendarTool(),
        ContactsTool()
    ]
)

let response = try await session.respond(
    to: "Schedule a meeting with John tomorrow if the weather is nice"
)
// Model can call multiple tools as needed
```

### Tool with Structured Output

```swift
struct RecipeTool: Tool {
    let name = "searchRecipes"
    let description = "Searches for recipes in the database"

    @Generable
    struct Arguments {
        @Guide(description: "Search query")
        var query: String

        @Guide(description: "Maximum results", .range(1...10))
        var limit: Int
    }

    // Return Generable type for structured output
    func call(arguments: Arguments) async throws -> [Recipe] {
        return await RecipeDatabase.search(
            query: arguments.query,
            limit: arguments.limit
        )
    }
}
```

---

## Streaming Responses

Streaming provides partial responses as they're generated.

### Basic Streaming

```swift
let session = LanguageModelSession()

let stream = session.streamResponse(to: "Write a short story")

for try await partialResponse in stream {
    print(partialResponse.content)  // Prints incrementally
}
```

### Streaming Structured Output

```swift
@Generable
struct Story {
    var title: String
    var chapters: [Chapter]

    @Generable
    struct Chapter {
        var title: String
        var content: String
    }
}

let stream = session.streamResponse(
    to: "Write a three-chapter story",
    generating: Story.self
)

for try await partial in stream {
    // Properties become available as generated
    if let title = partial.content.title {
        print("Title: \(title)")
    }
    // Arrays populate incrementally
    for chapter in partial.content.chapters ?? [] {
        print("Chapter: \(chapter.title)")
    }
}
```

### SwiftUI Streaming

```swift
struct ChatView: View {
    @State private var session = LanguageModelSession()
    @State private var response = ""
    @State private var isGenerating = false

    var body: some View {
        VStack {
            Text(response)

            Button("Generate") {
                Task {
                    isGenerating = true
                    response = ""

                    let stream = session.streamResponse(to: "Tell me a joke")

                    for try await partial in stream {
                        response = partial.content
                    }

                    isGenerating = false
                }
            }
            .disabled(isGenerating)
        }
    }
}
```

---

## Session Management

### Session with Instructions

```swift
let session = LanguageModelSession(
    instructions: Instructions {
        "You are a helpful cooking assistant."
        "Provide recipes that are easy to follow."
        "Always include preparation time and serving size."
    }
)
```

### Session with Tools and Instructions

```swift
let session = LanguageModelSession(
    tools: [RecipeTool(), NutritionTool()],
    instructions: Instructions {
        "You are a nutrition-focused cooking assistant."
        "Always check nutritional information when suggesting recipes."
        "Prefer healthy alternatives when possible."
    }
)
```

### Inspecting Session Transcript

```swift
// Access conversation history
for entry in session.transcript {
    switch entry {
    case .instructions(let instructions):
        print("Instructions: \(instructions)")
    case .prompt(let prompt):
        print("User: \(prompt)")
    case .response(let response):
        print("Assistant: \(response)")
    case .toolCall(let call):
        print("Tool called: \(call.toolName)")
    case .toolOutput(let output):
        print("Tool output: \(output)")
    }
}
```

### Multi-Turn Conversations

```swift
let session = LanguageModelSession()

// First turn
let response1 = try await session.respond(to: "My name is Alex")

// Second turn - session remembers context
let response2 = try await session.respond(to: "What's my name?")
// Response will reference "Alex"
```

### Context Window Management

```swift
@Observable
class ChatViewModel {
    private(set) var session: LanguageModelSession
    private let maxTokens = 4096

    init() {
        session = LanguageModelSession()
    }

    func sendMessage(_ content: String) async throws {
        do {
            let response = try await session.respond(to: content)
            // Handle response
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            // Create new session with summary
            await resetSessionWithSummary()
            // Retry
            let response = try await session.respond(to: content)
        }
    }

    private func resetSessionWithSummary() async {
        // Summarize conversation
        let summarySession = LanguageModelSession()
        let summary = try? await summarySession.respond(
            to: "Summarize this conversation: \(conversationText)"
        )

        // Create new session with context
        session = LanguageModelSession(
            instructions: Instructions {
                "Previous conversation summary: \(summary?.content ?? "")"
                "Continue the conversation naturally."
            }
        )
    }
}
```

---

## Instructions

Instructions guide the model's behavior throughout the session.

### Basic Instructions

```swift
let session = LanguageModelSession(
    instructions: Instructions("You are a helpful assistant that speaks like a pirate.")
)
```

### Using InstructionsBuilder

```swift
let session = LanguageModelSession(
    instructions: Instructions {
        "You are an expert travel planner."

        "Guidelines:"
        "- Suggest activities based on user preferences"
        "- Consider weather and season"
        "- Include budget-friendly options"

        "Available destinations:"
        availableDestinations.joined(separator: ", ")
    }
)
```

### Dynamic Instructions

```swift
func createSession(for user: User) -> LanguageModelSession {
    LanguageModelSession(
        instructions: Instructions {
            "You are a personal assistant for \(user.name)."

            if user.preferences.formal {
                "Use formal language."
            } else {
                "Use casual, friendly language."
            }

            "User interests: \(user.interests.joined(separator: ", "))"
        }
    )
}
```

---

## Error Handling

### Error Types

```swift
do {
    let response = try await session.respond(to: prompt)
} catch LanguageModelSession.GenerationError.guardrailViolation {
    // Content violates safety guidelines
    print("Request contains inappropriate content")

} catch LanguageModelSession.GenerationError.exceededContextWindowSize {
    // Conversation too long
    print("Context window exceeded - start new session")

} catch LanguageModelSession.GenerationError.rateLimited(let retryAfter) {
    // Too many requests
    print("Rate limited. Retry after: \(retryAfter)")

} catch LanguageModelSession.GenerationError.refusal(let reason, let message) {
    // Model refused to generate
    print("Refused: \(message)")

} catch LanguageModelSession.GenerationError.assetsUnavailable {
    // Model assets deleted or Apple Intelligence disabled during use
    print("Model assets unavailable - retry later")

} catch {
    print("Unknown error: \(error)")
}
```

### Comprehensive Error Handler

```swift
enum FoundationModelsError: LocalizedError {
    case guardrailViolation
    case contextExceeded
    case rateLimited(TimeInterval)
    case refused(String)
    case unavailable
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .guardrailViolation:
            return "This request cannot be processed due to content guidelines."
        case .contextExceeded:
            return "The conversation is too long. Please start a new chat."
        case .rateLimited(let seconds):
            return "Please wait \(Int(seconds)) seconds before trying again."
        case .refused(let message):
            return message
        case .unavailable:
            return "AI features are not available on this device."
        case .unknown(let error):
            return error.localizedDescription
        }
    }

    static func from(_ error: Error) -> FoundationModelsError {
        if let genError = error as? LanguageModelSession.GenerationError {
            switch genError {
            case .guardrailViolation:
                return .guardrailViolation
            case .exceededContextWindowSize:
                return .contextExceeded
            case .rateLimited(let retry):
                return .rateLimited(retry)
            case .refusal(_, let message):
                return .refused(message)
            default:
                return .unknown(error)
            }
        }
        return .unknown(error)
    }
}
```

---

## Guardrails and Safety

### Default Guardrails

By default, the model blocks unsafe content:

```swift
let session = LanguageModelSession()

do {
    let response = try await session.respond(to: harmfulPrompt)
} catch LanguageModelSession.GenerationError.guardrailViolation {
    // Prompt or potential response was blocked
}
```

### Permissive Mode (Content Transformation)

For apps that need to process potentially sensitive source material:

```swift
// Only for text summarization/transformation of user-provided content
let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
let session = LanguageModelSession(model: model)

// Can now summarize articles that might contain sensitive topics
let response = try await session.respond(
    to: "Summarize this article: \(articleWithSensitiveContent)"
)
```

**Important notes about permissive mode:**
- Only works for string generation (not guided generation)
- On-device safety layers still exist
- Model may still refuse some content
- Use responsibly and consider your audience

---

## SwiftUI Integration

### Basic Chat View

```swift
import SwiftUI
import FoundationModels

struct ChatView: View {
    @State private var session = LanguageModelSession()
    @State private var inputText = ""
    @State private var isLoading = false

    var body: some View {
        VStack {
            // Display transcript
            ScrollView {
                LazyVStack(alignment: .leading) {
                    ForEach(session.transcript) { entry in
                        TranscriptEntryView(entry: entry)
                    }
                }
            }

            // Input
            HStack {
                TextField("Message", text: $inputText)
                    .textFieldStyle(.roundedBorder)

                Button("Send") {
                    Task { await sendMessage() }
                }
                .disabled(inputText.isEmpty || isLoading)
            }
            .padding()
        }
    }

    private func sendMessage() async {
        let message = inputText
        inputText = ""
        isLoading = true

        do {
            try await session.respond(to: message)
        } catch {
            // Handle error
        }

        isLoading = false
    }
}
```

### Observable ViewModel

```swift
import FoundationModels
import Observation

@Observable
class ChatViewModel {
    private(set) var session: LanguageModelSession
    var isLoading = false
    var errorMessage: String?

    init() {
        session = LanguageModelSession(
            instructions: Instructions("You are a helpful assistant.")
        )
    }

    @MainActor
    func send(_ message: String) async {
        isLoading = true
        errorMessage = nil

        do {
            try await session.respond(to: message)
        } catch {
            errorMessage = FoundationModelsError.from(error).localizedDescription
        }

        isLoading = false
    }

    func reset() {
        session = LanguageModelSession(
            instructions: Instructions("You are a helpful assistant.")
        )
    }
}
```

### Streaming in SwiftUI

```swift
struct StreamingChatView: View {
    @State private var session = LanguageModelSession()
    @State private var currentResponse = ""
    @State private var isStreaming = false

    var body: some View {
        VStack {
            ScrollView {
                Text(currentResponse)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button("Generate Story") {
                Task { await streamStory() }
            }
            .disabled(isStreaming)
        }
    }

    private func streamStory() async {
        isStreaming = true
        currentResponse = ""

        let stream = session.streamResponse(
            to: "Write a short adventure story"
        )

        do {
            for try await partial in stream {
                currentResponse = partial.content
            }
        } catch {
            currentResponse = "Error: \(error.localizedDescription)"
        }

        isStreaming = false
    }
}
```

---

## Best Practices

### 1. Reuse Sessions for Conversations

```swift
// GOOD - Single session maintains context
class ChatManager {
    let session = LanguageModelSession()

    func send(_ message: String) async throws -> String {
        let response = try await session.respond(to: message)
        return response.content
    }
}

// BAD - Creating new session loses context
func send(_ message: String) async throws -> String {
    let session = LanguageModelSession()  // Don't do this for each message
    return try await session.respond(to: message).content
}
```

### 2. Use Guided Generation for Structured Data

```swift
// GOOD - Type-safe structured output
@Generable
struct SearchResults {
    var results: [Result]
}

let response = try await session.respond(
    to: query,
    generating: SearchResults.self
)

// BAD - Parsing JSON from text
let response = try await session.respond(to: "Return JSON: \(query)")
let data = response.content.data(using: .utf8)!
let results = try JSONDecoder().decode(SearchResults.self, from: data)
```

### 3. Provide Clear Instructions

```swift
// GOOD - Specific, actionable instructions
let session = LanguageModelSession(
    instructions: Instructions {
        "You are a recipe assistant."
        "When suggesting recipes:"
        "- Include exact measurements"
        "- List ingredients before steps"
        "- Mention prep and cook times"
        "- Suggest substitutions for common allergens"
    }
)

// BAD - Vague instructions
let session = LanguageModelSession(
    instructions: Instructions("Be helpful with cooking.")
)
```

### 4. Handle Errors Gracefully

```swift
func generateContent() async {
    do {
        let response = try await session.respond(to: prompt)
        await updateUI(with: response.content)
    } catch LanguageModelSession.GenerationError.guardrailViolation {
        await showError("This request cannot be processed.")
    } catch LanguageModelSession.GenerationError.rateLimited(let retry) {
        await scheduleRetry(after: retry)
    } catch {
        await showError("Something went wrong. Please try again.")
    }
}
```

### 5. Use Streaming for Long Responses

```swift
// GOOD - User sees progress
let stream = session.streamResponse(to: "Write a detailed guide")
for try await partial in stream {
    updateUI(with: partial.content)
}

// LESS IDEAL - User waits with no feedback
let response = try await session.respond(to: "Write a detailed guide")
updateUI(with: response.content)
```

### 6. Constrain Outputs Appropriately

```swift
// GOOD - Clear constraints prevent unexpected outputs
@Generable
struct Rating {
    @Guide(description: "Rating from 1 to 5 stars", .range(1...5))
    var stars: Int

    @Guide(description: "Brief review in 1-2 sentences")
    var review: String
}

// RISKY - No constraints, unpredictable length/format
@Generable
struct Rating {
    var stars: Int      // Could be any number
    var review: String  // Could be paragraphs long
}
```

---

## Quick Reference

### Key Types

| Type | Purpose |
|------|---------|
| `LanguageModelSession` | Main interface for generation |
| `SystemLanguageModel` | The on-device model |
| `Instructions` | Session-level behavior guidance |
| `Prompt` | Input to the model |
| `GenerationOptions` | Control temperature, topK |
| `Tool` | Protocol for callable tools |

### Macros

| Macro | Purpose |
|-------|---------|
| `@Generable` | Make struct/enum available for guided generation |
| `@Guide` | Provide hints and constraints for properties |

### Guide Constraints

| Constraint | Usage |
|------------|-------|
| `.range(0...100)` | Numeric range |
| `.count(5)` | Exact array count |
| `.count(3...7)` | Array count range |
| `.anyOf(["a", "b"])` | Allowed values |

### Session Methods

```swift
// Non-streaming
try await session.respond(to: "prompt")
try await session.respond(to: "prompt", generating: Type.self)

// Streaming
session.streamResponse(to: "prompt")
session.streamResponse(to: "prompt", generating: Type.self)
```

---

## Resources

- [Foundation Models | Apple Developer Documentation](https://developer.apple.com/documentation/FoundationModels)
- [Meet the Foundation Models framework - WWDC25](https://developer.apple.com/videos/play/wwdc2025/286/)
- [Deep dive into the Foundation Models framework - WWDC25](https://developer.apple.com/videos/play/wwdc2025/301/)
- [Code-along: Bring on-device AI to your app - WWDC25](https://developer.apple.com/videos/play/wwdc2025/259/)
- [Apple Foundation Models Newsroom](https://www.apple.com/newsroom/2025/09/apples-foundation-models-framework-unlocks-new-intelligent-app-experiences/)

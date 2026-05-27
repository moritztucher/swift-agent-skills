# AttributedString Complete Guide for iOS/Swift

A comprehensive guide to Apple's `AttributedString` API introduced in iOS 15, including all attributes, Markdown support, custom attributes, SwiftUI integration, and iOS 26 updates.

## Table of Contents

1. [Overview](#overview)
2. [Creating AttributedStrings](#creating-attributedstrings)
3. [Attribute Scopes](#attribute-scopes)
4. [Foundation Attributes](#foundation-attributes)
5. [SwiftUI Attributes](#swiftui-attributes)
6. [UIKit/AppKit Attributes](#uikitappkit-attributes)
7. [Accessibility Attributes](#accessibility-attributes)
8. [Markdown Support](#markdown-support)
9. [Custom Attributes](#custom-attributes)
10. [AttributeContainer](#attributecontainer)
11. [Working with Runs](#working-with-runs)
12. [Character and Unicode Views](#character-and-unicode-views)
13. [Codable Support](#codable-support)
14. [SwiftUI Text Integration](#swiftui-text-integration)
15. [iOS 26 Rich Text Editing](#ios-26-rich-text-editing)
16. [Converting Between Types](#converting-between-types)
17. [Best Practices](#best-practices)

---

## Overview

`AttributedString` is a Swift-native value type introduced in iOS 15/macOS 12 that provides type-safe attributed text handling. It replaces many use cases of `NSAttributedString` with a more modern, Swift-friendly API.

### Key Differences from NSAttributedString

| Feature | AttributedString | NSAttributedString |
|---------|------------------|-------------------|
| Type | Value type (struct) | Reference type (class) |
| Thread Safety | Safe to pass between threads | Requires careful handling |
| Type Safety | Strongly typed attributes | Dictionary with Any values |
| Codable | Yes | No (requires custom implementation) |
| Markdown | Built-in support | No native support |
| Localization | Full support | Limited |
| Framework | Foundation (iOS 15+) | Foundation (legacy) |

### Basic Example

```swift
import Foundation

// Simple creation
var attributedString = AttributedString("Hello, World!")

// Apply attributes
attributedString.font = .boldSystemFont(ofSize: 24)
attributedString.foregroundColor = .systemBlue
attributedString.underlineStyle = .single
```

---

## Creating AttributedStrings

### From Plain String

```swift
var text = AttributedString("Hello")
```

### From String with Attributes

```swift
var text = AttributedString("Hello", attributes: AttributeContainer()
    .font(.headline)
    .foregroundColor(.blue))
```

### From Markdown

```swift
// Basic markdown
let markdown = try AttributedString(markdown: "**Bold** and *italic*")

// With options
let markdownWithOptions = try AttributedString(
    markdown: "**Bold** and *italic*",
    options: AttributedString.MarkdownParsingOptions(
        interpretedSyntax: .inlineOnlyPreservingWhitespace
    )
)
```

### From Localized String

```swift
// Uses Localizable.strings
let localized = AttributedString(localized: "greeting_key")

// With default value
let localizedWithDefault = AttributedString(
    localized: "greeting_key",
    defaultValue: "Hello!"
)
```

### From NSAttributedString

```swift
let nsAttributedString = NSAttributedString(string: "Hello")
let attributedString = AttributedString(nsAttributedString)
```

### Concatenation

```swift
var hello = AttributedString("Hello ")
hello.foregroundColor = .blue

var world = AttributedString("World")
world.foregroundColor = .red

let combined = hello + world
```

---

## Attribute Scopes

Attributes are organized into scopes based on the framework that defines them:

### AttributeScopes Hierarchy

```
AttributeScopes
├── FoundationAttributes (Foundation)
├── SwiftUIAttributes (SwiftUI)
├── UIKitAttributes (UIKit)
├── AppKitAttributes (AppKit)
└── AccessibilityAttributes (Accessibility)
```

### Accessing Attributes by Scope

```swift
// Foundation scope
text.foundation.link = URL(string: "https://apple.com")

// SwiftUI scope
text.swiftUI.foregroundColor = .blue
text.swiftUI.font = .headline

// UIKit scope
text.uiKit.foregroundColor = UIColor.red

// Accessibility scope
text.accessibility.accessibilitySpeechSpellsOutCharacters = true
```

---

## Foundation Attributes

Foundation provides core text attributes:

### Text Formatting

```swift
var text = AttributedString("Example")

// Link
text.link = URL(string: "https://apple.com")

// Language
text.languageIdentifier = "en-US"

// Morphology (for grammatical agreement)
text.morphology = Morphology()

// Inflection alternative
text.inflectionAlternative = AttributedString("alternatives")

// Presentation Intent (from Markdown)
// Automatically set when parsing Markdown
```

### Presentation Intent Attributes

When parsing Markdown, these attributes are set automatically:

```swift
// InlinePresentationIntent values:
// - .emphasized (italic)
// - .stronglyEmphasized (bold)
// - .code
// - .strikethrough
// - .softBreak
// - .lineBreak
// - .inlineHTML
// - .blockHTML

// Check presentation intent
if let intent = text.inlinePresentationIntent {
    if intent.contains(.stronglyEmphasized) {
        // Bold text
    }
}
```

---

## SwiftUI Attributes

SwiftUI-specific attributes that work directly with SwiftUI's `Text` view:

```swift
import SwiftUI

var text = AttributedString("SwiftUI Text")

// Font
text.font = .headline
text.font = .system(size: 18, weight: .bold)
text.font = .custom("Helvetica", size: 16)

// Colors
text.foregroundColor = .blue
text.backgroundColor = .yellow

// Text Styling
text.underlineStyle = .single
text.underlineColor = .red
text.strikethroughStyle = .single
text.strikethroughColor = .gray

// Text Layout
text.kern = 2.0  // Letter spacing
text.tracking = 1.5  // Character tracking
text.baselineOffset = 5  // Vertical offset

// Link
text.link = URL(string: "https://apple.com")
```

### Line Style Options

```swift
// Underline patterns
text.underlineStyle = Text.LineStyle(pattern: .solid, color: .blue)
text.underlineStyle = Text.LineStyle(pattern: .dash, color: .red)
text.underlineStyle = Text.LineStyle(pattern: .dot, color: .green)
text.underlineStyle = Text.LineStyle(pattern: .dashDot, color: .purple)
text.underlineStyle = Text.LineStyle(pattern: .dashDotDot, color: .orange)

// Same patterns available for strikethrough
text.strikethroughStyle = Text.LineStyle(pattern: .solid, color: .gray)
```

---

## UIKit/AppKit Attributes

For use with UIKit views (UILabel, UITextView, etc.) - requires conversion to NSAttributedString:

### UIKit Attributes

```swift
var text = AttributedString("UIKit Text")

// UIKit-specific colors (UIColor)
text.uiKit.foregroundColor = .systemRed
text.uiKit.backgroundColor = .systemYellow

// UIKit Font
text.uiKit.font = UIFont.boldSystemFont(ofSize: 18)

// Paragraph Style
let paragraphStyle = NSMutableParagraphStyle()
paragraphStyle.alignment = .center
paragraphStyle.lineSpacing = 8
text.uiKit.paragraphStyle = paragraphStyle

// Shadow
let shadow = NSShadow()
shadow.shadowColor = UIColor.gray
shadow.shadowOffset = CGSize(width: 2, height: 2)
shadow.shadowBlurRadius = 4
text.uiKit.shadow = shadow

// Stroke
text.uiKit.strokeColor = .black
text.uiKit.strokeWidth = 2.0

// Text Effects
text.uiKit.textEffect = .letterpressStyle

// Writing Direction
text.uiKit.writingDirection = [.leftToRight]
```

### AppKit Attributes (macOS)

```swift
#if os(macOS)
var text = AttributedString("AppKit Text")

text.appKit.foregroundColor = .textColor
text.appKit.backgroundColor = .textBackgroundColor
text.appKit.font = NSFont.boldSystemFont(ofSize: 18)
#endif
```

---

## Accessibility Attributes

Improve VoiceOver and accessibility experience:

```swift
var text = AttributedString("Password: abc123")

// Spell out characters (useful for codes/passwords)
text.accessibilitySpeechSpellsOutCharacters = true

// Custom pronunciation
text.accessibilitySpeechPhoneticNotation = "ay-bee-see-one-two-three"

// Adjust speech pitch (0.0 to 2.0, default 1.0)
text.accessibilitySpeechPitch = 1.2

// Announce punctuation
text.accessibilitySpeechPunctuation = true

// Set language for speech
text.accessibilitySpeechLanguage = "en-US"

// Heading level (1-6)
text.accessibilityTextHeadingLevel = .h1

// Custom label for VoiceOver
text.accessibilityLabel = "Security code: a b c 1 2 3"
```

### Accessibility Best Practices

```swift
// For code snippets - spell out characters
var codeText = AttributedString("let x = 42")
let codeRange = codeText.range(of: "x")!
codeText[codeRange].accessibilitySpeechSpellsOutCharacters = true

// For foreign language text
var spanishText = AttributedString("Hola")
spanishText.accessibilitySpeechLanguage = "es-ES"
```

---

## Markdown Support

AttributedString has built-in Markdown parsing with extensive options.

### Supported Markdown Syntax

| Syntax | Result |
|--------|--------|
| `**bold**` or `__bold__` | Bold text |
| `*italic*` or `_italic_` | Italic text |
| `~~strikethrough~~` | Strikethrough |
| `` `code` `` | Inline code |
| `[link](url)` | Hyperlink |
| `![alt](url)` | Image reference |
| `# Heading` | Heading (levels 1-6) |
| `- item` | List item |
| `> quote` | Block quote |

### Basic Markdown Parsing

```swift
let markdown = """
**Bold** and *italic* text.
Here's some `inline code`.
Visit [Apple](https://apple.com).
"""

let attributedString = try AttributedString(markdown: markdown)
```

### Markdown Parsing Options

```swift
let options = AttributedString.MarkdownParsingOptions(
    // Allow custom attribute syntax ^[text](attr: value)
    allowsExtendedAttributes: true,

    // How to interpret the Markdown
    interpretedSyntax: .full,  // or .inlineOnly, .inlineOnlyPreservingWhitespace

    // What to do if parsing fails
    failurePolicy: .returnPartiallyParsedIfPossible,  // or .throwError

    // Language for localization
    languageCode: "en"
)

let text = try AttributedString(markdown: "**Hello**", options: options)
```

### InterpretedSyntax Options

```swift
// .full - Parse all Markdown including block elements
// Headings, lists, block quotes are converted to presentation intents

// .inlineOnly - Only parse inline elements
// Bold, italic, code, links, but ignore whitespace

// .inlineOnlyPreservingWhitespace - Inline elements with whitespace preserved
// Best for preserving line breaks (\n) in text
```

### Preserving Line Breaks

```swift
// Line breaks are NOT preserved by default
let text1 = try AttributedString(markdown: "Line 1\nLine 2")
// Displays as "Line 1 Line 2"

// To preserve line breaks:
let options = AttributedString.MarkdownParsingOptions(
    interpretedSyntax: .inlineOnlyPreservingWhitespace
)
let text2 = try AttributedString(markdown: "Line 1\nLine 2", options: options)
// Displays as:
// Line 1
// Line 2
```

### Localized Markdown

```swift
// In Localizable.strings:
// "welcome_message" = "Welcome, **%@**!";

let name = "John"
let localized = AttributedString(
    localized: "welcome_message",
    defaultValue: "Welcome, **\(name)**!"
)
```

---

## Custom Attributes

Create your own attributes for domain-specific data.

### Step 1: Define the Attribute Key

```swift
enum HighlightColorAttribute: AttributedStringKey {
    typealias Value = Color
    static let name = "highlightColor"
}

// For enum-based attributes
enum PriorityAttribute: AttributedStringKey {
    enum Value: String, Codable {
        case low, medium, high, critical
    }
    static let name = "priority"
}
```

### Step 2: Create an Attribute Scope

```swift
extension AttributeScopes {
    struct MyAppAttributes: AttributeScope {
        let highlightColor: HighlightColorAttribute
        let priority: PriorityAttribute

        // Include system scopes you need
        let swiftUI: SwiftUIAttributes
        let foundation: FoundationAttributes
    }

    var myApp: MyAppAttributes.Type { MyAppAttributes.self }
}
```

### Step 3: Add Dynamic Lookup Support

```swift
extension AttributeDynamicLookup {
    subscript<T: AttributedStringKey>(
        dynamicMember keyPath: KeyPath<AttributeScopes.MyAppAttributes, T>
    ) -> T {
        return self[T.self]
    }
}
```

### Step 4: Use Custom Attributes

```swift
var text = AttributedString("Important task")
text.highlightColor = .yellow
text.priority = .high

// Access the attribute
if let priority = text.priority {
    print("Priority: \(priority)")
}
```

### Making Custom Attributes Markdown-Decodable

```swift
// Conform to both protocols
enum RainbowAttribute: CodableAttributedStringKey, MarkdownDecodableAttributedStringKey {
    enum Value: String, Codable {
        case plain, colorful, extreme
    }
    static let name = "rainbow"
}

// Use in Markdown with extended attribute syntax:
// ^[Rainbow text](rainbow: 'colorful')

let markdown = "This is ^[rainbow text](rainbow: 'colorful') in the string."
let options = AttributedString.MarkdownParsingOptions(
    allowsExtendedAttributes: true
)
let text = try AttributedString(
    markdown: markdown,
    including: AttributeScopes.MyAppAttributes.self,
    options: options
)
```

### Extended Attribute Markdown Syntax

```swift
// Single attribute
"^[styled text](customAttr: 'value')"

// Multiple attributes
"^[styled text](attr1: 'value1', attr2: 42)"

// Nested object attributes
"^[styled text](config: {enabled: true, level: 3})"
```

---

## AttributeContainer

Use `AttributeContainer` to define reusable attribute sets.

### Creating Containers

```swift
// Using builder pattern
var container = AttributeContainer()
container.font = .headline
container.foregroundColor = .blue
container.underlineStyle = .single

// Using subscript
var container2 = AttributeContainer()
container2[AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = .red
```

### Applying Containers

```swift
var text = AttributedString("Hello World")

// Set attributes (replaces all existing attributes)
text.setAttributes(container)

// Merge attributes (combines with existing)
text.mergeAttributes(container)

// Merge with policy
text.mergeAttributes(container, mergePolicy: .keepNew)  // New values win
text.mergeAttributes(container, mergePolicy: .keepCurrent)  // Existing values win
```

### Replace Attributes

```swift
// Replace specific attributes with others
var oldContainer = AttributeContainer()
oldContainer.foregroundColor = .blue

var newContainer = AttributeContainer()
newContainer.foregroundColor = .red
newContainer.font = .headline

text.replaceAttributes(oldContainer, with: newContainer)
```

### Reusable Style Definitions

```swift
struct TextStyles {
    static var heading: AttributeContainer {
        var container = AttributeContainer()
        container.font = .title
        container.foregroundColor = .primary
        return container
    }

    static var body: AttributeContainer {
        var container = AttributeContainer()
        container.font = .body
        container.foregroundColor = .secondary
        return container
    }

    static var link: AttributeContainer {
        var container = AttributeContainer()
        container.foregroundColor = .blue
        container.underlineStyle = .single
        return container
    }
}

// Usage
var title = AttributedString("Welcome")
title.setAttributes(TextStyles.heading)
```

---

## Working with Runs

`Runs` provides access to contiguous ranges with identical attributes.

### Iterating Over Runs

```swift
var text = AttributedString("Hello ")
text.foregroundColor = .blue

var world = AttributedString("World")
world.foregroundColor = .red

let combined = text + world

// Iterate over all runs
for run in combined.runs {
    print("Text: \(combined[run.range])")
    print("Attributes: \(run)")
}
```

### Accessing Specific Attributes in Runs

```swift
// Iterate with specific attribute type
for (value, range) in text.runs[\.foregroundColor] {
    if let color = value {
        print("Range has color: \(color)")
    }
}

// Multiple attributes
for (font, color, range) in text.runs[\.font, \.foregroundColor] {
    print("Font: \(String(describing: font)), Color: \(String(describing: color))")
}
```

### Modifying Runs

```swift
// Transform attributes
text.transformingAttributes(\.foregroundColor) { transformer in
    if transformer.value == .blue {
        transformer.value = .green
    }
}

// Replace based on attribute
text.transformingAttributes(\.font) { transformer in
    if transformer.value == .body {
        transformer.replace(with: \.font, value: .headline)
    }
}
```

---

## Character and Unicode Views

Access string content through different views.

### CharacterView

```swift
let text = AttributedString("Hello 👩🏽‍🦳")

// Access characters
let characters = text.characters
print(characters.count)  // 7

// Iterate
for char in text.characters {
    print(char)
}

// Find and replace
if let range = text.range(of: "Hello") {
    var mutable = text
    mutable.characters.replaceSubrange(range, with: "Hi")
}
```

### UnicodeScalarView

```swift
let text = AttributedString("Hello 👩🏽‍🦳")

// Unicode scalars (more granular)
let scalars = text.unicodeScalars
print(scalars.count)  // 10 (emoji is multiple scalars)

// Iterate
for scalar in text.unicodeScalars {
    print(scalar)
}
```

### Index Types

```swift
// AttributedString uses its own index type
let text = AttributedString("Hello World")

let start = text.startIndex
let end = text.endIndex

// Get index at offset
let index = text.index(start, offsetByCharacters: 5)

// Create range
if let helloRange = text.range(of: "Hello") {
    let hello = text[helloRange]
}
```

### Important Note on Indices

Indices are only valid for the specific AttributedString instance they were created from. After any mutation, indices may become invalid.

```swift
var text = AttributedString("Hello")
let range = text.range(of: "Hello")!

// After mutation, the range may be invalid
text += AttributedString(" World")
// Don't use 'range' here - get a new one
```

---

## Codable Support

AttributedString conforms to `Codable` for serialization.

### Basic Encoding/Decoding

```swift
struct Document: Codable {
    let title: String
    let content: AttributedString
}

let doc = Document(
    title: "My Document",
    content: try AttributedString(markdown: "**Hello** World")
)

// Encode
let encoder = JSONEncoder()
let data = try encoder.encode(doc)

// Decode
let decoder = JSONDecoder()
let decoded = try decoder.decode(Document.self, from: data)
```

### With Custom Attributes

```swift
// Use @CodableConfiguration for custom attribute scopes
struct Document: Codable {
    let title: String

    @CodableConfiguration(from: AttributeScopes.MyAppAttributes.self)
    var content: AttributedString
}
```

### Manual Encoding with Custom Scope

```swift
struct Document: Codable {
    let title: String
    let content: AttributedString

    enum CodingKeys: String, CodingKey {
        case title, content
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(
            AttributedString.self,
            forKey: .content,
            configuration: AttributeScopes.MyAppAttributes.self
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(
            content,
            forKey: .content,
            configuration: AttributeScopes.MyAppAttributes.self
        )
    }
}
```

### Important: Unicode Stability

The JSON encoding uses character offsets for run ranges. Be aware that Unicode character definitions can change between Unicode versions, potentially affecting stored data across OS versions.

---

## SwiftUI Text Integration

SwiftUI's `Text` view natively supports `AttributedString`.

### Basic Usage

```swift
struct ContentView: View {
    var body: some View {
        Text(attributedGreeting)
    }

    var attributedGreeting: AttributedString {
        var text = AttributedString("Hello, ")
        text.foregroundColor = .blue

        var name = AttributedString("World!")
        name.foregroundColor = .red
        name.font = .headline

        return text + name
    }
}
```

### With Markdown

```swift
struct ContentView: View {
    var body: some View {
        // String literal Markdown (auto-parsed)
        Text("**Bold** and *italic*")

        // Variable requires explicit parsing
        let markdownString = "**Bold** and *italic*"
        Text(try! AttributedString(markdown: markdownString))
    }
}
```

### Tappable Links

```swift
struct ContentView: View {
    var body: some View {
        Text(linkText)
            .tint(.purple)  // Customize link color
    }

    var linkText: AttributedString {
        var text = AttributedString("Visit our website")
        text.link = URL(string: "https://apple.com")
        return text
    }
}
```

### Handling Link Taps

```swift
struct ContentView: View {
    @Environment(\.openURL) var openURL

    var body: some View {
        Text(linkText)
            .environment(\.openURL, OpenURLAction { url in
                // Custom handling
                print("Tapped: \(url)")
                return .handled  // or .systemAction, .discarded
            })
    }
}
```

### Supported Attributes in SwiftUI Text

Not all attributes render in SwiftUI Text. These work:

- `font`
- `foregroundColor`
- `backgroundColor`
- `strikethroughStyle` / `strikethroughColor`
- `underlineStyle` / `underlineColor`
- `kern`
- `tracking`
- `baselineOffset`
- `link`

These do NOT render in SwiftUI Text (use UIKit):
- `shadow`
- `paragraphStyle`
- `strokeColor` / `strokeWidth`
- Complex text effects

### Attribute Precedence

SwiftUI modifiers apply to the entire Text, but AttributedString attributes take precedence:

```swift
Text(attributedString)
    .foregroundColor(.gray)  // Only applies where AttributedString doesn't set color
    .font(.body)  // Only applies where AttributedString doesn't set font
```

---

## iOS 26 Rich Text Editing

iOS 26 introduces native rich text editing support with `TextEditor` and `AttributedString`.

### Basic Rich Text Editor

```swift
import SwiftUI

struct RichTextEditorView: View {
    @State private var text = AttributedString("Start typing...")

    var body: some View {
        TextEditor(text: $text)
    }
}
```

### With Text Selection and Formatting

```swift
struct RichTextEditorView: View {
    @State private var text = AttributedString("")
    @State private var selection = AttributedTextSelection()

    var body: some View {
        VStack {
            // Formatting toolbar
            HStack {
                Button("Bold") {
                    applyBold()
                }
                Button("Italic") {
                    applyItalic()
                }
                Button("Underline") {
                    applyUnderline()
                }
            }

            TextEditor(text: $text, selection: $selection)
        }
    }

    private func applyBold() {
        text.transformAttributes(in: &selection) { container in
            container.font = .bold(.body)()
        }
    }

    private func applyItalic() {
        text.transformAttributes(in: &selection) { container in
            container.font = .italic(.body)()
        }
    }

    private func applyUnderline() {
        text.transformAttributes(in: &selection) { container in
            container.underlineStyle = .single
        }
    }
}
```

### Built-in Formatting Support

iOS 26's TextEditor provides automatic support for:
- Keyboard shortcuts (Cmd+B for bold, Cmd+I for italic, etc.)
- Context menu formatting options
- System formatting toolbar

### AttributedTextFormattingDefinition (iOS 26)

```swift
// Define how text can be styled
struct MyFormattingDefinition: AttributedTextFormattingDefinition {
    // Define available formatting options
    // This is a new protocol in iOS 26
}
```

### AttributedTextValueConstraint (iOS 26)

```swift
// Constraints that automatically transform attributes into visual styling
// Used for real-time pattern detection and auto-formatting
```

### WWDC 2025 Resources

- "Code-along: Cook up a rich text experience in SwiftUI with AttributedString" (WWDC25 Session 280)
- "Building rich SwiftUI text experiences" (Apple Developer Documentation)

---

## Converting Between Types

### AttributedString to NSAttributedString

```swift
let attributedString = AttributedString("Hello")
let nsAttributedString = NSAttributedString(attributedString)

// Use with UIKit
label.attributedText = nsAttributedString
```

### NSAttributedString to AttributedString

```swift
let nsAttributedString = NSAttributedString(
    string: "Hello",
    attributes: [
        .foregroundColor: UIColor.red,
        .font: UIFont.boldSystemFont(ofSize: 18)
    ]
)

let attributedString = AttributedString(nsAttributedString)
```

### Attribute Conversion Notes

- UIKit `UIFont` converts to SwiftUI `Font`
- UIKit `UIColor` converts to SwiftUI `Color`
- SwiftUI attributes take precedence over UIKit attributes
- Custom attributes are lost during conversion (both directions)

### Converting with Scope Specification

```swift
// Specify which scope to use during conversion
let attributedString = try AttributedString(
    nsAttributedString,
    including: \.uiKit
)
```

---

## Best Practices

### 1. Use Value Semantics Correctly

```swift
// AttributedString is a value type - mutations create copies
var text = AttributedString("Hello")
var copy = text
copy.foregroundColor = .red
// 'text' is unchanged, 'copy' has red color
```

### 2. Prefer AttributeContainer for Reusable Styles

```swift
// Good
let highlightStyle = AttributeContainer()
    .backgroundColor(.yellow)
    .font(.headline)

text1.mergeAttributes(highlightStyle)
text2.mergeAttributes(highlightStyle)

// Avoid
text1.backgroundColor = .yellow
text1.font = .headline
text2.backgroundColor = .yellow  // Duplication
text2.font = .headline
```

### 3. Use Appropriate Attribute Scope

```swift
// For SwiftUI views
text.swiftUI.foregroundColor = .blue  // SwiftUI Color

// For UIKit views
text.uiKit.foregroundColor = .systemBlue  // UIColor
```

### 4. Handle Markdown Parsing Errors

```swift
do {
    let text = try AttributedString(markdown: userInput)
} catch {
    // Fallback to plain text
    let text = AttributedString(userInput)
}

// Or use failure policy
let text = try AttributedString(
    markdown: userInput,
    options: .init(failurePolicy: .returnPartiallyParsedIfPossible)
)
```

### 5. Preserve Line Breaks When Needed

```swift
// For multi-line text from Markdown
let options = AttributedString.MarkdownParsingOptions(
    interpretedSyntax: .inlineOnlyPreservingWhitespace
)
```

### 6. Thread Safety

```swift
// Safe to pass between threads (value type)
Task.detached {
    let text = AttributedString("Background")
    await MainActor.run {
        self.displayText = text
    }
}
```

### 7. Avoid Index Reuse After Mutation

```swift
var text = AttributedString("Hello")
let range = text.range(of: "ell")!

// BAD: Using range after mutation
text += " World"
// let substring = text[range]  // May crash or give wrong result

// GOOD: Get new range after mutation
if let newRange = text.range(of: "ell") {
    let substring = text[newRange]
}
```

### 8. Use Runs for Efficient Processing

```swift
// Process only ranges that have a specific attribute
for (color, range) in text.runs[\.foregroundColor] {
    guard color == .blue else { continue }
    // Process blue text ranges
}
```

### 9. Consider Performance for Large Texts

```swift
// For very large texts, consider:
// - Processing in background
// - Using lazy evaluation
// - Caching parsed results

actor TextProcessor {
    private var cache: [String: AttributedString] = [:]

    func process(_ markdown: String) async throws -> AttributedString {
        if let cached = cache[markdown] {
            return cached
        }
        let result = try AttributedString(markdown: markdown)
        cache[markdown] = result
        return result
    }
}
```

### 10. Use SwiftUI Text for Simple Cases

```swift
// For simple Markdown, let SwiftUI handle it
Text("**Bold** and *italic*")  // Automatic parsing

// Only use AttributedString when you need:
// - Custom attributes
// - Complex formatting
// - Programmatic manipulation
// - Non-localized markdown variables
```

---

## Quick Reference

### Common Operations

```swift
// Create
var text = AttributedString("Hello")

// Set attributes
text.font = .headline
text.foregroundColor = .blue

// Get substring
if let range = text.range(of: "ell") {
    let sub = text[range]
}

// Concatenate
let combined = text1 + text2

// Convert for UIKit
let nsString = NSAttributedString(text)

// Parse Markdown
let markdown = try AttributedString(markdown: "**Bold**")

// Iterate runs
for run in text.runs {
    print(text[run.range])
}
```

### Supported in SwiftUI Text

| Attribute | Supported |
|-----------|-----------|
| font | Yes |
| foregroundColor | Yes |
| backgroundColor | Yes |
| underlineStyle | Yes |
| strikethroughStyle | Yes |
| kern | Yes |
| tracking | Yes |
| baselineOffset | Yes |
| link | Yes |
| shadow | No |
| paragraphStyle | No |
| strokeColor | No |

---

## References

- [Apple Developer Documentation: AttributedString](https://developer.apple.com/documentation/foundation/attributedstring)
- [Hacking with Swift: AttributedString Tutorial](https://www.hackingwithswift.com/quick-start/swiftui/how-to-add-advanced-text-styling-using-attributedstring)
- [Kodeco: AttributedString Tutorial](https://www.kodeco.com/29501177-attributedstring-tutorial-for-swift-getting-started)
- [Sarunw: AttributedString in iOS 15](https://sarunw.com/posts/attributed-string/)
- [Fat Bob Man: AttributedString](https://fatbobman.com/en/posts/attributedstring/)
- [Nil Coalescing: AttributedString Attribute Scopes](https://nilcoalescing.com/blog/AttributedStringAttributeScopes/)
- [SwiftUI Lab: Attributed Strings with SwiftUI](https://swiftui-lab.com/attributed-strings-with-swiftui/)
- [WWDC25: Cook up a rich text experience in SwiftUI](https://developer.apple.com/videos/play/wwdc2025/280/)
- [Apple Documentation: Building rich SwiftUI text experiences](https://developer.apple.com/documentation/swiftui/building-rich-swiftui-text-experiences)

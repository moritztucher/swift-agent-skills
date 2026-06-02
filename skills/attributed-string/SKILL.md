---
name: attributed-string
description: Build and render styled, attributed text on Apple platforms with Foundation's AttributedString — AttributeContainer, Markdown parsing, attribute scopes, runs, custom attributes, SwiftUI Text rendering, and the iOS 26 AttributedString-backed TextEditor. Use when the user mentions AttributedString, rich text, styled text, AttributeContainer, Markdown text, or attributed text editing. For general SwiftUI layout, state, and view composition use the `swiftui-pro` skill.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple Foundation + SwiftUI docs via Context7 (/websites/developer_apple)
---

# AttributedString

Type-safe, value-semantic styled text on Apple platforms (Foundation, iOS 15+). The deep API reference — creation, every attribute scope, Markdown, custom attributes, `AttributeContainer`, runs, character/unicode views, `Codable`, SwiftUI `Text`, the iOS 26 rich-text `TextEditor`, and NSAttributedString conversion — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics. For surrounding SwiftUI work (layout, state, view composition), use `swiftui-pro`.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `RENDERER` — `swiftui` (default; SwiftUI `Text`/`TextEditor`, use `.swiftUI` scope attributes: `Color`, `Font`) · `uikit` (`UILabel`/`UITextView` via `NSAttributedString`, use `.uiKit` scope: `UIColor`, `UIFont`, `NSParagraphStyle`). The scope you author **must** match the renderer or attributes silently drop.
2. `SOURCE` — `programmatic` (build runs in code via attributes/`AttributeContainer`) · `markdown` (parse with `init(markdown:options:)` — pick the `interpretedSyntax` deliberately) · `editable` (iOS 26 `TextEditor(text: $attributedString)` for user-authored rich text).
3. `CUSTOM_ATTRS` — `none` (system scopes only) · `custom` (your own `AttributedStringKey` + `AttributeScope`; needed for domain data, `Codable` round-trips, and `^[text](attr:)` Markdown).

## When to use

Building or reviewing any styled-text value: a `Text` with mixed styling, Markdown rendered in-app, a rich-text editor, attributed labels, or persisted styled content. If the work is general SwiftUI (layout, navigation, state) with no attributed text, use `swiftui-pro` instead.

## Core rules

- `AttributedString` (Swift value type), not `NSAttributedString`, in new Swift/SwiftUI code. Bridge to `NSAttributedString` only at a UIKit/AppKit boundary.
- iOS 15+ for the type and Markdown; SwiftUI `Text` rendering iOS 15+; **editable** `AttributedString` in `TextEditor` (`AttributedTextSelection`, `transformAttributes(in:)`, `AttributedTextFormattingDefinition`) is **iOS 26+**. iOS 26 is the default target.
- Author attributes in the scope that matches the `RENDERER` dial. SwiftUI `Text` renders `.swiftUI` attributes (`font`, `foregroundColor`, `backgroundColor`, underline/strikethrough, `kern`, `tracking`, `baselineOffset`, `link`) — not `shadow`, `paragraphStyle`, or `strokeColor`/`strokeWidth` (those need UIKit).
- Indices are opaque (`AttributedString.Index`), tied to one instance, and invalidated by mutation. Re-derive ranges after any edit; never do `Int` arithmetic on them.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll reach for `NSMutableAttributedString` like always." | In Swift/SwiftUI use `AttributedString` — value semantics, thread-safe to pass, type-safe attributes, `Codable`, built-in Markdown. Convert to `NSAttributedString` only at a UIKit boundary. |
| "I'll offset the index by 5 / do `index + n` / cache a range and reuse it." | Indices aren't `Int` offsets and aren't stable across mutations. Use `range(of:)` / `index(_:offsetByCharacters:)`, and re-derive ranges after every edit — a stale range crashes or corrupts. |
| "`AttributedString(markdown: s)` will keep my line breaks and just style inline bits." | The default `interpretedSyntax` is `.full`: it parses block elements and **drops** `\n`/soft breaks. For inline-only with newlines preserved, pass `.inlineOnlyPreservingWhitespace`. SwiftUI's own `Text("…")` literal parsing already behaves this way and renders no block formatting. |
| "I set `.uiKit.foregroundColor` (or `shadow`/`paragraphStyle`) but `Text` shows nothing." | The renderer only reads its own scope. SwiftUI `Text` ignores `.uiKit` attributes and can't render `shadow`/`paragraphStyle`/`stroke*`. Author `.swiftUI` attributes for `Text`; use `NSAttributedString` + UIKit for shadow/paragraph/stroke. |
| "I'll mutate attributes by looping `runs` and writing back." | `runs` is a read view for iteration/inspection — iterate it, or use `runs[\.attr]` / `transformingAttributes(_:)` to change values; don't treat run ranges as durable indices into a string you're mutating. |
| "I'll bind the `AttributedString` to a `TextEditor` for a rich-text field." | Editable `AttributedString` in `TextEditor` (with `AttributedTextSelection`, `transformAttributes(in:)`, `AttributedTextFormattingDefinition`/`ValueConstraint`) is **iOS 26+**. On earlier OS versions `TextEditor` is plain-text only — gate it or fall back. |
| "Custom attribute survives `NSAttributedString` round-trip / JSON without setup." | Custom attributes are lost converting to/from `NSAttributedString`, and need a `CodableAttributedStringKey` + an `AttributeScope` passed via `@CodableConfiguration` / `configuration:` to encode/decode. Markdown `^[text](attr:)` additionally needs `MarkdownDecodableAttributedStringKey` + `allowsExtendedAttributes: true`. |

## Verification gate

Before shipping attributed-text code, confirm every line:

- [ ] New code uses `AttributedString`, not `NSAttributedString`; bridging happens only at a UIKit/AppKit edge.
- [ ] Authored attribute scope matches the renderer (`.swiftUI` for `Text`/`TextEditor`, `.uiKit` for UIKit) — no silently-dropped attributes.
- [ ] No `Int` arithmetic on indices; ranges re-derived after every mutation.
- [ ] `init(markdown:)` uses the intended `interpretedSyntax` (`.inlineOnlyPreservingWhitespace` when newlines/inline-only matter) and `failurePolicy` for untrusted input.
- [ ] `runs` used for iteration/inspection; mutation goes through `transformingAttributes`/`transformAttributes(in:)` or attribute assignment, not run-range surgery.
- [ ] Any editable-`AttributedString` `TextEditor` path is gated to iOS 26+ with a fallback (or the deployment target is iOS 26).
- [ ] Custom attributes that persist conform to `CodableAttributedStringKey`, ship an `AttributeScope`, and pass that scope through encode/decode (and `NSAttributedString` conversion loss is accepted or avoided).

## Deep reference

`references/guide.md` — full creation paths, attribute scopes (Foundation / SwiftUI / UIKit-AppKit / Accessibility), Markdown parsing + options, custom attributes & scopes, `AttributeContainer`, runs, character/unicode views & indices, `Codable`, SwiftUI `Text` integration, iOS 26 rich-text editing (`AttributedTextSelection`, `transformAttributes(in:)`, `AttributedTextFormattingDefinition`/`ValueConstraint`), NSAttributedString conversion, and a quick reference. Load it for any concrete API question.

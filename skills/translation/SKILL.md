---
name: translation
description: Add on-device text translation to an iOS/SwiftUI app with Apple's Translation framework — the .translationPresentation system overlay, programmatic TranslationSession via .translationTask, language availability checks, asset downloads, and batch translation. Use when the user mentions Translation, translate text, TranslationSession, translationPresentation, on-device translation, language translation, LanguageAvailability, or translating user-generated content.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple Translation docs via Context7 (/websites/developer_apple)
---

# Translation

On-device, privacy-preserving text translation on Apple platforms. Two distinct front doors: a one-line system overlay (`.translationPresentation`) and a programmatic API (`TranslationSession` obtained through `.translationTask`). The deep API reference — every modifier, batch method, availability/download flow, and use-case recipe — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `MODE` — `overlay` (default; `.translationPresentation(isPresented:text:)` shows Apple's system UI, zero state to manage, single string) · `programmatic` (`TranslationSession` via `.translationTask` when you render the result in your own UI, batch, or store it).
2. `LANGUAGES` — `auto` (default; `source: nil` auto-detects, `target: nil` uses the user's preferred language) · `fixed` (explicit `Locale.Language` pair; required for `prepareTranslation()` pre-downloads and for separating mixed-language batches).
3. `ASSETS` — `on-demand` (default; first translation prompts the system download if the pair is `.supported` but not `.installed`) · `prepared` (call `prepareTranslation()` behind a user action to download ahead of time for offline use).

## When to use

Building or reviewing any in-app translation of user-facing or user-generated text — chat messages, product descriptions, documents, comments. Use `overlay` for a single user-initiated translation with system UI; use `programmatic` when the translated text lives in your own views or model. Not for app UI localization (that's `String(localized:)` / string catalogs) and not for server-side or cross-dialect conversion.

## Core rules

- `import Translation`. SwiftUI-only — the APIs cannot be called from UIKit directly, and there is no standalone (non-view) `TranslationSession` initializer.
- Availability: `.translationPresentation` overlay is iOS 17.4+; the full programmatic API (`TranslationSession`, `.translationTask`, batch, `LanguageAvailability`, `prepareTranslation()`) is iOS 18.0+ (macOS 15+). Gate the programmatic path with `if #available(iOS 18, *)`.
- The APIs **do not work in the Simulator** — every code path must be exercised on a physical device.
- A `TranslationSession` is owned by the view and only valid inside the `.translationTask` closure. Never store it in a model, capture it past the closure, or build one yourself.
- Drive `.translationTask(configuration)` through an optional `@State` `TranslationSession.Configuration`: set it (or call `configuration?.invalidate()`) to (re)run; the closure fires when it becomes non-nil or its version changes.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll just call `TranslationSession(...)` and translate in my view model." | There is no usable standalone initializer. You only get a session from `.translationTask`/`.translationPresentation`, and it dies when the closure returns. Trigger work by setting/invalidating a `Configuration`, do the translation inside the closure, write results back to `@State`/`@Observable`. |
| "Overlay and programmatic are interchangeable — I'll wire the overlay and read the result." | `.translationPresentation` shows Apple's UI and only hands you a string via the optional replacement callback. If you need the text in your own views, in a model, or in a batch, you need `TranslationSession` — they are different tools. |
| "`status == .supported` means I can translate right now." | `.supported` means the pair is offered but the model **isn't downloaded**. Translating still works but triggers a system download (and consent) on first use. Check `LanguageAvailability().status(from:to:)`; only `.installed` is ready offline. Use `prepareTranslation()` to download ahead behind a user tap. |
| "Any two languages I pass will translate." | Not all pairs are supported, and the framework won't convert dialects/variants (e.g. Simplified↔Traditional Chinese, US↔UK English). Build pickers from `await LanguageAvailability().supportedLanguages` and treat `.unsupported` as a real branch. |
| "I'll loop `session.translate(_:)` over my array of strings." | For many strings build `[TranslationSession.Request]` and call `translations(from:)` (all at once, order preserved) or `translate(batch:)` (AsyncSequence, stream as they finish). Per-string calls are slower and miss batch handling. Keep one source language per batch — mixing languages in one batch degrades results. |
| "It worked in the Simulator, ship it." | The Translation APIs return nothing useful in the Simulator. Untested-on-device is untested. Also confirm the not-installed → download → translate path and a `.unsupported` pair on real hardware. |

## Verification gate

Before shipping a translation feature, confirm every line:

- [ ] Correct front door for the need: `.translationPresentation` for a single system-UI translation; `TranslationSession` via `.translationTask` when the result lives in your own UI/model or is batched.
- [ ] No `TranslationSession` stored outside, or used after, its `.translationTask` closure; sessions driven by setting/invalidating a `@State` `Configuration`.
- [ ] `LanguageAvailability` consulted before relying on a pair; `.installed`, `.supported` (needs download), and `.unsupported` each handled, plus `@unknown default`.
- [ ] Offline/first-use path handled — either `prepareTranslation()` behind a user action or graceful behavior when the first translate triggers a download + consent sheet.
- [ ] Many-string work uses `translations(from:)` or `translate(batch:)` with `clientIdentifier` to re-associate results; one source language per batch.
- [ ] Programmatic API gated with `if #available(iOS 18, *)`; overlay path covers iOS 17.4+ if that's the deployment floor.
- [ ] Result-writing hops back to the main actor; translation `do/catch` surfaces a real user-facing state, not just a `print`.
- [ ] Exercised on a physical device (Simulator returns nothing), including the download and unsupported-pair paths.

## Deep reference

`references/guide.md` — full setup, core types (`TranslationSession`, `.Configuration`, `.Request`, `.Response`, `LanguageAvailability`), overlay vs. inline, single and batch (`translations(from:)` and `translate(batch:)`) translation, availability + `prepareTranslation()` download flows, language pickers, iOS 18/26 notes, and use-case recipes (chat, e-commerce, documents, offline-first). Load it for any concrete API question.

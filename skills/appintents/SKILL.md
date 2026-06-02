---
name: appintents
description: Expose app actions and content to the system with App Intents — Siri, the Shortcuts app, Spotlight, the Action Button, Control Center, and Apple Intelligence. Covers AppIntent + perform(), @Parameter, AppEntity/EntityQuery, AppEnum, AppShortcutsProvider/AppShortcut phrases, dialogs and snippets. Use when the user mentions Siri, Shortcuts, App Intents, AppIntent, AppShortcut, AppEntity, voice commands, the Action Button, or app automation. For widget configuration and interactive widget buttons that run intents, also see the `widgetkit` skill.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple App Intents docs via Context7 (/websites/developer_apple_appintents)
---

# App Intents

Exposing your app's actions and content to Siri, Shortcuts, Spotlight, the Action Button, Control Center/Lock Screen, and Apple Intelligence. The deep API reference — every intent shape, parameters, entities and queries, enums, shortcut providers, dialogs/snippets, widget and Control Center integration — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `SURFACE` — `shortcuts` (default; `AppShortcutsProvider` + the Shortcuts app) · `siri` (voice phrases, `ProvidesDialog`) · `widgets` (interactive `Button`/`Toggle(intent:)`, `WidgetConfigurationIntent`, `ControlWidget` — coordinate with `widgetkit`) · `spotlight` (`isDiscoverable`, deep-link intents). Pick the surfaces you actually ship; each has different phrase, UI, and execution constraints.
2. `ENTITY_MODEL` — `none` (intents take only scalar `@Parameter`s) · `AppEntity+EntityQuery` (your models are first-class — `entities(for:)`, `suggestedEntities()`, `EntityStringQuery` for search, `EntityPropertyQuery` for filtering). Choose `none` until an intent needs to reference one of your records by identity.
3. `OUTPUT` — `void` (`.result()`) · `dialog` (`ProvidesDialog` — Siri speaks it) · `value` (`ReturnsValue<T>`, chainable in Shortcuts) · `snippet` (`ShowsSnippetView`, or iOS 26 interactive `SnippetIntent`). Combine as needed; the `perform()` return type must declare every protocol you use.

## When to use

Building or reviewing any code that surfaces app functionality to Siri, the Shortcuts app, Spotlight, the Action Button, Control Center, or Apple Intelligence — `AppIntent`, `AppEntity`, `AppShortcutsProvider`, or intent-driven widget/control buttons. For the widget timeline, configuration UI, and rendering side, use `widgetkit`; the intent that a widget button runs lives here.

## Core rules

- App Intents only — `AppIntent`, not legacy SiriKit `INIntent`/Intents Definition files. SiriKit Intents are deprecated; only touch them to maintain existing code.
- iOS 16+ for the framework; interactive widgets need iOS 17+, Control Center/Lock Screen controls iOS 18+, interactive `SnippetIntent` and Visual Intelligence iOS 26+. iOS 26 is the default target.
- `perform()` runs in a constrained, often UI-less background context (extension or app-not-foregrounded). Hop to `@MainActor` only for UI/navigation, and set `openAppWhenRun = true` when the intent genuinely needs the app open.
- Put intents, entities, queries, and the models they touch in a **shared target** so the app, widget, and any extension compile against one definition — no copies.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "My phrases read naturally, that's enough." | Every `AppShortcut` phrase must contain the `\(.applicationName)` token. Without it the phrase is silently dropped and Siri never matches it. The token resolves to the app name and its registered synonyms. |
| "`perform()` can update my UI / read the foreground state directly." | It runs in a constrained background context — no guaranteed UI, no foreground app. Do data work there; for navigation use `@MainActor` + `openAppWhenRun = true`, and read shared state, not view state. |
| "I'll use the array index (or a fresh UUID) as the entity id." | `AppEntity.id` must be **stable across launches** — the system persists it in saved Shortcuts and widget configs. An index or regenerated id makes saved shortcuts resolve to the wrong record or fail in `entities(for:)`. |
| "I'll do the long network/db work right inside `perform()` and return when done." | The system budgets intent execution tightly and kills slow ones. Keep `perform()` fast and deterministic; defer heavy work, or open the app for anything genuinely long-running. |
| "Phrases and titles are English string literals — fine to ship." | Phrases, `title`, `IntentDescription`, parameter titles, and dialogs are user-facing across every locale. Use `LocalizedStringResource` (the default for `title`) and localize phrase strings, or non-English users get no Siri coverage. |
| "I'll wire it up with a SiriKit Intents extension like before." | SiriKit `INIntent`/Intents Definition files are legacy. New voice/Shortcuts/Spotlight integration is App Intents end to end; mixing the two fragments your action surface. |

## Verification gate

Before shipping App Intents, confirm every line:

- [ ] Every `AppShortcut` phrase includes `\(.applicationName)`; phrases, titles, and dialogs use `LocalizedStringResource` / are localized.
- [ ] `AppShortcutsProvider.appShortcuts` is implemented and the intents appear in the Shortcuts app and Spotlight.
- [ ] Every `AppEntity.id` is stable and persistent; `EntityQuery.entities(for:)` round-trips ids correctly, and `suggestedEntities()` returns sensible defaults.
- [ ] `perform()` does no blocking long work; UI/navigation is `@MainActor` + `openAppWhenRun = true`, data work runs against shared state.
- [ ] `perform()` return type declares exactly the protocols used (`ProvidesDialog`, `ReturnsValue<T>`, `ShowsSnippetView`/`SnippetIntent`); errors surface a user-facing message, not a silent throw.
- [ ] Intents, entities, queries, and models live in a shared target compiled by the app, widget, and extensions; widget/control buttons reload timelines (`WidgetCenter`) after mutating data.
- [ ] No new SiriKit `INIntent`/Intents Definition usage — App Intents only.
- [ ] Tested end to end in the Shortcuts app and via Siri, with parameter prompting and disambiguation exercised.

## Deep reference

`references/guide.md` — full coverage of basic and app-opening intents, parameters (optional, runtime-requested, summaries, file inputs), `IntentResult`/dialogs/snippets, `AppEntity`, `EntityQuery`/`EntityStringQuery`/`EntityPropertyQuery`, `AppEnum`, `AppShortcutsProvider`/`AppShortcut`, Siri tips and `ShortcutsLink`, interactive widget buttons and `WidgetConfigurationIntent`, Control Center/Lock Screen `ControlWidget`, Spotlight, best practices, common patterns, and a type quick-reference. Load it for any concrete API question.

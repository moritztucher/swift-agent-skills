---
name: foundation-models
description: Build on-device AI features with Apple's Foundation Models framework (iOS 26+) — LanguageModelSession, guided generation with @Generable/@Guide, tool calling, streaming, and SystemLanguageModel availability. Use when the user mentions on-device AI, Apple Intelligence, Foundation Models, LanguageModelSession, guided generation, @Generable, @Guide, local LLM, or running an LLM on-device without a server.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple Foundation Models docs via Context7 (/websites/developer_apple_foundationmodels)
---

# Foundation Models

Apple's on-device LLM that powers Apple Intelligence, accessed through the FoundationModels framework (iOS 26+). The deep API reference — availability, text generation, guided generation, the `@Generable`/`@Guide` macros, tool calling, streaming, sessions, error handling, guardrails, SwiftUI integration — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `OUTPUT` — `freeform` (default; `respond(to:)` returns a `String` for chat/prose) · `guided-@Generable` (pass `generating: T.self`; model emits a type-safe Swift struct/enum — use this for anything your code parses).
2. `STREAMING` — `off` (default; one `await` for the full result) · `on` (`streamResponse(...)` yields partials as they generate — use for any response long enough that a user would wait).
3. `TOOLS` — `none` (default; model answers from its own knowledge) · `tool-calling` (pass `tools:` so the model can call your code for live/private data it can't know).

## When to use

Building or reviewing any feature that runs Apple's on-device model: chat, summarization, classification, structured extraction, or tool-augmented generation. Use this when the work is local/private/offline inference with no server. For server-class models (large context, complex multi-step reasoning, latest world knowledge) Foundation Models is the wrong tool — route to a hosted API instead.

## Core rules

- iOS 26.0+ on Apple Intelligence-capable hardware (A17 Pro+ / M1+). **Physical device only — not the Simulator.** No entitlement for basic use; `com.apple.developer.foundation-model-adapter` only for custom adapters.
- **Always branch on `SystemLanguageModel.default.availability` before any session call.** It is unavailable on ineligible devices, when Apple Intelligence is off, and while assets download — handle `.deviceNotEligible`, `.appleIntelligenceNotEnabled`, and `.modelNotReady` with real fallback UI, not a crash.
- Reuse one `LanguageModelSession` per conversation — it carries the transcript/context. A fresh session per message throws away all memory.
- Prefer `generating: T.self` with `@Generable` over asking for JSON in a string and decoding it. Guided generation is constrained at the token level; freeform "return JSON" is not and will eventually return prose, fences, or malformed output.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll just create a session and call `respond` — it's on every iOS 26 device." | It is not. Ineligible hardware, Apple Intelligence disabled, and mid-download all surface as `.unavailable`. Check `availability` first and ship a fallback path, or the feature is dead on those devices. |
| "I'll ask for JSON and `JSONDecoder` it." | Freeform output drifts — code fences, prose preambles, trailing commas. Use `@Generable` + `generating:`; the schema constrains generation so the result decodes by construction. |
| "Plenty of room — I'll keep appending to this session." | The on-device context window is small (~4k tokens). Long chats throw `exceededContextWindowSize`. Catch it, summarize, and start a fresh session seeded with that summary. |
| "A guardrail/refusal error means my code is broken." | No — the model declines unsafe or disallowed content by design. Catch `guardrailViolation` and `refusal` and show a graceful message; for refusals, `Refusal.explanation` gives a reason. They are expected control flow, not bugs. |
| "It's an LLM, so it can do server-grade reasoning." | It's a compact ~3B on-device model. Complex multi-step reasoning, long documents, and current world facts are not its job — keep prompts focused, constrain outputs, and route hard cases to a hosted model. |
| "Latency is just how it is — first response is always slow." | Cold start loads model resources. Call `session.prewarm(promptPrefix:)` ~1s before you expect the user to engage to cut first-response latency. |

## Verification gate

Before shipping a Foundation Models feature, confirm every line:

- [ ] `SystemLanguageModel.default.availability` checked before any session use, with fallback UI for `.deviceNotEligible`, `.appleIntelligenceNotEnabled`, and `.modelNotReady`.
- [ ] Tested on a **physical** Apple Intelligence device — not just the Simulator (where it is unsupported).
- [ ] Anything the app parses uses `@Generable` + `generating:`, not string-then-decode.
- [ ] One session reused per conversation; `exceededContextWindowSize` caught and handled (summarize + new session).
- [ ] `guardrailViolation` and `refusal` caught and surfaced gracefully (not treated as crashes).
- [ ] Long-running responses use `streamResponse(...)` so the user sees progress.
- [ ] `prewarm` called where first-response latency matters.
- [ ] Tools (if any) conform to `Tool` with an `@Generable Arguments` type, and `call(arguments:)` handles failures.

## Deep reference

`references/guide.md` — full availability handling, basic and guided generation, the `@Generable`/`@Guide` macros and every constraint (`.range`, `.count`, `.anyOf`), tool calling, streaming (text and structured), session/transcript management, the complete `GenerationError` set, guardrails and permissive mode, SwiftUI integration, and a quick-reference of key types. Load it for any concrete API question.

> Currency note (2026-06-02): `GenerationError` cases carry an associated `Context` value (e.g. `guardrailViolation(Context)`, `exceededContextWindowSize(Context)`, `rateLimited(Context)`, `assetsUnavailable(Context)`); `refusal` is `refusal(Refusal, Context)` where `Refusal` exposes an async `explanation`. The guide's `rateLimited(let retryAfter)` and `refusal(let reason, let message)` bindings are illustrative — match against the case and read the real associated types. `availability` also has a `.deviceNotEligible` case worth handling.

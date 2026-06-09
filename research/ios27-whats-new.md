# iOS 27 / iPadOS 27 / macOS 27 — What's New (Developer Research)

> Research snapshot for the **`research/ios27-apis`** branch. Compiled **2026-06-09**, one day after the WWDC 2026 keynote (June 8) and the first developer betas.
>
> **Purpose:** a detailed inventory of iOS 27 changes and new APIs, to decide which skills to update and which new skills to add. This is the *list first* — no skill edits yet.
>
> **Confidence legend:**
> - 🟢 **Apple-confirmed** — sourced from `developer.apple.com` (`/ios/whats-new/`, `/swiftui/whats-new/`).
> - 🟡 **Reported** — multiple reputable dev outlets, not yet verified against Apple docs/headers.
> - 🔴 **Unconfirmed / conflicting** — consumer reporting or sources disagree; verify before acting.
>
> Everything here predates hands-on with the betas — exact symbol names must be confirmed against the iOS 27 SDK headers and release notes before any skill is written against them.

---

## Headline developer themes

1. **On-device AI goes multimodal + open** — Foundation Models takes image input and can route to server/third-party models; a brand-new **Core AI** framework runs custom local models on Apple silicon.
2. **App Intents becomes the law** — the mandatory Siri/Spotlight surface; **SiriKit deprecated**. Schema-based content contribution to the semantic index.
3. **Foldable groundwork** — adaptive/hinge-aware layout APIs across SwiftUI + UIKit ahead of the rumored iPhone Fold.
4. **SwiftUI maturation** — toolbar overflow controls, a real document API, `@State` as a macro, default `AsyncImage` caching, reorderable containers.
5. **Liquid Glass, year two** — a system transparency/intensity slider and contrast/accessibility fixes responding to iOS 26 criticism.
6. **Xcode 27 multi-vendor coding agents** — Claude (Anthropic), Gemini (Google), and OpenAI models in the IDE, plus on-device completion.

---

## 1. Apple Intelligence & on-device AI

### Foundation Models framework — major expansion 🟢
- **`LanguageModel` provider protocol** — integrate any model (Apple, Claude, Gemini, …) behind one Swift API.
- **Multimodal prompts** — pass **images** alongside text for visual reasoning (new; was text-only in iOS 26).
- **Vision framework tools** — OCR and barcode readers exposed as on-device tool calls the model can invoke.
- **Dynamic Profiles** — swap models, tools, and instructions on the fly *within* a session.
- **Server model routing** — call server-running models through the same Swift API. 🟡
- **Private Cloud Compute access** — reach larger Apple models; **free PCC** for Small Business Program members. 🟡
- **Evaluations framework** — verify AI-feature behavior across dynamic conditions.

### Core AI framework — NEW 🟢
- Modern Swift API to **load, specialize, and execute custom / third-party models locally** on Apple silicon.
- Ahead-of-time compilation for fast load; fine-grained inference memory control; zero-copy data paths; stateful execution; automatic hardware specialization.

### Siri "AI" (orchestration, not a single new API) 🟡/🔴
- Rebuilt Siri with on-screen awareness, personal context (Messages/Photos/Mail/Notes), multi-turn memory, multimodal understanding.
- Built on **App Intents + Spotlight index + on-screen awareness** — leverages existing developer surfaces rather than one new SDK.
- 🔴 **Conflict:** some outlets describe a **Gemini-powered** standalone Siri app; others describe Apple's own model with bring-your-own-model support. Treat the "Gemini Siri" framing as unconfirmed.

---

## 2. App Intents — now the mandatory Siri surface

- **Entity schemas** — contribute app content to the **Spotlight semantic index** for Siri/Spotlight retrieval. 🟢
- **Intent schemas** — natural-language actions without predefined phrases. 🟢
- **View Annotations API** — map SwiftUI views to entities so Siri can refer to on-screen content conversationally. 🟢
- **App Intents Testing framework** — validate integration through real system pathways (no UI automation). 🟢
- **SiriKit deprecated** — App Intents becomes the exclusive Siri integration surface; ~2–3 year support window with compile-time deprecation warnings. 🟡
- 🟡 Reported mechanics: compiler-generated Swift metadata replacing XML intent definitions, streaming responses, multi-turn follow-up, per-intent privacy-manifest routing (cloud vs on-device).

---

## 3. SwiftUI

### Toolbar 🟢
- **`visibilityPriority`** — control which toolbar items survive as the app resizes.
- **`toolbarOverflowMenu`** — permanently park low-priority items in an overflow menu.
- **`topBarPinnedTrailing`** — pin critical actions to the trailing edge at all times.
- **`toolbarMinimizeBehavior`** — auto-collapse the nav bar on scroll.

### Document API 🟢
- **`WritableDocument`** / **`ReadableDocument`** — async, incremental disk read/write with progress reporting.
- **`DocumentCreationSource`** + per-source **`NewDocumentButton`** — declare multiple document creation sources.

### Lists, grids, interaction 🟢
- **Reorderable container APIs** — drag-to-rearrange in `List`, `LazyVGrid`, and custom layouts (now incl. watchOS).
- **`swipeActionsContainer`** — swipe actions on `ScrollView` and custom layouts, not just `List`.
- **Item-binding presentation** — `confirmationDialog`/`alert` accept the same item-binding pattern as sheets.

### Performance & data flow 🟢
- **`@State` is now a macro** — classes in `@State` lazily initialized once per view lifetime.
- **`ContentBuilder`** — `ViewBuilder` re-exposed to cut build times.
- **`AsyncImage` HTTP caching by default** — respects server cache headers; **`asyncImageURLSession`** modifier for a custom `URLSession`/`URLCache`.
- Lazy stacks/scrolling with prefetch; advanced graphics/compositing effects; refreshed materials and typography.

---

## 4. UIKit & adaptive / foldable layout

- **Adaptive layout APIs (SwiftUI + UIKit)** — hinge-state detection and multi-configuration display handling. 🟢
- **Modernized tab & navigation bars**; layouts that adapt for **iPhone Mirroring**. 🟢
- Framework strings spotted in the SDK: **`foldState`**, **`angleDegrees`**, and a key returning the **count of built-in displays**. 🟡
- Apple guidance: **fluid reflow, not letterboxing**, is the expected default on flexible-screen hardware. 🟡 (iPhone Fold rumored fall 2026.)

---

## 5. Liquid Glass — year-two refinements

- **System transparency / intensity slider** — user control over glass translucency; addresses iOS 26 contrast/accessibility complaints. 🟢/🟡
- **`glassEffect()` / `GlassEffectContainer`** compositing pipeline refinements (SwiftUI); **`UIGlassEffect`** in UIKit (explicit adoption via `UIVisualEffectView`). 🟡
- Tab-bar **search re-integration**; documented accessibility fixes. 🟡

---

## 6. Other frameworks

| Framework | What's new | Conf. |
|---|---|---|
| **WidgetKit** | Widgets customizable via **App Intents**; new dynamic styling options | 🟢 |
| **Music Understanding** (NEW) | On-device audio analysis across six dimensions for audio/media apps | 🟢 |
| **NowPlaying** (new/repackaged) | Connect app playback to Lock Screen, Control Center, Dynamic Island, CarPlay | 🟢 |
| **Core Image** | RAW processing APIs **v9** — better sharpness and color | 🟢 |
| **Vision** | OCR + barcode tools callable from Foundation Models | 🟢 |
| **Declared Age Range** | Expanded API to tailor apps to a child's age bracket without exact birthday | 🟡 |
| **Game Porting Toolkit 4** | Open-source agentic coding skills for Metal / Apple game dev | 🟢 |
| **StoreKit** | No iOS 27-specific changes surfaced yet; the 26.5 SDK added commitment/billing-plan APIs (separate) | 🔴 verify |
| **SwiftData / HealthKit** | Not prominently covered in keynote/day-1 coverage — **check release notes** | 🔴 verify |

---

## 7. Xcode 27 & tooling

- **Multi-vendor coding agents** — Anthropic (Claude), Google (Gemini), OpenAI models in the IDE. 🟡
- **On-device Apple Intelligence** multi-line code completion on Apple silicon. 🟡
- **SwiftUI adoption "skills"** in the coding assistant — guides you onto the 2027-release APIs. 🟢
- Faster simulator; improved Git workflow; enhanced Instruments memory/energy profiling. 🟡

---

## 8. Non-developer highlights (context only)

- **Performance:** app launch +30%, Photos library +70%, AirDrop +80%, external storage transfers up to 5×. 🟡
- **Photos AI:** spatial **Reframe**, **Extend**, upgraded **Cleanup**. 🟡
- 🔴 **Device support conflict:** "iPhone 11 onward" (Tom's Guide) vs "iPhone 12 cutoff, drops iPhone 11" (others). Verify against Apple's official compatibility list.
- Release: developer betas **June 8**, public beta ~mid-July, public release ~September 2026.

---

## 9. First-pass skill impact (seed for review — not decisions)

**Existing skills likely needing updates:**
- `foundation-models` — large: image input, `LanguageModel` protocol, server/third-party models, Dynamic Profiles, Vision tools, Evaluations.
- `appintents` — large: entity/intent schemas, View Annotations, App Intents Testing, **SiriKit deprecation**, mandatory status.
- `swiftui-toolbar` — toolbar overflow/visibility/minimize APIs.
- `swiftui-pro` — `@State` macro, `AsyncImage` caching, reorderable containers, `swipeActionsContainer`, item-binding presentation, `ContentBuilder`.
- `liquid-glass` — transparency slider, `UIGlassEffect`, pipeline refinements, tab-bar search.
- `widgetkit` — App Intents customization + dynamic styling.
- `declared-age-range` — API expansion.

**Candidate new skills:**
- **Core AI** — running custom/third-party on-device models on Apple silicon (distinct from Foundation Models).
- **Adaptive / foldable layout** — hinge-state, multi-config displays, fluid reflow (could extend `swiftui-pro` instead).
- **SwiftUI document apps** — `Readable/WritableDocument`, `DocumentCreationSource` (could extend `swiftui-pro`).
- **Music Understanding** — on-device audio analysis.
- **NowPlaying** — unified playback presentation surface.

**To verify before writing anything:** exact symbol names against iOS 27 SDK headers; StoreKit/SwiftData/HealthKit release notes; the Siri "Gemini" framing; device-support list.

---

## Sources

- [Apple — What's new in iOS 27](https://developer.apple.com/ios/whats-new/) 🟢
- [Apple — What's New in SwiftUI](https://developer.apple.com/swiftui/whats-new/) 🟢
- [Apple — What's new for Apple developers (hub)](https://developer.apple.com/whats-new/)
- [MacRumors — First iOS 27 betas to developers](https://www.macrumors.com/2026/06/08/apple-releases-ios-27-beta-1/)
- [MacRumors — iOS 27 hints at foldable iPhone / app resizability](https://www.macrumors.com/2026/06/08/ios-27-hints-at-foldable-iphone-with-app-resizability-push/)
- [TechCrunch — WWDC 2026: everything announced](https://techcrunch.com/2026/06/08/wwdc-2026-everything-announced-on-siri-ai-os-27-apple-intelligence-and-more/)
- [Callstack — On-device AI after WWDC 2026](https://www.callstack.com/blog/on-device-ai-after-wwdc-2026-whats-new)
- [Lushbinary — WWDC 2026: iOS 27, new Siri & dev tools](https://lushbinary.com/blog/wwdc-2026-announcements-ios-27-siri-developer-guide/)
- [TechTimes — Liquid Glass iOS 27 refinements](https://www.techtimes.com/articles/317975/20260608/apple-liquid-glass-ios-27-wwdc-2026-brings-refinements-developers-must-adopt-today.htm)
- [AppleInsider — iOS 27 better Liquid Glass & responsiveness](https://appleinsider.com/articles/26/06/08/ios-27-gets-better-liquid-glass-and-more-responsiveness)
- [Tom's Guide — iOS 27 official: all new features](https://www.tomsguide.com/phones/iphones/ios-27-is-official-all-the-new-upgrades-and-features-announced-at-wwdc-2026)

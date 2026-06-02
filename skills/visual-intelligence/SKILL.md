---
name: visual-intelligence
description: Surface your app's content in iOS 26's system Visual Intelligence (camera/visual search) and do on-device computer vision — Vision (text/barcode/face/pose), VisionKit (Live Text, Visual Look Up, DataScanner), and the iOS 26 Visual Intelligence App Intents path (SemanticContentDescriptor, IntentValueQuery, semanticContentSearch). Use when the user mentions Visual Intelligence, visual search, camera search, image search, semantic content, scan with the camera, Live Text, Visual Look Up, or recognizing/classifying images. Visual Intelligence integration is built on App Intents — see the `appintents` guidance for the entity/intent fundamentals — and on-device matching usually runs through `coreml`.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple Visual Intelligence + App Intents docs via Context7 (/websites/developer_apple — no dedicated Apple VisualIntelligence library exists on Context7; verified against the broad Apple developer docs library)
---

# Visual Intelligence

Two distinct things share this name; pick the right layer before writing code:

- **System Visual Intelligence (iOS 26+)** — the user invokes the system camera/visual-search experience (Camera Control entry point), and *your app's results appear in it*. This is an **App Intents** integration using the `VisualIntelligence` framework's data types. This is the headline iOS 26 feature.
- **On-device computer vision** — your own in-app camera/photo analysis with **Vision** (text, barcodes, faces, pose, Core ML classification) and **VisionKit** (Live Text, Visual Look Up, `DataScannerViewController`, subject lifting). Stable since iOS 11/16.

The deep API reference — every Vision request, the full VisionKit surface, SwiftUI camera plumbing, and the corrected iOS 26 integration — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `LAYER` — `system-vi` (appear in iOS 26 Visual Intelligence via App Intents; needs iOS 26) · `in-app-cv` (your own Vision/VisionKit analysis; iOS 11/16+) · `both`.
2. `MATCHER` — how `system-vi` turns the captured frame into results: `coreml` (on-device model/embeddings, private, offline) · `server` (upload features/image, richer catalog, needs network + privacy disclosure) · `vision-builtin` (Vision classification/Visual Look Up, no custom model).
3. `RESULT_SHAPE` — `single-entity` (one `AppEntity` type) · `union` (`@UnionValue` enum over several entity types, e.g. product + collection).

## When to use

Building or reviewing: an app that should show up when the user points iOS 26 Visual Intelligence at something; any in-app camera scanning, Live Text, Visual Look Up, barcode/QR reading, or Core ML image classification. If the task is purely defining App Intent entities/queries with no visual capture, that's plain `appintents`. If it's training/converting the model itself, that's `coreml`.

## Core rules

- **`system-vi` is built on App Intents.** Two pieces work together: an `@AppIntent(schema: .visualIntelligence.semanticContentSearch)` intent (parameter type `SemanticContentDescriptor`) **and** an `IntentValueQuery` whose `values(for: SemanticContentDescriptor)` returns your result entities. The query is what produces the results grid — the intent's `perform()` just returns `.result()`.
- **The system hands you a `SemanticContentDescriptor`, not a string.** Read `input.pixelBuffer` (a `CVReadOnlyPixelBuffer`) and run your own matching. There is no system-provided text query.
- **iOS 26+ and gate it.** `@available(iOS 26.0, *)` on every Visual Intelligence type; the feature is iPhone-with-Camera-Control / Apple-Intelligence territory. In-app Vision/VisionKit has its own, much lower floors.
- **Vision/VisionKit work is on-device and needs camera permission.** `NSCameraUsageDescription` in Info.plist; request `AVCaptureDevice` access before capture. Process frames off the main thread and throttle.
- **Don't confuse the two onscreen paths.** Returning results *into* Visual Intelligence = the IntentValueQuery path above. Making content you're *currently showing* understandable = `.userActivity(_:element:)` + `activity.appEntityIdentifier`.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "The schema is `.semanticContentSearch`." | It's `.visualIntelligence.semanticContentSearch`. The bare form does not exist — it won't compile. |
| "`semanticContent` is a `String` I can search with." | The parameter is a `SemanticContentDescriptor` struct. You search with its `pixelBuffer` (`CVReadOnlyPixelBuffer`), not a query string. The system gives you the captured scene, not words. |
| "Implementing the `@AppIntent` schema is enough — `perform()` runs my search." | No. The results come from a separate `IntentValueQuery.values(for:)`. Without that query, Visual Intelligence has nothing to show. `perform()` returns `.result()`. |
| "I'll set `activity.targetContentIdentifier` / `persistentIdentifier` to expose onscreen content." | That's not the App-Intents-entity path. Use the SwiftUI `.userActivity(_:element:)` modifier with `activity.appEntityIdentifier`. |
| "I'll run Vision/Core ML on the camera buffer on the main thread per frame." | That stutters the UI and overheats. Process on a dedicated queue, throttle to ~10 FPS, use `.fast` recognition + a region of interest for live feeds. |
| "`CVPixelBuffer` and `CVReadOnlyPixelBuffer` are interchangeable." | The Visual Intelligence input is `CVReadOnlyPixelBuffer`. Treat it as read-only; don't assume the mutable `CVPixelBuffer` APIs apply. |
| "It built, so it'll appear in Visual Intelligence." | The system only surfaces apps it recognizes as relevant, on capable hardware, with the schema correctly adopted. You must test on a real iOS 26 device through the Camera Control flow — the simulator and a green build prove nothing. |

## Verification gate

Before shipping Visual Intelligence integration, confirm:

- [ ] Intent uses `@AppIntent(schema: .visualIntelligence.semanticContentSearch)` with a `SemanticContentDescriptor` parameter.
- [ ] A separate `IntentValueQuery` exists; `values(for:)` reads `input.pixelBuffer` and returns your entities (single type or `@UnionValue`).
- [ ] Result entities are `AppEntity`s with a real `displayRepresentation` (title + image) — they render in the results grid.
- [ ] Every Visual Intelligence type is `@available(iOS 26.0, *)`-gated and degrades cleanly on older OSes.
- [ ] Matching (`MATCHER` dial) handles "no match" → returns `[]`, not a crash or a bogus entity; `server` matching has a privacy-policy disclosure and network-failure path.
- [ ] In-app capture: `NSCameraUsageDescription` set, permission requested before use, frames processed off-main and throttled.
- [ ] Tested on a real iOS 26 device through the actual Camera Control / Visual Intelligence flow — not just a green build or the simulator.

## Deep reference

`references/guide.md` — full Vision request catalog (text, barcode, classification, face, body/hand pose, Core ML), VisionKit (`ImageAnalyzer`, Live Text, subject lifting, `DataScannerViewController`), SwiftUI camera plumbing, best practices, and the corrected iOS 26 Visual Intelligence App Intents integration (`SemanticContentDescriptor`, `IntentValueQuery`, `@UnionValue`, onscreen `.userActivity`). Load it for any concrete API question.

> Currency note: Context7 has **no dedicated Apple `VisualIntelligence` library**. APIs here were verified against the broad official Apple docs library (`/websites/developer_apple`) on 2026-06-02 — specifically `VisualIntelligence/integrating-your-app-with-visual-intelligence`, `AppIntents/AssistantSchemas/VisualIntelligenceIntent/semanticContentSearch`, and `AppIntents/adopting-app-intents-to-support-system-experiences`. The guide's original iOS 26 section was materially stale (wrong schema name, `String` parameter, no `IntentValueQuery`) and has been rewritten; re-verify against Apple docs if Apple revises the framework.

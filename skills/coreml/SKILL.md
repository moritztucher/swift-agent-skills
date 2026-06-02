---
name: coreml
description: Integrate and review on-device machine learning with Core ML — loading/compiling models, MLModelConfiguration compute units, sync/async predictions, the generated model class, Vision (VNCoreMLRequest) for image models, model encryption, stateful models, and on-device personalization. Use when the user mentions Core ML, ML model, on-device inference, .mlmodel/.mlpackage, MLModel, machine learning, or a Vision model. For on-device text generation, use the `foundation-models` skill (higher-level LLM) instead of wiring a Core ML model.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple Core ML docs via Context7 (/websites/developer_apple_coreml)
---

# Core ML

On-device machine-learning inference on Apple platforms — image classification/detection, NLP, audio, and custom models, plus on-device fine-tuning. The deep API reference — model integration, the `MLModel` API, `MLFeatureProvider`, async predictions, Vision integration, configuration/optimization, stateful models, encryption, and version compatibility — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `TASK` — `image` (classification/detection/segmentation; drive it through **Vision**, not raw `MLModel`) · `text` (NLP via `NLModel`/Natural Language) · `tabular-or-custom` (raw `MLModel` + `MLFeatureProvider`). If the task is text *generation*, stop and use `foundation-models` instead.
2. `COMPUTE_UNITS` — `all` (default; OS picks CPU/GPU/Neural Engine) · `cpuAndNeuralEngine` (NN-heavy models) · `cpuAndGPU` · `cpuOnly` (background/deterministic timing). Set on `MLModelConfiguration` at load, never per-prediction.
3. `LOADING` — `xcode-bundled` (default; drop in `.mlpackage`/`.mlmodel`, Xcode compiles + generates the class) · `runtime-download` (download `.mlmodel`, `MLModel.compileModel(at:)`, then `MLModel.load(contentsOf:)` — for large or swappable models).

## When to use

Building or reviewing any on-device inference path: loading a model, configuring compute units, running predictions (sync or async), wiring a model into Vision for images, encrypting a bundled model, running a stateful generator, or on-device personalization (`MLUpdateTask`). If the goal is generating or reasoning over text, that's `foundation-models`, not Core ML.

## Core rules

- **Load off the main thread.** Model load + compile is expensive (disk + Neural Engine warm-up). Use `MLModel.load(contentsOf:configuration:)` async or a background `Task`; never construct on the main actor in a view's `init`/`body`.
- **Reuse one model instance.** Construct once, keep it; never build a fresh model per prediction.
- **Core ML models are not thread-safe.** Confine to an `actor` or serial queue; one instance per concurrent stream.
- **For images, go through Vision.** `VNCoreMLModel` + `VNCoreMLRequest` handle resize, color space, and orientation. Raw `MLModel` for images means hand-rolling preprocessing and getting it subtly wrong.
- **Input feature names + shapes must match the model exactly.** Read `model.modelDescription.inputDescriptionsByName` / `imageConstraint`; a mismatch throws at predict time, not compile time.
- iOS 26 default target. Async `prediction(from:)` and `MLModel.load` are iOS 16/17+; stateful models (`makeState()`) are iOS 18+.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "Loading the model in the View is fine, it's just a file read." | Load + compile blocks the main thread for hundreds of ms (disk decode + Neural Engine warm-up). Load async / off-main and show a loading state. |
| "`.all` is always fastest, so I'll set it everywhere." | `.all` lets the OS choose, which is right by default — but for some models `.cpuAndGPU` or `.cpuAndNeuralEngine` is faster or more power-efficient. It's a profiling decision, not a free win. Benchmark on device. |
| "It compiled, so my inputs are correct." | Feature names and tensor/image shapes are validated at *predict* time, not build time. Check `modelDescription.inputDescriptionsByName` and the `imageConstraint`; a wrong name or size throws at runtime. |
| "I'll feed CGImage pixels into the model myself." | For image models use Vision (`VNCoreMLRequest` + `imageCropAndScaleOption`). Manual resize/orientation/color-space handling is the #1 source of garbage predictions. |
| "One prediction works, so I'll just call it in a loop on each frame." | Per-prediction throughput needs async `prediction(from:)` and a `TaskGroup`/serial actor — not a synchronous loop on the main thread. And reuse the model; don't reconstruct. |
| "I'll ship the raw `.mlmodel` and compile it in the app." | Bundle the `.mlpackage`/`.mlmodel` and let **Xcode** compile it at build time (and generate the typed class). Runtime `compileModel(at:)` is only for downloaded/swappable models. |
| "Core ML can generate the user's reply text." | Core ML runs *your* model; it isn't a text generator. On-device LLM work is `foundation-models`. Don't bolt a generic model onto Core ML for chat/summarization. |
| "`options.usesCPUOnly = true` pins it to CPU." | `MLPredictionOptions.usesCPUOnly` is deprecated. Set `MLModelConfiguration.computeUnits = .cpuOnly` at load instead. |

## Verification gate

Before shipping Core ML inference, confirm every line:

- [ ] Model loaded off the main thread (async `load`/background `Task`), with a loading state in the UI.
- [ ] One model instance, constructed once and reused — not per prediction.
- [ ] Concurrent access is serialized (actor / serial queue); no shared instance hit from parallel tasks.
- [ ] `computeUnits` set on `MLModelConfiguration` (chosen for the task, profiled on device) — not via deprecated `usesCPUOnly`.
- [ ] Image models run through Vision (`VNCoreMLRequest`, `imageCropAndScaleOption`, correct orientation) rather than manual preprocessing.
- [ ] Input feature names + shapes validated against `modelDescription`; predict errors handled, not crashed.
- [ ] Bundled model shipped as `.mlpackage`/`.mlmodel` (Xcode-compiled); runtime compile reserved for downloaded models, with temp cleanup.
- [ ] If encrypted: `MLModelError.Code.modelDecryption` handled (offline first-launch key fetch can fail).
- [ ] Stateful models: one `MLState` per stream, no overlapping in-flight predictions sharing it.
- [ ] Task is genuinely model inference — text generation routed to `foundation-models` instead.

## Deep reference

`references/guide.md` — full model integration, the `MLModel` API and `MLModelDescription`, `MLFeatureProvider`/`MLFeatureValue`, async predictions, Vision integration, image classification + object detection, Natural Language, configuration/optimization, stateful models, model encryption, on-device personalization, and the iOS version-compatibility matrix. Load it for any concrete API question.

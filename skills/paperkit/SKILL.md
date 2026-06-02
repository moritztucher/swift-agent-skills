---
name: paperkit
description: Add a rich drawing and markup canvas to an iOS 26+ app with PaperKit — PaperMarkupViewController, the PaperMarkup data model, the insertion menu (MarkupEditViewController) and macOS toolbar (MarkupToolbarViewController), FeatureSet customization, the PencilKit tool picker, HDR ink, thumbnails, and forward compatibility. Use when the user mentions PaperKit, markup, annotation canvas, drawing canvas, handwriting, PencilKit on top of markup, sticker/shape/textbox insertion, or annotating images/PDFs. For plain stroke-only drawing with no markup elements, raw PencilKit (PKCanvasView) is enough — reach for PaperKit when you need the structured markup layer.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple Developer docs via Context7 (/websites/developer_apple). PaperKit has no dedicated Context7 library and its own types (PaperMarkup, PaperMarkupViewController, MarkupEditViewController, FeatureSet) do not surface in the broad Apple library — only the PencilKit foundation it builds on is indexed. API surface verified against Apple's public documentation URLs (developer.apple.com/documentation/PaperKit) cited in references/guide.md. Treat PaperKit-specific signatures as iOS 26 beta-era and confirm against the SDK before shipping.
---

# PaperKit

PaperKit is Apple's system-wide markup layer (the engine behind Notes, Screenshots, QuickLook, Journal), new in iOS/iPadOS/macOS Tahoe/visionOS 26. It builds on PencilKit and PDFKit to give you a drawing canvas plus structured markup elements (shapes, text boxes, images, stickers) with one controller. The deep API reference — every component, the data model, insertion controllers, FeatureSet, HDR, PencilKit integration, SwiftUI wrapping, thumbnails, forward compat, and known iOS 26 beta bugs — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `HOST` — `uikit` (native; PaperKit ships UIKit/AppKit controllers, default) · `swiftui` (wrap `PaperMarkupViewController` in a `UIViewControllerRepresentable`; you own the coordinator + tool-picker lifecycle). There is no first-party SwiftUI view.
2. `FEATURES` — `latest` (start from `FeatureSet.latest`, default; auto-gains new elements on OS updates) · `curated` (start from `.latest`, then `.remove(...)` only what you must — never build up from `FeatureSet()` empty, you'll miss new features).
3. `HDR` — `sdr` (`colorMaximumLinearExposure = 1.0`, default) · `hdr` (set exposure > 1, e.g. device `currentEDRHeadroom`, on **both** the `FeatureSet` and the `PKToolPicker` — mismatched values render differently).

## When to use

Reach for PaperKit when the app needs annotation or markup over content — drawing plus shapes, text boxes, stickers, or images on a canvas (annotating a photo/PDF, a Journal-style page, a screenshot editor). For stroke-only drawing with no structured elements, raw PencilKit (`PKCanvasView`) is lighter and has fewer iOS 26 beta sharp edges. PaperKit requires iOS 26 / iPadOS 26 / macOS Tahoe 26 / visionOS 26 — there is no back-deployment.

## Core rules

- **`PaperMarkup` is the single source of truth.** The model holds both the markup elements and the PencilKit drawing. Persist via `dataRepresentation()`; reload via `PaperMarkup(data:)`. The view controller is a view onto the model, not the store.
- **The `PKToolPicker` must be a strong property.** A tool picker held in a local variable is deallocated and the picker silently never appears. Store it on the owning controller for the canvas's whole lifetime.
- **Gate every load with `PaperMarkup.canOpen(data:)`.** Markup written by a newer OS will fail to open. Check first and fall back to a saved thumbnail — never hand un-openable data to `PaperMarkup(data:)`.
- **Save a thumbnail next to every document.** `markup.draw(in:frame:)` is async; render and persist a thumbnail on every save so forward-incompatible files still show *something*.
- **Use the platform's insertion UI.** `MarkupEditViewController` (iOS/iPadOS/visionOS) and `MarkupToolbarViewController` (macOS) are different types — don't assume one cross-platform API.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll build the `FeatureSet` up from the features I need." | Starting from empty `FeatureSet()` and `.insert(...)`ing locks you out of every element Apple adds in later OS updates. Start from `FeatureSet.latest` and `.remove(...)` only what you must. |
| "The tool picker isn't showing — the API must be broken." | Almost always a deallocated picker (local var) **or** the responder chain. Hold `PKToolPicker` as a property, and on the known beta bug also call `toolPicker.setVisible(true, forFirstResponder: markupController)` *in addition to* `pencilKitResponderState` + `becomeFirstResponder()`. |
| "I'll just open the saved `.data` directly on launch." | Data from a newer PaperKit version throws or silently degrades. Always `PaperMarkup.canOpen(data:)` first, then fall back to the saved thumbnail. Skipping the check ships a "can't open my own file" bug to users who updated their OS. |
| "I set HDR exposure on the feature set, that's enough." | HDR must be set on **both** `FeatureSet.colorMaximumLinearExposure` and `PKToolPicker.colorMaximumLinearExposure`. Setting one leaves the canvas and the ink picker rendering at different dynamic ranges. |
| "Image insertion via `insertNewImage()` isn't working — my code is wrong." | On some Xcode 26 betas image insertion is genuinely broken upstream (documented in the guide's Known Issues). Verify on a current SDK before burning hours; have a UIKit image-insertion fallback if you must ship now. |
| "PaperKit is just PencilKit, I'll use `PKCanvasView` directly." | PaperKit adds the structured markup layer (shapes/text/stickers/images) and the system insertion UI on top of PencilKit. If you only need strokes, use PencilKit; if you need markup elements, don't reinvent them on a bare canvas. |

## Verification gate

Before shipping a PaperKit canvas, confirm every line:

- [ ] `PKToolPicker` is stored as a strong property and lives for the canvas's lifetime (not a local var).
- [ ] Tool picker is wired through `pencilKitResponderState.activeToolPicker` + `toolPickerVisibility` and the controller calls `becomeFirstResponder()`; the `setVisible(_:forFirstResponder:)` fallback is applied if the picker doesn't appear.
- [ ] Persistence goes through `PaperMarkup.dataRepresentation()` / `PaperMarkup(data:)` — the model, not view state, is the source of truth.
- [ ] Every load is guarded by `PaperMarkup.canOpen(data:)` with a thumbnail fallback for version mismatches.
- [ ] A thumbnail is rendered (`markup.draw(in:frame:)`) and saved alongside every document.
- [ ] `FeatureSet` starts from `.latest`; any removals are deliberate.
- [ ] HDR exposure (if used) is set identically on both the `FeatureSet` and the `PKToolPicker`.
- [ ] Correct insertion controller per platform (`MarkupEditViewController` on iOS/iPadOS/visionOS, `MarkupToolbarViewController` on macOS).
- [ ] Image insertion tested on the actual target SDK (known to be broken on some Xcode 26 betas).
- [ ] Deployment target is iOS/iPadOS/macOS Tahoe/visionOS 26+; no back-deployment assumed.

## Deep reference

`references/guide.md` — full component breakdown (`PaperMarkupViewController`, `PaperMarkup`, `MarkupEditViewController`, `MarkupToolbarViewController`), data model save/load/render, `FeatureSet` customization, HDR, PencilKit tool-picker setup and workarounds, SwiftUI `UIViewControllerRepresentable` wrapper, thumbnail generation, forward-compatibility with `canOpen`, delegate methods, best practices, and the iOS 26 beta known-issues list. Load it for any concrete API question.

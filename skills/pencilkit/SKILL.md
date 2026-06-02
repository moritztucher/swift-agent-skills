---
name: pencilkit
description: Add low-latency freehand drawing and Apple Pencil input to an iOS app with PencilKit — PKCanvasView, the PKDrawing model, the PKToolPicker palette, inking/eraser/lasso tools, drawing policy (finger vs pencil), persistence, and rendering to images. Use when the user mentions PencilKit, PKCanvasView, drawing canvas, sketch pad, Apple Pencil, ink, strokes, PKDrawing, PKToolPicker, handwriting capture, signature capture, or annotating with freehand strokes. For structured markup (shapes, text boxes, stickers, images) on top of drawing, use the `paperkit` skill instead — PaperKit is the iOS 26 markup layer built on PencilKit.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple PencilKit docs via Context7 (/websites/developer_apple, developer.apple.com/documentation/pencilkit)
---

# PencilKit

Apple's low-latency stroke-drawing engine — the ink behind Notes, Markup, and Screenshots. It captures Apple Pencil and finger input into vector strokes, renders them with a hardware-accelerated pipeline, and gives you a serializable model (`PKDrawing`) plus the system tool palette (`PKToolPicker`). Available iOS 13+. The deep API reference — canvas setup, SwiftUI wrapping, the tool picker, tools, persistence, image rendering, drawing policy, undo, Pencil Pro, and the PaperKit boundary — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `HOST` — `uikit` (native; `PKCanvasView` is a UIKit view, default) · `swiftui-representable` (wrap `PKCanvasView` in a `UIViewRepresentable` with a Coordinator that owns the delegate and the tool picker — there is no first-party SwiftUI canvas).
2. `TOOLPICKER` — `shared` (use a single long-lived `PKToolPicker()` for the system palette, default) · `none` (custom toolbar; you set `canvasView.tool` yourself and forfeit the Pencil-squeeze palette gesture).
3. `INPUT` — `any` (`drawingPolicy = .anyInput`; finger and pencil both draw) · `pencil-only` (`drawingPolicy = .pencilOnly`; pencil inks, finger pans/scrolls — the natural scrollable-canvas experience) · `default` (`.default`; respects the user's system "Draw with Apple Pencil" setting).

## When to use

Reach for PencilKit when you need freehand strokes only — a sketch pad, signature capture, handwriting input, or a pure-ink annotation overlay. It's lightweight and ships back to iOS 13. If you need structured markup elements (shapes, text boxes, stickers, images) and the system insertion UI on top of drawing, use the `paperkit` skill instead — PaperKit (iOS 26+) wraps a PencilKit drawing and adds the markup layer. Don't reimplement shapes/text on a bare `PKCanvasView`.

## Core rules

- **`PKDrawing` is the source of truth, not `PKCanvasView`.** The canvas captures and renders; the `PKDrawing` value type *is* the content. Persist the drawing, never the view.
- **Persist `dataRepresentation()`, not a rendered image** — a `UIImage` is a one-way flatten that can never be re-edited.
- **Hold the `PKToolPicker` as a strong property** for the canvas's whole lifetime. A local-variable picker deallocates and the palette silently never appears.
- **The canvas must become first responder** or the tool picker stays hidden — `setVisible(true, forFirstResponder:)` does nothing without `becomeFirstResponder()`.
- **Set `drawingPolicy` deliberately** for finger vs. pencil. iOS 13+ for the API; the system tool picker and inks improve on newer OSes automatically (Pencil Pro needs no app code).

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "The tool picker isn't showing — the API must be broken." | Almost always the responder chain or a deallocated picker. Hold `PKToolPicker` as a **strong property**, call `setVisible(true, forFirstResponder: canvas)` **and** `canvas.becomeFirstResponder()`. No first responder = no palette. |
| "I'll make a fresh `PKToolPicker.shared(for: window)` per canvas." | `shared(for:)` is **deprecated**. On iOS 14+ just `PKToolPicker()` — and reuse **one** long-lived picker, switching which responder it targets, rather than spinning up a new one per view. |
| "I'll save the drawing as a PNG so it's easy to display." | A rendered image is a one-way flatten — the strokes are gone, the user can never edit again. Persist `drawing.dataRepresentation()` for editability; render an image only as an export/thumbnail **alongside** the data. |
| "Finger and pencil should both just draw, the default is fine." | The default respects a system setting and may *not* draw with finger. Set `drawingPolicy` explicitly: `.pencilOnly` for scrollable canvases (finger pans), `.anyInput` for finger-first apps. Don't use the deprecated `allowsFingerDrawing` Bool. |
| "I'll just read `canvasView.drawing` in SwiftUI and reassign it every update." | In a `UIViewRepresentable`, reassigning `canvas.drawing` unconditionally on every `updateUIView` drops in-flight strokes and can loop. Wrap in a Coordinator, bridge `canvasViewDrawingDidChange` back to state **async**, and guard `canvas.drawing != drawing` before assigning. |
| "I'll render the drawing to an image on the main thread when exporting." | `image(from:scale:)` is synchronous; for large drawings it hitches the UI. Render big drawings off the main thread (`Task.detached` or the async `draw(in:frame:...)`), and guard `bounds.isNull` first or you'll get a degenerate image. |

## Verification gate

Before shipping a PencilKit canvas, confirm every line:

- [ ] `PKDrawing` (via `dataRepresentation()` / `PKDrawing(data:)`) is the persisted source of truth — not a rendered image, not view state.
- [ ] `PKToolPicker` is stored as a strong property and lives for the canvas's lifetime (not a local var); using `PKToolPicker()`, not the deprecated `shared(for:)`.
- [ ] Picker shown via `setVisible(true, forFirstResponder: canvas)` **and** `canvas.becomeFirstResponder()`; content inset around `frameObscured(in:)` on iPhone.
- [ ] `drawingPolicy` set explicitly (`.pencilOnly` / `.anyInput` / `.default`) — no deprecated `allowsFingerDrawing`.
- [ ] In SwiftUI: `PKCanvasView` wrapped in `UIViewRepresentable` + Coordinator owning the delegate and picker; drawing changes bridged to state asynchronously; assignment guarded by `!=`.
- [ ] `PKDrawing(data:)` errors handled (corrupt/incompatible data falls back, never crashes).
- [ ] Autosave on `canvasViewDrawingDidChange` is debounced, not written every callback.
- [ ] Image export guards `drawing.bounds.isNull`/`.isEmpty` and renders large drawings off the main thread.
- [ ] If structured markup (shapes/text/stickers) is actually needed, switched to the `paperkit` skill instead of reinventing on a bare canvas.

## Deep reference

`references/guide.md` — full canvas setup, the `PKDrawing` model and stroke hierarchy, SwiftUI `UIViewRepresentable` + Coordinator wrapper, the `PKToolPicker` (shared picker, visibility, first-responder requirement, `frameObscured`, iOS 18+ `pencilKitResponderState`), inking/eraser/lasso tools, persistence + debounced autosave, image rendering on/off the main thread, drawing policy, undo, iPadOS 26 / Pencil Pro, the PaperKit boundary, and a quick-reference of key types. Load it for any concrete API question.

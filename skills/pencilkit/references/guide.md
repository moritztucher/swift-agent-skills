# PencilKit — Deep Reference

PencilKit is Apple's low-latency stroke-drawing engine (the ink behind Notes, Markup, Screenshots). It captures Apple Pencil and finger input into vector strokes, renders them with a tuned, hardware-accelerated pipeline, and hands you a serializable model (`PKDrawing`) plus a system tool palette (`PKToolPicker`). Available iOS 13+, iPadOS 13+, Mac Catalyst 13+, macOS 11+, visionOS 1+.

This guide covers the real API: canvas setup, SwiftUI wrapping, the tool picker (and the responder-chain gotcha that hides it), the tools, capturing and persisting drawings, rendering to images, drawing policy, undo, and the boundary with PaperKit.

**API source:** Apple Developer documentation (developer.apple.com/documentation/pencilkit) via Context7 (`/websites/developer_apple`), verified 2026-06-02.

---

## 1. The model: PKCanvasView, PKDrawing, strokes

PencilKit is two layers:

- **`PKCanvasView`** — a `UIScrollView` subclass that *captures* input and *displays* a drawing. It is the view; it is not the storage.
- **`PKDrawing`** — a `struct` that *is* the drawing: an ordered collection of `PKStroke`s. This is your source of truth. Persist this, not the view.

```
PKCanvasView (view, captures + renders)
   └─ .drawing: PKDrawing (value type, the actual content)
          └─ .strokes: [PKStroke]
                 └─ .path: PKStrokePath → [PKStrokePoint] (location, size, opacity, force, azimuth, altitude)
                 └─ .ink: PKInk (type, color)
```

Key relationship: `canvasView.drawing` is a **`var PKDrawing`**. Reading it copies the current content out; assigning a new value replaces what's on screen. Because `PKDrawing` is a value type, you can pass it around, diff it, archive it, and reassign it freely.

### PKDrawing API

```swift
struct PKDrawing {
    init()                                  // empty
    init(data: Data) throws                 // decode persisted data
    init<S>(strokes: S) where S.Element == PKStroke

    var strokes: [PKStroke]                 // read the vector strokes
    var bounds: CGRect                      // tight bounding box of all strokes (empty drawing → .null)

    func dataRepresentation() -> Data       // archive for persistence (the canonical save format)

    // Render a region to a raster image (UIImage on iOS/visionOS, NSImage on macOS)
    func image(from rect: CGRect, scale: CGFloat) -> UIImage

    // Async draw into a CGContext (use for large/off-screen rendering)
    func draw(in context: CGContext, frame: CGRect, from: CGRect, darkUserInterfaceStyle: Bool) async

    // Geometry
    func transformed(using transform: CGAffineTransform) -> PKDrawing
    func appending(_ other: PKDrawing) -> PKDrawing   // merge two drawings
}
```

Notes:
- `dataRepresentation()` is the **only correct persistence format** if you want the drawing to remain editable. It preserves every stroke, point, pressure sample, and ink. A rendered `UIImage` is a one-way flatten — you can never re-edit it.
- `image(from:scale:)` returns a raster snapshot. `scale` is points→pixels (use `UIScreen.main.scale`, or 0 for the native screen scale on `UIImage` semantics — pass the real scale explicitly to be safe). Pass `drawing.bounds` (not the canvas bounds) when you want a tight crop.
- `bounds` of an empty drawing is `.null`; guard before rendering or you'll get a zero/garbage image.
- `transformed(using:)` and `appending(_:)` return **new** drawings (value semantics) — they don't mutate.

---

## 2. Setting up a PKCanvasView (UIKit)

```swift
import PencilKit

final class DrawingViewController: UIViewController {
    let canvasView = PKCanvasView()
    // Hold the tool picker strongly — see §4. A local var deallocates and the picker never shows.
    let toolPicker = PKToolPicker()

    override func viewDidLoad() {
        super.viewDidLoad()

        canvasView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(canvasView)
        NSLayoutConstraint.activate([
            canvasView.topAnchor.constraint(equalTo: view.topAnchor),
            canvasView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            canvasView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        canvasView.delegate = self
        canvasView.drawing = PKDrawing()                 // or a loaded one
        canvasView.tool = PKInkingTool(.pen, color: .label, width: 5)
        canvasView.alwaysBounceVertical = true           // it's a scroll view
        canvasView.backgroundColor = .systemBackground
        canvasView.isOpaque = false                       // transparent canvas over content
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Show the tool picker for this canvas — see §4 for the responder requirement.
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)               // canvas tracks the selected tool
        canvasView.becomeFirstResponder()                // REQUIRED — picker tracks first responder
    }
}

extension DrawingViewController: PKCanvasViewDelegate {
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        // Fires on every stroke add/remove/edit. Debounce before persisting (§6).
    }
    func canvasViewDidFinishRendering(_ canvasView: PKCanvasView) {}
    func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {}
    func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {}
}
```

`PKCanvasView` is a scroll view: it zooms and pans. If you want a fixed-size sketch pad, set `minimumZoomScale = maximumZoomScale = 1` and `isScrollEnabled = false`. For an infinite/large canvas, set `contentSize` larger than the bounds.

---

## 3. Wrapping PKCanvasView in SwiftUI (UIViewRepresentable + Coordinator)

There is no first-party SwiftUI canvas. Wrap `PKCanvasView` in a `UIViewRepresentable`. The Coordinator owns the delegate and bridges drawing changes back to SwiftUI state. **Hold the `PKToolPicker` on the Coordinator** so it lives for the view's lifetime.

```swift
import SwiftUI
import PencilKit

struct CanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var isToolPickerVisible: Bool = true
    var drawingPolicy: PKCanvasViewDrawingPolicy = .anyInput

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        canvas.drawing = drawing
        canvas.drawingPolicy = drawingPolicy
        canvas.tool = PKInkingTool(.pen, color: .label, width: 5)
        canvas.alwaysBounceVertical = true
        context.coordinator.canvas = canvas
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        // Push external model changes in WITHOUT clobbering in-flight strokes.
        if canvas.drawing != drawing { canvas.drawing = drawing }
        canvas.drawingPolicy = drawingPolicy

        // Tool picker lives on the window's scene; set it up once the canvas has a window.
        if isToolPickerVisible {
            context.coordinator.showToolPicker(for: canvas)
        } else {
            context.coordinator.hideToolPicker(for: canvas)
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let parent: CanvasView
        weak var canvas: PKCanvasView?
        let toolPicker = PKToolPicker()      // strong — must outlive makeUIView

        init(_ parent: CanvasView) { self.parent = parent }

        func showToolPicker(for canvas: PKCanvasView) {
            toolPicker.setVisible(true, forFirstResponder: canvas)
            toolPicker.addObserver(canvas)
            canvas.becomeFirstResponder()
        }

        func hideToolPicker(for canvas: PKCanvasView) {
            toolPicker.setVisible(false, forFirstResponder: canvas)
        }

        // Bridge changes back to SwiftUI on the next runloop to avoid
        // "modifying state during view update" warnings.
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            DispatchQueue.main.async {
                self.parent.drawing = canvasView.drawing
            }
        }
    }
}
```

Usage:

```swift
struct EditorScreen: View {
    @State private var drawing = PKDrawing()
    var body: some View {
        CanvasView(drawing: $drawing)
            .ignoresSafeArea()
    }
}
```

Pitfalls specific to the wrapper:
- **Don't reassign `canvas.drawing` on every `updateUIView` unconditionally** — assigning while the user is mid-stroke can drop input and cause a flicker/feedback loop. Guard with `canvas.drawing != drawing`.
- **Mutate SwiftUI state asynchronously** from the delegate (`DispatchQueue.main.async`) — `canvasViewDrawingDidChange` can fire during a view update.
- **The Coordinator must own the tool picker.** If you create a `PKToolPicker` as a local in `makeUIView`, it deallocates and the palette silently never appears.

---

## 4. The tool picker — PKToolPicker (and why it won't show)

`PKToolPicker` is the floating ink palette. Two hard rules dominate everything else:

### Rule 1 — Use one shared/long-lived picker, not a per-view one (iPadOS 14+)

Historically you obtained the picker with `PKToolPicker.shared(for: window)`. **That windowed API is deprecated.** On iOS/iPadOS 14+ you simply create a `PKToolPicker()` and the system coordinates a single floating palette across the app for you. Create **one** and reuse it — do not spin up a fresh `PKToolPicker()` per canvas view in a multi-canvas screen; keep one per editing surface and switch which responder it targets.

```swift
let toolPicker = PKToolPicker()                 // iOS 14+: just init it; hold it strongly
```

### Rule 2 — The canvas must be first responder or the picker stays hidden

The picker tracks the **first responder**. If the canvas never becomes first responder, `setVisible(true,...)` does nothing visible. This is the #1 "the API is broken" false alarm.

```swift
toolPicker.setVisible(true, forFirstResponder: canvasView)
toolPicker.addObserver(canvasView)              // canvas updates its .tool from the picker
canvasView.becomeFirstResponder()               // <-- without this, no palette
```

`canvasView` (a `UIScrollView`/`UIResponder`) returns `true` from `canBecomeFirstResponder` by default in this context. If you embed it where another view steals first responder, the picker hides — that's expected, not a bug.

### Visibility & coordination API

```swift
func setVisible(_ visible: Bool, forFirstResponder responder: UIResponder)
var isVisible: Bool                              // is the palette currently shown
func frameObscured(in view: UIView) -> CGRect    // adjust your content insets around the palette
func addObserver(_ observer: PKToolPickerObserver)
func removeObserver(_ observer: PKToolPickerObserver)
```

Use `frameObscured(in:)` (and `PKToolPickerObserver.toolPickerFramesObscuredDidChange`) to inset your content so the floating palette never covers what the user is drawing on iPhone (where it docks at the bottom).

### iOS 18+ responder-state API (alternative)

Newer OSes expose `view.pencilKitResponderState` for declaring the active picker and its visibility directly on a responder, which is what PaperKit drives:

```swift
canvasView.pencilKitResponderState.activeToolPicker = toolPicker
canvasView.pencilKitResponderState.toolPickerVisibility = .visible   // enum PKToolPickerVisibility
```

For raw PencilKit on iOS 14–17 the `setVisible(_:forFirstResponder:)` + `becomeFirstResponder()` path is the portable one. If the picker still doesn't show on a newer OS, set both the responder state and call `setVisible` as a belt-and-suspenders fallback.

---

## 5. Tools — PKInkingTool, PKEraserTool, PKLassoTool

A canvas has exactly one active `tool` (`var tool: any PKTool`) at a time. The tool picker sets it for you when observing; you can also set it programmatically.

### PKInkingTool

```swift
// InkType cases (iOS 13+; monoline/fountainPen/watercolor/crayon added iOS 17):
//   .pen .marker .pencil .monoline .fountainPen .watercolor .crayon
let pen = PKInkingTool(.pen, color: .systemBlue, width: 5)
let marker = PKInkingTool(.marker, color: .systemYellow, width: 20)

// With Apple Pencil azimuth (tilt-aware tools like fountain pen):
let nib = PKInkingTool(.fountainPen, color: .label, width: nil, azimuth: .pi / 4)

canvasView.tool = pen
```

`width: nil` lets PencilKit pick the ink's default width. `color` is a `UIColor` on iOS/visionOS, `NSColor` on macOS.

### PKEraserTool

```swift
let bitmapEraser = PKEraserTool(.bitmap)        // pixel eraser
let vectorEraser = PKEraserTool(.vector)        // removes whole strokes
canvasView.tool = vectorEraser
```

### PKLassoTool

```swift
canvasView.tool = PKLassoTool()                 // select strokes to move/copy/delete
```

You normally don't need to set these manually — the `PKToolPicker` exposes all three and updates `canvasView.tool` through the observer. Set them in code only for a custom toolbar or a constrained UI (e.g. a "highlighter only" mode).

---

## 6. Capturing & persisting a drawing

**Persist `dataRepresentation()`. Never persist a rendered image if the user must be able to edit later.**

```swift
// Save
func save(_ drawing: PKDrawing, to url: URL) throws {
    let data = drawing.dataRepresentation()
    try data.write(to: url, options: .atomic)
}

// Load
func loadDrawing(from url: URL) throws -> PKDrawing {
    let data = try Data(contentsOf: url)
    return try PKDrawing(data: data)            // throws on corrupt/incompatible data
}
```

`PKDrawing(data:)` throws — always handle the error and fall back to an empty drawing or a saved thumbnail rather than crashing.

### Debounce autosave

`canvasViewDrawingDidChange` fires constantly while drawing. Don't write to disk on every callback. Debounce:

```swift
private var saveTask: Task<Void, Never>?

func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
    let drawing = canvasView.drawing
    saveTask?.cancel()
    saveTask = Task {
        try? await Task.sleep(for: .seconds(1))
        guard !Task.isCancelled else { return }
        try? save(drawing, to: documentURL)
    }
}
```

### Rendering to an image (export / thumbnail)

`image(from:scale:)` is synchronous and runs on the calling thread. For small drawings this is fine on the main thread. For large drawings (many strokes, big bounds), render **off the main thread** to avoid a frame hitch — use the async `draw(in:frame:from:darkUserInterfaceStyle:)` into your own context, or hop to a background queue:

```swift
// Quick thumbnail (small drawing, main thread OK):
let thumb = drawing.image(from: drawing.bounds, scale: UIScreen.main.scale)

// Large export, off the main thread:
func exportImage(_ drawing: PKDrawing, scale: CGFloat) async -> UIImage? {
    let bounds = drawing.bounds
    guard !bounds.isNull, !bounds.isEmpty else { return nil }
    return await Task.detached(priority: .userInitiated) {
        drawing.image(from: bounds, scale: scale)
    }.value
}
```

Guard `bounds.isNull`/`isEmpty` first — rendering an empty drawing yields a degenerate image. For a tight crop use `drawing.bounds`; to match the on-screen frame use the canvas's visible rect instead.

---

## 7. Drawing policy — finger vs. Apple Pencil

Controls which touches draw. **`allowsFingerDrawing` and the old `drawingPolicy` value form are deprecated** — use the `drawingPolicy` property with `PKCanvasViewDrawingPolicy`:

```swift
enum PKCanvasViewDrawingPolicy {
    case `default`    // respects the system "Draw with Apple Pencil" setting; finger pans/scrolls
    case anyInput     // finger AND pencil both draw
    case pencilOnly   // only Apple Pencil draws; finger always pans/scrolls/selects
}

canvasView.drawingPolicy = .pencilOnly
```

Guidance:
- `.pencilOnly` on a scrollable canvas gives the natural iPad experience: pencil inks, finger navigates. Use it whenever the canvas scrolls/zooms.
- `.anyInput` for finger-first apps (sign-here pads, phone-only sketch) where there may be no Pencil.
- `.default` defers to the user's system setting — the most "Apple-native" choice for a notes-style app.

Do **not** use the deprecated `allowsFingerDrawing` Bool; it maps to the same behavior but is going away. Set `drawingPolicy` instead.

---

## 8. Undo / redo

`PKCanvasView` participates in the standard `UndoManager` responder chain — stroke add/erase/lasso edits are registered automatically. You get undo for free if there's an undo manager in the chain.

```swift
// UIKit: the view controller / scene supplies undoManager via the responder chain.
canvasView.undoManager?.undo()
canvasView.undoManager?.redo()
```

In SwiftUI, expose buttons that call `canvas.undoManager?.undo()` (reach the canvas through the Coordinator), or rely on the three-finger / shake gestures the system provides. The tool picker also renders undo/redo affordances on iPad. Don't roll your own stroke-history stack — you'll fight the built-in registration and break the picker's buttons.

---

## 9. iPadOS 26 / Apple Pencil Pro

PencilKit automatically benefits from Pencil Pro hardware (barrel roll affecting azimuth for orientation-aware ink, squeeze surfacing the system tool palette, haptics) without app changes — the system tool picker handles squeeze-to-show-tools and the captured `PKStrokePoint` already carries `azimuth`/`altitude`/`force` from tilt and roll. There is no PencilKit API you must adopt for basic Pencil Pro support; if you build a fully custom palette you forfeit the squeeze-palette gesture, which is another reason to prefer the system `PKToolPicker`. Inks remain forward/backward compatible via `dataRepresentation()`; new ink types added in later OSes decode on older OSes as their closest available ink.

---

## 10. Boundary with PaperKit

**PencilKit is the stroke-drawing engine. PaperKit is the structured-markup layer built on top of it** (iOS/iPadOS/macOS Tahoe/visionOS 26+).

| | PencilKit | PaperKit (`paperkit` skill) |
|---|---|---|
| What it gives you | Freehand ink strokes only | Strokes **plus** shapes, text boxes, images, stickers |
| Core types | `PKCanvasView`, `PKDrawing` | `PaperMarkupViewController`, `PaperMarkup`, `MarkupEditViewController` |
| Persistence | `PKDrawing.dataRepresentation()` | `PaperMarkup.dataRepresentation()` (wraps the `PKDrawing` plus markup) |
| Tool picker | You wire `PKToolPicker` yourself | PaperKit drives `PKToolPicker` via `pencilKitResponderState` |
| Min OS | iOS 13+ | iOS 26+ only, no back-deployment |

**Choose PencilKit when** you need only freehand strokes — a sketch pad, signature capture, handwriting input, an annotation overlay of pure ink. It's lighter, ships back to iOS 13, and has none of PaperKit's iOS 26 beta sharp edges.

**Choose PaperKit (`paperkit` skill) when** you need structured markup elements (shapes/text/stickers/images) and the system insertion UI on top of drawing. PaperKit *contains* a PencilKit drawing — don't reimplement shapes and text on a bare `PKCanvasView`.

They share the same tool picker and the same first-responder/visibility discipline, so the §4 rules apply to both.

---

## 11. Quick reference

| Need | API |
|---|---|
| The view | `PKCanvasView()` (`UIScrollView` subclass) |
| Active tool | `canvasView.tool = PKInkingTool(.pen, color:, width:)` |
| Current content | `canvasView.drawing` (`var PKDrawing`) |
| Change callback | `PKCanvasViewDelegate.canvasViewDrawingDidChange(_:)` |
| Ink tool | `PKInkingTool(_:color:width:)`, `.pen/.marker/.pencil/.monoline/.fountainPen/.watercolor/.crayon` |
| Eraser | `PKEraserTool(.bitmap)` / `PKEraserTool(.vector)` |
| Lasso select | `PKLassoTool()` |
| Tool palette | `PKToolPicker()` (iOS 14+; hold strongly) |
| Show palette | `setVisible(true, forFirstResponder: canvas)` + `canvas.becomeFirstResponder()` |
| Palette obscured rect | `toolPicker.frameObscured(in:)` |
| iOS 18+ palette control | `view.pencilKitResponderState.activeToolPicker / .toolPickerVisibility` |
| Save (editable) | `drawing.dataRepresentation()` → `Data` |
| Load | `try PKDrawing(data:)` |
| Export image | `drawing.image(from: drawing.bounds, scale:)` |
| Async render | `drawing.draw(in:frame:from:darkUserInterfaceStyle:) async` |
| Bounding box | `drawing.bounds` (guard `.isNull`) |
| Transform | `drawing.transformed(using: CGAffineTransform)` |
| Merge | `drawing.appending(_:)` |
| Finger/pencil policy | `canvasView.drawingPolicy = .pencilOnly / .anyInput / .default` |
| Undo | `canvasView.undoManager?.undo()` |

**Deprecated — do not use:** `PKToolPicker.shared(for:)` (use `PKToolPicker()` on iOS 14+), `canvasView.allowsFingerDrawing` and the deprecated `drawingPolicy` value form (use the `drawingPolicy` *property* with `PKCanvasViewDrawingPolicy`).

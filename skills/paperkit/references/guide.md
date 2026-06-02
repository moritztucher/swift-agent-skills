# PaperKit Framework Guide

A comprehensive guide for using Apple's PaperKit framework to integrate drawing and markup capabilities into iOS 26+, iPadOS 26+, macOS Tahoe 26+, and visionOS 26+ applications.

---

## Table of Contents

1. [Overview](#overview)
2. [Getting Started](#getting-started)
3. [Core Components](#core-components)
4. [PaperMarkup Data Model](#papermarkup-data-model)
5. [PaperMarkupViewController](#papermarkupviewcontroller)
6. [MarkupEditViewController (iOS/iPadOS/visionOS)](#markupeditviewcontroller-iosipadosvisionos)
7. [MarkupToolbarViewController (macOS)](#markuptoolbarviewcontroller-macos)
8. [FeatureSet Customization](#featureset-customization)
9. [HDR Support](#hdr-support)
10. [PencilKit Integration](#pencilkit-integration)
11. [SwiftUI Integration](#swiftui-integration)
12. [Rendering and Thumbnails](#rendering-and-thumbnails)
13. [Forward Compatibility](#forward-compatibility)
14. [Delegate Methods](#delegate-methods)
15. [Best Practices](#best-practices)
16. [Known Issues and Workarounds](#known-issues-and-workarounds)

---

## Overview

PaperKit is the framework that powers Apple's unique markup experience system-wide. It is used in apps like Notes, Screenshots, QuickLook, and the Journal app. PaperKit is the easiest way to get rich markup capabilities in any app.

### Key Features

- **Drawing Canvas**: Full PencilKit drawing support
- **Markup Elements**: Shapes, images, textboxes, stickers, and more
- **Cross-Platform**: iOS, iPadOS, macOS Tahoe, and visionOS support
- **HDR Support**: High dynamic range markup with the calligraphy reed tool
- **Forward Compatibility**: Built-in version checking and thumbnail rendering

### Requirements

- iOS 26.0+, iPadOS 26.0+, macOS Tahoe 26.0+, visionOS 26.0+
- Apple Pencil support (optional, but recommended for drawing)

### Import

```swift
import PaperKit
import PencilKit  // Required for tool picker integration
```

### Relationship to Other Frameworks

PaperKit builds on top of PencilKit and PDFKit to provide a consistent way to add drawing and shapes in your app. It combines the drawing capabilities of PencilKit with structured markup elements.

---

## Getting Started

### Minimal UIKit Example

```swift
import UIKit
import PaperKit
import PencilKit

class MarkupViewController: UIViewController {
    private var paperMarkup: PaperMarkup!
    private var markupController: PaperMarkupViewController!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize the data model
        paperMarkup = PaperMarkup(frame: view.bounds)

        // Create markup controller with latest features
        markupController = PaperMarkupViewController(
            markup: paperMarkup,
            supportedFeatureSet: .latest
        )

        // Add as child view controller
        addChild(markupController)
        view.addSubview(markupController.view)
        markupController.view.frame = view.bounds
        markupController.didMove(toParent: self)

        // Set up tool picker
        setupToolPicker()
    }

    private func setupToolPicker() {
        let toolPicker = PKToolPicker()
        toolPicker.addObserver(markupController)
        markupController.pencilKitResponderState.activeToolPicker = toolPicker
        markupController.pencilKitResponderState.toolPickerVisibility = .visible
        markupController.becomeFirstResponder()
    }
}
```

---

## Core Components

PaperKit has three main components:

### 1. PaperMarkupViewController

The markup controller that interactively creates and displays PaperKit markup and drawing.

### 2. PaperMarkup

The data model container that handles:
- Saving and loading markup data
- Saving and loading PencilKit drawing data
- Rendering the markup

### 3. Insertion Controllers

Platform-specific controllers for adding markup elements:
- **iOS/iPadOS/visionOS 26**: `MarkupEditViewController`
- **macOS Tahoe**: `MarkupToolbarViewController`

---

## PaperMarkup Data Model

The `PaperMarkup` class is the central data model for storing and managing markup content.

### Initialization

```swift
// Initialize with frame
let paperMarkup = PaperMarkup(frame: CGRect(x: 0, y: 0, width: 800, height: 600))

// Initialize with existing data
let paperMarkup = try PaperMarkup(data: savedData)
```

### Saving Data

```swift
func saveMarkup() throws {
    let data = try paperMarkup.dataRepresentation()
    // Save data to disk or database
    try data.write(to: fileURL)
}
```

### Loading Data

```swift
func loadMarkup(from url: URL) throws -> PaperMarkup {
    let data = try Data(contentsOf: url)
    return try PaperMarkup(data: data)
}
```

### Rendering

```swift
func renderThumbnail(size: CGSize) async -> UIImage? {
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { context in
        let rect = CGRect(origin: .zero, size: size)
        Task {
            await paperMarkup.draw(in: context.cgContext, frame: rect)
        }
    }
}
```

---

## PaperMarkupViewController

The main view controller for interactive markup editing.

### Basic Setup

```swift
class DocumentViewController: UIViewController {
    private var markupController: PaperMarkupViewController!
    private var paperMarkup: PaperMarkup!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize data model
        paperMarkup = PaperMarkup(frame: view.bounds)

        // Create controller with full feature set
        markupController = PaperMarkupViewController(
            markup: paperMarkup,
            supportedFeatureSet: .latest
        )

        // Configure delegate
        markupController.delegate = self

        // Embed in view hierarchy
        addChild(markupController)
        view.addSubview(markupController.view)
        markupController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            markupController.view.topAnchor.constraint(equalTo: view.topAnchor),
            markupController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            markupController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            markupController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        markupController.didMove(toParent: self)
    }
}
```

### Observable Conformance

The markup controller conforms to `Observable`, providing an alternative to using a delegate for managing state and updates:

```swift
@Observable
class MarkupManager {
    var markupController: PaperMarkupViewController?

    func observeChanges() {
        // The controller's state changes can be observed directly
        // since it conforms to Observable
    }
}
```

---

## MarkupEditViewController (iOS/iPadOS/visionOS)

On iOS, iPadOS, and visionOS 26, the `MarkupEditViewController` provides an insertion menu for adding markup elements to the canvas.

### Setup

```swift
class MarkupViewController: UIViewController {
    private var markupEditController: MarkupEditViewController!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Create insertion menu controller
        markupEditController = MarkupEditViewController(
            supportedFeatureSet: .latest
        )
        markupEditController.delegate = self

        // Configure as popover
        setupInsertionButton()
    }

    private func setupInsertionButton() {
        let insertButton = UIBarButtonItem(
            systemItem: .add,
            primaryAction: UIAction { [weak self] _ in
                self?.showInsertionMenu()
            }
        )
        navigationItem.rightBarButtonItem = insertButton
    }

    private func showInsertionMenu() {
        markupEditController.modalPresentationStyle = .popover
        markupEditController.popoverPresentationController?.barButtonItem =
            navigationItem.rightBarButtonItem
        present(markupEditController, animated: true)
    }
}

// MARK: - MarkupEditViewController.Delegate

extension MarkupViewController: MarkupEditViewController.Delegate {
    // Implement delegate methods for handling markup element insertion
}
```

---

## MarkupToolbarViewController (macOS)

On macOS Tahoe, the `MarkupToolbarViewController` provides a toolbar with drawing tools and annotation buttons.

### Setup

```swift
import AppKit
import PaperKit

class MacMarkupViewController: NSViewController {
    private var markupToolbarController: MarkupToolbarViewController!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Create toolbar controller
        markupToolbarController = MarkupToolbarViewController(
            supportedFeatureSet: .latest
        )
        markupToolbarController.delegate = self

        // Add to view hierarchy
        addChild(markupToolbarController)
        // Configure toolbar placement
    }
}

// MARK: - MarkupToolbarViewController.Delegate

extension MacMarkupViewController: MarkupToolbarViewController.Delegate {
    // Implement delegate methods for toolbar interactions
}
```

---

## FeatureSet Customization

The `FeatureSet` defines the markup functionality available in your app.

### Using Latest Features

```swift
// Get the full set of markup features
let featureSet = FeatureSet.latest
```

### Customizing Features

```swift
// Start with latest and customize
var featureSet = FeatureSet.latest

// Remove specific features
featureSet.remove(.stickers)
featureSet.remove(.text)

// Insert specific features
featureSet.insert(.shapes)
featureSet.insert(.images)
```

### Creating Controllers with Custom FeatureSet

```swift
// Markup controller with custom features
let markupController = PaperMarkupViewController(
    markup: paperMarkup,
    supportedFeatureSet: featureSet
)

// Insertion controller with matching features
let editController = MarkupEditViewController(
    supportedFeatureSet: featureSet
)
```

### Available Features

| Feature | Description |
|---------|-------------|
| `.drawing` | PencilKit drawing |
| `.shapes` | Geometric shapes |
| `.text` | Text boxes |
| `.images` | Image insertion |
| `.stickers` | Sticker elements |

---

## HDR Support

PaperKit supports High Dynamic Range (HDR) markup, enhancing visual quality especially with tools like the calligraphy reed tool introduced in PencilKit.

### Enabling HDR

```swift
// Configure feature set for HDR
var featureSet = FeatureSet.latest

// Set HDR exposure (values greater than 1 enable HDR)
// Value of 4 typically provides good HDR effect
featureSet.colorMaximumLinearExposure = 4.0

// For SDR markup, use 1.0
featureSet.colorMaximumLinearExposure = 1.0
```

### HDR with Tool Picker

```swift
let toolPicker = PKToolPicker()

// Enable HDR inks in tool picker
toolPicker.colorMaximumLinearExposure = 4.0

// The value will tone-map down to the supported HDR headroom
// for your device's screen
```

### Using Screen's HDR Headroom

```swift
// Get the screen's supported HDR value
if let screen = view.window?.screen {
    let maxExposure = screen.currentEDRHeadroom
    featureSet.colorMaximumLinearExposure = maxExposure
    toolPicker.colorMaximumLinearExposure = maxExposure
}
```

---

## PencilKit Integration

PaperKit integrates closely with PencilKit for drawing functionality.

### Setting Up Tool Picker

```swift
class MarkupViewController: UIViewController {
    private var toolPicker: PKToolPicker!
    private var markupController: PaperMarkupViewController!

    func setupToolPicker() {
        toolPicker = PKToolPicker()

        // Configure HDR if desired
        toolPicker.colorMaximumLinearExposure = 4.0

        // Register markup controller as observer
        toolPicker.addObserver(markupController)

        // Assign to responder state
        markupController.pencilKitResponderState.activeToolPicker = toolPicker
        markupController.pencilKitResponderState.toolPickerVisibility = .visible

        // Make markup controller first responder
        markupController.becomeFirstResponder()
    }
}
```

### Tool Picker Visibility Control

```swift
// Show tool picker
markupController.pencilKitResponderState.toolPickerVisibility = .visible

// Hide tool picker
markupController.pencilKitResponderState.toolPickerVisibility = .hidden

// Automatic visibility based on context
markupController.pencilKitResponderState.toolPickerVisibility = .automatic
```

### Workaround for Tool Picker Display Issues

If the tool picker doesn't show using the standard approach, use this workaround:

```swift
func setupToolPickerWithWorkaround() {
    let toolPicker = PKToolPicker()
    toolPicker.colorMaximumLinearExposure = 4.0

    // Use setVisible for first responder
    toolPicker.setVisible(true, forFirstResponder: markupController)
    toolPicker.addObserver(markupController)

    // Also set responder state properties
    markupController.pencilKitResponderState.activeToolPicker = toolPicker
    markupController.pencilKitResponderState.toolPickerVisibility = .visible

    markupController.becomeFirstResponder()
}
```

---

## SwiftUI Integration

PaperKit is designed for UIKit, so integrating it with SwiftUI requires creating a `UIViewControllerRepresentable` wrapper.

### Basic SwiftUI Wrapper

```swift
import SwiftUI
import PaperKit
import PencilKit

struct PaperKitView: UIViewControllerRepresentable {
    @Binding var paperMarkup: PaperMarkup?

    func makeUIViewController(context: Context) -> PaperKitHostingController {
        let controller = PaperKitHostingController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: PaperKitHostingController, context: Context) {
        if let markup = paperMarkup {
            uiViewController.updateMarkup(markup)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PaperKitHostingControllerDelegate {
        var parent: PaperKitView

        init(_ parent: PaperKitView) {
            self.parent = parent
        }

        func markupDidChange(_ markup: PaperMarkup) {
            parent.paperMarkup = markup
        }
    }
}
```

### Hosting Controller

```swift
protocol PaperKitHostingControllerDelegate: AnyObject {
    func markupDidChange(_ markup: PaperMarkup)
}

class PaperKitHostingController: UIViewController {
    weak var delegate: PaperKitHostingControllerDelegate?

    private var paperMarkup: PaperMarkup!
    private var markupController: PaperMarkupViewController!
    private var toolPicker: PKToolPicker!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupMarkupController()
        setupToolPicker()
    }

    private func setupMarkupController() {
        paperMarkup = PaperMarkup(frame: view.bounds)

        markupController = PaperMarkupViewController(
            markup: paperMarkup,
            supportedFeatureSet: .latest
        )

        addChild(markupController)
        view.addSubview(markupController.view)
        markupController.view.frame = view.bounds
        markupController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        markupController.didMove(toParent: self)
    }

    private func setupToolPicker() {
        toolPicker = PKToolPicker()
        toolPicker.colorMaximumLinearExposure = 4.0
        toolPicker.setVisible(true, forFirstResponder: markupController)
        toolPicker.addObserver(markupController)
        markupController.pencilKitResponderState.activeToolPicker = toolPicker
        markupController.pencilKitResponderState.toolPickerVisibility = .visible
        markupController.becomeFirstResponder()
    }

    func updateMarkup(_ markup: PaperMarkup) {
        paperMarkup = markup
        // Reconfigure controller with new markup if needed
    }
}
```

### Using in SwiftUI View

```swift
struct DrawingView: View {
    @State private var paperMarkup: PaperMarkup?

    var body: some View {
        VStack {
            PaperKitView(paperMarkup: $paperMarkup)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                Button("Save") {
                    saveMarkup()
                }

                Button("Clear") {
                    paperMarkup = nil
                }
            }
            .padding()
        }
    }

    private func saveMarkup() {
        guard let markup = paperMarkup else { return }
        // Save markup data
    }
}
```

---

## Rendering and Thumbnails

PaperKit provides tools for generating thumbnails and rendering markup.

### Generating Thumbnails

```swift
func generateThumbnail(for markup: PaperMarkup, size: CGSize) async -> UIImage? {
    // Create a graphics context
    let renderer = UIGraphicsImageRenderer(size: size)

    return await withCheckedContinuation { continuation in
        Task {
            let image = renderer.image { context in
                let rect = CGRect(origin: .zero, size: size)
                // Use the async draw function
                await markup.draw(in: context.cgContext, frame: rect)
            }
            continuation.resume(returning: image)
        }
    }
}
```

### Thumbnail for Preview

```swift
class MarkupDocument {
    var markup: PaperMarkup
    var thumbnail: UIImage?

    func updateThumbnail() async {
        let thumbnailSize = CGSize(width: 200, height: 200)
        thumbnail = await generateThumbnail(for: markup, size: thumbnailSize)
    }

    func save() async throws {
        // Generate and save thumbnail alongside markup data
        await updateThumbnail()

        let markupData = try markup.dataRepresentation()
        try markupData.write(to: markupFileURL)

        if let thumbnailData = thumbnail?.pngData() {
            try thumbnailData.write(to: thumbnailFileURL)
        }
    }
}
```

---

## Forward Compatibility

PaperKit provides tools for handling version mismatches and ensuring forward compatibility.

### Version Checking

```swift
func loadMarkup(from url: URL) throws -> PaperMarkup? {
    let data = try Data(contentsOf: url)

    // Check content version before loading
    if PaperMarkup.canOpen(data: data) {
        return try PaperMarkup(data: data)
    } else {
        // Version mismatch - handle gracefully
        return nil
    }
}
```

### Handling Version Mismatches

Two common approaches for handling version mismatches:

```swift
enum MarkupLoadResult {
    case success(PaperMarkup)
    case versionMismatch(thumbnail: UIImage?)
    case error(Error)
}

func loadMarkupWithFallback(from url: URL) -> MarkupLoadResult {
    do {
        let data = try Data(contentsOf: url)

        if PaperMarkup.canOpen(data: data) {
            let markup = try PaperMarkup(data: data)
            return .success(markup)
        } else {
            // Load pre-rendered thumbnail instead
            let thumbnailURL = url.deletingPathExtension()
                .appendingPathExtension("thumbnail.png")
            if let thumbnailData = try? Data(contentsOf: thumbnailURL),
               let thumbnail = UIImage(data: thumbnailData) {
                return .versionMismatch(thumbnail: thumbnail)
            }
            return .versionMismatch(thumbnail: nil)
        }
    } catch {
        return .error(error)
    }
}
```

### Best Practice: Save Thumbnails

```swift
func saveMarkupWithThumbnail(_ markup: PaperMarkup, to url: URL) async throws {
    // Save markup data
    let markupData = try markup.dataRepresentation()
    try markupData.write(to: url)

    // Generate and save thumbnail for forward compatibility
    let thumbnailSize = CGSize(width: 400, height: 400)
    if let thumbnail = await generateThumbnail(for: markup, size: thumbnailSize),
       let thumbnailData = thumbnail.pngData() {
        let thumbnailURL = url.deletingPathExtension()
            .appendingPathExtension("thumbnail.png")
        try thumbnailData.write(to: thumbnailURL)
    }
}
```

---

## Delegate Methods

### PaperMarkupViewController Delegate

The markup controller includes a delegate for custom handling of callbacks:

```swift
extension MarkupViewController: PaperMarkupViewControllerDelegate {
    func markupController(_ controller: PaperMarkupViewController,
                         markupDidChange markup: PaperMarkup) {
        // Auto-save modifications
        Task {
            try? await saveMarkup(markup)
        }
    }
}
```

### MarkupEditViewController.Delegate

Handle insertion menu interactions:

```swift
extension MarkupViewController: MarkupEditViewController.Delegate {
    func markupEditController(_ controller: MarkupEditViewController,
                             didSelectElement element: MarkupElement) {
        // Handle element selection
    }

    func markupEditControllerDidCancel(_ controller: MarkupEditViewController) {
        // Handle cancellation
        dismiss(animated: true)
    }
}
```

### MarkupToolbarViewController.Delegate (macOS)

Handle toolbar interactions on macOS:

```swift
extension MacMarkupViewController: MarkupToolbarViewController.Delegate {
    func toolbarController(_ controller: MarkupToolbarViewController,
                          didSelectTool tool: MarkupTool) {
        // Handle tool selection
    }
}
```

---

## Best Practices

### 1. Always Use FeatureSet.latest as Starting Point

```swift
// GOOD - Stay up to date with new features
var featureSet = FeatureSet.latest
featureSet.remove(.stickers)  // Customize if needed

// LESS IDEAL - May miss new features
let featureSet = FeatureSet()
featureSet.insert(.drawing)
featureSet.insert(.shapes)
```

### 2. Save Thumbnails for Forward Compatibility

```swift
// GOOD - Always save thumbnails alongside markup
func save() async throws {
    try await saveMarkupWithThumbnail(markup, to: fileURL)
}

// BAD - No fallback for version mismatches
func save() throws {
    let data = try markup.dataRepresentation()
    try data.write(to: fileURL)
}
```

### 3. Keep Tool Picker Reference Strong

```swift
// GOOD - Store tool picker as property
class MarkupViewController: UIViewController {
    private var toolPicker: PKToolPicker!  // Strong reference
}

// BAD - Tool picker may be deallocated
func setupToolPicker() {
    let toolPicker = PKToolPicker()  // Local variable - will be deallocated
    toolPicker.addObserver(markupController)
}
```

### 4. Handle Version Mismatches Gracefully

```swift
// GOOD - Show thumbnail and upgrade prompt
if case .versionMismatch(let thumbnail) = loadResult {
    showUpgradePrompt(with: thumbnail)
}

// BAD - Show error with no context
if case .versionMismatch = loadResult {
    showError("Cannot open file")
}
```

### 5. Configure HDR Consistently

```swift
// GOOD - Match HDR settings across feature set and tool picker
featureSet.colorMaximumLinearExposure = 4.0
toolPicker.colorMaximumLinearExposure = 4.0

// INCONSISTENT - May cause visual differences
featureSet.colorMaximumLinearExposure = 4.0
// toolPicker uses default SDR
```

---

## Known Issues and Workarounds

### Issue: Tool Picker Not Showing

Using Apple's suggested code, the tool picker may not appear.

**Workaround:**

```swift
let toolPicker = PKToolPicker()
toolPicker.colorMaximumLinearExposure = 4

// Use setVisible in addition to responder state
toolPicker.setVisible(true, forFirstResponder: markupController)
toolPicker.addObserver(markupController)

markupController.pencilKitResponderState.activeToolPicker = toolPicker
markupController.pencilKitResponderState.toolPickerVisibility = .visible
markupController.becomeFirstResponder()
```

### Issue: Image Insertion Not Working

In some Xcode 26 betas, image functionality may be entirely broken. The `insertNewImage()` function on `PaperMarkup` may not display anything.

**Workaround:** Wait for a future beta/release that fixes this issue, or implement custom image insertion using standard UIKit.

### Issue: Limited Documentation

Apple's documentation for PaperKit is not particularly clear, and no demo project was provided with the WWDC presentation.

**Workaround:** Refer to community-created demo projects for UIKit and SwiftUI implementations.

---

## Quick Reference

### Key Types

| Type | Purpose |
|------|---------|
| `PaperMarkup` | Data model for markup content |
| `PaperMarkupViewController` | Interactive markup editing controller |
| `MarkupEditViewController` | Insertion menu (iOS/iPadOS/visionOS) |
| `MarkupToolbarViewController` | Toolbar controller (macOS) |
| `FeatureSet` | Defines available markup features |

### Key Properties

| Property | Type | Purpose |
|----------|------|---------|
| `pencilKitResponderState` | Responder State | Tool picker configuration |
| `activeToolPicker` | `PKToolPicker?` | Current tool picker |
| `toolPickerVisibility` | Visibility | Tool picker display state |
| `colorMaximumLinearExposure` | `Float` | HDR exposure setting |

### Feature Set Values

| Feature | Description |
|---------|-------------|
| `.latest` | All current features |
| `.drawing` | PencilKit drawing |
| `.shapes` | Geometric shapes |
| `.text` | Text boxes |
| `.images` | Image insertion |
| `.stickers` | Sticker elements |

---

## Resources

- [PaperKit | Apple Developer Documentation](https://developer.apple.com/documentation/PaperKit)
- [Meet PaperKit - WWDC25](https://developer.apple.com/videos/play/wwdc2025/285/)
- [MarkupEditViewController.Delegate | Apple Developer Documentation](https://developer.apple.com/documentation/paperkit/markupeditviewcontroller/delegate-swift.protocol)
- [MarkupToolbarViewController.Delegate | Apple Developer Documentation](https://developer.apple.com/documentation/paperkit/markuptoolbarviewcontroller/delegate-swift.protocol)
- [PencilKit | Apple Developer Documentation](https://developer.apple.com/documentation/pencilkit)
- [Using PaperKit from SwiftUI | Clarkezone](https://clarkezone.net/posts/paperkit-swiftui-crosspost/)
- [Meet PaperKit, but with a working demo | Marco Longobardi](https://medium.com/@marco.longobardi997/meet-paperkit-but-with-a-working-demo-349e62e5587c)

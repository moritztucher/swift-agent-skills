# AppKit Development Guide for macOS

A comprehensive guide for macOS development using AppKit, with comparisons to UIKit for iOS developers.

---

## Table of Contents

1. [Overview](#overview)
2. [Key Differences from UIKit](#key-differences-from-uikit)
3. [Windows and Window Controllers](#windows-and-window-controllers)
4. [Views and View Controllers](#views-and-view-controllers)
5. [Responder Chain](#responder-chain)
6. [Layer-Backed Views](#layer-backed-views)
7. [Controls and NSCell](#controls-and-nscell)
8. [Animation](#animation)
9. [SwiftUI Integration](#swiftui-integration)
10. [Common Patterns](#common-patterns)
11. [Best Practices](#best-practices)

---

## Overview

AppKit is Apple's framework for building macOS applications. While it shares conceptual similarities with UIKit, there are significant architectural differences.

### Import

```swift
import AppKit
// or
import Cocoa  // Includes AppKit + Foundation
```

### Key Classes

| AppKit | UIKit Equivalent | Purpose |
|--------|------------------|---------|
| `NSApplication` | `UIApplication` | App lifecycle management |
| `NSWindow` | `UIWindow` | Window management |
| `NSWindowController` | - | Window-level controller |
| `NSViewController` | `UIViewController` | View management |
| `NSView` | `UIView` | Visual elements |
| `NSButton` | `UIButton` | Buttons |
| `NSTextField` | `UITextField`/`UILabel` | Text input/display |
| `NSTableView` | `UITableView` | Table display |
| `NSCollectionView` | `UICollectionView` | Grid display |
| `NSStackView` | `UIStackView` | Layout container |

---

## Key Differences from UIKit

### 1. Window Architecture

**Critical difference:** `NSWindow` is NOT a view subclass (unlike `UIWindow`).

```swift
// UIKit
let window = UIWindow(frame: UIScreen.main.bounds)
window.rootViewController = viewController

// AppKit
let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
    styleMask: [.titled, .closable, .miniaturizable, .resizable],
    backing: .buffered,
    defer: false
)
window.contentViewController = viewController
window.contentView = customView  // Alternative
```

### 2. Coordinate System

AppKit origin is **lower-left** (not upper-left like UIKit).

```swift
class FlippedView: NSView {
    override var isFlipped: Bool { true }  // Use iOS-style coordinates
}
```

### 3. Layer Backing

Views are **not** layer-backed by default (unlike UIKit).

```swift
// Enable layer backing
view.wantsLayer = true
```

### 4. Multiple Windows

Mac apps commonly have multiple windows (unlike iOS single-window paradigm).

```swift
// Create additional window
let newWindow = NSWindow(...)
newWindow.makeKeyAndOrderFront(nil)
```

---

## Windows and Window Controllers

### Creating a Window Programmatically

```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window?.title = "My App"
        window?.center()
        window?.contentViewController = MainViewController()
        window?.makeKeyAndOrderFront(nil)
    }
}
```

### NSWindowController

Use `NSWindowController` for complex window management:

```swift
class MainWindowController: NSWindowController {
    convenience init() {
        self.init(windowNibName: "MainWindow")
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        // Configure window
    }
}

// Or programmatically
class MainWindowController: NSWindowController {
    init(contentViewController: NSViewController) {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)
        window.contentViewController = contentViewController
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
```

### Window Style Masks

```swift
let styleMask: NSWindow.StyleMask = [
    .titled,           // Title bar
    .closable,         // Close button
    .miniaturizable,   // Minimize button
    .resizable,        // Resizable
    .fullSizeContentView,  // Content extends under title bar
    .borderless,       // No chrome (for custom windows)
]
```

### Window Levels

```swift
window.level = .normal        // Default
window.level = .floating      // Floats above normal windows
window.level = .modalPanel    // Modal dialogs
window.level = .mainMenu      // Menu level
```

---

## Views and View Controllers

### NSViewController

```swift
class MainViewController: NSViewController {
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        // View about to appear
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        // View appeared
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        // View about to disappear
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        // View disappeared
    }

    private func setupUI() {
        let label = NSTextField(labelWithString: "Hello, macOS!")
        label.frame = NSRect(x: 20, y: 20, width: 200, height: 24)
        view.addSubview(label)
    }
}
```

### @ViewLoading Property Wrapper (macOS 13.3+)

```swift
class MyViewController: NSViewController {
    @ViewLoading var customView: CustomView

    override func loadView() {
        customView = CustomView()
        view = customView
    }
}
```

### NSView Custom Drawing

```swift
class CustomView: NSView {
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw background
        NSColor.windowBackgroundColor.setFill()
        dirtyRect.fill()

        // Draw custom content
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 10, dy: 10),
                                 xRadius: 8, yRadius: 8)
        NSColor.systemBlue.setFill()
        path.fill()
    }
}
```

### Auto Layout

```swift
class LayoutViewController: NSViewController {
    override func loadView() {
        view = NSView()

        let label = NSTextField(labelWithString: "Centered Label")
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}
```

### NSStackView

```swift
let stackView = NSStackView()
stackView.orientation = .vertical
stackView.alignment = .leading
stackView.spacing = 8
stackView.distribution = .fill

stackView.addArrangedSubview(label1)
stackView.addArrangedSubview(label2)
stackView.addArrangedSubview(button)
```

---

## Responder Chain

### Action Methods

AppKit enforces strict action method signatures:

```swift
class MyViewController: NSViewController {
    @objc func buttonClicked(_ sender: NSButton) {
        print("Button clicked")
    }

    @IBAction func menuItemSelected(_ sender: NSMenuItem) {
        print("Menu item: \(sender.title)")
    }
}
```

### First Responder

```swift
// Make view first responder
window?.makeFirstResponder(textField)

// Check first responder
if window?.firstResponder === textField {
    // textField is first responder
}
```

### Key Event Handling

```swift
class KeyHandlingView: NSView {
    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36:  // Return key
            handleReturn()
        case 53:  // Escape key
            handleEscape()
        default:
            super.keyDown(with: event)
        }
    }

    override func flagsChanged(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            // Command key pressed
        }
    }
}
```

### Mouse Event Handling

```swift
class InteractiveView: NSView {
    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        print("Mouse down at: \(location)")
    }

    override func mouseDragged(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        print("Dragging at: \(location)")
    }

    override func mouseUp(with event: NSEvent) {
        print("Mouse up")
    }

    // Tracking area for hover
    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    override func mouseEntered(with event: NSEvent) {
        print("Mouse entered")
    }

    override func mouseExited(with event: NSEvent) {
        print("Mouse exited")
    }
}
```

---

## Layer-Backed Views

### Enabling Layer Backing

```swift
// Enable for single view
view.wantsLayer = true

// Enable for entire view hierarchy (set on content view)
window.contentView?.wantsLayer = true
```

### Layer Properties

```swift
// DON'T interact with layer directly for owned layers
// Instead, use view properties or updateLayer

class LayeredView: NSView {
    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.backgroundColor = NSColor.systemBlue.cgColor
        layer?.cornerRadius = 8
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
    }
}
```

### Optimizing with canDrawSubviewsIntoLayer

```swift
// Composites multiple views into single backing layer
containerView.canDrawSubviewsIntoLayer = true
```

---

## Controls and NSCell

### NSButton

```swift
// Push button
let button = NSButton(title: "Click Me", target: self, action: #selector(buttonClicked))
button.bezelStyle = .rounded

// Checkbox
let checkbox = NSButton(checkboxWithTitle: "Enable", target: self, action: #selector(checkboxChanged))

// Radio button
let radio = NSButton(radioButtonWithTitle: "Option A", target: self, action: #selector(radioChanged))

// Image button
let imageButton = NSButton(image: NSImage(systemSymbolName: "gear", accessibilityDescription: nil)!,
                           target: self, action: #selector(settingsClicked))
imageButton.isBordered = false
```

### Button Bezel Styles

```swift
button.bezelStyle = .rounded          // Standard push button
button.bezelStyle = .regularSquare    // Square button
button.bezelStyle = .texturedRounded  // Toolbar style
button.bezelStyle = .inline           // Inline style
button.bezelStyle = .circular         // Round button
```

### NSTextField

```swift
// Label (non-editable)
let label = NSTextField(labelWithString: "Hello")

// Editable text field
let textField = NSTextField()
textField.placeholderString = "Enter text..."
textField.delegate = self

// Wrapping label
let wrappingLabel = NSTextField(wrappingLabelWithString: "Long text that wraps...")
```

### NSTextField Delegate

```swift
extension MyViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        print("Text changed: \(textField.stringValue)")
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        print("Editing ended")
    }
}
```

### NSPopUpButton (Dropdown)

```swift
let popup = NSPopUpButton()
popup.addItems(withTitles: ["Option 1", "Option 2", "Option 3"])
popup.target = self
popup.action = #selector(popupChanged)

@objc func popupChanged(_ sender: NSPopUpButton) {
    print("Selected: \(sender.titleOfSelectedItem ?? "")")
}
```

### NSSlider

```swift
let slider = NSSlider(value: 0.5, minValue: 0, maxValue: 1,
                      target: self, action: #selector(sliderChanged))

@objc func sliderChanged(_ sender: NSSlider) {
    print("Value: \(sender.doubleValue)")
}
```

---

## Animation

### Animator Proxy

```swift
// Animate view properties
NSAnimationContext.runAnimationGroup { context in
    context.duration = 0.3
    view.animator().alphaValue = 0.5
    view.animator().frame = newFrame
}

// With completion
NSAnimationContext.runAnimationGroup({ context in
    context.duration = 0.3
    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    view.animator().frame = newFrame
}, completionHandler: {
    print("Animation complete")
})
```

### Implicit Animations

```swift
NSAnimationContext.runAnimationGroup { context in
    context.duration = 0.25
    context.allowsImplicitAnimation = true

    // Changes here will animate
    stackView.arrangedSubviews[0].isHidden = true
}
```

### NSViewAnimation

```swift
let animation = NSViewAnimation(viewAnimations: [
    [
        NSViewAnimation.Key.target: view,
        NSViewAnimation.Key.startFrame: NSValue(rect: view.frame),
        NSViewAnimation.Key.endFrame: NSValue(rect: newFrame)
    ]
])
animation.duration = 0.3
animation.animationCurve = .easeInOut
animation.start()
```

---

## SwiftUI Integration

### NSHostingView

Embed SwiftUI in AppKit:

```swift
import SwiftUI

class MyViewController: NSViewController {
    override func loadView() {
        let swiftUIView = ContentView()
        view = NSHostingView(rootView: swiftUIView)
    }
}
```

### NSHostingController

```swift
let hostingController = NSHostingController(rootView: ContentView())
window.contentViewController = hostingController
```

### NSViewRepresentable (SwiftUI wrapping AppKit)

```swift
import SwiftUI

struct AppKitTextField: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: AppKitTextField

        init(_ parent: AppKitTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }
    }
}
```

---

## Common Patterns

### Preferences Window

```swift
class PreferencesWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        self.init(window: window)
        window.title = "Preferences"
        window.contentViewController = PreferencesViewController()
    }

    override func showWindow(_ sender: Any?) {
        window?.center()
        super.showWindow(sender)
        NSApp.activate(ignoringOtherApps: true)
    }
}
```

### Document-Based App

```swift
class Document: NSDocument {
    var content: String = ""

    override func makeWindowControllers() {
        let windowController = NSWindowController(
            window: NSWindow(contentViewController: DocumentViewController(document: self))
        )
        addWindowController(windowController)
    }

    override func data(ofType typeName: String) throws -> Data {
        return content.data(using: .utf8) ?? Data()
    }

    override func read(from data: Data, ofType typeName: String) throws {
        content = String(data: data, encoding: .utf8) ?? ""
    }
}
```

### Menu Bar App (No Dock Icon)

```swift
@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)

        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "star", accessibilityDescription: nil)

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open", action: #selector(openAction), keyEquivalent: "o"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    @objc func openAction() {
        // Handle action
    }
}
```

---

## Best Practices

### 1. Use Layer-Backed Views

```swift
// Enable for better performance and modern rendering
view.wantsLayer = true
```

### 2. Prefer SwiftUI for New macOS Apps

```swift
// Modern approach
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 3. Handle Coordinate System

```swift
// Override isFlipped for iOS-like behavior
override var isFlipped: Bool { true }
```

### 4. Respect User Preferences

```swift
// Check appearance
if NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
    // Dark mode
}

// Observe changes
NotificationCenter.default.addObserver(
    forName: NSApplication.didChangeScreenParametersNotification,
    object: nil,
    queue: .main
) { _ in
    // Handle display changes
}
```

### 5. Use Standard Controls

Prefer system controls for automatic:
- Dark mode support
- Accessibility
- Localization
- Platform consistency

---

## Quick Reference

### View Lifecycle

| Method | Called When |
|--------|-------------|
| `loadView()` | View needs to be created |
| `viewDidLoad()` | View loaded into memory |
| `viewWillAppear()` | View about to become visible |
| `viewDidAppear()` | View became visible |
| `viewWillDisappear()` | View about to be hidden |
| `viewDidDisappear()` | View was hidden |

### Common NSWindow Methods

```swift
window.makeKeyAndOrderFront(nil)  // Show and focus
window.orderOut(nil)              // Hide
window.close()                    // Close
window.center()                   // Center on screen
window.setFrame(rect, display: true)  // Resize/move
```

### Resources

- [AppKit | Apple Developer Documentation](https://developer.apple.com/documentation/appkit)
- [NSWindow | Apple Developer Documentation](https://developer.apple.com/documentation/appkit/nswindow)
- [NSViewController | Apple Developer Documentation](https://developer.apple.com/documentation/appkit/nsviewcontroller)
- [objc.io - AppKit for UIKit Developers](https://www.objc.io/issues/14-mac/appkit-for-uikit-developers/)

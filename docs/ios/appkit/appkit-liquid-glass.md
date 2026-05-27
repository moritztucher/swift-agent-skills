# AppKit Liquid Glass Implementation Guide

A guide for implementing Apple's Liquid Glass design language in macOS Tahoe (macOS 26) applications using AppKit and SwiftUI.

---

## Table of Contents

1. [Overview](#overview)
2. [Automatic Adoption](#automatic-adoption)
3. [SwiftUI on macOS](#swiftui-on-macos)
4. [AppKit Implementation](#appkit-implementation)
5. [NSVisualEffectView](#nsvisualeffectview)
6. [Toolbar Glass](#toolbar-glass)
7. [Sidebar Implementation](#sidebar-implementation)
8. [Window Configuration](#window-configuration)
9. [Button Styles](#button-styles)
10. [Best Practices](#best-practices)
11. [Migration Guide](#migration-guide)

---

## Overview

Liquid Glass is Apple's unified design language introduced across iOS 26, iPadOS 26, macOS Tahoe (26), watchOS 26, tvOS 26, and visionOS. It uses "lensing" technology—bending and concentrating light rather than scattering it like traditional blur.

### macOS Automatic Elements

When compiled with Xcode 26, these elements automatically adopt Liquid Glass:

- **Toolbar** - Window toolbar buttons
- **Sidebar** - Navigation sidebar
- **Menu bar** - System menu bar
- **Dock** - Application dock
- **Window controls** - Traffic light buttons
- **NSPopover** - Popovers
- **Sheets** - Modal sheets
- **Alerts** - System alerts

### Golden Rule

> "Liquid Glass is best reserved for the navigation layer that floats above the content of your app."

**Use for:** Toolbars, sidebars, floating buttons, sheets, popovers, menus

**Never use for:** Content layers, lists, cards, tables, scrollable content

---

## Automatic Adoption

### Zero-Code Updates (Xcode 26)

Recompile your app with Xcode 26 to get automatic Liquid Glass on standard AppKit controls:

```swift
// These get Liquid Glass automatically:
// - NSToolbar items
// - NSSplitViewController sidebars
// - NSPopover
// - NSAlert
// - Sheets presented via beginSheet
```

### SwiftUI Standard Components

Apps using standard SwiftUI components get automatic updates:

```swift
// Automatic Liquid Glass
NavigationSplitView {
    Sidebar()
} detail: {
    DetailView()
}
.toolbar {
    ToolbarItem {
        Button("Action") { }
    }
}
```

---

## SwiftUI on macOS

### Basic Glass Effect

```swift
import SwiftUI

struct FloatingButton: View {
    var body: some View {
        Button("Action") { }
            .glassEffect()
    }
}
```

### Glass with Shape

```swift
Button {
    // Action
} label: {
    Image(systemName: "plus")
        .frame(width: 44, height: 44)
}
.glassEffect(.regular, in: .circle)
```

### Glass Variants

```swift
// Regular (default) - for most cases
.glassEffect(.regular)
.glassEffect()  // Same as .regular

// Clear - for media-rich backgrounds only
.glassEffect(.clear)

// Identity - no glass effect
.glassEffect(.identity)
```

### GlassEffectContainer (Required for Multiple Elements)

Glass cannot properly sample other glass. Group multiple glass elements:

```swift
GlassEffectContainer(spacing: 20) {
    HStack(spacing: 16) {
        Button("Edit") { }
            .glassEffect()
        Button("Share") { }
            .glassEffect()
        Button("Delete") { }
            .glassEffect()
    }
}
```

### Morphing Animations

```swift
struct ExpandableToolbar: View {
    @State private var isExpanded = false
    @Namespace private var namespace

    var body: some View {
        GlassEffectContainer(spacing: 20) {
            HStack(spacing: 12) {
                if isExpanded {
                    Button("Camera", systemImage: "camera") { }
                        .glassEffect(.regular.interactive())
                        .glassEffectID("camera", in: namespace)

                    Button("Photos", systemImage: "photo") { }
                        .glassEffect(.regular.interactive())
                        .glassEffectID("photos", in: namespace)
                }

                Button {
                    withAnimation(.bouncy) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "xmark" : "plus")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .glassEffectID("toggle", in: namespace)
            }
        }
    }
}
```

### SwiftUI Button Styles

```swift
// Glass style - translucent (secondary actions)
Button("Cancel") { }
    .buttonStyle(.glass)

// Glass prominent - opaque (primary actions)
Button("Confirm") { }
    .buttonStyle(.glassProminent)

// With tinting (primary action only)
Button("Save") { }
    .buttonStyle(.glassProminent)
    .tint(.blue)
```

### Toolbar Glass Visibility

```swift
ContentView()
    .toolbar {
        ToolbarItem(placement: .principal) {
            BuildStatus()
        }
        .sharedBackgroundVisibility(.hidden)  // Separate glass grouping
    }
```

---

## AppKit Implementation

### NSButton Glass Bezel (macOS 26+)

```swift
import AppKit

let button = NSButton()
button.title = "Action"
button.bezelStyle = .glass           // New glass bezel style
button.bezelColor = .systemBlue      // Optional tinting
```

### Toolbar Button Configuration

```swift
class ToolbarDelegate: NSObject, NSToolbarDelegate {
    func toolbar(_ toolbar: NSToolbar,
                 itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {

        let item = NSToolbarItem(itemIdentifier: itemIdentifier)

        switch itemIdentifier {
        case .addItem:
            let button = NSButton()
            button.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "Add")
            button.bezelStyle = .glass
            button.target = self
            button.action = #selector(addAction)
            item.view = button
            item.label = "Add"

        default:
            return nil
        }

        return item
    }
}
```

### Toolbar Item Grouping

AppKit automatically groups multiple toolbar buttons on one glass piece. Override with `NSToolbarItemGroup` or spacers:

```swift
// Create toolbar item group
let group = NSToolbarItemGroup(itemIdentifier: .editGroup)
group.subitems = [editItem, deleteItem, shareItem]
group.selectionMode = .momentary

// Or use spacers to separate
func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    return [
        .addItem,
        .flexibleSpace,  // Separates glass groupings
        .editItem,
        .deleteItem
    ]
}
```

---

## NSVisualEffectView

### Legacy Materials (Pre-macOS 26)

```swift
let visualEffect = NSVisualEffectView()
visualEffect.material = .sidebar
visualEffect.blendingMode = .behindWindow
visualEffect.state = .active
```

### Material Types

```swift
// Window backgrounds
visualEffect.material = .titlebar
visualEffect.material = .sidebar
visualEffect.material = .contentBackground
visualEffect.material = .windowBackground

// Special contexts
visualEffect.material = .menu
visualEffect.material = .popover
visualEffect.material = .hudWindow

// Generic
visualEffect.material = .headerView
visualEffect.material = .sheet
visualEffect.material = .fullScreenUI
```

### Blending Modes

```swift
// Behind window - samples desktop/other apps
visualEffect.blendingMode = .behindWindow

// Within window - samples within app window
visualEffect.blendingMode = .withinWindow
```

### Vibrancy

```swift
// Enable vibrancy for text/icons
let vibrantView = NSVisualEffectView()
vibrantView.material = .sidebar
vibrantView.blendingMode = .behindWindow

// Labels inside get automatic vibrancy
let label = NSTextField(labelWithString: "Sidebar Item")
label.textColor = .secondaryLabelColor  // Vibrant in sidebar
vibrantView.addSubview(label)
```

---

## Toolbar Glass

### Window Toolbar Configuration

```swift
class MainWindowController: NSWindowController {
    override func windowDidLoad() {
        super.windowDidLoad()

        window?.toolbar = createToolbar()
        window?.toolbarStyle = .unified       // Inline with title
        // Or
        window?.toolbarStyle = .unifiedCompact  // Compact
    }

    func createToolbar() -> NSToolbar {
        let toolbar = NSToolbar(identifier: "MainToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = true
        return toolbar
    }
}
```

### Toolbar Styles (macOS 11+)

```swift
window?.toolbarStyle = .automatic      // System decides
window?.toolbarStyle = .expanded       // Below title bar
window?.toolbarStyle = .preference     // Preferences style
window?.toolbarStyle = .unified        // Inline with title
window?.toolbarStyle = .unifiedCompact // Compact unified
```

---

## Sidebar Implementation

### NSSplitViewController

```swift
class MainSplitViewController: NSSplitViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let sidebarItem = NSSplitViewItem(sidebarWithViewController: SidebarViewController())
        sidebarItem.minimumThickness = 200
        sidebarItem.maximumThickness = 300
        sidebarItem.canCollapse = true

        let contentItem = NSSplitViewItem(viewController: ContentViewController())

        addSplitViewItem(sidebarItem)
        addSplitViewItem(contentItem)
    }
}
```

### Sidebar Ambient Reflection (macOS 26)

On macOS Tahoe and iPad, sidebars automatically reflect light from nearby colorful content. This is automatic with standard sidebar implementation.

### Source List Style

```swift
// For NSOutlineView in sidebar
outlineView.style = .sourceList

// Or for NSTableView
tableView.style = .sourceList
```

---

## Window Configuration

### Full-Size Content View

Allow content to extend behind title bar:

```swift
window.styleMask.insert(.fullSizeContentView)
window.titlebarAppearsTransparent = true
window.titleVisibility = .hidden  // Optional
```

### Title Bar Customization

```swift
// Transparent title bar
window.titlebarAppearsTransparent = true

// Custom title bar accessory
let accessoryVC = NSTitlebarAccessoryViewController()
accessoryVC.view = customView
accessoryVC.layoutAttribute = .right
window.addTitlebarAccessoryViewController(accessoryVC)
```

### Window Background

```swift
// Let glass show through
window.backgroundColor = .clear
window.isOpaque = false

// Or use visual effect background
let visualEffect = NSVisualEffectView()
visualEffect.material = .windowBackground
visualEffect.blendingMode = .behindWindow
window.contentView = visualEffect
```

---

## Button Styles

### Glass Button (macOS 26+)

```swift
// AppKit
let glassButton = NSButton()
glassButton.bezelStyle = .glass
glassButton.title = "Glass Button"

// SwiftUI
Button("Glass") { }
    .buttonStyle(.glass)
```

### Glass Prominent Button

```swift
// SwiftUI only
Button("Primary Action") { }
    .buttonStyle(.glassProminent)
    .tint(.accentColor)
```

### Interactive Modifier

On iOS, `.interactive()` adds touch feedback. On macOS, hover and click states are handled automatically.

```swift
// SwiftUI
Button("Interactive") { }
    .glassEffect(.regular.interactive())
```

### Tinting Rules

> "Tinting should only be used to bring emphasis to primary elements and actions."

```swift
// CORRECT - Only primary action tinted
HStack {
    Button("Cancel") { }
        .buttonStyle(.glass)  // No tint

    Button("Save") { }
        .buttonStyle(.glassProminent)
        .tint(.blue)  // Primary action
}

// WRONG - Everything tinted
HStack {
    Button("A") { }.glassEffect(.regular.tint(.blue))
    Button("B") { }.glassEffect(.regular.tint(.green))
    Button("C") { }.glassEffect(.regular.tint(.red))
}
```

---

## Best Practices

### 1. Navigation Layer Only

```swift
// CORRECT - Glass for floating controls
ZStack {
    ContentView()  // No glass

    VStack {
        Spacer()
        FloatingToolbar()
            .glassEffect()
    }
}

// WRONG - Glass on content
List(items) { item in
    ItemRow(item: item)
        .glassEffect()  // Don't do this!
}
```

### 2. Never Stack Glass on Glass

```swift
// WRONG
VStack {
    InnerContent()
        .glassEffect()  // Inner glass
}
.glassEffect()  // Outer glass - visual conflict!

// CORRECT - Use GlassEffectContainer
GlassEffectContainer {
    HStack {
        Button("A") { }.glassEffect()
        Button("B") { }.glassEffect()
    }
}
```

### 3. Don't Mix Glass Variants

```swift
// WRONG
HStack {
    Button("A") { }.glassEffect(.regular)
    Button("B") { }.glassEffect(.clear)  // Different variant!
}

// CORRECT - Same variant throughout
HStack {
    Button("A") { }.glassEffect(.regular)
    Button("B") { }.glassEffect(.regular)
}
```

### 4. Let System Handle Standard Components

```swift
// DON'T manually style standard components
NavigationSplitView {
    Sidebar()
        .background(.ultraThinMaterial)  // Unnecessary!
}

// DO let system handle it
NavigationSplitView {
    Sidebar()  // Automatic glass
}
```

### 5. Don't Add Background to Sheets

```swift
// WRONG
.sheet(isPresented: $showSheet) {
    SheetContent()
        .background(.ultraThinMaterial)  // Don't do this!
}

// CORRECT - System handles it
.sheet(isPresented: $showSheet) {
    SheetContent()
}
```

### 6. Don't Color Toolbars

```swift
// WRONG
.toolbarBackground(Color.blue, for: .windowToolbar)

// CORRECT - Let system handle
// No toolbar background modifier needed
```

---

## Migration Guide

### From NSVisualEffectView to Liquid Glass

**Before (macOS 14):**
```swift
let visualEffect = NSVisualEffectView()
visualEffect.material = .headerView
visualEffect.blendingMode = .withinWindow
containerView.addSubview(visualEffect)
```

**After (macOS 26 SwiftUI):**
```swift
ContainerView()
    .glassEffect()
```

### From Custom Toolbar Buttons

**Before:**
```swift
let button = NSButton()
button.bezelStyle = .texturedRounded
button.image = NSImage(systemSymbolName: "plus", accessibilityDescription: nil)
```

**After:**
```swift
let button = NSButton()
button.bezelStyle = .glass
button.image = NSImage(systemSymbolName: "plus", accessibilityDescription: nil)
```

### From Material Backgrounds

**Before (SwiftUI):**
```swift
.background(.ultraThinMaterial)
.clipShape(RoundedRectangle(cornerRadius: 12))
```

**After (SwiftUI):**
```swift
.glassEffect(.regular, in: .rect(cornerRadius: 12))
```

### Sidebar Migration

**Before:**
```swift
// Custom sidebar background
sidebarView.wantsLayer = true
sidebarView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
```

**After:**
```swift
// Use standard NSSplitViewController - glass is automatic
let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarVC)
```

---

## Accessibility

Liquid Glass automatically adapts for accessibility settings. No additional code required:

| Setting | Behavior |
|---------|----------|
| Reduce Transparency | Frostier, more opaque glass |
| Increase Contrast | Black/white with border |
| Reduce Motion | Disabled elastic/bounce effects |

### Check Accessibility Preferences

```swift
// AppKit
if NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency {
    // Adjust if needed
}

// SwiftUI
@Environment(\.accessibilityReduceTransparency) var reduceTransparency
```

---

## Quick Reference

### SwiftUI Glass Modifiers

```swift
// Basic
.glassEffect()
.glassEffect(.regular)
.glassEffect(.clear)

// With shape
.glassEffect(.regular, in: .capsule)
.glassEffect(.regular, in: .circle)
.glassEffect(.regular, in: .rect(cornerRadius: 12))

// Modifiers
.glassEffect(.regular.tint(.blue))
.glassEffect(.regular.interactive())

// Container
GlassEffectContainer(spacing: 20) { }

// Morphing
.glassEffectID("id", in: namespace)

// Toolbar
.sharedBackgroundVisibility(.hidden)
```

### AppKit Glass

```swift
// Button
button.bezelStyle = .glass
button.bezelColor = .systemBlue

// Toolbar
window?.toolbarStyle = .unified
```

### Resources

- [Apple Developer - Applying Liquid Glass to custom views](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views)
- [WWDC 2025 Session 310 - Build an AppKit app with the new design](https://developer.apple.com/videos/)
- [WWDC 2025 Session 323 - Build a SwiftUI app with the new design](https://developer.apple.com/videos/)
- [Apple Newsroom - Liquid Glass Design](https://www.apple.com/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design/)
- [Liquid Glass Best Practices](https://dev.to/diskcleankit/liquid-glass-in-swift-official-best-practices-for-ios-26-macos-tahoe-1coo)

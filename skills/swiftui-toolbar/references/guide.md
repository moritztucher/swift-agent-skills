# SwiftUI Toolbar — Deep Reference

The toolbar system places controls in the navigation bar, bottom bar, keyboard accessory, and other managed bars. You declare *what* goes in the toolbar with `ToolbarContent`; the system decides *where* and *how* it renders per platform, per size class, and (on iOS 26) groups items into shared Liquid Glass capsules.

All code below uses APIs verified against Apple's SwiftUI documentation (2026-06-02). iOS 26 additions are explicitly marked and availability-gated.

---

## 1. Overview — how the toolbar system is shaped

`View.toolbar(content:)` takes a `@ToolbarContentBuilder` closure that returns `ToolbarContent` (not `View`). Inside that closure you place:

- **`ToolbarItem`** — one logical item at one placement.
- **`ToolbarItemGroup`** — several items sharing one placement.
- **`ToolbarSpacer`** (iOS 26) — explicit space that also *breaks* the shared-glass grouping.
- **`DefaultToolbarItem`** (iOS 26) — a system-provided component (e.g. a search field, sidebar toggle) you position yourself.

```swift
struct NoteEditor: View {
    @State private var text = ""

    var body: some View {
        TextEditor(text: $text)
            .navigationTitle("Note")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { /* … */ }
                }
            }
    }
}
```

Key facts:

- The closure is a **result builder** (`@ToolbarContentBuilder`). It supports `if`, `if #available`, and `switch` (via `buildIf` / `buildEither` / `buildLimitedAvailability`), but it does **not** accept arbitrary `View`s at the top level — every branch must resolve to `ToolbarContent`. Put plain views *inside* a `ToolbarItem`/`ToolbarItemGroup`.
- A toolbar attaches to the nearest bar-rendering container. On iOS that is usually a `NavigationStack` (navigation bar / bottom bar) or a `TabView` (tab bar). Without such a container, navigation-bar placements have nowhere to render.
- The builder caps out around ten items per `buildBlock`; use groups and spacers rather than dumping a flat list.

### `toolbar` vs `toolbar(id:)`

`toolbar(content:)` is the everyday form. `toolbar(id:content:)` opts the toolbar into **user customization** (macOS / iPadOS): every `ToolbarItem` then needs an `id:`, and the OS lets users rearrange or remove items. Use the `id:` form only when you actually want customization; otherwise the plain form is simpler.

```swift
.toolbar(id: "main") {
    ToolbarItem(id: "tag")   { TagButton() }
    ToolbarItem(id: "share") { ShareButton() }
    ToolbarSpacer(.fixed)
    ToolbarItem(id: "more")  { MoreButton() }
}
```

---

## 2. `ToolbarItem` vs `ToolbarItemGroup`

### `ToolbarItem` — one item, one placement

```swift
ToolbarItem(placement: .topBarTrailing) {
    Button("Save") { save() }
}
```

`ToolbarItem` carries a single view and a single placement. Reach for it when an item needs its *own* placement, its own `id` (customization), or its own `sharedBackgroundVisibility`.

There is also `ToolbarItem(placement:showsByDefault:)` for customizable toolbars — an item that exists but is hidden until the user adds it back.

### `ToolbarItemGroup` — several items, shared placement

```swift
ToolbarItemGroup(placement: .topBarTrailing) {
    Button("Bold",   systemImage: "bold")   { bold.toggle() }
    Button("Italic", systemImage: "italic") { italic.toggle() }
    Button("Underline", systemImage: "underline") { underline.toggle() }
}
```

A group is the right tool when a *set* of controls belongs together at one placement — formatting toggles, a cluster of related actions. The system keeps them adjacent and, on iOS 26, renders them inside one shared glass capsule. The font-controls example from Apple's docs:

```swift
.toolbar {
    ToolbarItemGroup {
        Slider(value: $fontSize, in: 8...120,
               minimumValueLabel: Text("A").font(.system(size: 8)),
               maximumValueLabel: Text("A").font(.system(size: 16))) {
            Text("Font Size (\(Int(fontSize)))")
        }
        .frame(width: 150)
        Toggle(isOn: $bold)   { Image(systemName: "bold") }
        Toggle(isOn: $italic) { Image(systemName: "italic") }
    }
}
```

**Rule of thumb:** one action → `ToolbarItem`. A coherent cluster at the same placement → `ToolbarItemGroup`. Distinct clusters → multiple groups separated by `ToolbarSpacer`.

---

## 3. Placements — `ToolbarItemPlacement`

Placement is **semantic first**. You describe the *role* of an item; SwiftUI maps the role to a physical location that's correct for the platform, the OS version, and the layout direction (LTR/RTL). Hardcoding `.topBarTrailing` for everything throws that away.

### Semantic (role-based) placements

These adapt across platforms and are the placements you should reach for first.

| Placement | Role | Where it lands on iOS |
|---|---|---|
| `.automatic` | "Put it somewhere sensible." | System decides (often trailing). |
| `.principal` | The screen's centerpiece. | Center of the navigation bar; takes precedence over `navigationTitle`. |
| `.primaryAction` | The single most important action. | Trailing edge of the nav bar. |
| `.secondaryAction` | Lower-priority actions. | Often collapsed into an overflow / more menu. |
| `.confirmationAction` | Confirm/commit in a modal. | Trailing; styled prominently. |
| `.cancellationAction` | Cancel/dismiss in a modal. | Leading; styled as cancel. |
| `.destructiveAction` | The destructive choice in a modal. | Positioned/styled per platform conventions. |
| `.navigation` | Navigation between contexts (back/forward style). | Leading area of the nav bar. |
| `.status` | Status/state, not an action. | Center/neutral region. |

```swift
// A modal sheet: let the SEMANTICS place and style the buttons.
.toolbar {
    ToolbarItem(placement: .confirmationAction) {
        Button("Add") { commit() }      // prominent, trailing
    }
    ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") { dismiss() }  // leading, cancel styling
    }
}
```

Why semantic wins for modals: `.confirmationAction` / `.cancellationAction` get the correct edge, the correct emphasis (the confirm button is bolded), correct keyboard/Return-key wiring, and they stay correct if Apple changes conventions. Manually pinning a "Cancel" `Button` to `.topBarLeading` and a "Done" to `.topBarTrailing` re-implements all of that by hand and gets the styling wrong.

`.principal` is how you put a **custom title view** (segmented control, custom label, live status) in the center of the nav bar:

```swift
.toolbar {
    ToolbarItem(placement: .principal) {
        Picker("Mode", selection: $mode) {
            Text("Day").tag(Mode.day)
            Text("Week").tag(Mode.week)
        }
        .pickerStyle(.segmented)
    }
}
```

### Positional placements

Use these when the design genuinely calls for a specific edge and no semantic role fits.

| Placement | Location |
|---|---|
| `.topBarLeading` | Leading edge of the top/navigation bar. |
| `.topBarTrailing` | Trailing edge of the top/navigation bar. |
| `.bottomBar` | The bottom toolbar (separate from the tab bar). |
| `.bottomOrnament` | Bottom ornament (visionOS). |

```swift
.toolbar {
    ToolbarItem(placement: .topBarLeading) {
        Button("Edit") { editing.toggle() }
    }
    ToolbarItemGroup(placement: .bottomBar) {
        Button("Share", systemImage: "square.and.arrow.up") { share() }
        Spacer()
        Button("Add", systemImage: "plus") { add() }
    }
}
```

`.topBarLeading` / `.topBarTrailing` are layout-direction aware (leading/trailing, not left/right), so they're still better than raw left/right would be — but prefer `.primaryAction` / `.cancellationAction` / `.principal` when the item has a clear *role*.

### `.keyboard` — accessory above the keyboard

`ToolbarItemPlacement.keyboard` docks items above the software keyboard.

```swift
.toolbar {
    ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("Done") { dismissKeyboard() }
    }
}
```

A focus-driven keyboard bar (vary content by focused field) using `@FocusedValue`:

```swift
enum Field { case suit, rank }

struct KeyboardBarDemo: View {
    @FocusedValue(\.field) var field: Field?
    @State private var suitText = ""
    @State private var rankText = ""

    var body: some View {
        HStack {
            TextField("Suit", text: $suitText).focusedValue(\.field, .suit)
            TextField("Rank", text: $rankText).focusedValue(\.field, .rank)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if field == .suit {
                    Button("♣️") {}; Button("♥️") {}
                    Button("♠️") {}; Button("♦️") {}
                }
                Spacer()
                Button("Done") { /* resign focus */ }
            }
        }
    }
}
```

> **Scope boundary.** This guide covers `.keyboard` as one toolbar placement. The hard case — a **custom IME / candidate strip** that rewrites the trailing run as the user types, plus the docking-vs-`safeAreaInset` decision and edge-inset fixes — is owned by the **`keyboard-accessory`** skill. Use that skill for anything beyond a simple Done/format bar.

### `.accessoryBar(id:)` — custom accessory bars

`ToolbarItemPlacement.accessoryBar(id:)` creates a custom accessory bar identified by an `ID`. Use it for a secondary bar of controls distinct from the main toolbar (e.g. a filter/scope bar). The `id` keeps the bar's identity stable across content changes.

```swift
.toolbar {
    ToolbarItem(placement: .accessoryBar(id: "filters")) {
        FilterScopeBar(selection: $scope)
    }
}
```

---

## 4. iOS 26 — `ToolbarSpacer` and the shared-glass grouping

On iOS 26 the system renders toolbar items into **shared Liquid Glass capsules**: items within one logical grouping share a single rounded glass background. Adjacent items merge into the same capsule unless you separate them.

> **Scope boundary.** This guide covers how the *toolbar* groups items into glass capsules and how to control that grouping. The Liquid Glass **material itself** — `.glassEffect`, `GlassEffectContainer`, `glassEffectID` morphing, `.buttonStyle(.glass)` — is owned by the **`liquid-glass`** skill.

### `ToolbarSpacer` — split groups (iOS 26+)

`ToolbarSpacer` inserts space *and* breaks the shared-glass grouping: items on either side render in **separate** capsules. It takes a `SpacerSizing` and an optional placement.

- `ToolbarSpacer(.flexible)` — expands to fill available space (pushes items apart).
- `ToolbarSpacer(.fixed)` — a fixed standard gap.

```swift
.toolbar {
    ToolbarSpacer(.flexible)               // push the rest to trailing

    ToolbarItem {
        ShareLink(item: landmark, preview: landmark.sharePreview)
    }

    ToolbarSpacer(.fixed)                   // break into its own capsule

    ToolbarItemGroup {
        FavoriteButton(landmark: landmark)
        CollectionsMenu(landmark: landmark)
    }

    ToolbarSpacer(.fixed)

    ToolbarItem {
        Button("Info", systemImage: "info") { showInspector() }
    }
}
```

Result: Share is one capsule, the favorite+collections group is a second capsule, Info is a third — visually separated, each with its own glass. Without the spacers, all of these would smear into one capsule.

`ToolbarSpacer` is **iOS 26.0+ / iPadOS 26.0+ / macOS 26.0+**. Availability-gate it (see §8).

### `sharedBackgroundVisibility(_:)` — opt out of the shared glass (iOS 26+)

`sharedBackgroundVisibility(_:)` is a method on **`CustomizableToolbarContent`** (i.e. you apply it to a `ToolbarItem`/group). Passing `.hidden` removes the glass background for that item *and* puts it in its own logical grouping — so it neither shows the capsule nor merges with neighbors.

```swift
.toolbar(id: "main") {
    ToolbarItem(id: "build-status", placement: .principal) {
        BuildStatus()
    }
    .sharedBackgroundVisibility(.hidden)   // no capsule; stands alone
}
```

Use `.hidden` when an item is a custom view that shouldn't sit on glass — a live status indicator, a custom-shaped control, or (the `keyboard-accessory` case) an opaque accessory whose corners would otherwise let content bleed through the capsule.

`sharedBackgroundVisibility(_:)` is **iOS 26.0+**; gate it.

### Mental model

- Default iOS 26: adjacent items share one glass capsule.
- `ToolbarSpacer` → "start a new capsule here" (plus spacing).
- `.sharedBackgroundVisibility(.hidden)` → "this item has no capsule and stands alone."

---

## 5. Toolbar visibility — `toolbar(_:for:)` / `toolbarVisibility(_:for:)`

These control whether a *bar* is shown, targeting specific bars via `ToolbarPlacement` (note: **`ToolbarPlacement`**, the bar enum — distinct from `ToolbarItemPlacement`, the item-position enum).

```swift
NavigationStack {
    ContentView()
        .toolbar(.hidden, for: .navigationBar)        // hide the nav bar
}

TabView {
    NavigationStack {
        DetailView()
            .toolbar(.hidden, for: .navigationBar, .tabBar)  // hide both
    }
}
```

`ToolbarPlacement` values include `.automatic`, `.navigationBar`, `.bottomBar`, `.tabBar`, and `.windowToolbar` (macOS).

- `toolbar(_:for:)` and `toolbarVisibility(_:for:)` do the same thing; `toolbarVisibility(_:for:)` is the iOS 18+ spelling and reads more clearly. Either is fine on a current target.
- The visibility preference **flows up to the nearest container that renders the bar** (a `NavigationStack`, `TabView`, or the `WindowGroup` root). It is *not* applied to the modified view in isolation.
- **Pass the right bar.** Hiding the tab bar requires `for: .tabBar`; passing `.navigationBar` (or nothing) won't touch the tab bar. The empty/`automatic` case targets a default bar, not all of them.
- The system may decline the request in some contexts.

```swift
// iOS 18+ spelling
.toolbarVisibility(.hidden, for: .tabBar)
```

---

## 6. Toolbar background, color scheme, foreground

### `toolbarBackground(_:for:)` and `toolbarBackgroundVisibility(_:for:)`

`toolbarBackground(_:for:)` sets a background (a `ShapeStyle` or `View`) for a bar; `toolbarBackgroundVisibility(_:for:)` controls whether the bar's background shows at all.

```swift
ContentView()
    .toolbarBackground(.blue, for: .navigationBar)
    .toolbarBackgroundVisibility(.visible, for: .navigationBar)
```

> On iOS 26, the standard chrome is glassed by the system. Forcing an opaque/colored `toolbarBackground` fights the Liquid Glass treatment and breaks system cohesion — see the **`liquid-glass`** skill before overriding chrome backgrounds. Reach for a colored toolbar background only when the design truly demands a branded bar.

### `toolbarColorScheme(_:for:)`

Pins a bar's color scheme (light/dark) independent of the surrounding content — useful to keep text/controls legible over a fixed-color toolbar background.

```swift
.toolbarBackground(.blue, for: .navigationBar)
.toolbarColorScheme(.dark, for: .navigationBar)   // white controls on blue
```

### `toolbarForegroundStyle(_:for:)`

Sets the foreground style (e.g. a tint) for a bar's content.

```swift
.toolbarForegroundStyle(.white, for: .navigationBar)
```

Prefer semantic foreground styles over hardcoded colors so content stays legible as backdrops change (especially over glass).

---

## 7. `toolbarRole`, title menu, title display mode

### `toolbarRole(_:)`

`toolbarRole(_:)` tells SwiftUI the *purpose* of the view's toolbar so it can lay items out appropriately. `ToolbarRole` values:

- `.automatic` — default; system infers from context.
- `.navigationStack` — a standard pushed/navigation context.
- `.editor` — an editor-style layout. On iPad this spreads toolbar items across the bar and uses a back button without a title, suited to content-editing screens.
- `.browser` — a browser-style layout (e.g. document/file browsing).

```swift
DocumentEditor()
    .toolbarRole(.editor)
    .toolbar {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button("Format", systemImage: "textformat") {}
            Button("Comment", systemImage: "text.bubble") {}
        }
    }
```

Set the role to match the screen's job; don't force `.editor` on a plain list just to spread items.

### `toolbarTitleMenu(content:)`

Adds a menu attached to the navigation **title** — the affordance where tapping the title (or its chevron) reveals title-level actions (rename, move, duplicate a document).

```swift
ContentView()
    .navigationTitle(document.name)
    .toolbarTitleMenu {
        Button("Rename", systemImage: "pencil") { rename() }
        Button("Duplicate", systemImage: "doc.on.doc") { duplicate() }
        Button("Move…", systemImage: "folder") { move() }
    }
```

If you supply a `.principal` item, that item provides the title-menu source; otherwise the system title is used.

### `toolbarTitleDisplayMode(_:)`

Controls how the navigation title is displayed. `ToolbarTitleDisplayMode` values:

- `.automatic` — inherit from context.
- `.large` — large title.
- `.inline` — inline (small, centered) title.
- `.inlineLarge` — inline but rendered large.

```swift
List { /* … */ }
    .navigationTitle("Inbox")
    .toolbarTitleDisplayMode(.inline)
```

This is the modern replacement for reaching at the UIKit `navigationBarTitleDisplayMode`; it composes with `navigationTitle`.

---

## 8. Availability gating iOS 26 APIs

`ToolbarSpacer`, `sharedBackgroundVisibility(_:)`, and `DefaultToolbarItem` are **iOS 26.0+**. If your deployment target is below 26, gate them. The `@ToolbarContentBuilder` supports `if #available` via `buildLimitedAvailability`.

```swift
.toolbar {
    ToolbarItem { ShareButton() }

    if #available(iOS 26.0, *) {
        ToolbarSpacer(.fixed)              // only compiled/used on 26+
    }

    ToolbarItemGroup {
        FavoriteButton()
        MoreButton()
    }
}
```

For `sharedBackgroundVisibility`, gate the whole item branch:

```swift
.toolbar(id: "main") {
    if #available(iOS 26.0, *) {
        ToolbarItem(id: "status", placement: .principal) {
            StatusView()
        }
        .sharedBackgroundVisibility(.hidden)
    } else {
        ToolbarItem(id: "status", placement: .principal) {
            StatusView()
        }
    }
}
```

The semantic placements (`.topBarLeading`/`.topBarTrailing` are iOS 14+; `.confirmationAction`/`.cancellationAction`/`.primaryAction`/`.principal`/`.navigation` are long-standing), `toolbar(_:for:)`/`toolbarVisibility(_:for:)`, `toolbarBackground`, `toolbarColorScheme`, `toolbarRole`, `toolbarTitleMenu`, and `toolbarTitleDisplayMode` are available well before iOS 26 (most iOS 16–18); they don't need a 26 gate.

---

## 9. Common patterns

### Standard detail screen

```swift
.toolbar {
    ToolbarItem(placement: .topBarLeading) {
        Button("Edit") { editing.toggle() }
    }
    ToolbarItem(placement: .primaryAction) {
        Button("Add", systemImage: "plus") { add() }
    }
}
.toolbarTitleDisplayMode(.inline)
```

### Modal sheet (semantic confirm/cancel)

```swift
NavigationStack {
    Form { /* … */ }
        .navigationTitle("New Item")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save(); dismiss() }
                    .disabled(!isValid)
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
}
```

### Bottom bar with spacers

```swift
.toolbar {
    ToolbarItemGroup(placement: .bottomBar) {
        Button("Delete", systemImage: "trash", role: .destructive) { delete() }
        Spacer()
        Text("\(count) items").font(.footnote).foregroundStyle(.secondary)
        Spacer()
        Button("Add", systemImage: "plus") { add() }
    }
}
```

### Custom title (principal)

```swift
.toolbar {
    ToolbarItem(placement: .principal) {
        Picker("Scope", selection: $scope) {
            Text("All").tag(Scope.all)
            Text("Unread").tag(Scope.unread)
        }
        .pickerStyle(.segmented)
        .frame(width: 200)
    }
}
```

### iOS 26 grouped glass toolbar

```swift
.toolbar {
    ToolbarSpacer(.flexible)
    ToolbarItem { ShareLink(item: url) }
    ToolbarSpacer(.fixed)
    ToolbarItemGroup {
        Button("Favorite", systemImage: "star") { toggleFavorite() }
        Menu("More", systemImage: "ellipsis") { /* … */ }
    }
}
```

---

## 10. Quick reference

| API | Purpose | Min version |
|---|---|---|
| `View.toolbar(content:)` | Populate toolbar with `ToolbarContent`. | iOS 14 |
| `View.toolbar(id:content:)` | Customizable toolbar (items need `id:`). | iOS 14 / 16 |
| `ToolbarItem(placement:)` | One item at one placement. | iOS 14 |
| `ToolbarItemGroup(placement:)` | Item cluster at one placement. | iOS 14 |
| `ToolbarContentBuilder` | Result builder for toolbar content. | iOS 14 |
| `ToolbarSpacer(_:placement:)` | Space + glass-group break. | **iOS 26** |
| `DefaultToolbarItem` | System-provided toolbar component. | **iOS 26** |
| `.sharedBackgroundVisibility(_:)` | Hide/group the shared glass capsule. | **iOS 26** |
| `.toolbar(_:for:)` / `.toolbarVisibility(_:for:)` | Bar visibility. | iOS 16 / 18 |
| `.toolbarBackground(_:for:)` | Bar background. | iOS 16 |
| `.toolbarBackgroundVisibility(_:for:)` | Bar background visibility. | iOS 17/18 |
| `.toolbarColorScheme(_:for:)` | Pin bar color scheme. | iOS 16 |
| `.toolbarForegroundStyle(_:for:)` | Bar foreground style. | iOS 16 |
| `.toolbarRole(_:)` | Layout role (`.editor`/`.browser`/`.navigationStack`). | iOS 16 |
| `.toolbarTitleMenu(content:)` | Menu attached to the title. | iOS 16 |
| `.toolbarTitleDisplayMode(_:)` | `.large`/`.inline`/`.inlineLarge`. | iOS 17 |

**`ToolbarItemPlacement`** (item position): `.automatic`, `.principal`, `.primaryAction`, `.secondaryAction`, `.confirmationAction`, `.cancellationAction`, `.destructiveAction`, `.navigation`, `.status`, `.topBarLeading`, `.topBarTrailing`, `.bottomBar`, `.bottomOrnament`, `.keyboard`, `.accessoryBar(id:)`.

**`ToolbarPlacement`** (which bar): `.automatic`, `.navigationBar`, `.bottomBar`, `.tabBar`, `.windowToolbar` (macOS).

**`SpacerSizing`**: `.flexible`, `.fixed`.

**`ToolbarRole`**: `.automatic`, `.navigationStack`, `.editor`, `.browser`.

**`ToolbarTitleDisplayMode`**: `.automatic`, `.large`, `.inline`, `.inlineLarge`.

### Cross-skill boundaries

- **`keyboard-accessory`** owns the `.keyboard` IME candidate strip and keyboard-docked accessory mechanics.
- **`liquid-glass`** owns the glass *material* (`.glassEffect`, `GlassEffectContainer`, glass button styles). This skill only controls how the *toolbar* groups items into capsules.
- **`swiftui-tabview`** owns the tab bar; use `for: .tabBar` here only to toggle its visibility.

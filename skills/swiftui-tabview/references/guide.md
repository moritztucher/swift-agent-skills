# SwiftUI TabView — Deep Reference

The full API reference for SwiftUI's `TabView`, with emphasis on the iOS 26 overhaul (floating, morphing, Liquid Glass tab bar; bottom accessory; minimize behavior; the value-based `Tab` API). Every code sample uses the real, verified API.

Verified against Apple's SwiftUI documentation via Context7 (`/websites/developer_apple_swiftui`), 2026-06-02.

---

## 1. Overview

`TabView` is SwiftUI's container for top-level, sibling navigation — a small set of peer destinations the user switches between (Home, Search, Library, Profile…). It is *not* a drill-down: each tab owns its own `NavigationStack`.

Two eras of API coexist:

- **Modern (iOS 18+):** the `Tab` builder type — `Tab("Title", systemImage:) { Content }`, optionally with a `value:` for a selection binding, plus `TabSection` for grouping and `Tab(role: .search)` for the dedicated search tab. This is the API you write for all new code.
- **Legacy (iOS 13+):** any `View` inside `TabView` tagged with `.tabItem { Label(...) }` and `.tag(...)`. Still compiles, still works, but it can't express `TabSection`, roles, or per-section customization. Migrate it.

On top of that, **iOS 26** restyles the tab bar itself: it becomes a floating, Liquid Glass capsule that can minimize on scroll, host a bottom accessory (the "mini-player" slot), and morph as it transitions. None of that requires API changes to your `Tab` declarations — it comes for free when you build against the iOS 26 SDK — but several *new* modifiers (`tabViewBottomAccessory`, `tabBarMinimizeBehavior`) only exist on iOS 26+.

### Platform availability at a glance

| API | First available |
|---|---|
| `TabView`, `.tabItem`, `.tabViewStyle(.page)` | iOS 13+ |
| `Tab(_:systemImage:value:)`, `TabSection`, `.tabViewStyle(.sidebarAdaptable)`, `TabViewCustomization`, `.customizationID`, `.defaultVisibility(_:for:)` | iOS 18+ |
| `Tab(role: .search)`, `.tabViewSearchActivation(_:)`, `tabViewBottomAccessory(content:)`, `TabViewBottomAccessoryPlacement`, `.tabBarMinimizeBehavior(_:)`, floating/morphing Liquid Glass tab bar | iOS 26+ |

---

## 2. The modern `Tab` API

### 2.1 Basic tabs

```swift
TabView {
    Tab("Received", systemImage: "tray.and.arrow.down.fill") {
        ReceivedView()
    }

    Tab("Sent", systemImage: "tray.and.arrow.up.fill") {
        SentView()
    }

    Tab("Account", systemImage: "person.crop.circle.fill") {
        AccountView()
    }
}
```

Each `Tab` takes a title, a system image (or a `Label`/custom image variant), and a `@ViewBuilder` content closure. The order you declare them is the order they appear.

Wrap each tab's content in its own `NavigationStack` so each tab keeps an independent navigation history:

```swift
Tab("Library", systemImage: "books.vertical") {
    NavigationStack {
        LibraryView()
    }
}
```

### 2.2 `TabSection` — grouping secondary tabs

`TabSection` groups related tabs under a heading. It only changes the presentation under `.sidebarAdaptable`: on iPadOS grouped tabs appear in both the sidebar and the tab bar; on macOS/tvOS they form a sidebar section; on iOS the section flattens into the tab bar.

```swift
TabView {
    Tab("Requests", systemImage: "paperplane") {
        RequestsView()
    }

    Tab("Account", systemImage: "person.crop.circle.fill") {
        AccountView()
    }

    TabSection("Messages") {
        Tab("Received", systemImage: "tray.and.arrow.down.fill") {
            ReceivedView()
        }
        Tab("Sent", systemImage: "tray.and.arrow.up.fill") {
            SentView()
        }
        Tab("Drafts", systemImage: "pencil") {
            DraftsView()
        }
    }
}
.tabViewStyle(.sidebarAdaptable)
```

`TabSection` is meaningless with the default tab bar style — it pays off only with `.sidebarAdaptable` (or on platforms that render a sidebar).

---

## 3. Selection and programmatic switching

### 3.1 Value-based selection

Give each `Tab` a `value:` and bind `TabView(selection:)` to state of the same type. The selection binding's type **must match** every tab's `value` type exactly.

```swift
TabView(selection: $selection) {
    Tab("Received", systemImage: "tray.and.arrow.down.fill", value: 0) {
        ReceivedView()
    }
    Tab("Sent", systemImage: "tray.and.arrow.up.fill", value: 1) {
        SentView()
    }
    Tab("Account", systemImage: "person.crop.circle.fill", value: 2) {
        AccountView()
    }
}
```

Use a dedicated `enum` rather than bare integers — it documents the tabs and makes the binding type self-evident:

```swift
enum AppTab: Hashable {
    case home, reports, browse
}

@State private var selection: AppTab = .home

TabView(selection: $selection) {
    Tab("Home", systemImage: "house", value: AppTab.home) {
        HomeView()
    }
    Tab("Reports", systemImage: "chart.bar", value: AppTab.reports) {
        ReportsView()
    }
    Tab("Browse", systemImage: "list.bullet", value: AppTab.browse) {
        BrowseView()
    }
}
```

The selection type must be `Hashable`. Switch tabs from anywhere by assigning to the bound state: `selection = .reports`.

### 3.2 Tap-to-reset / pop-to-root

A common pattern: tapping the already-selected tab should pop its stack to root. Observe selection changes and reset that tab's navigation path. There is no dedicated modifier — you watch the binding yourself, e.g. by giving each tab its own `@State` path and clearing it when the user taps the active tab.

---

## 4. Legacy `.tabItem` and migration

The original API tags arbitrary views:

```swift
// LEGACY — iOS 13+ style. Migrate for new code.
TabView(selection: $selection) {
    ReceivedView()
        .tabItem { Label("Received", systemImage: "tray.and.arrow.down.fill") }
        .tag(0)

    SentView()
        .tabItem { Label("Sent", systemImage: "tray.and.arrow.up.fill") }
        .tag(1)
}
```

### Why migrate

- `.tabItem` can't express `TabSection`, `Tab(role: .search)`, per-tab `customizationID`, or `defaultVisibility(_:for:)`.
- The modern `Tab(...value:)` ties label and selection value into one declaration, so label and `.tag` can't drift out of sync.
- iOS 26 tab-bar features (customization, sidebar adaptation) are built around the `Tab` type.

### Mechanical migration

| Legacy | Modern |
|---|---|
| `View.tabItem { Label(t, systemImage: i) }.tag(v)` | `Tab(t, systemImage: i, value: v) { View }` |
| `.tabViewStyle(.page)` | unchanged (still valid) |
| no grouping possible | wrap related tabs in `TabSection(...)` |
| no search role | `Tab(role: .search) { ... }` |

```swift
// AFTER
TabView(selection: $selection) {
    Tab("Received", systemImage: "tray.and.arrow.down.fill", value: 0) {
        ReceivedView()
    }
    Tab("Sent", systemImage: "tray.and.arrow.up.fill", value: 1) {
        SentView()
    }
}
```

Don't mix `Tab` and `.tabItem` in the same `TabView` — pick one.

---

## 5. Styles

Apply with `.tabViewStyle(_:)` on the `TabView`.

### 5.1 `.automatic` (default)

The platform-appropriate tab bar. On iOS 26 this is the floating, Liquid Glass capsule bar. You usually want this; don't override it without a reason.

### 5.2 `.sidebarAdaptable` (iOS 18+)

One declaration, platform-adaptive layout:

- **iPadOS:** top tab bar that can adapt into a sidebar.
- **iOS:** bottom tab bar (the section grouping flattens in).
- **macOS:** always a sidebar.
- **tvOS:** always a sidebar.
- **visionOS:** an ornament, plus a sidebar for `TabSection` secondary tabs.

```swift
TabView {
    Tab("Home", systemImage: "house") { HomeView() }
    Tab("Account", systemImage: "person") { AccountView() }
    TabSection("Categories") {
        Tab("Climate", systemImage: "fan") { ClimateView() }
        Tab("Lights", systemImage: "lightbulb") { LightsView() }
    }
}
.tabViewStyle(.sidebarAdaptable)
```

This is the right style for content-rich, iPad-class apps. Be aware it materially changes layout on iPad and Mac — verify there, not just on iPhone. `TabViewCustomization` (Section 8) only applies under this style.

### 5.3 `.page` (paged scrolling)

A full-screen, swipeable pager (think onboarding carousels). Index dots via `.page(indexDisplayMode:)`:

```swift
TabView {
    ForEach(pages) { page in
        PageView(page)
    }
}
.tabViewStyle(.page(indexDisplayMode: .always))
```

This is a different interaction model from a tab bar — no labels, no bottom bar; the tabs are swipe pages. Don't reach for it as a navigation tab bar.

---

## 6. The bottom accessory (iOS 26+)

`tabViewBottomAccessory(content:)` places a persistent view *above* the tab bar — the "mini-player" slot (Apple Music's now-playing bar is the canonical example). It is purpose-built: a single, persistent, app-wide accessory that sits with the tab bar, not a general overlay.

```swift
TabView {
    Tab("Home", systemImage: "house") { HomeView() }
    Tab("Alerts", systemImage: "bell") { AlertsView() }
    TabSection("Categories") {
        Tab("Climate", systemImage: "fan") { ClimateView() }
        Tab("Lights", systemImage: "lightbulb") { LightsView() }
    }
}
.tabViewBottomAccessory {
    HomeStatusView()
}
```

### Reacting to placement

The accessory's layout changes as the tab bar minimizes. Read `\.tabViewBottomAccessoryPlacement` from the environment and render the appropriate density. `TabViewBottomAccessoryPlacement` has two cases:

- `.inline` — compact, sitting inline with a visible bottom tab bar.
- `.expanded` — expanded on top of the bottom tab bar (or at the bottom of the tab's content when there is no bottom bar).

```swift
struct MusicPlaybackView: View {
    @Environment(\.tabViewBottomAccessoryPlacement) var placement

    var body: some View {
        switch placement {
        case .inline:
            ControlsPlaybackView()      // compact transport controls
        case .expanded:
            SliderPlaybackView()        // larger UI with a scrubber
        default:
            ControlsPlaybackView()
        }
    }
}
```

`TabViewBottomAccessoryPlacement` is available iOS 26+ on all platforms. Switch over its cases with a `default` so the code survives future additions.

---

## 7. Minimize behavior (iOS 26+)

`.tabBarMinimizeBehavior(_:)` controls when the floating tab bar collapses to give content more room.

```swift
TabView {
    Tab("Numbers", systemImage: "number") {
        ScrollView {
            ForEach(0..<50) { index in
                Text("\(index)").padding()
            }
        }
    }
    Tab("Alerts", systemImage: "bell") {
        AlertsView()
    }
}
.tabBarMinimizeBehavior(.onScrollDown)
```

`TabBarMinimizeBehavior` values:

- `.automatic` — system default.
- `.onScrollDown` — minimize when downward scrolling starts. **iPhone only** (`.onScrollDown` minimization is not supported for the iPad tab bar); on iPad it's a no-op.
- `.onScrollUp` — the inverse trigger.
- `.never` — never minimize.

This is an iOS 26+ modifier. Gate it behind `if #available(iOS 26, *)` if your deployment target is older, or apply it conditionally so older OSes simply skip it.

---

## 8. The search tab (iOS 26+)

`Tab(role: .search)` is a *special* tab. The system positions it apart from the others (trailing, distinct treatment in the iOS 26 bar) and gives it search semantics — you don't give it a title/image the way you would a normal tab; its role defines its appearance.

```swift
struct TabExampleView: View {
    @State private var text = ""

    var body: some View {
        TabView {
            Tab("Books", systemImage: "book") {
                BooksTab()
            }
            Tab(role: .search) {
                NavigationStack {
                    SearchContent()
                }
            }
        }
        .searchable(text: $text)
        .tabViewSearchActivation(.searchTabSelection)
    }
}
```

`.tabViewSearchActivation(_:)` controls how selecting the search tab engages search. `.searchTabSelection` activates the search field when the user selects the search tab. Pair the search tab with `.searchable(...)` on the `TabView` (or within the search tab's stack) so there is an actual search field to drive.

Don't treat the search role as a cosmetic icon swap — it changes placement and behavior, and there should be at most one per `TabView`.

---

## 9. User customization (iOS 18+)

Under `.sidebarAdaptable`, users can reorder, show, and hide tabs. To persist that, you need three things wired together:

1. An `@AppStorage`-backed `TabViewCustomization` value (persists across launches).
2. A stable `.customizationID(_:)` on **every** customizable `Tab` and `TabSection`.
3. The `.tabViewCustomization($customization)` modifier on the `TabView`.

```swift
@AppStorage("MyAppTabViewCustomization")
private var customization: TabViewCustomization

@State private var selection: MyTab = .home

TabView(selection: $selection) {
    Tab("Home", systemImage: "house", value: MyTab.home) {
        MyHomeView()
    }
    .customizationID("com.myApp.home")

    Tab("Reports", systemImage: "chart.bar", value: MyTab.reports) {
        MyReportsView()
    }
    .customizationID("com.myApp.reports")

    TabSection("Categories") {
        Tab("Climate", systemImage: "fan", value: MyTab.climate) {
            ClimateView()
        }
        .customizationID("com.myApp.climate")

        Tab("Lights", systemImage: "lightbulb", value: MyTab.lights) {
            LightsView()
        }
        .customizationID("com.myApp.lights")
    }
    .customizationID("com.myApp.categories")
}
.tabViewStyle(.sidebarAdaptable)
.tabViewCustomization($customization)
```

### Rules that bite

- **The `customizationID` must be stable and unique across builds.** It's the key the persisted layout is stored under. Change it (or omit it) and the user's saved arrangement is lost or won't restore. Use reverse-DNS strings or a derived constant — never an index or a localized title.
- **Customization only takes effect under `.sidebarAdaptable`.** The plain bar isn't user-customizable.
- A `TabSection` also takes a `customizationID` so the whole group can be reordered.

### Controlling visibility

`.defaultVisibility(_:for:)` sets a tab's initial visibility in a given placement (e.g. hidden in the sidebar by default but available to add back):

```swift
Tab("Browse", systemImage: "list.bullet", value: MyTab.browse) {
    MyBrowseView()
}
.customizationID("com.myApp.browse")
.defaultVisibility(.hidden, for: .sidebar)
```

---

## 10. Badges

Attach `.badge(_:)` to a `Tab` — numeric or string:

```swift
TabView {
    Tab("Received", systemImage: "tray.and.arrow.down.fill") {
        ReceivedView()
    }
    .badge(2)

    Tab("Sent", systemImage: "tray.and.arrow.up.fill") {
        SentView()
    }

    Tab("Account", systemImage: "person.crop.circle.fill") {
        AccountView()
    }
    .badge("!")
}
```

A numeric badge of `0` hides automatically; drive it from observed state (unread count, pending items). Keep strings short — the badge is a small pill on the tab.

---

## 11. iOS 26 floating / Liquid Glass tab bar

On the iOS 26 SDK the tab bar is restyled by the system:

- It **floats** as a Liquid Glass capsule above your content rather than sitting in an opaque bar.
- It **minimizes** on scroll (see `.tabBarMinimizeBehavior`) and **morphs** between states.
- The **bottom accessory** (Section 6) docks with it and reflows as it minimizes (the `placement` environment value).
- The search role tab gets distinct placement in the bar.

You get this by building against the iOS 26 SDK — your `Tab` declarations don't change. The job is mostly to *not fight it*:

- Don't set an opaque or custom-colored tab bar background trying to recreate the old solid bar. Let content scroll under the glass.
- Make sure scroll content extends under the floating bar (don't add manual bottom padding that recreates a fake opaque bar); use the system's safe-area handling.
- Foreground content over/under glass should use semantic colors so it stays legible as the backdrop shifts.

For everything about the glass material itself — `.glassEffect`, `GlassEffectContainer`, morphing, fallbacks, and the chrome-cohesion rules — see the **`liquid-glass`** skill. This skill owns the `TabView` API; `liquid-glass` owns the material. For the surrounding navigation chrome and toolbars, pair with the **`swiftui-toolbar`** skill.

---

## 12. Fallbacks for < iOS 26

If your deployment target is below iOS 26, the iOS 26-only modifiers don't exist on older OSes. Gate them.

```swift
var body: some View {
    let tabs = TabView(selection: $selection) {
        Tab("Home", systemImage: "house", value: AppTab.home) {
            HomeView()
        }
        Tab("Search", systemImage: "magnifyingglass", value: AppTab.search) {
            SearchView()
        }
    }

    if #available(iOS 26, *) {
        tabs
            .tabBarMinimizeBehavior(.onScrollDown)
            .tabViewBottomAccessory { NowPlayingBar() }
    } else {
        tabs   // standard bottom bar, no accessory / minimize
    }
}
```

Notes:

- `Tab(_:systemImage:value:)`, `TabSection`, `.sidebarAdaptable`, and `TabViewCustomization` are iOS 18+, so on an iOS 18–25 target they work but you get the pre-26 (non-floating) bar.
- `Tab(role: .search)`, `.tabViewSearchActivation`, `tabViewBottomAccessory`, `TabViewBottomAccessoryPlacement`, and `.tabBarMinimizeBehavior` are strictly iOS 26+. Each needs an `#available` gate (or `@available` on the surrounding view) if you ship below 26.
- The legacy `.tabItem` path remains the only option if you support iOS 17 or earlier.

---

## 13. Accessibility

- **Labels:** every tab needs a clear text label, not an icon alone. The `Tab("Title", systemImage:)` form gives VoiceOver a label automatically; if you build a custom label, ensure it has accessible text.
- **Badges:** a badge changes a tab's accessibility value (VoiceOver reads the count). Keep badge content meaningful — don't use it for decoration.
- **Reduce Motion:** the iOS 26 morph/minimize animations respect `accessibilityReduceMotion` at the system level; don't reintroduce your own large tab-transition animations that ignore it.
- **Reduce Transparency / Increase Contrast:** the system glass bar adapts automatically. Don't override the bar background in a way that defeats those settings.
- **Dynamic Type:** tab labels scale; verify the bar still reads at large accessibility text sizes — over-long titles truncate, so keep them short.
- **Search tab:** ensure the search field reachable from `Tab(role: .search)` is itself labeled and that results are navigable.

---

## 14. Quick reference

| Need | API |
|---|---|
| A tab | `Tab("Title", systemImage: "icon") { View }` |
| A selectable tab | `Tab("Title", systemImage: "icon", value: v) { View }` + `TabView(selection: $sel)` |
| Group secondary tabs | `TabSection("Heading") { Tab… }` (needs `.sidebarAdaptable`) |
| Search tab | `Tab(role: .search) { View }` + `.searchable` + `.tabViewSearchActivation(.searchTabSelection)` |
| Adaptive layout | `.tabViewStyle(.sidebarAdaptable)` |
| Paged carousel | `.tabViewStyle(.page(indexDisplayMode:))` |
| Mini-player slot | `.tabViewBottomAccessory { View }` + `@Environment(\.tabViewBottomAccessoryPlacement)` |
| Collapse bar on scroll | `.tabBarMinimizeBehavior(.onScrollDown)` (iPhone) |
| Persisted user reorder | `@AppStorage TabViewCustomization` + `.customizationID` on each tab + `.tabViewCustomization($c)` |
| Hide a tab by default | `.defaultVisibility(.hidden, for: .sidebar)` |
| Badge | `.badge(2)` / `.badge("!")` on a `Tab` |
| Legacy tab (migrate) | `View.tabItem { Label(…) }.tag(v)` |

### Version cheat sheet

- **iOS 13+:** `TabView`, `.tabItem`/`.tag`, `.tabViewStyle(.page)`.
- **iOS 18+:** `Tab` builder, `value:`, `TabSection`, `.sidebarAdaptable`, `TabViewCustomization`, `.customizationID`, `.defaultVisibility(_:for:)`.
- **iOS 26+:** `Tab(role: .search)`, `.tabViewSearchActivation`, `tabViewBottomAccessory`, `TabViewBottomAccessoryPlacement`, `.tabBarMinimizeBehavior`, floating/morphing Liquid Glass tab bar.

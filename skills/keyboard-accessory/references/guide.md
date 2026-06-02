# Keyboard Accessory — custom IME candidate strip in SwiftUI

A keyboard accessory is a view docked above the system keyboard. The non-trivial case is a custom IME-style candidate strip: the user types romanized input (e.g. ASCII pinyin) on a plain keyboard, and a horizontal strip of candidate characters appears above the keys. Tapping a candidate replaces the trailing romanized run with the chosen character — replacing the OS's own input method with your own.

> **Verified 2026-06-02** against Apple's SwiftUI documentation: `ToolbarItemGroup(placement: .keyboard)`, `ToolbarItemPlacement.keyboard` (positions items above the software keyboard, or at the bottom with a hardware keyboard; Touch Bar on macOS), and `sharedBackgroundVisibility(_:)` on `CustomizableToolbarContent` (the iOS 26 shared-glass control).

## Architecture — three concerns, kept separate

| Concern | What it owns |
|---|---|
| **Matcher** (pure logic) | `suggestions(for: String) -> [Candidate]`. Maps the trailing typed run to ranked candidates. Back it with a dictionary/index; keep it free of SwiftUI. |
| **Strip** (visual) | A horizontal `ScrollView` of candidate cells. Stateless — takes `[Candidate]` + an `onSelect` closure. |
| **Modifier** (wiring) | A `ViewModifier` that docks the strip, computes candidates from a `@Binding var text`, and performs the replace-trailing-run edit on tap. Call sites just pass the text binding. |

Keep these decoupled so the dictionary can be swapped for a real index without touching the UI.

## The five problems that actually bite

### 1. Docking — must track the keyboard, not float

`safeAreaInset(edge: .bottom)` is the textbook way to pin a bar above the keyboard, but it **fails to track the keyboard inside a `fullScreenCover`** (and some other presentations) — the bar ends up hidden behind the keyboard. The reliable cross-context placement is `ToolbarItemGroup(placement: .keyboard)`, which is backed by UIKit's input-accessory system and follows the keyboard everywhere.

```swift
content.toolbar {
    ToolbarItemGroup(placement: .keyboard) { strip }
}
```

### 2. iOS 26 Liquid Glass capsule

On iOS 26, every toolbar grouping — including `.keyboard` — is wrapped in a shared Liquid Glass capsule (rounded, translucent, side-inset). Its rounded corners let whatever sits behind it (e.g. a CTA button pushed up by keyboard avoidance) bleed through. Opt out with `sharedBackgroundVisibility(.hidden)`, gated for availability since it's iOS 26-only:

```swift
@ToolbarContentBuilder
var group: some ToolbarContent {
    if #available(iOS 26.0, *) {
        ToolbarItemGroup(placement: .keyboard) { strip }
            .sharedBackgroundVisibility(.hidden)
    } else {
        ToolbarItemGroup(placement: .keyboard) { strip }
    }
}
```

### 3. Edge-to-edge opacity

Even with glass hidden, the toolbar adds ~16pt horizontal insets, leaving gaps at the strip's corners. Counter them so the opaque background reaches both screen edges:

```swift
strip.padding(.horizontal, -16).frame(maxWidth: .infinity)
```

### 4. Incremental matching

Match per-keystroke, not per-completed-syllable. A single letter should already surface candidates (`c` → every syllable starting with `c`), plus multi-character entries the input is spelling toward, plus a greedy fallback when the input contains a full unit plus extra letters. Cap the result count so the strip stays tight.

Pin the input field to ASCII so the matcher gets clean romanized input regardless of the user's system keyboard:

```swift
TextField("…", text: $text).keyboardType(.asciiCapable)
```

### 5. Dismissal

Add a background tap to resign focus, so tapping empty space hides the keyboard (and the accessory with it):

```swift
Color.clear.contentShape(Rectangle())
    .onTapGesture { isFocused = false }
```

When the editor lives inside a `ScrollView`, add the idiomatic scroll-to-dismiss as well:

```swift
ScrollView { … }.scrollDismissesKeyboard(.immediately)
```

## The replace-trailing-run edit

On candidate tap, find the length of the trailing romanized run, delete it, append the chosen character:

```swift
let n = trailingRomanLength(in: text)   // count trailing ASCII letters
if n > 0 { text.removeLast(n) }
text.append(candidate.character)
```

This leaves already-committed characters untouched and lets the user keep typing the next syllable.

## Focus-driven content (optional)

When several fields share one accessory, vary the strip by which field is focused using `@FocusedValue` rather than rebuilding the toolbar per field:

```swift
TextField("…", text: $text).focusedValue(\.imeField, .pinyin)
// in the toolbar content:
@FocusedValue(\.imeField) var field
```

## Takeaways

- `.keyboard` toolbar placement > `safeAreaInset` for anything presented modally.
- iOS 26 glass is opt-out, not opt-in — expect to disable it on custom accessories.
- Keep matcher / strip / wiring decoupled so the dictionary can be swapped for a real index without touching the UI.
- An audio-replay or formatting toolbar is a different accessory concern — don't fold it into the IME wiring.

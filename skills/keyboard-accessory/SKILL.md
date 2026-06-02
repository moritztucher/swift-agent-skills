---
name: keyboard-accessory
description: Build a view docked above the system keyboard in SwiftUI — input accessory bars and, the hard case, a custom IME-style candidate strip (type romanized input, tap a candidate to replace the trailing run). Use when the user mentions keyboard accessory, input accessory view, a bar/toolbar above the keyboard, a candidate strip, a custom input method / IME, or pinyin/romaji-style typing. For general toolbar placements use `swiftui-toolbar`; for the glass material use `liquid-glass`.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple SwiftUI docs via Context7 (/websites/developer_apple_swiftui)
---

# Keyboard Accessory

A view docked above the system keyboard — most interestingly a custom IME candidate strip that replaces the OS input method with your own. The full pattern (three-part architecture, the replace-trailing-run edit, focus-driven content) is in `references/guide.md`. This file is the decision and discipline layer.

## Dials

1. `PLACEMENT` — `keyboard-toolbar` (default; `ToolbarItemGroup(placement: .keyboard)`, tracks the keyboard everywhere incl. modals) · `safe-area-inset` (only for a non-modal inline editor — breaks inside `fullScreenCover`).
2. `GLASS` — `shared` (default iOS 26 toolbar capsule) · `hidden` (`sharedBackgroundVisibility(.hidden)`, availability-gated — use for custom accessories so the capsule's rounded corners don't bleed content through).
3. `CONTENT` — `static` (one strip) · `focus-driven` (`@FocusedValue` to vary the strip per focused field).

## When to use

Building any bar docked above the keyboard, and especially a custom candidate/IME strip that rewrites text as the user types. Separate the matcher (pure logic), the strip (stateless view), and the wiring (a `ViewModifier`) so the dictionary can be swapped without touching the UI. For generic toolbar placement mechanics see `swiftui-toolbar`; this skill owns the keyboard-docked accessory and the IME edit.

## Core rules

- Dock with `ToolbarItemGroup(placement: .keyboard)`, not `safeAreaInset`, for anything that can be presented modally.
- Keep the matcher SwiftUI-free: `suggestions(for: String) -> [Candidate]`. The strip is stateless (`[Candidate]` + `onSelect`). The modifier does the editing.
- The replace edit: count the trailing romanized run, `removeLast(n)`, append the chosen character — never rebuild the whole string (it would clobber committed text).
- Match incrementally (per keystroke), and cap candidate count so the strip stays one row.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "`safeAreaInset(.bottom)` is the SwiftUI way to pin a bar above the keyboard." | It fails to track the keyboard inside `fullScreenCover` (and some other presentations) — the bar hides behind the keyboard. Use `ToolbarItemGroup(placement: .keyboard)`, backed by the UIKit input-accessory system. |
| "iOS 26 glass on the toolbar is fine, it's just styling." | The shared Liquid Glass capsule's rounded corners let content behind it bleed through. For a custom accessory, opt out with `sharedBackgroundVisibility(.hidden)` (gated `if #available(iOS 26.0, *)`). |
| "Glass hidden, so my opaque strip reaches the edges." | The toolbar still adds ~16pt horizontal insets, leaving corner gaps. Counter with `.padding(.horizontal, -16).frame(maxWidth: .infinity)`. |
| "I'll match once the user finishes a syllable." | Match per keystroke — a single letter should already surface candidates, plus multi-char entries being spelled toward, plus a greedy fallback. Waiting feels broken. |
| "I'll replace the whole text field value on tap." | Only replace the trailing romanized run (`removeLast(n)` + append). Rewriting the whole string clobbers already-committed characters. |
| "One accessory, so I'll hardcode its content." | If multiple fields share it, drive content with `@FocusedValue` instead of rebuilding the toolbar per field. And don't fold an unrelated audio/format bar into the IME wiring — that's a separate accessory. |

## Verification gate

- [ ] Accessory docked via `ToolbarItemGroup(placement: .keyboard)` and verified inside a `fullScreenCover`/sheet, not just an inline screen.
- [ ] iOS 26: shared glass opted out (`sharedBackgroundVisibility(.hidden)`, availability-gated) for the custom strip; nothing bleeds through behind it.
- [ ] Strip reaches both screen edges (negative horizontal padding counters the toolbar inset).
- [ ] Candidates update per keystroke and the count is capped to one row.
- [ ] Tapping a candidate replaces only the trailing run; committed text is untouched and typing continues.
- [ ] A background tap resigns focus and dismisses the keyboard + accessory.
- [ ] Matcher is SwiftUI-free and unit-testable; strip is stateless.

## Deep reference

`references/guide.md` — the three-concern architecture (matcher / strip / modifier), the docking/glass/edge/matching/dismissal problems in full, the replace-trailing-run edit, and the `@FocusedValue` focus-driven pattern, with code.

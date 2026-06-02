---
name: swiftui-badge
description: Add and style notification badges in SwiftUI with the `.badge()` modifier — counts and text on tab items, list rows, and toolbar buttons, plus `.badgeProminence()`. Use when the user mentions badge, notification count, unread indicator, tab badge, or `.badge()` in SwiftUI.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple SwiftUI docs via Context7 (/websites/developer_apple_swiftui)
---

# SwiftUI Badges

The `.badge()` modifier for notification counts and short labels on tab items, list rows, and toolbar buttons. The full reference — every placement, prominence behavior, and the toolbar workaround — is in `references/guide.md`. This file is the decision and discipline layer.

## Dials

1. `CONTENT` — `count` (`Int`; `0` auto-hides) · `text` (`String`/`LocalizedStringKey` label) · `none` (omit the modifier rather than passing an empty value).
2. `PLACEMENT` — `tab` · `list-row` · `toolbar` (works on iOS 26 but is undocumented — see the overlay caveat).
3. `PROMINENCE` — `standard` (default red) · `decreased` (accent-colored, list rows + tabs only).

## When to use

Surfacing an unread/notification count or a short status label on a tab, list row, or toolbar control. For anything richer than a count or short string (custom shapes, colors, positioning on arbitrary views), use a manual `overlay(alignment:)` instead.

## Core rules

- A `count` badge of `0` is hidden automatically — don't conditionally remove the modifier yourself.
- `.badge()` only applies to the contexts SwiftUI supports (tab items, `List` rows, toolbar buttons). On other views it's a no-op.
- Localize text badges with `LocalizedStringKey`; pass `Int` for counts so the system formats them.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll branch on `count > 0` to hide the badge." | A `count` of `0` already hides automatically. The conditional is dead code. |
| "`.badgeProminence(.decreased)` will tone down my toolbar badge." | It does **not** affect toolbar button badges — they stay red. It only changes list-row and tab badges. |
| "I'll `.badge()` this custom view to put a dot on it." | `.badge()` only works on tab items, list rows, and toolbar buttons. For arbitrary views use `overlay(alignment: .topTrailing)`. |
| "I'll hardcode the count as a `String`." | Pass an `Int` so the system localizes/format the number; use a `String`/`LocalizedStringKey` only for actual text labels. |
| "Toolbar badges are a documented API I can rely on." | Toolbar-button badge support works on iOS 26 but is undocumented — for a guaranteed accent-colored toolbar badge use a manual `overlay` with a `Text`. |

## Verification gate

- [ ] Counts passed as `Int` (auto-hide at `0`, localized formatting); text badges use `LocalizedStringKey`.
- [ ] No manual `count > 0` guard around the modifier.
- [ ] `.badgeProminence` only relied on for list-row/tab badges, not toolbar.
- [ ] Toolbar badges either accept the system red or use an explicit `overlay` for custom color.
- [ ] Badge actually renders in the target context (tab/list/toolbar) — verified on the deployment target.

## Deep reference

`references/guide.md` — the `.badge()` API across every placement, prominence behavior, the toolbar caveat, and the manual `overlay` workaround, with examples.

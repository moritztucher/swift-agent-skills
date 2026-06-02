---
name: ios-design-elevate
description: Apply a design system to an existing app's Views, screen by screen, verifying each change visually in the simulator (build → screenshot → compare → iterate). Rewrites only the visual layer — colors, fonts, spacing, motion, indicators, vocabulary — never business logic, navigation, or data flow.
user_invocable: true
argument-hint: <optional: scope — feature name, path, or "all". e.g. "Features/Dashboard" or "all">
---

# /ios-design-elevate — Apply & Verify Design

Elevate an app's visual craft by rewriting the visual layer of its Views to match the design system — and **verify every screen by actually looking at it** in the simulator. You are a senior iOS engineer focused exclusively on visual craft.

**You change:** colors, fonts, weights, sizes, tracking, gradients, indicator shapes, animation curves, spacing, backgrounds, shadows, materials, vocabulary (label text), custom shapes.
**You never change:** business logic, ViewModels, data flow, navigation, services, models, tests. If a ViewModel exposes a `Bool`, you change how the View *renders* it — not the value.

## Principles

- **Verify by sight, not imagination.** After every screen, screenshot the running app and Read the PNG. The change is real only if you can see it. This replaces guessing whether an edit "looks right."
- **Elevate craft — don't enforce a doc.** The goal is that the *after* screenshot genuinely looks better to a designer's eye, not that the code matches `DESIGN-SYSTEM.md`. Wiring in spec'd components or resizing things is not elevation unless it actually improves what's on screen. Read the design system as **direction, not gospel**: when a spec'd value looks worse rendered (e.g. an oversized hero number), keep what looks best and flag the doc as needing an update — the implementation is often the deliberate, better choice.
- **Respect intentional choices; a no-op is valid.** Existing values are usually deliberate. Before changing one, assume it might be intentional and ask whether the change truly looks better. If a screen already looks strong, **say so and leave it** — "this is already good, no change" is an honest, correct outcome. Never manufacture changes to look busy.
- **Real elevation is craft, not conformance.** The levers worth pushing are the ones that make *this* screen more refined or distinctive — composition, rhythm, hierarchy, a signature treatment — judged by the rendered result. If you can't articulate why the after looks better than the before, don't ship it.
- **Fit this app.** Push the app's own direction — don't impose an unrelated aesthetic. There is no house theme.
- **Theme first, then Views.** Extract concrete values into a shared theme layer (`Core/Theme/`) before editing screens, so Views reference tokens, not hardcoded values.
- **Consistency.** A treatment that's the app's identity should hold across every screen; one odd-one-out screen breaks it.
- **Preserve behavior.** Build after each screen; the app must work identically.

## Visual Loop (required)

1. Booted simulator UDID: `axe list-simulators` (boot with `xcrun simctl boot <UDID>` if needed).
2. Build & run: `xcodebuild -scheme "<Scheme>" -destination 'platform=iOS Simulator,name=<device>' -derivedDataPath .build build`, then `xcrun simctl install booted <App.app>` + `xcrun simctl launch booted <bundleID>`.
3. Navigate to a screen with AXe (`axe tap --label … --udid <UDID>`; see `/ios-automate`).
4. Capture: `axe screenshot --udid <UDID> --output .design/<screen>-<before|after>.png`.
5. **Read the PNG** and judge the real pixels against the design system.

## Flow

### Phase 0 — Context & reconciliation
1. Read `CLAUDE.md`, `ARCHITECTURE.md`, `docs/DESIGN-SYSTEM.md` (levers, palette+roles, type scale, vocabulary, indicators, motion), `docs/DESIGN-AUDIT.md` if present, and `~/.claude/skills/ios-design-brief/references/design-craft-patterns.md` (technique benchmark).
2. **Reconcile infrastructure:** scan for existing design packages, theme/token files, and color assets. Build a conflict table (token · system spec · existing value · action). Never let two color systems coexist — that's a top cause of invisible rendering. Decide override strategy with the user.
3. **Enforce color scheme:** if the system specifies dark or light, ensure the root view sets `.preferredColorScheme(.dark/.light)`. Materials, system colors, and vibrancy depend on it — a dark-spec app running light renders invisible gray-on-gray.

### Phase 1 — Theme layer
Create/update a theme (`Core/Theme/AppTheme.swift`) holding all concrete values from the design system — colors (with roles + gradients), the full type scale (`Font.system(size:weight:design:)`), vocabulary constants, dimensions, and animation tokens. Build any custom components the system specifies (status indicators, progress viz, badges) into `ViewComponents/`. Apply visibility minimums so tokens actually register: borders ≥2pt at ≥0.6 opacity; card surfaces ≥0.08 luminance difference from parent (or a visible border/shadow); secondary text ≥0.5, tertiary ≥0.3 opacity; depth shadows ≥4pt radius at ≥0.15 opacity. Materials only over dark-enough backgrounds.

### Phase 2 — Inventory & plan
Scope: argument → that feature/path; `all`/none → all `*View.swift`. Read each View and **look at its current screenshot**, then produce a prioritized plan (P1 main/most-seen screens → P3 supporting). For each screen, judge honestly: is it already strong (leave it), or is there a specific craft gap worth closing? Note what you'd change and *why it would look better* — not just "to match the doc." Present the plan; wait for confirmation. It's fine for the plan to conclude that some screens need nothing.

### Phase 3 — Screen-by-screen (the loop)
For each screen, in priority order:
1. **Before:** screenshot the current screen; Read it (baseline).
2. **Elevate:** make the visual-layer changes you can defend as genuine improvements, using theme tokens. If you need a display-only computed property, add it to the ViewModel without changing logic.
3. **Build:** `xcodebuild … build`. Fix failures before proceeding.
4. **After:** screenshot again; Read it.
5. **Compare — is it actually better?** Put before and after side by side and judge with a designer's eye: does the after look genuinely more refined / clearer / more distinctive? Not "does it match `DESIGN-SYSTEM.md`" — the doc can be wrong, and a value that conforms to it (e.g. a 44pt hero) can still look worse than what was there. **If the after isn't clearly better, revert the change** and note why (often: the original was a deliberate, better choice — flag the doc for update). Also sanity-check perceptibility on the real image (cards distinct from parent, borders/accents/gradients actually visible, materials over dark-enough backgrounds) — but visibility is the floor, "looks better" is the bar.
6. Brief report: what changed, *why it looks better*, files changed — or "no change: already strong."

### Phase 4 — Consistency pass
Grep for leftovers: hardcoded colors not using the theme, default `.font(.body/.headline)` without explicit weight/size, generic strings that should be vocabulary tokens, system indicators that should be custom, lingering old-package colors, materials over non-dark backgrounds, sub-minimum borders/opacities. Fix. Full build. Optionally spawn `ios-ui-design-advisor` for 10+ View projects to check cross-screen consistency.

### Phase 5 — Report
Summarize: views elevated (N/total), theme tokens + custom components created, before→after lever profile (safe/moderate/bold per lever with the technique used), screens table, build status, remaining opportunities (anything blocked on logic/navigation or needing user input), and a human-QA checklist (renders on device; Dynamic Type holds; respects reduce-motion; custom indicators have VoiceOver labels; feels like one cohesive app; identifiable from one screenshot).

## Hard rules
- Never touch business logic — tempted to edit a ViewModel method? Stop; visual layer only.
- Theme before Views; build after every screen; preserve all functionality (pull-to-refresh, swipe actions, navigation, empty states).
- If the system doesn't specify something, ask — don't guess.
- Every technique should be at the pattern-library level. `.font(.headline)` where the spec calls for `.system(size: 80, weight: .black, design: .rounded)` is defaulting, not elevating.

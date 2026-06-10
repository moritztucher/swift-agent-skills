# iOS Development Guide

Load this guide for iOS work only. Project CLAUDE.md files in iOS projects pull it in via `@~/.claude/docs/ios/ios-guide.md`.

---

## Role

**You are a senior iOS engineer.** Bring the judgment of someone who has shipped production apps for years: question requirements that conflict with platform conventions, push back on patterns that will rot, prefer Apple-native APIs over wrappers, and call out work that would not pass a senior code review. Default to building things the way an experienced Apple-platform engineer would.

---

## View Inventory (per project)

Every iOS project maintains a `VIEW-INVENTORY.md` at the project root.

- **Before implementing any new View, ViewModifier, ButtonStyle, or shared UI component:** read `VIEW-INVENTORY.md` first. If a matching component already exists, reuse or extend it rather than inventing a parallel one.
- **When adding a new shared component:** add an entry to `VIEW-INVENTORY.md` in the same turn that introduces the file.
- **When renaming or deleting a component:** update the inventory in the same diff.

`/ios-init` scaffolds an empty inventory for a new project, or scans the codebase and pre-fills it for an existing one (it auto-detects which).

---

## Core Stack

| Setting | Value |
|---------|-------|
| iOS Target | iOS 18+ (minimum) |
| UI Framework | SwiftUI only |
| Architecture | MVVM |
| Dependencies | Swift Package Manager |
| Concurrency | async/await only |
| State | @Observable pattern |

**SwiftUI API freshness — non-negotiable.** Training data lags new iOS modifier APIs by 1–2 cycles, so even on "familiar" SwiftUI work, default to consulting current sources before writing custom view code:

- **Context7** — `/websites/developer_apple_swiftui` (Apple's official SwiftUI docs, 15k+ snippets) for any modifier, View, or API question.
- **`swiftui-pro` skill** (Paul Hudson) — invoke when writing or reviewing SwiftUI; nudges toward modern APIs and modifier-first patterns.
- **`swiftui-expert-skill`** (Antoine van der Lee) — invoke for iOS 26 Liquid Glass and recent platform additions.

**Discovery rule:** before implementing a custom solution for a common UI need (list margins, scroll insets, tab accessories, color mixing, recursive lists, badges, menus, quick-look previews, etc.), check Context7/skills for a built-in modifier first. If you'd reach for a custom `View` or `ViewModifier` and the need is generic, you're probably reinventing one of Apple's recent additions.

**Swift Concurrency — same rule.** Concurrency semantics evolved fast (Swift 5.5 → 6, strict concurrency, `@concurrent`, default isolation) and training data is consistently behind:

- **`swift-concurrency` skill** — invoke for any diagnostic involving `@MainActor`, actors, `Sendable`, data races, async/await refactors, or Swift 6 migration warnings.
- **Context7 backups** — `/avdlee/swift-concurrency-agent-skill` (Antoine van der Lee, 829 snippets) or `/twostraws/swift-concurrency-agent-skill` (Paul Hudson, 208 snippets) for deeper queries.

For other frameworks, use Context7 when unfamiliar.

---

## Naming Conventions

| Component | Pattern | Example |
|-----------|---------|---------|
| Views | `[Feature]View` | `UserProfileView` |
| ViewModels | `[Feature]ViewModel` | `UserProfileViewModel` |
| Models | Noun | `User`, `Profile` |
| Managers | `[Feature]Manager` | `AuthManager` |
| Services | `[Feature]Service` | `NetworkService` |

---

## Pre-Commit Validation

Before suggesting commits:
1. Build succeeds: `xcodebuild -scheme [Scheme] -quiet build`
2. SwiftLint passes (if configured)

**On failure:** Fix simple issues automatically. For complex failures, report and ask.

---

## Architecture Rules

- **Pattern:** MVVM with NavigationCoordinator using `NavigationPath`
- **Dependency Injection:** Use SwiftUI `Environment` — no global singletons
- **Networking:** All API calls go through a `NetworkService` wrapper — Views and ViewModels never call URLSession directly
- **Project structure:**
  - `App/` — App entry point, configuration
  - `Core/` — Services, managers, extensions, shared models
  - `Features/` — Feature modules, each with Views/, ViewModels/, Models/
  - `ViewComponents/` — Shared reusable UI components
  - `Resources/` — Assets, localization, fonts
- **Feature components:** Feature-specific UI components go in `Features/[Feature]/Views/ViewComponents/`
- **Shared components:** Cross-feature UI components go in the root `ViewComponents/`
- **Concurrency:** async/await only — no Combine, no completion handlers
- **State:** `@Observable` pattern — never `@ObservableObject`/`@Published`

---

## ViewModel Rules

- **Use `@Observable` macro** — never use `@ObservableObject` or `@Published`
- **All business logic lives here** — Views only render state and forward user actions
- **No networking code** — delegate to Service classes (e.g., `NetworkService`, `AuthService`)
- **async/await only** — no completion handlers or Combine publishers
- **`@MainActor`** — annotate the class or specific methods that update UI-bound state
- **Testable:** Depend on protocol abstractions for services, enabling mock injection in tests
- **Loading/error state:** Expose loading and error states as published properties for the View to observe

---

## SwiftUI View Rules

- **No business logic in Views** — delegate all logic to ViewModels
- **Use `.task`** for async work, not `onAppear` with `Task { }`
- **Prefer ternary** for conditional property changes (preserves view identity, better animation)
- **Avoid closures** in view modifier parameters — they are not `Equatable` and cause unnecessary redraws
- **Cheap init()** — never perform async work or heavy computation in a View initializer
- **Extract subviews freely** — there is no performance cost to extracting subviews into separate structs/properties
- **Accessibility:** Always check `accessibilityReduceMotion` before adding animations
- **Previews:** Include `#Preview` with multiple configurations (light/dark, different data states)
- **State:** Use `@State` for view-local state, pass ViewModel via `.environment()` or init
- **Navigation:** Use `NavigationPath`-based coordination, not `NavigationLink(destination:)`

---

## SwiftUI Patterns

- **List rows:** Use `.contentShape(.rect)` on List row content so the entire area is tappable
- **Backgrounds:** When a view or sheet has a background color/gradient, use `.ignoresSafeArea()` or apply the background to the outermost container so it covers the entire screen

---

## Swift Style Rules

- **Naming:** `camelCase` for variables/functions, `PascalCase` for types/protocols
- **Immutability:** Prefer `let` over `var` — only use `var` when mutation is required
- **Line length:** Max 130 characters
- **Organization:** Use `// MARK: -` to separate logical sections (Properties, Lifecycle, Methods, etc.)
- **One View per file:** Each SwiftUI View struct gets its own file
- **Self:** Only use explicit `self` when the compiler requires it (closures, initializers)
- **Errors:** Define custom `LocalizedError` enums per error domain — avoid raw strings
- **Secrets:** Keychain for sensitive data (tokens, passwords). UserDefaults for non-sensitive preferences only
- **Guard:** Prefer `guard` for early exits over nested `if` statements
- **Access control:** Use the most restrictive access level possible (`private` by default, widen as needed)

---

## Security Rules

- **No hardcoded secrets** — never commit API keys, tokens, or passwords in source code
- **HTTPS only** — all network requests must use HTTPS, no exceptions
- **Keychain** for tokens, passwords, and credentials — never UserDefaults for sensitive data
- **PrivacyInfo.xcprivacy** — include and keep updated for App Store compliance
- **Input validation** at system boundaries — user input, API responses, deep links
- **SSL/TLS** — never disable certificate validation, even in debug builds
- **Biometrics** — use `LocalAuthentication` framework for biometric auth, always provide a fallback

---

## Testing Rules

- **Framework:** Use XCTest
- **File naming:** `[ClassName]Tests.swift` — mirror the main project's folder structure
- **SUT naming:** Name the system under test `sut` for clarity
- **Mocks:** Create mock services via protocol conformance — no production service instances in tests
- **Edge cases:** Test error conditions, empty states, and boundary values — not just the happy path
- **One focus per test:** Each test method should assert one logical behavior
- **Async testing:** Use `async` test methods with `await` — no `XCTestExpectation` for async/await code
- **Naming:** `test_[method]_[condition]_[expectedResult]` (e.g., `test_login_invalidPassword_throwsError`)

---

## iOS Development Workflow

The skills compose into a light lifecycle: **Setup → Plan → Build → Verify → Ship.** Not sure where you are? Run **`/ios`** — the orchestrator detects the project's state and routes you to the right next step.

The build philosophy is **UI-first**: get the app's flow feeling good with the UI layer before wiring logic and backend. The brief decomposes each feature into a UI layer and a Logic & Backend layer so you can do exactly that. There is no formal epic/preflight/TDD-delivery pipeline.

**Standard path (works for new *and* existing projects — `/ios-init` and `/ios-brief` auto-detect which):**
```
/ios-init → /ios-brief → /ios-design-brief → build features UI-first, then logic
    → /ios-design-audit / /ios-design-elevate → /ios-review → /ios-commit → /pr-to-develop
```

**Design-only improvement:**
```
/ios-design-brief → /ios-design-audit → /ios-design-elevate → /ios-review
```

| Phase | Skill | What It Does | Output |
|-------|-------|-------------|--------|
| Setup | `/ios` | Detect project state, show the map, route to the next step | — |
| Setup | `/ios-load` | Load iOS guide into an ad-hoc chat with no project `CLAUDE.md` | — |
| Setup | `/ios-init` | New / fresh / existing project: description-led setup + repo files | CLAUDE.md, ARCHITECTURE.md, ADR-0001, .gitignore, LICENSE, README |
| Plan | `/ios-brief` | Living source of truth: features split into UI + Logic/Backend, MVP vs Later | docs/PROJECT-BRIEF.md |
| Plan | `/ios-design-brief` | Establish project-wide visual design system through Q&A | docs/DESIGN-SYSTEM.md |
| Build | *(write code)* | Build the next MVP feature UI-first, then layer in logic & backend | Production code |
| Build | `/ios-design-elevate` | Rewrite visual layer to match design system — theme, levers, consistency | Elevated Views + theme layer |
| Build | `/ios-build`, `/ios-test`, `/ios-automate` | Build the project, run tests, drive the simulator | Build/test results |
| Verify | `/ios-review` | Severity-rated code review (CRITICAL/HIGH/MEDIUM/LOW) | review-{file}.md |
| Verify | `/ios-audit` | Four-lens audit (PM/UX/UI/ARCH) of project or feature | docs/AUDIT-REPORT.md |
| Verify | `/ios-design-audit` | Audit visual craft against pattern library benchmarks | docs/DESIGN-AUDIT.md |
| Verify | `/ios-onboarding-audit` | Onboarding audit or greenfield design (activation, permissions, flow) | docs/ONBOARDING-AUDIT.md |
| Ship | `/ios-commit` | Well-formed commit following project conventions | Commit |
| Ship | `/pr-to-develop`, `/pr-to-main` | PR into develop; release PR develop → main | Pull request |
| Ship | `/ios-release-notes` | Categorized release summary + App Store "What's New" from git | Release notes |

**Rules:**
- **Plan** writes to `docs/` — no code. The brief is a living reference; re-run `/ios-brief` to keep it current.
- **Build UI-first** — make the flow feel good before wiring logic. Tests are encouraged for logic/backend but not gated by a formal verification step.
- `/ios-design-elevate` rewrites only the visual layer and must not break existing behaviour.
- A change isn't done until `/ios-review` shows no CRITICAL issues.
- Design isn't done until `/ios-design-audit` shows at least 2-3 levers at "bold" and no HIGH findings remain.

---

## Project Initialization (/ios-init)

Detects **new** / **fresh Xcode scaffold** / **existing** codebase and adapts. Typical flow: create the Xcode project → run `/ios-init` → describe the project in a few sentences.

**Step 1 — Project Description:** the user describes the project in 1–5 sentences (what it is, storage, platforms, open-source/commercial, B2B/B2C). The skill mines this for technical *and* product signals, pre-fills decisions, and only asks about gaps. The raw blurb is carried into `/ios-brief`.

**Setup path (new / fresh scaffold):**
- **A1 Setup:** Platforms (multi-select: iOS / iPadOS / macOS / visionOS / tvOS / watchOS), deployment target, database, distribution (open source / commercial), audience (B2B / B2C), git prefix, bundle ID.
- **A2 Tech brainstorm:** networking, auth, navigation, sync, offline, integrations — confidence-tracked (→90%). Scaffolds the folder structure.

**Adopt path (existing):** scan the codebase, present findings, fill only undetectable gaps; document the existing structure instead of scaffolding.

Then create: `CLAUDE.md`, `.claude/memory.md`, `ARCHITECTURE.md` (diagram tailored to the actual decisions), `docs/decisions/ADR-0001`, `CHANGELOG.md`, `VIEW-INVENTORY.md`, `.gitignore`, `LICENSE` (when applicable), `README.md`, folder structure (new/fresh only), and optionally `Backlog.md`. Repo files are generated-if-missing — never silently overwritten. Finishes by writing `docs/.ios-init-decisions.json` and handing off to `/ios-brief`.

---

## Quick Reference

### Use
- SwiftUI, async/await, SPM, NavigationPath
- Environment for DI, @Observable pattern
- Context7 for docs, ADRs for decisions

### Avoid
- UIKit, completion handlers, hardcoded secrets
- Business logic in Views, @ObservableObject/@Published

---

## Reference Docs

For detailed guidelines, read these when needed:

| Topic | Doc |
|-------|-----|
| Coding standards, testing, security | `~/.claude/docs/ios/ios-coding-standards.md` |
| Git workflow, commits, PRs, Issues | `~/.claude/docs/git-workflow.md` |
| Architecture, DI, project structure, ADRs | `~/.claude/docs/ios/architecture-patterns.md` |

---

## Project Templates

| Template | Location |
|----------|----------|
| Project Memory | `~/.claude/docs/templates/project-memory-template.md` |
| Architecture | `~/.claude/docs/templates/architecture-template.md` |
| ADR | `~/.claude/docs/templates/adr-template.md` |
| Changelog | `~/.claude/docs/templates/changelog-template.md` |
| Backlog | `~/.claude/docs/templates/backlog-template.md` |
| Design System | `~/.claude/docs/templates/design-system-template.md` |
| View Inventory | `~/.claude/docs/templates/view-inventory-template.md` |

---

## Framework Skills

The deep framework guidance lives in the installed skill catalog, not in docs. Before implementing or reviewing any Apple framework feature (Live Activities, widgets, HealthKit, StoreKit, App Intents, …), check the catalog for a matching specialist skill and load it before writing code — prefer a loaded skill over answering from memory. Skill names are framework-literal (`healthkit`, `storekit`, `widgetkit`, …); if no name matches the user's phrasing, scan for the feature ("lock screen tracking" → `activitykit`, "Sign in with Apple" → `authenticationservices`).

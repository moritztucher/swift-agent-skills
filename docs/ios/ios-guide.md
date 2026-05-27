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

`/ios-init` scaffolds an empty inventory; `/ios-init-existing` scans the codebase and pre-fills it.

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

Use Context7 for up-to-date docs when implementing unfamiliar frameworks.

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

The standard workflow for taking a project from idea to delivered epic:

**New project:**
```
/ios-init → /project-brief → /ios-design-brief → /epic-detail {N} → /preflight-check
    → /ios-implement-epic {N} → /ios-design-audit → /ios-design-elevate
    → /ios-verify {N} → /ios-review
```

**Existing project (already has code):**
```
/ios-init-existing → /project-brief-existing → /ios-design-brief → /epic-detail {N} → /preflight-check
    → /ios-implement-epic {N} → /ios-design-audit → /ios-design-elevate
    → /ios-verify {N} → /ios-review
```

**Existing project (design-only improvement):**
```
/ios-design-brief → /ios-design-audit → /ios-design-elevate → /ios-review
```

| Step | Skill | What It Does | Output |
|------|-------|-------------|--------|
| 1a | `/ios-init` | New project: setup + tech brainstorm (90% confidence) | CLAUDE.md, ARCHITECTURE.md, ADR-0001, folder structure |
| 1b | `/ios-init-existing` | Existing project: scan codebase, pre-fill docs from observed facts | Same files, pre-filled from code scan |
| 2 | `/project-brief` | Define project scope, features, epics (reads ios-init decisions) | docs/PROJECT-BRIEF.md |
| 2.5 | `/ios-design-brief` | Establish project-wide visual design system through Q&A | docs/DESIGN-SYSTEM.md |
| 3 | `/epic-detail {N}` | Expand epic into implementation doc with PM/UX/UI/ARCH questions + ACs | docs/epics/EPIC-{N}.md |
| 4 | `/preflight-check` | Validate brief + all epics for contradictions and gaps | docs/PREFLIGHT-REPORT.md |
| 5 | `/ios-implement-epic {N}` | TDD delivery: write tests → implement → verify → fix gaps → report | Production + test code |
| 5.5 | `/ios-design-audit` | Audit visual craft against pattern library benchmarks | docs/DESIGN-AUDIT.md |
| 5.6 | `/ios-design-elevate` | Rewrite visual layer to match design system — theme, levers, consistency | Elevated Views + theme layer |
| 6 | `/ios-verify {N}` | Run all tests, map results to ACs, produce gap report | docs/epics/EPIC-{N}_verification.md |
| 7 | `/ios-review` | Severity-rated code review (CRITICAL/HIGH/MEDIUM/LOW) | review-{file}.md |
| * | `/ios-audit` | Four-lens audit (PM/UX/UI/ARCH) of existing project or feature | docs/AUDIT-REPORT.md |
| * | `/ios-onboarding-audit` | Onboarding audit or greenfield design (activation, permissions, flow, metrics) | docs/ONBOARDING-AUDIT.md |

**Rules:**
- Steps 1-4 are **planning** — no code, confidence-tracked (90% threshold)
- Steps 5-7 are **execution** — code + tests, pass/fail verification
- Steps 5.5-5.6 are **design execution** — runs after functional code works, before final verify. Design elevation must not break existing tests.
- All acceptance criteria MUST have an AC-ID (e.g., `AC-1`) and a test type (`unit` / `integration` / `ui`)
- Test names MUST include AC-ID: `/// AC-1: criterion` + `test_AC1_method_condition_expected()`
- Implementation is not complete until `/ios-verify` passes and `/ios-review` has no CRITICAL issues
- Design is not complete until `/ios-design-audit` shows at least 2-3 levers at "bold" and no HIGH findings remain

---

## Project Initialization (/ios-init)

Two phases:

**Phase A — Setup:** Ask 4 questions:
1. Database: SwiftData / RealmSwift / CoreData / None
2. iOS Target: iOS 18+ / iOS 26+ / Other
3. Git Prefix: e.g., P66, APP
4. Bundle ID: e.g., com.company.appname

**Phase B — Tech Architecture Brainstorm:** Iteratively ask about networking, auth, navigation, sync, offline support, 3rd-party integrations, etc. Track confidence (30% -> 90%). Stop when 90% or user says "done."

Then create: `CLAUDE.md`, `.claude/memory.md`, `ARCHITECTURE.md`, `docs/decisions/ADR-0001`, `CHANGELOG.md`, project folder structure, and optionally `Backlog.md` (pre-seeded with tasks from tech choices).

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

## Framework Guides

Organized by domain in `~/.claude/docs/ios/`. Read the relevant guide before implementing unfamiliar frameworks.

| Category | Path | Guides |
|----------|------|--------|
| SwiftUI | `docs/ios/swiftui/` | swiftui-guidelines, swiftui-performance, swiftui-badge, swiftui-webview, LiquidGlass, swift-charts, attributed-string, tipkit, design-craft-patterns |
| AppKit | `docs/ios/appkit/` | appkit, appkit-liquid-glass |
| Data & Persistence | `docs/ios/data/` | swiftdata, realmswift, cloudkit, corespotlight |
| Commerce | `docs/ios/commerce/` | storekit, revenuecat, revenuecat-paywall-fix, firebase, passkit |
| AI & ML | `docs/ios/ai/` | coreml, foundation-models, visual-intelligence, speech-analyzer |
| Screen Time | `docs/ios/screen-time/` | screen-time-api, familycontrols, managedsettings, deviceactivity |
| Hardware | `docs/ios/hardware/` | corebluetooth, accessorysetupkit, wifiaware, corehaptics, energykit, watchconnectivity |
| System | `docs/ios/system/` | activitykit, widgetkit, appintents, healthkit, auth, localauthentication, corelocation, mapkit, avfoundation, photosui, contacts, eventkit, notifications, carplay, translation, and more |

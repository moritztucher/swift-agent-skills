# iOS House Rules

Agent-neutral iOS/Swift engineering rules for this skill set. Claude Code users get these via the `@import`-ed iOS guide; if you are using Codex, Cursor, Gemini CLI, Kiro, or any other [Agent Skills](https://agentskills.io/clients) client, this file is your equivalent. Copy it (or symlink it) into your iOS project root as `AGENTS.md`.

The full skill catalog installs on any compatible agent with:

```bash
npx skills add moritztucher/swift-agent-skills
```

---

## Role

Act as a senior iOS engineer. Question requirements that conflict with platform conventions, push back on patterns that will rot, prefer Apple-native APIs over wrappers, and call out work that would not pass a senior code review.

---

## Core Stack

| Setting | Value |
|---------|-------|
| iOS Target | iOS 18+ (minimum) |
| UI Framework | SwiftUI only |
| Architecture | MVVM |
| Dependencies | Swift Package Manager |
| Concurrency | async/await only |
| State | `@Observable` pattern |

**Skill routing.** Before implementing or reviewing any Apple framework feature (Live Activities, widgets, HealthKit, StoreKit, App Intents, …), check the installed skill catalog for a matching specialist and load it before writing code — prefer a loaded skill over answering from memory. Skill names are framework-literal (`healthkit`, `storekit`, `widgetkit`, …), so match on the framework name first; if no name matches the user's phrasing, scan the catalog for the feature ("lock screen tracking" → `activitykit`, "Sign in with Apple" → `authenticationservices`).

**API freshness — non-negotiable.** Training data lags new SwiftUI and Swift Concurrency APIs by 1–2 release cycles. Before writing custom view code for a common UI need (list margins, scroll insets, tab accessories, color mixing, badges, menus, quick-look previews, …), check current Apple documentation for a built-in modifier first — if you'd reach for a custom `View` or `ViewModifier` and the need is generic, you're probably reinventing a recent Apple addition. The `swiftui-pro` and `swift-concurrency` skills from this catalog encode that discipline and work on any Agent Skills client.

---

## Component Reuse

Before implementing any new View, ViewModifier, ButtonStyle, or shared UI component, search the codebase (`ViewComponents/`, the feature's `ViewComponents/`) for an existing match — reuse or extend it rather than inventing a parallel one.

Projects may optionally keep a `VIEW-INVENTORY.md` index at the root. If the project has one, check it first and update it in the same diff that adds, renames, or removes a shared component.

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

## Architecture Rules

- **Pattern:** MVVM with a NavigationCoordinator using `NavigationPath` — centralize navigation, support deep links through the coordinator.
- **Dependency injection:** SwiftUI `Environment` — no global singletons. Use init injection for ViewModels when testing is critical.
- **Networking:** all API calls go through a `NetworkService` wrapper — Views and ViewModels never call URLSession directly.
- **Concurrency:** async/await only — no Combine, no completion handlers.
- **State:** `@Observable` macro — never `@ObservableObject`/`@Published`. `@State` for view-local state and for owning `@Observable` objects; `@Environment` for app-wide dependencies.
- **Project structure:**
  - `App/` — entry point, configuration
  - `Core/` — services, managers, extensions, shared models, navigation, protocols
  - `Features/[Feature]/` — `Views/` (with feature-local `ViewComponents/`) and `ViewModels/`
  - `ViewComponents/` (root) — components reused across features
  - `Resources/` — assets, localization, fonts

---

## ViewModel Rules

- `@Observable` macro; all business logic lives here — Views only render state and forward actions.
- No networking code — delegate to Service classes.
- async/await only; annotate the class or UI-state-updating methods with `@MainActor`.
- Depend on protocol abstractions for services so mocks can be injected in tests.
- Expose loading and error states as observable properties.

---

## SwiftUI View Rules

- No business logic in Views.
- Use `.task` for async work, not `onAppear` with `Task { }`.
- Prefer ternary for conditional property changes (preserves view identity, better animation).
- Avoid closures in view modifier parameters — they are not `Equatable` and cause unnecessary redraws.
- Cheap `init()` — never perform async work or heavy computation in a View initializer.
- Extract subviews freely — no performance cost.
- Always check `accessibilityReduceMotion` before adding animations.
- Include `#Preview` with multiple configurations (light/dark, different data states).
- Navigation via `NavigationPath` coordination, not `NavigationLink(destination:)`.
- List rows: `.contentShape(.rect)` so the entire row is tappable.
- Full-screen backgrounds: apply to the outermost container or use `.ignoresSafeArea()`.

---

## Swift Style

- `camelCase` for variables/functions, `PascalCase` for types/protocols.
- Prefer `let` over `var`; prefer `guard` for early exits.
- Max line length 130 characters; organize with `// MARK: -` sections.
- One SwiftUI View struct per file; explicit `self` only when the compiler requires it.
- Most restrictive access level possible — `private` by default.
- Custom `LocalizedError` enums per error domain — no raw error strings.
- DocC comments where suitable; inline comments only for the *why* of non-obvious logic (rate limits, edge cases, side effects).
- Keep code simple and minimal — no over-engineering.

---

## Security Rules

- No hardcoded secrets — never commit API keys, tokens, or passwords.
- HTTPS only; never disable SSL/TLS certificate validation, even in debug builds.
- Keychain for tokens, passwords, credentials — UserDefaults only for non-sensitive preferences.
- Include and maintain `PrivacyInfo.xcprivacy` for App Store compliance.
- Validate input at system boundaries — user input, API responses, deep links.
- Biometrics via the LocalAuthentication framework, always with a fallback.

---

## Testing Rules

- XCTest; test files named `[ClassName]Tests.swift`, mirroring the main project structure.
- Name the system under test `sut`; mock services via protocol conformance — no production service instances in tests.
- `async` test methods with `await` — no `XCTestExpectation` for async/await code.
- Test naming: `test_[method]_[condition]_[expectedResult]`.
- Test error conditions, empty states, and boundary values — not just the happy path. One logical behavior per test.

---

## Definition of Done

Before marking any task complete:

- Compiles without errors or warnings; SwiftLint passes if configured.
- No hardcoded secrets; sensitive data in Keychain; all requests HTTPS.
- No business logic in Views; ViewModels own data manipulation; Services own external operations.
- Async work uses `.task`; no unnecessary re-renders.
- Follows HIG; respects Dynamic Type and accessibility settings; correct in light and dark mode.
- Edge cases handled; error states show user-friendly messages.

---

## Documentation Conventions

- **ADRs** in `docs/decisions/NNNN-brief-title.md` (Status / Context / Decision / Consequences / Date) for decisions that add dependencies, choose between patterns, deviate from standards, or carry significant trade-offs.
- **ARCHITECTURE.md** at project root: system overview, key decisions (linking ADRs), component relationships.
- **CHANGELOG.md** with categorized entries (Added / Fixed / Changed / Removed) per version.
- Ask before modifying a project's `Backlog.md`.

---

## Workflow Skills

The `/ios-*` workflow skills (init → brief → design-brief → build → review → commit → PR) install with the catalog and run on any Agent Skills client. On clients without subagent support, the audit/review skills run their advisor passes inline instead of in parallel — same output, slower. See `README.md` § Non-Claude users.

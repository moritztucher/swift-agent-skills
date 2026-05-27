# Architecture Patterns

> Full architecture patterns reference. Core rules are in CLAUDE.md.

## Navigation

- **Use NavigationCoordinator with NavigationPath** for all navigation logic
- Centralize navigation in a coordinator to keep views clean and testable
- Support deep linking through the coordinator

## Dependency Injection

- **Prefer Environment** for passing dependencies down the view hierarchy
- Use init injection for ViewModels when testing is critical
- Never use global singletons unless absolutely necessary

```swift
@main
struct MyApp: App {
    @State private var userManager = UserManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(userManager)
        }
    }
}

// In child views
struct ContentView: View {
    @Environment(UserManager.self) var userManager
}
```

## Network Layer

- **Always use a wrapper NetworkService pattern** with async/await
- Never put networking code directly in ViewModels
- Centralize URL construction, headers, and error handling in the service

```swift
class NetworkService {
    func fetch<T: Decodable>(_ endpoint: String) async throws -> T {
        let url = URL(string: "https://api.example.com/\(endpoint)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
```

## State Management

- Use `@State` for local view state and owning `@Observable` objects
- Use `@Observable` macro for ViewModels and Managers (NOT `@ObservableObject`)
- Use `@Environment` for app-wide dependencies
- Pass `@Observable` objects as plain properties when not using Environment

```swift
@Observable
class UserViewModel {
    var user: User?
    var isLoading = false

    func fetchUser() async {
        // Implementation
    }
}

struct UserView: View {
    @State private var viewModel = UserViewModel()

    var body: some View {
        // View content
    }
}
```

## Project Structure

```
ProjectName/
├── App/
│   ├── ContentView.swift
│   └── ProjectNameApp.swift
├── Core/
│   ├── Model/
│   │   └── [ModelName]/          # Contains Model + ModelManager
│   ├── Services/
│   ├── Enums/
│   ├── Extensions/
│   ├── Navigations/
│   ├── Utilities/
│   └── Protocols/
├── Development/                   # Views for testing animations/workflows
├── ViewComponents/                # Shared components across features
├── Features/
│   └── [FeatureName]/
│       ├── Views/
│       │   └── ViewComponents/
│       └── ViewModels/
└── Resources/                     # Asset folders
```

## Architecture Decision Records (ADRs)

### When to Create

Create an ADR for decisions that:
- Add a new dependency or framework
- Choose between architectural patterns
- Deviate from standard practices
- Involve significant trade-offs

**Rule of thumb:** If you'd need to explain "why did we do it this way?" in 6 months, write an ADR.

### Location

Store ADRs in: `docs/decisions/`

### Format

Filename: `NNNN-brief-title.md` (e.g., `0001-use-realmswift-for-persistence.md`)

```markdown
# ADR-NNNN: [Title]

## Status
[Proposed | Accepted | Deprecated | Superseded by ADR-XXXX]

## Context
[What is the issue or decision we're facing?]

## Decision
[What did we decide to do?]

## Consequences
### Pros
- [Benefit 1]
- [Benefit 2]

### Cons
- [Drawback 1]
- [Drawback 2]

## Date
[YYYY-MM-DD]
```

## ARCHITECTURE.md

Maintain an `ARCHITECTURE.md` file in the project root that provides:
- High-level system overview
- Key architectural decisions (linking to ADRs)
- Component relationships
- Data flow diagrams (when helpful)

Update when architecture changes significantly.

## Documentation Management

### CHANGELOG.md

```markdown
# Changelog

## [Unreleased]

## [1.2.0] - 2024-01-15
### Added
- User profile editing feature

### Fixed
- Navigation crash on iPad

### Changed
- Updated authentication flow
```

Include: Version number, Date, Categorized changes (Added, Fixed, Changed, Removed)

### Update Documentation After

- Adding public APIs or interfaces
- Making architecture changes
- Adding new features

## Backlog Management

Optional `Backlog.md` in project root:

```markdown
# Backlog

## Features
### High Priority
- [ ] Feature description

### Medium Priority
- [ ] Feature description

### Low Priority
- [ ] Feature description

## Bugs
### High / Medium / Low Priority
- [ ] Bug description

## Tech Debt
### High / Medium / Low Priority
- [ ] Tech debt item

## Ideas
- [ ] Future consideration
```

**Rule:** Ask before modifying the backlog file.

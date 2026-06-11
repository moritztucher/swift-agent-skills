# Architecture Patterns — Examples & Formats

> The rules live in `ios-guide.md` (loaded via `@import`). This file carries the expanded code examples, the detailed project structure, and the documentation formats.

## Dependency Injection (Environment)

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

## Network Layer (NetworkService wrapper)

```swift
class NetworkService {
    func fetch<T: Decodable>(_ endpoint: String) async throws -> T {
        let url = URL(string: "https://api.example.com/\(endpoint)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
```

## State Management (@Observable)

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

## Project Structure (detailed)

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

Create an ADR for decisions that:
- Add a new dependency or framework
- Choose between architectural patterns
- Deviate from standard practices
- Involve significant trade-offs

**Rule of thumb:** If you'd need to explain "why did we do it this way?" in 6 months, write an ADR.

Store in `docs/decisions/`, filename `NNNN-brief-title.md` (e.g., `0001-use-swiftdata-for-persistence.md`). Use the template at `~/.claude/docs/templates/adr-template.md`.

## ARCHITECTURE.md

Maintain an `ARCHITECTURE.md` in the project root: high-level system overview, key decisions (linking ADRs), component relationships, data-flow diagrams when helpful. Update when architecture changes significantly.

## CHANGELOG.md

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

Include: version number, date, categorized changes (Added, Fixed, Changed, Removed). Update documentation after adding public APIs, making architecture changes, or adding features.

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

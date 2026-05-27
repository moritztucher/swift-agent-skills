# Architecture Rules

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

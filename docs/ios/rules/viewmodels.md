---
globs: "**/*ViewModel.swift,**/ViewModels/**/*.swift"
---

# ViewModel Rules

- **Use `@Observable` macro** — never use `@ObservableObject` or `@Published`
- **All business logic lives here** — Views only render state and forward user actions
- **No networking code** — delegate to Service classes (e.g., `NetworkService`, `AuthService`)
- **async/await only** — no completion handlers or Combine publishers
- **`@MainActor`** — annotate the class or specific methods that update UI-bound state
- **Testable:** Depend on protocol abstractions for services, enabling mock injection in tests
- **Loading/error state:** Expose loading and error states as published properties for the View to observe

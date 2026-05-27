---
globs: "**/*View.swift,**/Views/**/*.swift"
---

# SwiftUI View Rules

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

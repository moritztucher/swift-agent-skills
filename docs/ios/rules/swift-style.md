---
globs: "**/*.swift"
---

# Swift Style Rules

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

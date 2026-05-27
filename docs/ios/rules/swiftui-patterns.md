---
globs: "**/*View.swift,**/Views/**/*.swift"
---

# SwiftUI Patterns

- **List rows:** Use `.contentShape(.rect)` on List row content so the entire area is tappable
- **Backgrounds:** When a view or sheet has a background color/gradient, use `.ignoresSafeArea()` or apply the background to the outermost container so it covers the entire screen

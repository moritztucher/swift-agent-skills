---
name: ios-review
description: Perform a thorough code review on changes or specified files
---

# /review - Code Review

Perform a thorough, severity-rated code review on changes or specified files. Produces a structured report with rule citations and actionable fix suggestions.

## Instructions

### Step 1 — Determine Scope

- If argument provided (file path or directory), review that target
- Otherwise, ask: staged changes, unstaged changes, or specific file?

For staged/unstaged changes:
```bash
git diff --staged  # or git diff for unstaged
```

For directories, glob for `*.swift` files and read the architecturally significant ones.

### Step 2 — Load Rules

Read the project's architectural rules from these sources (skip any that don't exist):
1. `CLAUDE.md` — project-specific tech decisions and rules (the `@import`-ed iOS guide carries the global rules)
2. `ARCHITECTURE.md` — architecture overview and patterns
3. `AGENTS.md` at the project root, if present (non-Claude setups carry the house rules there)

### Step 3 — Review Across Categories

Analyze code against every rule category. For each category, note what was followed correctly and what was violated.

#### Category 1: Architecture (MVVM)
- Views contain no business logic — only render state and forward actions
- ViewModels use `@Observable` — never `@ObservableObject` / `@Published`
- ViewModels delegate to Service classes — no direct networking
- Services accessed via protocol abstractions for testability
- Feature code in `Features/[Name]/`, shared components in `ViewComponents/`

#### Category 2: SwiftUI Patterns
- `.task` for async work — not `onAppear` with `Task { }`
- Ternary for conditional property changes (preserves view identity)
- No closures in view modifier parameters (not `Equatable`, causes redraws)
- Cheap `init()` — no async work or heavy computation in View initializers
- `.contentShape(.rect)` on List rows for full tappability
- Background colors use `.ignoresSafeArea()` on outermost container
- `#Preview` with multiple configurations

#### Category 3: Navigation
- `NavigationPath`-based coordination — not `NavigationLink(destination:)`
- NavigationCoordinator pattern for centralized navigation
- Deep linking handled if declared in ARCHITECTURE.md

#### Category 4: Concurrency
- async/await only — no Combine publishers, no completion handlers
- `@MainActor` on ViewModels or methods that update UI-bound state
- Thread safety for shared mutable state

#### Category 5: Security (OWASP Top 10)
- No hardcoded secrets, API keys, tokens, or passwords
- HTTPS only — no HTTP URLs
- Keychain for credentials — never UserDefaults for sensitive data
- Input validation at system boundaries
- SSL/TLS certificate validation never disabled

#### Category 6: Data & State
- `@State` for view-local state only
- ViewModel passed via `.environment()` or init
- Environment for dependency injection — no global singletons
- Proper error handling with custom `LocalizedError` enums

#### Category 7: Swift Style
- `camelCase` for variables/functions, `PascalCase` for types/protocols
- `let` over `var` — `var` only when mutation required
- `guard` for early exits — not nested `if`
- `// MARK: -` to separate logical sections
- One View per file
- Most restrictive access level (`private` by default)
- Max 130 character line length

#### Category 8: Performance
- No unnecessary view redraws (closures in modifiers, missing `Equatable`)
- Check `accessibilityReduceMotion` before animations
- Pagination for large data sets
- Appropriate caching strategy

### Step 4 — Classify Each Violation

For each violation, assign a severity:

| Severity | Definition | Examples |
|----------|-----------|----------|
| **CRITICAL** | Security risk, data loss, or crash | Hardcoded secret, force unwrap on optional API response, no Keychain for tokens |
| **HIGH** | Breaks architectural rule, will cause maintainability problems | Business logic in View, `@ObservableObject` instead of `@Observable`, completion handlers |
| **MEDIUM** | Diverges from convention, creates tech debt | Wrong file placement, missing error handling, no `@MainActor` |
| **LOW** | Minor style or naming inconsistency | Missing `// MARK:`, slightly over line length, missing `private` |

### Step 5 — Generate Report

Present the full report. Also save to `review-{basename}.md` in the same directory if reviewing a file/directory.

```markdown
# Code Review — {file or feature name}

**Date:** {YYYY-MM-DD}
**Reviewed:** {path or "staged changes"}
**Reviewer:** /ios-review

---

## Summary

| Severity | Count |
|----------|-------|
| CRITICAL | N |
| HIGH | N |
| MEDIUM | N |
| LOW | N |
| **Total** | **N** |

**Verdict:** {PASS / PASS WITH WARNINGS / FAIL}
- PASS: zero CRITICAL and HIGH violations
- PASS WITH WARNINGS: zero CRITICAL, one or more HIGH
- FAIL: one or more CRITICAL violations

---

## Violations

### CRITICAL

#### CRIT-1: {Short title}
- **File:** `path/to/file.swift:line`
- **Rule:** {Rule name and category}
- **What's wrong:** {Concise description}
- **Fix:** {Specific, actionable fix — code snippet if helpful}

### HIGH

#### HIGH-1: {Short title}
- **File:** `path/to/file.swift:line`
- **Rule:** {Rule name and category}
- **What's wrong:** {Concise description}
- **Fix:** {Specific, actionable fix}

### MEDIUM

#### MED-1: {Short title}
...

### LOW

#### LOW-1: {Short title}
...

---

## What Looks Good

- {Brief bulleted list of rules that were followed correctly — reward good patterns}

---

## Recommendations

{Architectural suggestions beyond specific violations — refactoring opportunities, missing abstractions, patterns to adopt}
```

### Step 6 — Offer Fixes

- If CRITICAL or HIGH issues found, offer to fix them automatically
- For MEDIUM/LOW, mention them but don't push — the user decides
- Start with the first CRITICAL issue (often causes cascading problems)

## Rules

- **Cite the rule** — every violation must reference a named rule/category
- **Be specific** — include file paths and line numbers
- **Do not fail on style alone** — only flag genuine rule violations
- **If rules are silent** on a topic, note it as LOW/advisory, not a violation
- **Acknowledge good code** — the "What Looks Good" section is not optional

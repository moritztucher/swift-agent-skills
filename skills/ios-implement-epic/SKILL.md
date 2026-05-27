---
name: ios-implement-epic
description: Full epic delivery orchestrator for iOS. Drives TDD workflow — writes XCTests, implements epic steps, verifies all ACs pass, fixes gaps in a loop. Produces a delivery report.
user_invocable: true
argument-hint: <epic number, e.g. "1" for EPIC-1>
---

# iOS Epic Implementation Orchestrator

You are a staff iOS engineer delivering a complete epic. You follow a strict TDD workflow: write failing tests first, implement until tests pass, verify full coverage, fix gaps, and run final quality gates. You work methodically through epic steps, checking in with the user at key decision points.

## Input

`$ARGUMENTS` is an epic number (e.g., `1` for EPIC-1).

If empty, ask the user for the epic number.

---

## Phase 0 — Understand the Epic

1. Read `docs/epics/EPIC-{number}.md`.
   - If it doesn't exist, tell the user to run `/epic-detail {number}` first and stop.
   - If confidence is below 90%, warn and ask the user to confirm before proceeding.
2. Read `docs/PROJECT-BRIEF.md` for broader context.
3. Read `CLAUDE.md` for project tech decisions.
4. Read `ARCHITECTURE.md` for architecture patterns.
5. Extract and summarize:
   - **Goals** — what this epic delivers
   - **Dependencies** — verify they are met (check if dependent code/files exist)
   - **Implementation Steps** — the ordered step list
   - **Acceptance Criteria** — the success definition (with test types)
   - **Expected Outcome** — what the user should see when done
6. If dependencies are NOT met, report which are missing and ask the user how to proceed.

Present a brief implementation plan:

```
## Implementation Plan — Epic {N}: {Name}

**Steps:** {N} implementation steps
**ACs:** {N} acceptance criteria ({X} unit, {Y} integration, {Z} ui)
**Estimated test files:** {list}

### Execution Order:
1. Phase 1: Write failing XCTests (TDD red)
2. Phase 2: Implement steps {first} through {last}
3. Phase 3: Verify all ACs pass
4. Phase 4: Fix gaps (if any)
5. Phase 5: Quality gates (build + review)

Proceed?
```

Wait for user confirmation before starting.

---

## Phase 1 — TDD Red Phase (Write Tests)

Generate all test files before writing any production code.

### Process:

1. Parse Acceptance Criteria from the epic document.
2. Group ACs by test type and target test file.
3. Check which test files already exist and which ACs are already covered.
4. Generate test files — one per test target:
   - Read existing test helpers and conventions from the test target
   - Write tests with `AC-{N}:` prefixed test names
   - Merge into existing files (never overwrite)

### XCTest Conventions:

```swift
import XCTest
@testable import {ProjectModule}

final class {Feature}Tests: XCTestCase {

    // MARK: - Properties

    private var sut: {SystemUnderTest}!

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        // Setup with mock dependencies
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Tests

    /// AC-1: {criterion text}
    func test_AC1_{methodName}_{condition}_{expectedResult}() async throws {
        // Given
        // When
        // Then
    }
}
```

### Rules:
- Every AC MUST have a test with its AC-ID in the doc comment: `/// AC-{N}: {criterion}`
- Test naming: `test_AC{N}_{method}_{condition}_{expected}()`
- Follow existing test patterns (read existing tests for conventions)
- Use protocol-based mocks — no production service instances in tests
- Use `async` test methods with `await` — no `XCTestExpectation`
- Name the system under test `sut`

### Verify Red Phase:

Run tests to confirm they fail on assertions (not compilation errors):

```bash
xcodebuild test -scheme "{Scheme}" -destination "platform=iOS Simulator,name=iPhone 16" -only-testing:"{TestTarget}" -quiet 2>&1
```

If tests error (not fail), fix the test code before proceeding.

Report to user:
```
## TDD Red Phase Complete

- Tests written: {N} new, {M} updated
- All new tests confirmed FAILING (red)
- Ready for implementation
```

---

## Phase 2 — Implementation

Work through Implementation Steps **in order**. For each step:

### 2a. Read the step
Read the step description from the epic. Understand:
- What files to create or modify
- What the expected behavior is
- Which ACs this step addresses

### 2b. Explore current state
Before writing code, read relevant existing files:
- Source files that will be modified
- Related components/services for context and patterns
- Data models if schema changes are involved

### 2c. Implement
Write the production code. Follow these principles:
- **Minimal changes** — only touch what the step requires
- **Match existing patterns** — read similar files for conventions
- **Use existing utilities** — check `Core/Extensions/`, `Core/Services/`
- **Follow MVVM** — business logic in ViewModels, Views only render
- **@Observable** — never @ObservableObject/@Published
- **async/await** — no Combine, no completion handlers
- **Handle errors** at system boundaries

### 2d. Incremental test + build check
After implementing each step, run the subset of tests relevant to that step:

```bash
# Build check
xcodebuild -scheme "{Scheme}" -quiet build 2>&1

# Run specific tests
xcodebuild test -scheme "{Scheme}" -destination "platform=iOS Simulator,name=iPhone 16" -only-testing:"{TestTarget}/{TestClass}" -quiet 2>&1
```

Report progress:
```
## Step {N} Complete — {step title}

- Files changed: {list}
- Tests now passing: AC-1, AC-3, AC-5
- Tests still failing: AC-2 (expected — depends on Step {M})
```

### 2e. Course correct
If a test fails unexpectedly after implementation:
1. Read the error message carefully
2. Check if the test or the implementation has the bug
3. Fix the root cause (prefer fixing implementation over adjusting tests)
4. If the epic's AC is ambiguous, ask the user for clarification

If implementation gets complex or deviates from the epic, **STOP and re-plan** — do not push through.

---

## Phase 3 — Full Verification

After all steps are implemented, run the complete test suite:

```bash
xcodebuild test -scheme "{Scheme}" -destination "platform=iOS Simulator,name=iPhone 16" -resultBundlePath TestResults 2>&1
```

### Build the AC verification matrix:

Map every test result to its AC. For each AC, determine:
- **PASS:** Test exists and passes
- **FAIL:** Test exists but fails
- **NO TEST:** No test covers this AC (should not happen after Phase 1)

Present the full matrix to the user.

---

## Phase 4 — Gap Fix Loop

If Phase 3 reveals gaps:

### For FAIL results:
1. Read the test error message
2. Identify root cause (implementation bug, missing feature, wrong assumption)
3. Fix the implementation
4. Re-run the specific failing test
5. Repeat until it passes

### For NO TEST results (should be rare):
1. Write the missing test
2. Implement if needed
3. Verify it passes

### Loop limit:
- Maximum **3 iterations** of Phase 3 -> Phase 4
- If ACs still fail after 3 iterations, report the remaining failures and ask the user for guidance

After each fix iteration, re-run the full suite to check for regressions.

---

## Phase 5 — Quality Gates

Once all ACs pass, run final quality checks:

### Gate 1: Clean build
```bash
xcodebuild -scheme "{Scheme}" -configuration Debug -destination "platform=iOS Simulator,name=iPhone 16" -quiet build 2>&1
```

### Gate 2: Code review
Run the equivalent of `/ios-review` on all changed files:
- Check architecture violations (MVVM adherence, file placement)
- Check SwiftUI patterns (no business logic in views, proper state management)
- Check security (no hardcoded secrets, Keychain usage)
- Check concurrency (async/await only, @MainActor where needed)

Report results. If any CRITICAL or HIGH issues are found, fix them before declaring the epic complete.

---

## Phase 6 — Delivery Report

Print the final delivery report:

```markdown
# Epic Delivery Report

**Epic:** EPIC-{N}: {title}
**Date:** {YYYY-MM-DD}
**Source:** docs/epics/EPIC-{N}.md

---

## Summary

| Metric | Value |
|--------|-------|
| Implementation steps completed | {N}/{N} |
| Acceptance criteria passing | {N}/{N} |
| Test files created/modified | {N} |
| Production files created/modified | {N} |
| Architecture violations | {N} ({severity}) |
| Build status | {Clean / Warnings} |

**Status:** DELIVERED / DELIVERED WITH CAVEATS / BLOCKED

---

## AC Results

| AC | Criterion (short) | Type | Result |
|----|-------------------|------|--------|
| AC-1 | ... | unit | PASS |
| AC-2 | ... | ui | PASS |

---

## Files Changed

### Production Code
- `Features/Auth/Views/LoginView.swift` (new)
- `Core/Services/AuthService.swift` (modified)

### Test Code
- `Tests/AuthServiceTests.swift` (new)
- `Tests/LoginViewModelTests.swift` (new)

---

## Known Limitations / Follow-ups

- {any caveats, deferred items, or known issues}
```

---

## Important Rules

- **Always write tests before implementation** (Phase 1 before Phase 2)
- **Never skip the verification phase** (Phase 3 is mandatory)
- **Stop and re-plan if stuck** — do not brute-force through failures
- **Ask the user at decision points** — dependency issues, ambiguous ACs, architectural choices
- **AC-ID in test doc comments is non-negotiable** — this is how verification works
- **Match existing code patterns** — read before writing, always
- **One commit-worthy chunk per step** — keep changes reviewable
- **Follow all project rules** — read CLAUDE.md, architecture rules, SwiftUI rules

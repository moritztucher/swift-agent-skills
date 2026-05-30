---
name: ios-verify
description: Run all XCTests, map results to epic acceptance criteria, and produce a coverage matrix + gap report
user_invocable: true
argument-hint: <epic number, e.g. "1" for EPIC-1>
---

# iOS Implementation Verifier

You are a senior QA lead performing comprehensive implementation verification for an iOS project. Your goal is to check that every acceptance criterion in an epic is (a) covered by a test and (b) passing. You run all tests, map results to ACs, and produce a gap report.

> **Next step:** when all ACs pass, run `/ios-review` for a final code review, then `/ios-commit` and `/ios-pr`.

## Input

`$ARGUMENTS` is an epic number (e.g., `1` for EPIC-1).

If empty, ask the user for the epic number.

---

## Phase 1 — Parse All ACs

1. Read `docs/epics/EPIC-{number}.md`.
   - If it doesn't exist, tell the user to run `/ios-epic {number}` first and stop.
2. Extract every acceptance criterion. For each AC, capture:
   - **AC ID** (AC-1, AC-2, ...)
   - **Criterion** (the testable statement)
   - **Type** (unit / integration / ui)
3. Also read `CLAUDE.md` for the Xcode scheme name and test target.

Store as a structured list for cross-referencing.

---

## Phase 2 — Discover Tests

Search for test files that cover this epic's ACs. Use two strategies:

### Strategy A: Search by AC-ID pattern
Search all test files for `AC-{N}` patterns:
```bash
grep -r "AC-" --include="*.swift" -l
```

### Strategy B: Search by feature name
Search for test files matching the epic's feature name in the test directories.

For each discovered test file, read it and extract:
- Test method names (from `func test_...()`)
- AC IDs referenced in doc comments (`/// AC-N:`)
- Which AC each test covers

Build the **coverage matrix**:

```
| AC   | Type        | Test File                     | Test Method                                    | Found |
|------|-------------|-------------------------------|------------------------------------------------|-------|
| AC-1 | unit        | AuthServiceTests.swift        | test_AC1_login_validCredentials_succeeds        | YES   |
| AC-2 | ui          | LoginViewTests.swift          | test_AC2_loginButton_invalidEmail_showsError    | YES   |
| AC-3 | integration | —                             | —                                              | NO    |
```

---

## Phase 3 — Run Tests

### Find scheme and test target

```bash
xcodebuild -list -quiet 2>&1
```

### Run all tests

```bash
xcodebuild test \
  -scheme "{Scheme}" \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  -resultBundlePath TestResults \
  2>&1
```

Parse output for:
- Total tests, passed, failed, skipped
- Per-test status with test name (to match AC IDs)
- Error messages for failures

### Timeout handling
- Default timeout: 300s
- If the test run times out, report partial results and note the timeout

---

## Phase 4 — Map Results to ACs

Cross-reference test results with the AC list:

For each AC, determine its status:

| Status | Meaning |
|--------|---------|
| **PASS** | Test exists, tagged with AC-ID, and passed |
| **FAIL** | Test exists, tagged with AC-ID, but failed |
| **NO TEST** | No test found for this AC |
| **SKIP** | Test exists but was skipped |
| **UNTAGGED** | Test likely covers this AC (by name/file match) but lacks `AC-N` tag |

Also detect **orphan tests**: tests with `AC-N` tags that don't match any AC in the epic (may indicate stale tests).

---

## Phase 5 — Implementation Check

Beyond test coverage, verify that the implementation exists:

For each AC, check if the referenced code artifact exists:
- **ACs mentioning Views:** Check if the View file exists in `Features/`
- **ACs mentioning ViewModels:** Check if the ViewModel exists
- **ACs mentioning Services:** Check if the Service file exists in `Core/Services/`
- **ACs mentioning Models:** Check if the Model file exists

Use **Glob/Grep** for this — do not read every file.

---

## Phase 6 — Generate Report

Print and save the report to `docs/epics/EPIC-{number}_verification.md`.

```markdown
# Implementation Verification Report

**Epic:** EPIC-{N}: {title}
**Date:** {YYYY-MM-DD}
**Source:** docs/epics/EPIC-{N}.md

---

## Summary

| Metric | Count |
|--------|-------|
| Total ACs | {N} |
| Covered by tests | {N} |
| Tests passing | {N} |
| Tests failing | {N} |
| No test (gap) | {N} |
| Untagged (likely covered) | {N} |

**Overall:** PASS / FAIL / PARTIAL
- **PASS:** All ACs have tagged tests, all passing
- **PARTIAL:** Some ACs passing, gaps or failures exist
- **FAIL:** Majority of ACs failing or missing tests

---

## Test Execution Results

### XCTest
- **Ran:** {N} tests
- **Passed:** {N} | **Failed:** {N} | **Skipped:** {N}
- **Duration:** {N}s
- **Build:** {Clean / Warnings / Errors}

---

## AC Coverage Matrix

| AC | Criterion (short) | Type | Test File | Test Method | Result | Notes |
|----|-------------------|------|-----------|-------------|--------|-------|
| AC-1 | Login succeeds | unit | AuthServiceTests | test_AC1_login_valid_succeeds | PASS | |
| AC-2 | Error shown | ui | LoginViewTests | test_AC2_loginButton_error | FAIL | Missing error label |
| AC-3 | Token stored | integration | — | — | NO TEST | Gap: need Keychain test |

---

## Gaps

### Missing Tests (NO TEST)

| AC | Type | Criterion | Suggested Test File | Action Required |
|----|------|-----------|---------------------|-----------------|
| AC-3 | integration | Token stored in Keychain | KeychainServiceTests.swift | Write test |

### Failing Tests (FAIL)

| AC | Test | Error | Suggested Fix |
|----|------|-------|---------------|
| AC-2 | test_AC2_loginButton_error | XCTAssertNotNil failed | Fix: add error label to LoginView |

### Untagged Tests (UNTAGGED)

| AC | Test File | Test Method | Action |
|----|-----------|-------------|--------|
| AC-4 | ProfileTests | test_profileLoad | Add `/// AC-4:` doc comment |

### Orphan Tests

| Test | AC Tag | Issue |
|------|--------|-------|
| test_AC99_legacy | AC-99 | No AC-99 in epic — stale test? |

---

## Implementation Artifacts Check

| AC | Required Artifact | Exists | Path |
|----|-------------------|--------|------|
| AC-1 | AuthService | YES | Core/Services/AuthService.swift |
| AC-3 | KeychainService | NO | Core/Services/KeychainService.swift |

---

## Recommendations

1. **Priority fixes:** {ordered list}
2. **Test tagging:** {tests to add AC-N doc comments}
3. **Missing implementations:** {code that needs to be written}

---

## Next Steps

- Fix failing tests and implementation gaps
- Re-run: `/ios-verify {N}` to confirm all green
- When all PASS: run `/ios-review` on changed files as final gate
```

---

## Important Rules

- **Never modify production code or test code** — this skill only reads and reports
- **AC-ID matching is case-insensitive** — `AC-1`, `ac-1`, `Ac-1` all match
- **Truncate criterion text** in the matrix table to ~60 chars for readability
- **Always save the report file** in addition to printing it
- **If no tests exist at all**, recommend running `/ios-implement {N}` which includes TDD test generation
- **Parse xcodebuild output carefully** — handle both pass and fail output formats

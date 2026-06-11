---
name: swift-testing
description: Write and review unit/integration tests with Apple's Swift Testing framework (the Xcode 16/26 default) — @Test, #expect, #require, @Suite, traits, parameterized tests, async tests, confirmation(), and migrating from XCTest. Use when the user mentions Swift Testing, @Test, #expect, #require, @Suite, unit test, parameterized test, migrate from XCTest, or writing a test. For async/await mechanics inside tests see the swift-concurrency skill.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Swift Testing docs via Context7 (/swiftlang/swift-testing)
---

# Swift Testing

Apple's Swift Testing framework — the default test framework in Xcode 16+ and recommended through Xcode 26. `@Test`/`@Suite` types, `#expect`/`#require` macros, traits, parameterized tests, `confirmation()`, and the incremental XCTest migration. The full API reference — every macro form, trait, suite/setup pattern, async + error testing, the XCTest mapping tables, and what stays in XCTest — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `FRAMEWORK` — `swift-testing` (default for all new unit/integration tests) · `xctest-still-needed` (UI automation with `XCUIApplication`, or performance `measure`/`XCTMetric` — these have no Swift Testing equivalent and stay in XCTest).
2. `STYLE` — `flat-@Test` (free `@Test` functions, no shared state) · `@Suite` (a type grouping tests, with per-test fixtures via stored properties and `init`/`deinit`).
3. `DATA` — `single` (one set of inputs per test) · `parameterized` (`@Test(arguments:)` runs the test once per input, each reported and re-runnable on its own).

## When to use

Writing or reviewing any unit or integration test for Swift code, or migrating an XCTest suite. Swift Testing and XCTest run in the same target — migrate file by file, don't rewrite wholesale. For the async/await and Sendable mechanics a test exercises, pair with `swift-concurrency`. Run the suite with `xcodebuild test -scheme "<Scheme>" -destination 'platform=iOS Simulator,name=<device>'`.

## Core rules

- `import Testing`. New unit/integration tests are Swift Testing — no `XCTestCase`, no `func test...` naming, no `XCTAssert*`.
- `#expect` is a soft check (records issue, test continues); `try #require` is a hard check (throws, stops the test) and also unwraps optionals. Pick by whether later code depends on the result.
- A suite type gets a **fresh instance per test**, and tests run in parallel + randomized order by default. Setup goes in `init`, teardown in `deinit` (needs a `class`/`actor`) — never assume ordering or shared mutable state. Opt into serial with `.serialized`.
- UI automation (`XCUIApplication`) and performance (`measure`/`XCTMetric`) stay in XCTest. Everything else is Swift Testing.
- Let the macros capture expressions — write `#expect(a == b)`, not a helper that returns a `Bool`, so failures show the real operands and diffs.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll keep this one `XCTAssertEqual` inside my `@Test` — it still compiles." | `XCTAssert*` only works inside `XCTestCase`. Inside `@Test` you get no failure unless you use `#expect`/`#require`. Don't mix the two families. |
| "`#expect` is fine here; if it's nil the next line just fails too." | If later code dereferences the value, use `try #require` — it stops the test with one clear failure. A failed `#expect` keeps running and produces a confusing cascade (or a crash on force-unwrap). |
| "I'll put shared state in a property and set it in `setUp` like before." | There is no `setUp`/`tearDown`, and the suite is re-instantiated for every test. Initialize fixtures in `init` (teardown in `deinit` on a `class`/`actor`). A property mutated by one test is never seen by another. |
| "I'll port the UI test / the `measure {}` block to Swift Testing too." | Swift Testing has no `XCUIApplication` and no `XCTMetric`/`measure`. UI automation and performance tests must stay in XCTest. Leave those targets alone. |
| "I'll wrap the assertion in a `check(_:)` helper to DRY it up." | The macro expands at the call site to capture the source expression; behind a helper you lose the operand values and collection diffs in the failure message. Keep `#expect`/`#require` inline. |
| "I'll loop over the inputs inside one `@Test`." | A loop stops at the first failure and reports one result for all inputs. Use `@Test(arguments:)` — each case runs independently, is reported separately, and is individually re-runnable. |

## Verification gate

Before considering a test (or migration) done, confirm every line:

- [ ] `import Testing`; tests are `@Test` functions, no `XCTestCase`/`XCTAssert*` left in migrated code.
- [ ] Each check is `#expect` (continue) or `try #require` (stop / unwrap) chosen deliberately — `#require` wherever later lines depend on the result.
- [ ] No assertion is hidden behind a helper that returns `Bool` — expressions are inline so failures show operands.
- [ ] Suite state lives in `init` (setup) and `deinit` (teardown); no reliance on test order or cross-test shared mutable state; `.serialized` added only where genuinely required.
- [ ] Tables of inputs are parameterized (`arguments:` / `zip` / cartesian), not `for` loops.
- [ ] Async events from callbacks/notifications use `confirmation()`; awaitable calls just use `async`/`await`.
- [ ] Error tests use `#expect(throws:)`/`#require(throws:)` with the right granularity (`(any Error).self`, a type, a value, or `Never.self`).
- [ ] UI-automation and performance tests remain in XCTest, unchanged.

## Deep reference

`references/guide.md` — overview, `@Test`/`#expect`/`#require`, suites + setup/teardown via `init`/`deinit`, all traits (tags, enable/disable, bug, time limit, serialized, custom `TestScoping`), parameterized tests, async + `confirmation`, error testing + `withKnownIssue`, organizing/running, the XCTest assertion and structural mapping tables, and what stays in XCTest. Load it for any concrete API question.

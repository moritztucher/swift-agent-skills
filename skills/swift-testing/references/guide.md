# Swift Testing — Deep Reference

Apple's Swift Testing framework: the default test framework in Xcode 16+ (and the recommended one through Xcode 26). It ships with the Swift toolchain (`import Testing`) and runs side by side with XCTest in the same target — you migrate incrementally, you do not rewrite everything at once.

This guide is the full API reference. The `SKILL.md` next to it is the decision/discipline layer; read that first.

---

## 1. Overview

Swift Testing replaces `XCTestCase` subclasses and the `XCTAssert*` family with:

- `@Test` — a free function or method that is a test.
- `#expect(...)` — a soft check; on failure it records an issue and the test keeps running.
- `#require(...)` — a hard check; on failure it throws and stops the test. Also unwraps optionals.
- `@Suite` — a type (struct/actor/class/enum) that groups tests and shares traits.
- Traits — declarative metadata on `@Test`/`@Suite`: tags, enable/disable conditions, time limits, bug links, serialization.
- Parameterized tests — one `@Test` run many times with different arguments.
- `confirmation()` — for callback/notification/delegate-style async events.

Both macros capture the source expression, so failure messages show the actual operand values and collection diffs — no need to pass a custom message just to know what the values were.

```swift
import Testing

@Test func twoPlusTwo() {
    #expect(2 + 2 == 4)
}
```

There is no `func test...` naming convention, no subclassing, no `XCTestCase`. A test is just a function annotated with `@Test`.

---

## 2. @Test — the test function

```swift
import Testing

@Test func userStartsLoggedOut() {
    let session = Session()
    #expect(session.user == nil)
}
```

### Display name

Pass a string as the first argument to give a human-readable name shown in the test navigator and logs:

```swift
@Test("A new session has no signed-in user")
func userStartsLoggedOut() {
    #expect(Session().user == nil)
}
```

### async / throws

A test may be `async`, `throws`, or both. Mark it exactly like any Swift function:

```swift
@Test func fetchesProfile() async throws {
    let profile = try await api.profile(for: "abc")
    #expect(profile.name == "Ada")
}
```

### Static and instance methods

Tests can be instance methods of a suite type (the common case) or `static` methods. Instance methods require the suite type to have a zero-argument initializer (see §4).

---

## 3. #expect and #require

### #expect — soft check, test continues

`#expect` evaluates a boolean expression. On failure it records an issue and the test keeps going, so a single run can surface multiple failures.

```swift
@Test func cartTotals() {
    let cart = Cart(items: [.coffee, .muffin])
    #expect(cart.count == 2)
    #expect(cart.total == 7.50)        // both checks run even if the first fails
    #expect(cart.isEmpty == false)
}
```

Because the macro captures the expression, the failure message shows operand values:

```
Expectation failed: (cart.count → 3) == 2
```

Collections diff automatically:

```swift
#expect([1, 2, 4] == [1, 2, 3])
// Expectation failed: ([1, 2, 4]) == ([1, 2, 3])
// inserted [4], removed [3]
```

### #require — hard check, test stops

`try #require(...)` throws `ExpectationFailedError` on failure, stopping the test immediately. Use it when subsequent lines cannot run meaningfully unless the condition holds. Always `try`, so the test must be `throws`.

```swift
@Test func decodesResponse() throws {
    let data = sampleJSON
    let decoded = try #require(try? JSONDecoder().decode(User.self, from: data))
    // `decoded` is non-optional here; the test stopped if decoding failed
    #expect(decoded.id == 42)
}
```

### #require unwraps optionals (replaces XCTUnwrap)

`try #require(optional)` returns the unwrapped, non-optional value and stops the test if it was `nil`:

```swift
@Test func findsFirstPart() throws {
    let engine = FoodTruck.shared.engine
    let part = try #require(engine.parts.first)   // non-optional `part`
    #expect(part.isFunctional)
}
```

It also works for `as?` casts and any other optional expression:

```swift
let shape: any Shape = Circle(radius: 5)
let circle = try #require(shape as? Circle)
#expect(circle.radius == 5)
```

### Rule of thumb

- Independent assertion, want to see all failures in one run → `#expect`.
- Later code dereferences/depends on this value or condition → `try #require`.

---

## 4. Suites, setup, and teardown

A suite is any Swift type containing `@Test` methods. The `@Suite` attribute is optional for discovery but required to give a display name or attach suite-wide traits.

```swift
@Suite("Cart behavior")
struct CartTests {
    @Test func startsEmpty() { #expect(Cart().isEmpty) }
    @Test func addsItem() {
        var cart = Cart()
        cart.add(.coffee)
        #expect(cart.count == 1)
    }
}
```

### Fresh instance per test — this is the key model change

Swift Testing **instantiates the suite type once per test method**, and runs tests in parallel by default. There is no shared mutable state between tests unless you opt into it (e.g. `static`, a global, or an external resource). Stored properties are per-test fixtures.

```swift
@Suite struct AccountTests {
    // Re-created fresh for every test — no bleed-through between tests
    let account = Account(balance: 100)

    @Test func deposit() {
        account.deposit(50)
        #expect(account.balance == 150)
    }

    @Test func withdraw() {
        account.withdraw(30)
        #expect(account.balance == 70)   // sees 100, not 150 — fresh instance
    }
}
```

### Setup via `init`, teardown via `deinit`

There is no `setUp()`/`tearDown()`. Use the initializer for setup and `deinit` for teardown. `init` may be `async`, `throws`, or both. `deinit` is only available on a `class` or `actor` (structs have no deinit).

```swift
final class DatabaseTests {
    let db: Database

    init() async throws {
        db = try await Database.openTemporary()   // setUp equivalent
        try await db.migrate()
    }

    deinit {
        try? db.deleteFile()                       // tearDown equivalent
    }

    @Test func insertsRow() async throws {
        try await db.insert(User(name: "Ada"))
        #expect(try await db.count() == 1)
    }
}
```

For a struct suite (no `deinit`), do teardown inline or with a custom trait (§5, `TestScoping`).

### The suite type needs a callable zero-argument initializer

Instance `@Test` methods require an implicit or explicit `init()` taking no required arguments:

```swift
@Suite struct FoodTruckTests {
    var batteryLevel = 100
    @Test func exists() { #expect(batteryLevel == 100) }   // ✅ implicit init()
}

@Suite struct CashRegisterTests {
    private init(cashOnHand: Decimal = 0.0) async throws { ... }
    @Test func calculateSalesTax() { ... }                 // ✅ callable init()
}

struct MenuTests {
    var foods: [Food]                                      // no zero-arg init
    @Test func orderAllFoods() { ... }                     // ❌ requires init()
    @Test static func specialOfTheDay() { ... }            // ✅ static needs no init
}
```

### Nested suites

Suites can nest; nested suites inherit the enclosing suite's traits (tags, disabled, etc.):

```swift
@Suite struct NetworkTests {
    @Suite struct RetryTests {
        @Test func retriesOnTimeout() async throws { ... }
    }
}
```

---

## 5. Traits

Traits are values passed after the name in `@Test`/`@Suite`. Suite traits apply to every test in the suite (and nested suites) when `isRecursive`.

### Tags — for filtering and grouping across files

Define tags in an extension of `Tag`, then attach with `.tags(_:)`:

```swift
extension Tag {
    @Tag static var critical: Self
    @Tag static var network: Self
}

@Test("Vendor's license is valid", .tags(.critical))
func licenseValid() { ... }

@Suite(.tags(.network))            // applies to all tests in the suite
struct APITests { ... }
```

Run or filter by tag in Xcode's Test Plan or with `swift test --filter`.

### Conditional execution — `.enabled(if:)` and `.disabled(_:)`

```swift
// Run only when a flag is set
@Test(.enabled(if: FeatureFlags.isNewCheckoutEnabled))
func newCheckoutFlow() async throws { ... }

// Always skip, with a reason shown in results
@Test(.disabled("Waiting for backend fix #4521"))
func flakyIntegration() async throws { ... }

// Skip on a condition
@Test(.disabled(if: ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 14,
                "Requires macOS 14+"))
func modernAPI() { #expect(ModernAPI.isAvailable) }

// Async condition closure
@Test(.enabled("Feature enabled remotely") {
    await RemoteConfig.shared.isEnabled("new_feature")
})
func remotelyEnabled() async throws { ... }
```

A disabled/not-enabled test is **skipped**, not failed — clearer than commenting it out, and it shows up as skipped in reports.

### Bug links — `.bug(_:)`

Associate a test with an issue-tracker URL/identifier:

```swift
@Test(.bug("https://github.com/example/app/issues/4521", "Checkout total off by rounding"))
func checkoutRounding() { ... }
```

### Time limits — `.timeLimit(_:)`

Cancel a test that runs too long. The granularity is whole minutes (minimum 1 minute).

```swift
@Test(.timeLimit(.minutes(2)))
func networkOperationCompletes() async throws {
    let data = try await LongRunningService.fetchLargeDataset()
    #expect(data.count > 0)
}

@Suite(.timeLimit(.minutes(1)))     // each test in the suite gets the limit
struct SlowTests { ... }
```

### Serialization — `.serialized`

Tests run in parallel by default. Force serial execution (e.g. shared file/global) at the suite or parameterized-test level:

```swift
@Suite("File system", .serialized)
struct FileSystemTests {
    @Test func createFile() throws { ... }
    @Test func deleteFile() throws { ... }
}
```

`.serialized` also serializes the cases of a parameterized test.

### Custom traits with scoped setup/teardown — `TestScoping`

For reusable setup/teardown that wraps the test body (the closest thing to a shared `setUp`/`tearDown` across suites), implement a trait conforming to `TestTrait`/`SuiteTrait` and `TestScoping`:

```swift
struct WithTestDatabase: TestTrait, SuiteTrait, TestScoping {
    var isRecursive: Bool { true }

    func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: @Sendable () async throws -> Void
    ) async throws {
        let db = try await TestDatabase.setUp()
        defer { Task { try? await db.tearDown() } }
        try await function()        // runs the test inside this scope
    }
}

extension Trait where Self == WithTestDatabase {
    static var withTestDatabase: Self { WithTestDatabase() }
}

@Suite(.withTestDatabase)
struct UserRepositoryTests {
    @Test func createUser() async throws { ... }
}
```

---

## 6. Parameterized tests

Run one `@Test` once per input — each input is reported as its own test case, with its own pass/fail and its own re-run button. Prefer this over a `for` loop inside one test: a loop stops at the first failure and reports a single result for all inputs.

### Single collection

```swift
@Test("Parse valid dates", arguments: [
    "2024-01-15", "2023-12-31", "2000-02-29",
])
func parseDate(_ dateString: String) throws {
    let date = try #require(DateParser.parse(dateString))
    #expect(date > Date(timeIntervalSince1970: 0))
}
```

The parameter name(s) of the function receive the elements.

### Zipped collections (paired, not cartesian)

Use `zip` when inputs and expected outputs line up one-to-one:

```swift
@Test("City maps to country", arguments: zip(
    ["Tokyo", "Paris", "Cairo"],
    ["Japan", "France", "Egypt"]
))
func cityCountry(city: String, country: String) async throws {
    let result = try await GeoAPI.lookup(city: city)
    #expect(result.country == country)
}
```

### Two collections (cartesian product)

Passing two `arguments:` collections runs every combination:

```swift
@Test("Multiplication is commutative", arguments: [1, 2, 3], [10, 20, 30])
func multiplication(a: Int, b: Int) {
    #expect(a * b == b * a)
}
```

This runs 9 cases (3 × 3). Use `zip` if you do **not** want the cross product.

---

## 7. Asynchronous code

### async/await tests

Mark the test `async` and `await` normally:

```swift
@Test func priceLookupYieldsExpectedValue() async {
    let price = await unitPrice(for: .mozarella)
    #expect(price == 3)
}
```

### confirmation() — callbacks, notifications, delegates

`confirmation` is the replacement for `XCTestExpectation`/`fulfillment(of:)` when an event is delivered through a callback, delegate, or `NotificationCenter` rather than an awaitable function. The confirmation must be invoked the expected number of times *before the closure returns*; otherwise an issue is recorded.

```swift
@Test func truckEmitsSoldFoodEvent() async {
    await confirmation("Truck emits soldFood") { soldFood in
        FoodTruck.shared.eventHandler = { event in
            if case .soldFood = event { soldFood() }   // confirm
        }
        await Customer().buy(.soup)
    }
}
```

Specify how many times the event should occur with `expectedCount`:

```swift
@Test func emitsThreeEvents() async {
    await confirmation("Three updates", expectedCount: 3) { confirm in
        let observer = Observer { confirm() }
        await trigger(observer, times: 3)
    }
}
```

You can also assert an event does **not** happen with `expectedCount: 0`.

Unlike XCTest expectations, `confirmation` does not block or suspend waiting for a timeout — the closure body must drive the work to completion. For events that genuinely complete at an indeterminate future point, drive them with structured concurrency (e.g. `await` the operation, or `Task`/`AsyncStream`) inside the closure.

---

## 8. Error testing

### Expect any error

```swift
@Test func rejectsNegativeIndex() {
    var order = PizzaToppings(bases: [.calzone])
    #expect(throws: (any Error).self) {
        try order.add(topping: .mozarella, toPizzasIn: -1 ..< 0)
    }
}
```

### Expect a specific error type

```swift
#expect(throws: DivisionError.self) {
    try divide(10, by: 0)
}
```

### Expect a specific error value (Equatable error)

```swift
#expect(throws: NetworkError.timeout) {
    try fetchWithTimeout(url: url, timeout: 0)
}
```

### Expect NO error — `Never.self`

```swift
#expect(throws: Never.self) {
    try safeOperation()
}
```

### Custom error predicate

When you need to inspect the thrown error (e.g. an associated value), use the trailing `throws:` closure form:

```swift
await #expect {
    try await fetchResource()
} throws: { error in
    guard let net = error as? NetworkError else { return false }
    return net.statusCode == 404
}
```

`#require(throws:)` exists too, stopping the test if the expected throw doesn't happen.

### Known issues — `withKnownIssue`

Track an expected failure (an open bug) without leaving the test red or commented out. If the wrapped code fails as expected, no failure is recorded; if it unexpectedly *passes*, an issue is recorded telling you the bug is fixed and the wrapper can be removed.

```swift
@Test func parsesLegacyFormat() throws {
    withKnownIssue("Legacy parser broken until #1234 lands") {
        try LegacyParser.parse(input)
    }
}

// Conditional / selective / intermittent variants:
withKnownIssue("Crashes on Linux", isIntermittent: false) {
    try platformCode()
} when: {
    ProcessInfo.processInfo.operatingSystem == .linux
}
```

This is the Swift Testing equivalent of XCTest's `XCTExpectFailure`.

---

## 9. Organizing & running

### Organizing

- Group related tests in a `@Suite` type; nest suites for sub-areas.
- Use `@Tag` for cross-cutting concerns (e.g. `.critical`, `.network`, `.slow`) that span files.
- Give tests and suites display names; they read as sentences in the navigator.

### Running

- **Xcode 16+ / 26**: the Test navigator and `⌘U` run Swift Testing and XCTest together. Diamonds next to `@Test`/`@Suite` run individual tests; parameterized cases expand to individual rows.
- **Command line** (SwiftPM): `swift test` runs both frameworks. Filter with `swift test --filter <regex>` (matches suite/test names). Tag-based selection is configured via Test Plans in Xcode.
- Tests run **in parallel and in randomized order** by default — never assume ordering or shared state. Opt into serial execution with `.serialized`.

---

## 10. Migrating from XCTest

Swift Testing and XCTest coexist in the same test target and the same build, so migrate file by file or test by test. Keep `import XCTest` for the tests still using it and add `import Testing` for the new ones.

### Assertion mapping

| XCTest | Swift Testing |
|---|---|
| `XCTAssert(x)` / `XCTAssertTrue(x)` | `#expect(x)` |
| `XCTAssertFalse(x)` | `#expect(!x)` |
| `XCTAssertEqual(a, b)` | `#expect(a == b)` |
| `XCTAssertNotEqual(a, b)` | `#expect(a != b)` |
| `XCTAssertGreaterThan(a, b)` | `#expect(a > b)` |
| `XCTAssertNil(x)` | `#expect(x == nil)` |
| `XCTAssertNotNil(x)` | `#expect(x != nil)` |
| `XCTAssertIdentical(a, b)` | `#expect(a === b)` |
| `XCTUnwrap(x)` | `try #require(x)` |
| `XCTAssertThrowsError(try f())` | `#expect(throws: (any Error).self) { try f() }` |
| `XCTAssertThrowsError` + type check | `#expect(throws: MyError.self) { try f() }` |
| `XCTAssertNoThrow(try f())` | `#expect(throws: Never.self) { try f() }` |
| `continueAfterFailure = false` + `XCTAssertTrue` | `try #require(...)` (throws & stops) |
| `XCTFail("msg")` | `Issue.record("msg")` |
| `XCTExpectFailure { ... }` | `withKnownIssue { ... }` |

### Structural mapping

| XCTest | Swift Testing |
|---|---|
| `class FooTests: XCTestCase` | `struct FooTests` (or `final class` if you need `deinit`), optionally `@Suite` |
| `func testBar()` naming convention | `@Test func bar()` (any name) |
| `setUp()` / `setUpWithError()` / `async setUp()` | `init()` / `init() throws` / `init() async throws` |
| `tearDown()` / `tearDownWithError()` | `deinit` (requires `class`/`actor`), or a `TestScoping` trait |
| `XCTestExpectation` + `wait(for:)` / `fulfillment(of:)` | `await confirmation { ... }` |
| Test plans / `-only-testing` | tags + `.enabled/.disabled` traits, `--filter` |
| Looping over inputs in one test | parameterized `@Test(arguments:)` |
| `XCTSkip` / `XCTSkipIf` | `.disabled(...)` / `.enabled(if:)` traits |

### Migration order (recommended)

1. Convert a whole `XCTestCase` at a time to a suite, so its setup/teardown semantics move cleanly to `init`/`deinit`.
2. Replace `XCTAssert*` with `#expect`; replace `XCTUnwrap` and any "must hold" preconditions with `try #require`.
3. Fold input loops into parameterized tests.
4. Replace expectations with `confirmation`.
5. Leave UI and performance tests in XCTest (below) — do not try to port them.

---

## 11. What stays in XCTest

Swift Testing does **not** cover these; keep using XCTest for them:

- **UI automation** — `XCUIApplication`, `XCUIElement`, `XCUIElementQuery`, launching and driving the app's UI. There is no Swift Testing equivalent; UI test targets remain `XCTestCase`-based.
- **Performance testing** — `measure { }`, `XCTMetric` (e.g. `XCTClockMetric`, `XCTMemoryMetric`, `XCTCPUMetric`), and performance baselines. These have no Swift Testing counterpart.

Everything else — unit tests, integration tests, async tests, error tests — should be Swift Testing on new code. UI/performance suites can live in the same project; they just stay in their XCTest targets.

---

## 12. Quick reference

```swift
import Testing

// Basic
@Test func name() { #expect(cond) }
@Test("Display name") func n() async throws { ... }

// Checks
#expect(a == b)                    // soft, continues
try #require(a == b)               // hard, stops
let x = try #require(optional)     // unwrap or stop

// Errors
#expect(throws: MyError.self)  { try f() }
#expect(throws: MyError.case)  { try f() }     // specific value
#expect(throws: Never.self)    { try f() }     // must not throw
await #expect { try await f() } throws: { $0 is MyError }

// Suite + fixtures
@Suite("Name") struct S { let fixture = make() /* fresh per test */ }
final class C { init() async throws { /*setUp*/ }; deinit { /*tearDown*/ } }

// Traits
@Test(.tags(.critical), .timeLimit(.minutes(1)),
      .bug("https://…/123"), .disabled("reason"),
      .enabled(if: flag))
@Suite(.serialized, .tags(.network))

// Parameterized
@Test(arguments: [a, b, c]) func t(_ x: T) { ... }
@Test(arguments: zip(inputs, expected)) func t(i: I, e: E) { ... }
@Test(arguments: xs, ys) func t(x: X, y: Y) { ... }   // cartesian

// Async events
await confirmation("desc", expectedCount: 1) { confirm in ... confirm() ... }

// Known bug
withKnownIssue("until #123") { try flaky() }
```

---
globs: "**/*Tests.swift,**/Tests/**/*.swift"
---

# Testing Rules

- **Framework:** Use XCTest
- **File naming:** `[ClassName]Tests.swift` — mirror the main project's folder structure
- **SUT naming:** Name the system under test `sut` for clarity
- **Mocks:** Create mock services via protocol conformance — no production service instances in tests
- **Edge cases:** Test error conditions, empty states, and boundary values — not just the happy path
- **One focus per test:** Each test method should assert one logical behavior
- **Async testing:** Use `async` test methods with `await` — no `XCTestExpectation` for async/await code
- **Naming:** `test_[method]_[condition]_[expectedResult]` (e.g., `test_login_invalidPassword_throwsError`)

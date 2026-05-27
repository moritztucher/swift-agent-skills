---
description: Run unit tests and UI tests for the iOS project
disable-model-invocation: true
---

# /test - Run Tests

Run unit tests and UI tests for the iOS project.

## Instructions

1. Find the Xcode project and list schemes:
   ```bash
   xcodebuild -list
   ```

2. Identify test schemes (usually ending in "Tests" or containing "Test")

3. Ask what to run:
   - All tests
   - Unit tests only
   - UI tests only
   - Specific test file/class

4. Run tests:
   ```bash
   xcodebuild test -scheme "[Scheme]" -destination "platform=iOS Simulator,name=iPhone 16" -only-testing:"[TestTarget]" 2>&1
   ```

5. Parse results for:
   - Test count (passed/failed/skipped)
   - Failed test names and reasons
   - Test duration

6. Present results:

```markdown
## Test Results

**Status**: All Passed / X Failed
**Total**: Y tests
**Duration**: Z seconds

### Failed Tests (if any)
- `testFunctionName` in TestClass.swift
  - Expected: X
  - Actual: Y

### Skipped Tests (if any)
- `testSkippedName` - reason
```

7. On failures:
   - Offer to investigate failing tests
   - Show relevant source code
   - Suggest fixes

## Test Coverage (Optional)

If requested, run with coverage:
```bash
xcodebuild test -scheme "[Scheme]" -enableCodeCoverage YES ...
```

Then parse coverage report from DerivedData.

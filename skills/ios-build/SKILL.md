---
description: Build the Xcode project and report results
disable-model-invocation: true
---

# /build - Build iOS Project

Build the Xcode project and report results.

## Instructions

1. Find the Xcode project/workspace:
   ```bash
   find . -name "*.xcworkspace" -o -name "*.xcodeproj" | head -5
   ```

2. List available schemes:
   ```bash
   xcodebuild -list
   ```

3. If multiple schemes, ask which to build. Otherwise use the default.

4. Determine build configuration:
   - Default: Debug
   - Ask if Release build is needed

5. Run build:
   ```bash
   xcodebuild -scheme "[Scheme]" -configuration [Debug/Release] -destination "platform=iOS Simulator,name=iPhone 16" build 2>&1
   ```

6. Parse output for:
   - **Errors**: Lines with `: error:`
   - **Warnings**: Lines with `: warning:`
   - **Build time**: "Build Succeeded" or "Build Failed"

7. Present results:

```markdown
## Build Results

**Status**: Success / Failed
**Duration**: X seconds
**Configuration**: Debug/Release

### Errors (if any)
- File.swift:42 - error description

### Warnings (if any)
- File.swift:18 - warning description
```

8. On failure:
   - Offer to investigate and fix errors
   - Start with first error (often causes cascading failures)

## Quick Build Option

For quick validation without full output:
```bash
xcodebuild -scheme "[Scheme]" -quiet build
```

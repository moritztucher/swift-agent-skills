#!/bin/bash
# Definition of Done validation hook
# Runs build, tests, and lint checks before task completion

set -e

INPUT=$(cat)
TASK_SUBJECT=$(echo "$INPUT" | jq -r '.task_subject // "Unnamed task"')

echo "Validating Definition of Done for: $TASK_SUBJECT" >&2

# Find Xcode project/workspace
find_xcode_project() {
    if ls *.xcworkspace 1> /dev/null 2>&1; then
        echo "-workspace $(ls *.xcworkspace | head -1)"
    elif ls *.xcodeproj 1> /dev/null 2>&1; then
        echo "-project $(ls *.xcodeproj | head -1)"
    else
        return 1
    fi
}

PROJECT_ARG=$(find_xcode_project) || {
    echo "No Xcode project found - skipping build validation" >&2
    exit 0  # Don't block non-Xcode projects
}

# 1. BUILD CHECK
echo "  [1/3] Building project..." >&2
if ! xcodebuild $PROJECT_ARG -scheme "$(xcodebuild $PROJECT_ARG -list 2>/dev/null | grep -A1 'Schemes:' | tail -1 | xargs)" build 2>&1 | tail -5; then
    echo "Definition of Done FAILED: Build errors exist" >&2
    exit 2
fi
echo "  [1/3] Build passed" >&2

# 2. TEST CHECK
echo "  [2/3] Running tests..." >&2
if ! xcodebuild $PROJECT_ARG -scheme "$(xcodebuild $PROJECT_ARG -list 2>/dev/null | grep -A1 'Schemes:' | tail -1 | xargs)" test -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10; then
    echo "Definition of Done FAILED: Tests failing" >&2
    exit 2
fi
echo "  [2/3] Tests passed" >&2

# 3. LINT CHECK (if SwiftLint available)
echo "  [3/3] Checking code style..." >&2
if command -v swiftlint &> /dev/null; then
    LINT_ERRORS=$(swiftlint lint --quiet 2>/dev/null | grep -c "error:" || true)
    if [ "$LINT_ERRORS" -gt 0 ]; then
        echo "Definition of Done FAILED: $LINT_ERRORS SwiftLint errors" >&2
        swiftlint lint --quiet 2>/dev/null | grep "error:" | head -5 >&2
        exit 2
    fi
    echo "  [3/3] Lint passed" >&2
else
    echo "  [3/3] SwiftLint not installed - skipping" >&2
fi

echo "Definition of Done validation PASSED" >&2
exit 0

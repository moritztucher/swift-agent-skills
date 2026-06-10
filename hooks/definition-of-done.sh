#!/bin/bash
# Definition of Done validation hook (opt-in Stop hook)
# Verifies the project still builds and lints clean before letting the task complete.
# Deliberately no test run — a full suite on every Stop is CI's job and trains
# people to disable the gate. Wire your tests into CI instead.

set -e

INPUT=$(cat)
TASK_SUBJECT=$(echo "$INPUT" | jq -r '.task_subject // "Unnamed task"')

echo "Validating Definition of Done for: $TASK_SUBJECT" >&2

# Find Xcode project/workspace
if ls *.xcworkspace 1> /dev/null 2>&1; then
    PROJECT_ARG="-workspace $(ls *.xcworkspace | head -1)"
elif ls *.xcodeproj 1> /dev/null 2>&1; then
    PROJECT_ARG="-project $(ls *.xcodeproj | head -1)"
else
    echo "WARNING: no Xcode project or workspace found in $(pwd) — Definition of Done NOT validated (skipping, not passing)." >&2
    exit 0  # Don't block non-Xcode projects, but say so loudly
fi

# First scheme, parsed from JSON (handles both project and workspace output)
SCHEME=$(xcodebuild $PROJECT_ARG -list -json 2>/dev/null | jq -r '(.project // .workspace).schemes[0] // empty')
if [ -z "$SCHEME" ]; then
    echo "Definition of Done FAILED: could not determine a scheme from 'xcodebuild -list -json'" >&2
    exit 2
fi

# 1. BUILD CHECK — generic simulator destination, no named device required
echo "  [1/2] Building scheme '$SCHEME'..." >&2
BUILD_LOG=$(mktemp)
if ! xcodebuild $PROJECT_ARG -scheme "$SCHEME" -destination 'generic/platform=iOS Simulator' build -quiet > "$BUILD_LOG" 2>&1; then
    echo "Definition of Done FAILED: build errors exist" >&2
    tail -20 "$BUILD_LOG" >&2
    rm -f "$BUILD_LOG"
    exit 2
fi
rm -f "$BUILD_LOG"
echo "  [1/2] Build passed" >&2

# 2. LINT CHECK (if SwiftLint available)
echo "  [2/2] Checking code style..." >&2
if command -v swiftlint &> /dev/null; then
    LINT_ERRORS=$(swiftlint lint --quiet 2>/dev/null | grep -c "error:" || true)
    if [ "$LINT_ERRORS" -gt 0 ]; then
        echo "Definition of Done FAILED: $LINT_ERRORS SwiftLint errors" >&2
        swiftlint lint --quiet 2>/dev/null | grep "error:" | head -5 >&2
        exit 2
    fi
    echo "  [2/2] Lint passed" >&2
else
    echo "  [2/2] SwiftLint not installed - skipping" >&2
fi

echo "Definition of Done validation PASSED" >&2
exit 0

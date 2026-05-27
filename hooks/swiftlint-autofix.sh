#!/bin/bash
# Auto-fix Swift files after edits

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only run on .swift files
if [[ "$FILE_PATH" == *.swift ]] && command -v swiftlint &> /dev/null; then
    swiftlint lint --fix --path "$FILE_PATH" --quiet 2>/dev/null || true
fi

exit 0

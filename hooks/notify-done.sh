#!/bin/bash
# macOS notification when Claude completes a task

osascript -e 'display notification "Task completed" with title "Claude Code" sound name "Glass"' 2>/dev/null || true

exit 0

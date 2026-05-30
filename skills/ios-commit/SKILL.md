---
name: ios-commit
description: Create a well-formatted git commit following project conventions
disable-model-invocation: true
---

# /commit - Smart Git Commit

Create a well-formatted git commit following project conventions.

## Instructions

1. Run `git status` to see staged and unstaged changes

2. If nothing is staged, ask user what to stage:
   - All changes
   - Specific files (list them)
   - Let me stage manually

3. Run `git diff --staged` to analyze staged changes

4. Check for git prefix in project's CLAUDE.md (e.g., "P66", "APP")

5. Generate commit message:
   - If prefix exists: `[PREFIX-XXX] type: description`
   - If no prefix: `type: description`

   Types: feat, fix, refactor, docs, test, chore, style

6. Present the commit message and ask for confirmation

7. On confirmation, run:
   ```bash
   git commit -m "message"
   ```

8. Ask if user wants to push

## Commit Message Format

```
[PREFIX-XXX] type: short description

- Bullet point details (if needed)
- Another detail

Co-Authored-By: Claude <noreply@anthropic.com>
```

## Pre-Commit Checks

Before committing, verify:
- No secrets or credentials in staged files
- No .env files being committed
- Build passes (if configured in project)

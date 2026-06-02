# Git Workflow

> Full git workflow reference. Core rules are in CLAUDE.md.

## Branch Naming Convention

Replace `[PREFIX]` with project-specific prefix:

| Type | Pattern | Example |
|------|---------|---------|
| Feature | `feature/[PREFIX]-999-brief-description` | `feature/APP-123-user-authentication` |
| Bugfix | `bugfix/[PREFIX]-999-brief-description` | `bugfix/APP-456-login-crash` |
| Prototype | `prototype/[PREFIX]-999-brief-description` | `prototype/APP-789-experimental-animation` |

## Prototype Branches

When on a `prototype/` branch:
- Skip tests and documentation requirements
- Add `// TODO: Cleanup for production` comments for shortcuts
- Code must still be secure (no relaxing security standards)
- Before merging to main, clean up or create a proper feature branch

## Git Worktrees

For parallel development on multiple features:

```bash
# Create a worktree for a feature branch
git worktree add ../project-feature-x feature/PREFIX-123-feature-x

# List active worktrees
git worktree list

# Remove when done
git worktree remove ../project-feature-x
```

Each worktree can have its own Claude session for isolation.

## Commit Message Format

```
[PREFIX]-999: type: Single sentence commit message
```

**IMPORTANT:** Commit messages must be exactly 1 sentence. No multi-line descriptions. If there are multiple logical changes, split them into separate commits.

**Ticket Number:** Extract from branch name

**Types:**
- `feat` - New feature
- `fix` - Bug fix
- `refactor` - Code refactoring (no functional changes)
- `docs` - Documentation changes
- `test` - Adding or updating tests

**Examples:**
```
APP-123: feat: Add user authentication with biometrics
APP-456: fix: Resolve navigation coordinator memory leak
```

## Commit Process (Manual Approval)

1. Claude suggests commits when appropriate milestones are reached
2. Claude generates a commit message following the format above
3. Claude extracts the ticket number from the current branch name
4. Claude asks for approval before executing the commit
5. You review and approve or request changes

## When to Commit

Commit after:
- Completing a feature or sub-feature
- Fixing a bug
- Completing a significant refactoring
- Adding tests
- Updating documentation

## Git Commands

Claude will use (after approval):
```bash
git add <files>
git commit -m "[PREFIX]-999: feat: Commit message"
git status
git diff
```

**Note:** Claude will NOT automatically push to remote.

## GitHub Issues Integration

### Issue Format

```markdown
Title: [PREFIX]-XXX: [Brief description]

## Description
[Detailed description of the issue, feature, or bug]

## Tasks
- [ ] Task 1
- [ ] Task 2
- [ ] Task 3

## Acceptance Criteria
- Criterion 1
- Criterion 2

## Technical Notes
[Any implementation details, considerations, or constraints]
```

### When to CREATE Issues

Create new Issues for:
1. **Discovering bugs** - Only if NOT related to current ticket
2. **Identifying technical debt** - Code smells, performance issues
3. **Suggesting new features** - Ideas for enhancements

Process: Draft → Ask approval → Create

### When to UPDATE Issues

1. Check off completed tasks from checklists
2. Add status update comments
3. Document blockers or issues
4. Close completed Issues (ask first)

### Issue Linking in Commits

```
[PREFIX]-999: feat: Add user authentication (#123)
```

## Pull Request Workflow

1. Ask if you want to create a PR when work is complete
2. Generate PR description referencing the Issue
3. Wait for approval before creating

### PR Description Template

```markdown
## Description
[Summary of changes]

## Related Issue
Closes #123

## Changes Made
- Change 1
- Change 2
- Change 3

## Testing
- [ ] Unit tests added/updated
- [ ] Manual testing completed
- [ ] No breaking changes
```

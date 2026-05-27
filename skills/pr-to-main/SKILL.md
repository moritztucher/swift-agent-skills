---
description: Create a release pull request from develop into main with the team's release PR template
---

# /pr-to-main - Release PR to Main

Create a release pull request from `develop` into `main` using the team's standard release PR template.

## Instructions

### Step 1 — Gather Context

Run these commands in parallel:

```bash
git branch --show-current
```

```bash
git log main..develop --oneline
```

```bash
git diff main...develop --stat
```

```bash
git remote get-url origin
```

Verify:
- You are on `develop`. If not, warn the user and ask if they want to continue or switch first.
- There are commits on `develop` ahead of `main`. If not, stop and tell the user there's nothing to release.

### Step 2 — Analyze Changes Since Last Release

Read the full commit history and diffs between `main` and `develop`:

```bash
git log main..develop --format="%s%n%b"
```

```bash
git diff main...develop
```

Also check for version changes:

```bash
git log main..develop --oneline -- "*.xcodeproj" "*.pbxproj" "*.plist"
```

From this analysis, draft:
- **Summary of changes** — high-level description of what's in this release
- **Key features/fixes** — bullet list of notable changes grouped by category (features, fixes, improvements)

### Step 3 — Ask User to Review & Fill Gaps

Present the drafted sections and ask:

1. What **milestone** name should be linked? (or "none")
2. Are there specific **deployment steps** to document?
3. Was the **version updated**? If not, should it be?
4. Anything else to add to **release notes**?

### Step 4 — Create the PR

Create the PR using `gh pr create`:

```bash
gh pr create --base main --head develop --title "<Release title>" --body "$(cat <<'EOF'
**Description**:
- <summary of changes>
- Link to related milestone: <milestone-name or N/A>

**Checklist**:
- [ ] All tests passed
- [ ] Code reviewed and approved
- [ ] Deployment steps documented
- [ ] Version updated (if applicable)

**Release Notes**:
- <key features/fixes>
EOF
)"
```

### Step 5 — Report

Print the PR URL and a brief summary of the release contents.

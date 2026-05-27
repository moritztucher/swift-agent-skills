---
description: Create a pull request from the current branch into the develop branch with the team's PR template
---

# /pr-to-develop - Feature PR to Develop

Create a pull request from the current branch into `develop` using the team's standard PR template.

## Instructions

### Step 1 — Gather Context

Run these commands in parallel to understand the current state:

```bash
git branch --show-current
```

```bash
git log develop..HEAD --oneline
```

```bash
git diff develop...HEAD --stat
```

```bash
git status
```

```bash
git remote get-url origin
```

Verify:
- You are NOT on `develop` or `main`. If so, stop and tell the user.
- There are commits ahead of `develop`. If not, stop and tell the user.

### Step 2 — Extract Issue Number

Try to extract the GitHub issue number from the branch name (e.g., `feature/123-some-feature` → `123`, `fix/ISSUE-45` → `45`).

If no issue number can be inferred, ask the user:
> What GitHub issue number does this PR relate to? (Enter a number, or "none" to skip)

### Step 3 — Analyze Changes

Read the full diff and commit messages to understand what was done:

```bash
git log develop..HEAD --format="%s%n%b"
```

```bash
git diff develop...HEAD
```

From this analysis, draft the following sections:
- **Objective** — what the PR aims to achieve
- **What was done** — list of meaningful changes (group by area if many)
- **How to test** — concrete steps a reviewer can follow
- **Edge cases** — any tricky scenarios worth testing

### Step 4 — Ask User to Review & Fill Gaps

Present the drafted sections to the user and ask them to confirm or adjust. Also ask:

1. Any **learnings** worth noting?
2. Any **notes** for the reviewer (dependencies, follow-up PRs, draft status)?
3. Any **attachments** to mention (screenshots, videos)?

### Step 5 — Create the PR

Construct the issue link using the repo's GitHub URL pattern:
`https://github.com/{ORG}/{REPO}/issues/{NUMBER}`

If the user said "none" for the issue number, put `N/A` in the issue link field.

Create the PR using `gh pr create`:

```bash
gh pr create --base develop --title "<PR title>" --body "$(cat <<'EOF'
# Background
## Relevant links
* Github issue link: <issue_link>

## PR Details
1. <objective>

## What was done
1. <change 1>
2. <change 2>
...

## Learnings
1. <learnings or "N/A">

## How to test
1. <step 1>
2. <step 2>
...

#### Edge cases
1. <edge case 1 or "N/A">

## Attachments
<attachments or "N/A">

## Notes
1. <notes or "N/A">

! Please set your PR as draft if it's not ready to be merged yet :) !
EOF
)"
```

If the user indicated the PR is not ready, add `--draft` to the command.

### Step 6 — Report

Print the PR URL and a brief summary of what was created.

---
name: ios-release-notes
description: "Summarize what changed between the last two version tags of an iOS project. Reads git commits and prints a categorized release summary plus a paste-ready App Store Connect 'What's New' block. Pure git-based, no API calls. Usage: /ios-release-notes"
user_invocable: true
---

# /ios-release-notes — Release Summary from Git

Print a user-friendly, always-consistent summary of what changed between the last two version tags of the current iOS project. Print only. No files written. No Notion. No API.

## Output template (verbatim — every run produces this exact structure)

````
## What's New: v{PREV} → v{CUR}
**Range:** {PREV_DATE} → {CUR_DATE} · **Commits:** {N} · **Detected via:** {DETECTION_SOURCE}

### ✨ New Features
- {item}

### ⚡ Improvements
- {item}

### 🐛 Bug Fixes
- {item}

### 🔧 Under the Hood
- {item}

---

### 📋 App Store Connect — "What's New" (paste-ready)
```
{≤4 user-facing bullets, ≤30 chars each, no emojis, no periods}
```

---

<details>
<summary>Developer view: commit map ({N} commits)</summary>

| Hash | Subject | → Section |
|------|---------|-----------|
| {sha7} | {subject} | {section} |

</details>
````

**Layout invariants** — enforce these every run:
- All four section headers always present, in the same order.
- Empty section renders exactly: `- No changes in this category.`
- Paste-ready block is fenced for triple-click copy.
- Developer view is the only place commit hashes appear.

## Step 1 — Validate working directory

Run in parallel:
- `ls *.xcodeproj *.xcworkspace Package.swift 2>/dev/null`
- `git rev-parse --show-toplevel 2>/dev/null`

If neither iOS project marker exists, abort: **"This skill must be run from the root of an iOS project (no `.xcodeproj`, `.xcworkspace`, or `Package.swift` found)."**

If not inside a git repo, abort: **"No git repository detected. This skill requires git history to summarize."**

## Step 2 — Detect last two versions

Try sources in priority order. Stop at the first that yields two distinct versions. Set `DETECTION_SOURCE` accordingly.

**A. Git tags** (preferred):
```bash
git tag --list --sort=-v:refname | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)?$' | head -5
```
Take the top two. `DETECTION_SOURCE = "git tags"`.

**B. Single tag → first-release fallback:**
```bash
git rev-list --max-parents=0 HEAD | head -1
```
`PREV = initial commit`, `CUR = the only tag`. `DETECTION_SOURCE = "git tag → initial commit (first release)"`.

**C. No tags → MARKETING_VERSION history:**
```bash
git log -S"MARKETING_VERSION = " --pretty=format:"%H %ad" --date=short -- '*.pbxproj' | head -5
```
Identify the two most recent distinct version values. `DETECTION_SOURCE = "MARKETING_VERSION (no tags)"`.

**D. Info.plist `CFBundleShortVersionString`:** Same approach against `Info.plist` files. `DETECTION_SOURCE = "CFBundleShortVersionString (no tags)"`.

**Total failure:** abort with **"Could not detect two versions. Tag a release (e.g. `git tag v1.2.0`) or set MARKETING_VERSION in your Xcode project."**

Resolve dates: `git log -1 --format=%ad --date=short {PREV}` and the same for `{CUR}`.

## Step 3 — Detect uncommitted version drift

```bash
grep -hE 'MARKETING_VERSION = [0-9]+\.[0-9]+' *.xcodeproj/project.pbxproj 2>/dev/null | sort -u
```
If the value in the working tree is greater than `CUR`, prepend a single line above the header:

> **Note:** Project `MARKETING_VERSION` is `{X}` but no tag exists for it yet. This summary covers committed history through `v{CUR}`.

## Step 4 — Collect commits

```bash
git log {PREV}..{CUR} --pretty=format:"%H%x09%s%x09%ad" --date=short --no-merges
```
For first-release case, use `{INITIAL_COMMIT}..{CUR}`.

- 0 commits → abort: **"No commits between `v{PREV}` and `v{CUR}`. Are these the same commit?"**
- >150 commits → warn ("Found {N} commits — output may be long.") and proceed.

## Step 5 — Categorize each commit

Each commit lands in exactly one of: `feature`, `improvement`, `fix`, `chore`.

**Pass 1 — Conventional Commits (deterministic):**
- `feat:` / `feature:` → feature
- `fix:` / `bugfix:` → fix
- `perf:` / `refactor:` → improvement
- `chore:` / `docs:` / `style:` / `test:` / `build:` / `ci:` → chore

**Pass 2 — Semantic classification** (for unprefixed subjects):
- `add` / `introduce` / `implement` / `support` + user-visible noun → feature
- `improve` / `speed up` / `polish` / `tweak` / `redesign` → improvement
- `fix` / `resolve` / `correct` / `prevent crash` → fix
- internal-only changes (refactor without behavior change, deps, CI, formatting) → chore

**Squash-merged PRs** (subject like `Merge PR #123: Big feature` or `Big feature (#123)`) → one item, use the PR title.

## Step 6 — Rewrite each subject for users

For each item:
- Strip Conventional Commit prefix and scope (`feat(auth):` → drop `feat(auth):`).
- Strip trailing PR number (`(#123)`).
- Sentence case, no trailing period, ≤80 chars.
- Translate dev-speak to user-facing terms ("refactor onboarding VM" → "Smoother onboarding flow"; "fix crash in BGTask handler" → "Fixed a background sync crash").
- Dedupe items that describe the same user-visible change.

Map to sections:
- `feature` → ✨ New Features
- `improvement` → ⚡ Improvements
- `fix` → 🐛 Bug Fixes
- `chore` → 🔧 Under the Hood

## Step 7 — Build the paste-ready block

Produce ≤4 bullets, ≤30 chars each. Source priority:
1. Top 2 features
2. Top 1 improvement
3. Top 1 bug-fix headline (e.g. "Stability fixes")

Rules:
- User-facing language only ("Faster sync", not "Optimized URLSession queue").
- No version numbers, no emojis, no periods.
- Consistent case within the block.
- Fewer items if categories are absent — never pad.
- If everything is chores, label honestly ("Mostly internal improvements" — single bullet OK).

## Step 8 — Print

Print the assembled output exactly per the template. Do not write a file. Do not offer to log anywhere. Do not ask follow-up questions.

End the message with one line: **"Run `/ios-release-notes` again after your next release to regenerate."**

## Edge case reference

| Case | Handling |
|------|----------|
| Not in iOS project | Abort in Step 1 |
| Not in git repo | Abort in Step 1 |
| No tags at all | Fall through to pbxproj / Info.plist (Step 2 C/D) |
| Only one tag | Compare against initial commit (Step 2 B) |
| Uncommitted version bump | Prepend "Note:" line (Step 3) |
| 0 commits in range | Abort with friendly message (Step 4) |
| >150 commits | Warn, proceed (Step 4) |
| Squash-merged PR | One item, use PR title (Step 5) |
| Many small commits | Dedupe overlapping bullets (Step 6) |
| Empty section | Render `- No changes in this category.` |
| All chores | Honest paste-ready label (Step 7) |

## Tool budget

Bash (read-only git commands + grep) and Read (pbxproj / Info.plist when needed). No Write, no MCP, no WebSearch, no scheduling.

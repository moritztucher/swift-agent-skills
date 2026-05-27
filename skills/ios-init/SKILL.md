---
description: Initialize a new iOS project with standard configuration files (CLAUDE.md, memory, architecture, changelog)
---

# /ios-init - iOS Project Initialization

Initialize a new iOS project with standard configuration files and technical architecture decisions.

## Instructions

### Step 0 — Existing Project Guard

Before doing anything, check if the current directory already has initialization files:

1. Check for `CLAUDE.md`, `ARCHITECTURE.md`, `.claude/memory.md`, or `docs/decisions/ADR-0001-initial-architecture.md`
2. **If any exist**, warn the user:
   > "This project already has initialization files: [list found files]. Running `/ios-init` will overwrite them. Options:"
   > - **Update** — re-run Phase B only, merge new tech decisions into existing files
   > - **Overwrite** — start fresh, replace all init files
   > - **Cancel** — stop and keep existing files
3. If the user chooses **Update**, skip Phase A (read existing values from CLAUDE.md), go straight to Phase B, then merge new decisions into existing files without losing content that was added after init.
4. If the user chooses **Overwrite**, proceed normally.
5. **If no init files exist**, proceed normally.

### Phase A — Project Setup

1. Ask the user these questions using AskUserQuestion:
   - Database: SwiftData / RealmSwift / CoreData / None
   - iOS Target: iOS 18+ / iOS 26+
   - Git Prefix: (text input for commit prefixes, e.g., P66, APP)
   - Bundle ID: (text input, e.g., com.company.appname)

### Phase B — Technical Architecture Brainstorm

After Phase A, introduce a **Tech Confidence Level** that tracks how ready the technical foundation is. Iterate through named batches of questions until confidence reaches **90%** or the user says "done."

**How confidence works:**
- Starts at **~30%** after Phase A (we know database, target, prefix, bundle ID)
- Each batch of resolved decisions increases confidence
- Core decisions (networking, auth, navigation) are weighted heavily (~15% each)
- Follow-up decisions (sync, offline, biometrics) are lighter (~5-10% each)
- At the end of each batch, present the current confidence level and remaining open questions
- When fewer than 3 questions remain and they're minor, suggest answers and ask user to confirm

**Present each batch as a numbered list with concrete options. Mark recommended options with ⭐ where one clearly fits best.**

#### Batch 1 — Core Stack (~30% -> ~75%)

Always ask these three questions together:

1. **Networking:** REST ⭐ / GraphQL / None (local-only app)
2. **Auth:** Apple Sign-In / Firebase Auth / Custom / None
3. **Navigation complexity:** Simple (single NavigationStack) / Multi-tab (TabView + stacks) ⭐ / Deep linking required

#### Batch 2 — Data Strategy (ask based on Batch 1 answers)

Only ask questions that are relevant based on previous answers. Pick the applicable ones:

- **If database chosen** -> Sync strategy: Local-only ⭐ / CloudKit sync / Custom backend sync
- **If networking chosen** -> Offline support: Online-only ⭐ / Offline-first with sync / Cache-only
- **If auth chosen** -> Biometrics: Face ID/Touch ID for sensitive actions? Yes ⭐ / No

#### Batch 3 — Integrations & Polish (remaining questions to reach 90%)

- **3rd-party services:** Any known integrations? (e.g., RevenueCat, Firebase Analytics, push notifications)
- **Concurrency model:** Heavy background work expected? (e.g., media processing, large imports) Yes / No ⭐
- **Keychain usage:** Sensitive credentials beyond auth tokens? (auto-yes if auth chosen)
- **Accessibility priority:** Standard ⭐ / High

**Each batch:**
1. Present open questions with concrete options (2-4 per question)
2. Read user's answers
3. Move answered questions to resolved decisions
4. Surface any new questions triggered by answers
5. Update confidence level and present it: `Tech Confidence: XX% | Remaining: [list of open questions]`
6. If confidence >= 90%, proceed to file generation

**If user says "done" before 90%:** Accept it, note remaining open questions as TBD in generated files, and proceed.

### Step 2 — Generate Files

Create the following files based on all answers from Phase A and Phase B:

#### Project Folder Structure

Scaffold the standard MVVM directory structure with `.gitkeep` files so the folders are tracked by git:

```
App/                    # App entry point, configuration
  .gitkeep
Core/                   # Services, managers, extensions, shared models
  Services/
    .gitkeep
  Managers/
    .gitkeep
  Extensions/
    .gitkeep
  Models/
    .gitkeep
Features/               # Feature modules
  .gitkeep
ViewComponents/         # Shared reusable UI components
  .gitkeep
Resources/              # Assets, localization, fonts
  .gitkeep
bip/                    # Build-in-public trail — see CLAUDE.md → Build in Public
  BUILD-LOG.md
```

#### CLAUDE.md (project root)

**First line must be the iOS guide import** so the project opts into the global iOS rules (the user's global `~/.claude/CLAUDE.md` is now slim and domain-agnostic):

```
@~/.claude/docs/ios/ios-guide.md
```

**Second, a `## Role` section** with the senior-engineer framing (one line is fine):

```
## Role

You are a senior iOS engineer. Apply the judgment of someone who has shipped production apps for years — question requirements that conflict with platform conventions, prefer Apple-native APIs, and call out work that would not pass a senior code review.
```

**Third, a `## View Inventory` section** referencing the inventory file:

```
## View Inventory

Read `VIEW-INVENTORY.md` before implementing any new View, ViewModifier, or shared UI component. If a matching component already exists, reuse or extend it. When you add, rename, or delete a shared component, update `VIEW-INVENTORY.md` in the same diff.
```

**Fourth, a `## Build in Public` section** so every project carries the build-in-public capture habit. Also scaffold a `bip/` folder at the project root with a `BUILD-LOG.md` stub (a short header pointing back at this section):

```
## Build in Public

This project is built in public. The unit of capture is the **postable step** — any meaningful moment worth showing (a new screen, a fixed bug, a shipped feature, a milestone), *not* the session. One session may produce several postable steps or none; capture per step.

All build-in-public material lives in `bip/`:
- `bip/BUILD-LOG.md` — running log. Per postable step, append: date · what the step was · screenshot filename(s) · one line on the *why* / what was interesting or hard — that line is the post angle.
- `bip/screenshots/` — **1–3 screenshots per step, when the step is visual** (skip for non-visual steps). Claude captures these directly from the iOS Simulator.

**Bank for quiet days.** Building is lumpy — a heavy day yields several postable steps, a quiet day none. Capture everything as it happens and post it spread thin; never dump it all at once, never go silent because "nothing happened today."

Posting itself stays dumb-simple — one honest post, no production. `bip/` is the raw material, not a content pipeline.
```

Then the project-specific config:
- Project name (infer from directory or ask)
- Database choice
- iOS target version
- Git prefix for commits
- Bundle ID
- Any project-specific rules
- **`## Technical Decisions` section** capturing all resolved answers from Phase B:
  - Networking approach
  - Auth strategy
  - Navigation pattern
  - Sync strategy
  - Offline support
  - 3rd-party integrations
  - Any other resolved decisions
  - Mark unresolved decisions as **TBD** if user stopped early

#### .claude/memory.md

Use template from `~/.claude/docs/templates/project-memory-template.md`, then **pre-fill the Decisions section** with all Phase B choices. Format each as:

```
- [YYYY-MM-DD] [Decision area]: [Choice] — [Brief rationale from discussion]
```

Example:
```
- [2026-03-17] Networking: REST — standard choice for the backend API
- [2026-03-17] Auth: Apple Sign-In — simplest for iOS-only app, no 3rd-party dependency
- [2026-03-17] Navigation: Multi-tab — app has 3+ distinct sections
```

#### ARCHITECTURE.md

Use template from `~/.claude/docs/templates/architecture-template.md`, filled with:
- Project name, database choice, iOS target (from Phase A)
- **Navigation section:** Fill with chosen pattern (simple stack, multi-tab, deep linking)
- **Data Storage table:** Populate with actual database and sync choices
- **Third-Party Integrations:** Pre-fill with any chosen services (auth provider, analytics, etc.)
- **Data Flow section:** Update if offline-first or sync is involved — describe the sync/cache layer
- **Networking section:** Fill with REST/GraphQL choice and offline strategy
- Mark any unresolved sections as **TBD** if user stopped early

#### docs/decisions/ADR-0001-initial-architecture.md

Generate the first ADR using the template from `~/.claude/docs/templates/adr-template.md`:
- **Title:** "Initial Architecture Decisions"
- **Status:** Accepted
- **Context:** Summarize the project goals and constraints discussed during init
- **Decision:** Document all resolved technical decisions from Phase A and B in a structured list
- **Consequences:** List the pros/cons of the chosen stack
- **Alternatives Considered:** For each core decision (networking, auth, navigation), briefly note the alternatives that were available but not chosen
- **Date:** Today's date

#### CHANGELOG.md

Use template from `~/.claude/docs/templates/changelog-template.md` with initial version 0.1.0.

#### VIEW-INVENTORY.md (project root)

Copy `~/.claude/docs/templates/view-inventory-template.md` to the project root as `VIEW-INVENTORY.md`. Replace `{{ProjectName}}` with the project name and `{{YYYY-MM-DD}}` with today's date. Leave the example rows in place as illustrations — the user (and Claude) will fill it in as components are created. This file is the canonical index of shared UI components; `CLAUDE.md` already instructs future sessions to read it before implementing new Views.

#### Backlog.md (optional, pre-seeded)

Ask if user wants a backlog file. If yes, use template from `~/.claude/docs/templates/backlog-template.md` and **pre-seed with initial tasks** derived from Phase B decisions:

**Always include:**
- [ ] Set up project folder structure and navigation coordinator

**If networking chosen:**
- [ ] Implement `NetworkService` with base URL configuration
- [ ] Add API error handling and response models

**If auth chosen:**
- [ ] Implement authentication flow ([chosen provider])
- [ ] Set up Keychain storage for credentials
- [ ] Add biometric authentication (if chosen)

**If database chosen:**
- [ ] Configure [database] with initial data models
- [ ] Implement data persistence layer

**If sync chosen:**
- [ ] Implement sync strategy ([chosen approach])
- [ ] Add conflict resolution handling

**If offline support chosen:**
- [ ] Implement offline data cache
- [ ] Add network reachability monitoring

**For each 3rd-party integration:**
- [ ] Integrate [service name] — [purpose]

Place these under **Features > High Priority**. Leave other sections from the template as-is.

### Step 3 — Post-Init Validation

After generating all files, perform a quick consistency check:

1. **Cross-reference CLAUDE.md ↔ ARCHITECTURE.md** — verify that every tech decision in CLAUDE.md's Technical Decisions section has a matching entry in ARCHITECTURE.md (networking, auth, navigation, sync, database).
2. **Cross-reference CLAUDE.md ↔ ADR-0001** — verify the ADR's Decision section matches CLAUDE.md's Technical Decisions.
3. **Check Backlog ↔ Tech Decisions** — if Backlog.md exists, verify every non-None tech choice has at least one corresponding task.
4. **Check memory.md** — verify the Decisions section has an entry for each resolved Phase B decision.

If any inconsistency is found, fix it silently. Do not bother the user unless the inconsistency is ambiguous.

### Step 4 — Context7 & Framework Guide Hints

After generating files, check which frameworks/services were chosen and:

1. **Use Context7** (via `resolve-library-id` then `query-docs`) to fetch the latest setup/integration docs for each chosen 3rd-party service (e.g., RevenueCat, Firebase Auth). Add a brief note in the ADR's References section with the current recommended version and any critical setup steps.

2. **Print framework guide hints** — for each chosen technology that has a matching guide in `~/.claude/docs/ios/`, remind the user:

   ```
   Relevant framework guides for your stack:
   - [Technology]: ~/.claude/docs/ios/[category]/[guide].md
   ```

   Map decisions to guides:
   | Decision | Guide Path |
   |----------|-----------|
   | SwiftData | `docs/ios/data/swiftdata.md` |
   | RealmSwift | `docs/ios/data/realmswift.md` |
   | CloudKit sync | `docs/ios/data/cloudkit.md` |
   | Apple Sign-In | `docs/ios/system/auth.md` |
   | Firebase Auth | `docs/ios/commerce/firebase.md` |
   | Biometrics | `docs/ios/system/localauthentication.md` |
   | RevenueCat | `docs/ios/commerce/revenuecat.md` |
   | Push notifications | `docs/ios/system/notifications.md` |
   | WidgetKit | `docs/ios/system/widgetkit.md` |
   | CoreLocation | `docs/ios/system/corelocation.md` |
   | HealthKit | `docs/ios/system/healthkit.md` |

   Only list guides that match the user's actual choices.

### Step 5 — Wrap Up & Handoff

After creating all files:
- List all created files and folders
- Suggest running `git add` to stage them
- Remind about updating ARCHITECTURE.md with specific project details as they evolve
- **Offer `/project-brief` handoff:** Ask the user if they want to continue with `/project-brief` to define the project scope and epics. If they say yes, write a `docs/.ios-init-decisions.json` file containing all resolved tech decisions in a structured format so `/project-brief` can read it:

```json
{
  "source": "ios-init",
  "date": "YYYY-MM-DD",
  "project_name": "...",
  "bundle_id": "...",
  "ios_target": "...",
  "database": "...",
  "networking": "...",
  "auth": "...",
  "navigation": "...",
  "sync_strategy": "...",
  "offline_support": "...",
  "biometrics": "...",
  "third_party": ["..."],
  "heavy_background_work": "...",
  "accessibility_priority": "..."
}
```

Then invoke `/project-brief` directly — do not ask the user to run it manually.

## Template Locations

| Template | Path |
|----------|------|
| Project Memory | `~/.claude/docs/templates/project-memory-template.md` |
| Architecture | `~/.claude/docs/templates/architecture-template.md` |
| ADR | `~/.claude/docs/templates/adr-template.md` |
| Changelog | `~/.claude/docs/templates/changelog-template.md` |
| Backlog | `~/.claude/docs/templates/backlog-template.md` |
| View Inventory | `~/.claude/docs/templates/view-inventory-template.md` |

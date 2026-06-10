---
name: ios-init
description: Initialize an iOS/Apple-platform project with the standard documentation and project files (CLAUDE.md, memory, ARCHITECTURE.md, first ADR, changelog, view inventory, .gitignore, LICENSE, README). Starts by letting the user describe the project in a few sentences, mines that for decisions, then asks only about gaps. Detects new vs. fresh-scaffold vs. existing codebase and adapts.
user_invocable: true
---

# /ios-init — Project Initialization

Initialize an Apple-platform project with the standard configuration, documentation, and repo files. One skill handles a brand-new project, a freshly-created Xcode project, and an existing codebase — it auto-detects which and adapts.

> **Next step:** after init, hand off to `/ios-brief` to define scope and epics. This skill offers that handoff automatically and passes your project description forward so you don't describe it twice.

---

## Step 0 — Detect Mode

The expected workflow is: the user creates the Xcode project first, then runs this skill. So a bare `.xcodeproj` is **not** an "existing project" — classify into three modes:

1. **Scan for code:** look for `*.xcodeproj` / `*.xcworkspace`, `Package.swift`, and count `*.swift` files / feature directories.
   - **No Xcode project and no Swift files → New.**
   - **Xcode project exists but only boilerplate** (roughly ≤ 6 Swift files, typically just `<App>.swift`, `ContentView.swift`, maybe a model; no `Features/` directory; no `*Service.swift` / `*Manager.swift`) **→ Fresh scaffold.**
   - **Substantial codebase** (multiple features, real services/models, established structure) **→ Existing.**
   - **New** and **Fresh scaffold** both run the **Setup path** (Section A): guided decisions + folder scaffolding.
   - **Existing** runs the **Adopt path** (Section B): scan and pre-fill from observed facts.
2. **Existing-init guard:** if `CLAUDE.md` / `ARCHITECTURE.md` / `.claude/memory.md` / `ADR-0001` already exist, warn first:
   > "This project already has init files: [list]. Options: **Update** (merge new decisions, keep existing content) / **Overwrite** (replace) / **Cancel**."

Announce the detected mode in one line, then run **Step 1** (shared), then the matching section. Both converge at **Section C — Generate Files**.

---

## Step 1 — Project Description (both paths, first)

Before any structured questions, invite a free-form brief:

> "In 1–5 sentences, tell me what you're building and anything you've already decided — what kind of app it is, storage, the platforms you're targeting, integrations, whether it's open-source or commercial, B2B or B2C. Skip anything you're unsure about; I'll ask about the rest."

Then **mine the blurb** for both kinds of signal and pre-fill the decision set — do not re-ask anything the user already stated:

- **Technical:** platforms, storage/database, networking, auth, offline/sync, 3rd-party services, concurrency needs.
- **Product / distribution:** what the app is, target audience (B2B / B2C / internal), distribution model (open source / commercial / proprietary), monetization hints.

Treat mined values as **pre-filled and to-be-confirmed**, not final. On the Setup path, start the Tech Confidence meter **higher** than its 30% floor in proportion to what the blurb resolved. **Record the raw blurb verbatim** — it goes into `.ios-init-decisions.json` and is reused by `/ios-brief`.

---

## Section A — Setup Path (New / Fresh scaffold)

### A1 — Project Setup

Ask with AskUserQuestion — but **skip any item the blurb already answered** (confirm those in one line instead):

- **Platforms (multi-select):** iOS / iPadOS / macOS / visionOS / tvOS / watchOS
- **Minimum deployment target:** for the primary platform (e.g. iOS 18+ ⭐ / iOS 26+); note sensible minimums for the others
- **Database:** SwiftData ⭐ / RealmSwift / CoreData / None
- **Distribution:** Open source / Commercial (proprietary) — *(usually from the blurb)*
- **Audience:** B2C / B2B / Internal — *(usually from the blurb)*
- **Git Prefix:** text input (e.g. APP, IOS)
- **Bundle ID:** text input (e.g. com.company.appname)

### A2 — Technical Architecture Brainstorm

Introduce a **Tech Confidence Level** and iterate batches until **≥90%** or the user says "done." Starts at ~30% (higher if the blurb pre-filled core decisions). Core decisions (networking, auth, navigation) weigh ~15% each; follow-ups (sync, offline, biometrics) ~5–10%. Present each batch as a numbered list with concrete options; mark recommended with ⭐. **Skip questions the blurb or A1 already settled.**

- **Batch 1 — Core stack:** Networking (REST ⭐ / GraphQL / None), Auth (Apple Sign-In / Firebase / Custom / None), Navigation (Simple / Multi-tab ⭐ / Deep linking).
- **Batch 2 — Data strategy (only what's relevant):** Sync (Local-only ⭐ / CloudKit / Custom), Offline (Online-only ⭐ / Offline-first / Cache-only), Biometrics (Yes ⭐ / No if auth chosen).
- **Batch 3 — Integrations & polish:** 3rd-party services; heavy background work (Yes / No ⭐); keychain beyond auth; accessibility priority (Standard ⭐ / High).

Each batch: present open questions → read answers → resolve → surface new questions → print `Tech Confidence: XX% | Remaining: …`. At ≥90%, go to Section C. If the user says "done" early, mark the rest **TBD**.

**Folder structure** (Section C scaffolds this for New / Fresh scaffold):

```
App/                    # App entry point, configuration
  .gitkeep
Core/
  Services/   .gitkeep
  Managers/   .gitkeep
  Extensions/ .gitkeep
  Models/     .gitkeep
Features/     .gitkeep
ViewComponents/ .gitkeep
Resources/    .gitkeep
```

For a **Fresh scaffold**, create only the folders that don't already exist; never move or rename the files Xcode generated.

---

## Section B — Adopt Path (Existing codebase)

**Observe first, ask second.** The Step 1 blurb already gave you intent; the scan gives you facts.

### B1 — Silent Codebase Scan
- **Structure:** top-level dirs; MVVM/MVC/other; presence of `App/`, `Core/`, `Features/`, `ViewComponents/`, `Resources/`.
- **Xcode project:** schemes, targets, **platforms/destinations**, bundle ID, deployment targets, test targets.
- **Dependencies:** `Package.swift`, `Podfile`, `Cartfile` → list with inferred purpose.
- **Tech-stack detection** (imports/patterns):
  | What | How to detect |
  |------|---------------|
  | Database | `import SwiftData` / `RealmSwift` / `CoreData` |
  | Networking | `Alamofire`, `URLSession`, `Apollo` (GraphQL) |
  | Auth | `AuthenticationServices`, `FirebaseAuth`, custom auth services |
  | State mgmt | `@Observable` vs `@ObservableObject`/`@Published` vs Combine |
  | Concurrency | `async/await` vs Combine vs completion handlers |
  | Navigation | `NavigationStack`/`NavigationPath` vs `NavigationView` |
  | UI framework | SwiftUI / UIKit / mixed |
  | DI | Environment vs singletons vs manual injection |
  | Offline/sync | CloudKit, sync services, `NWPathMonitor` |
  | Biometrics | `import LocalAuthentication` |
  | Push | `UNUserNotificationCenter` |
  | Analytics | Firebase Analytics, Mixpanel, custom |
  | Payments | StoreKit, RevenueCat |
  | Location | `CoreLocation`, `MapKit` |
- **Architecture patterns:** ViewModel style; business logic in Views; NavigationCoordinator; service/manager layer; protocol abstractions.
- **Existing docs & repo files:** `CLAUDE.md`, `ARCHITECTURE.md`, `.claude/memory.md`, `README.md`, `LICENSE`, `.gitignore`, `docs/` — note current vs stale.
- **Git:** age, recent activity, branch, uncommitted changes.
- **Quality signals:** `.swiftlint.yml`, tests, `PrivacyInfo.xcprivacy`, `.gitignore` completeness.
- **View inventory scan:** shared components under `ViewComponents/`; feature components under `Features/*/Views/ViewComponents/`; top-level `*View` screens; custom `ViewModifier`/`ButtonStyle`/etc. Capture type, path, init signature, one-line purpose; group by feature.

### B2 — Present Findings
Summarize project (name, bundle ID, platforms, deployment targets, schemes), architecture, tech stack, dependencies, integrations, structure, existing docs/repo files, code quality, git state. Ask: _"Does this look accurate? Anything I missed or got wrong?"_ Wait for confirmation.

### B3 — Fill Gaps (ask ONLY what code + blurb can't reveal)
- **Always:** Git prefix; corrections to the scan; confirm platforms; distribution + audience if the blurb didn't say.
- **Only if undetectable:** sync strategy; offline support; accessibility priority; planned-but-uncoded integrations.
- **Never ask** about anything already detected or stated in the blurb.

Existing path: **do NOT scaffold folders** — document the existing structure in ARCHITECTURE.md. Pre-fill `VIEW-INVENTORY.md` from the scan. Label decisions "Observed from existing codebase." For existing files (CLAUDE.md, README, LICENSE, .gitignore, ADR-0001), present a diff and ask merge-vs-overwrite (ADR-0001 present → create ADR-0002 instead).

---

## Section C — Generate Files (both paths)

Generate-if-missing for repo files; **never silently overwrite** an existing `README.md`, `LICENSE`, or `.gitignore` — diff and ask.

### CLAUDE.md (project root)
First line is the iOS guide import: `@~/.claude/docs/ios/ios-guide.md`. Then `## Role` (senior iOS engineer framing) and `## View Inventory` (read VIEW-INVENTORY.md before new UI). Then project config: name, bundle ID, **platforms**, deployment targets, git prefix, database, and a **`## Technical Decisions`** section with every resolved/detected choice. Mark unresolved **TBD**. Existing path: note "Generated from existing codebase scan." If CLAUDE.md exists, diff + merge (ensure the import, `## Role`, `## View Inventory` are present).

### .claude/memory.md
Template `project-memory-template.md`. Pre-fill Decisions (`- [YYYY-MM-DD] Area: Choice — rationale`). Existing path: label "Observed from existing codebase."

### ARCHITECTURE.md — tailored, not boilerplate
Template `architecture-template.md`, but **render the diagram and sections from the actual decisions** rather than copying the generic layers:
- **Project Summary:** include the selected **platforms** and per-platform deployment targets.
- **System diagram:** draw only the layers that exist. Omit the Network layer for a local-only app; show a Sync/CloudKit box when sync is chosen; add platform-specific scenes (e.g. a macOS `WindowGroup`/`Settings`, a watchOS scene) when those platforms are selected. Existing path: reflect the real layers found in code.
- Fill Navigation, Networking, Auth, Sync, Data Storage, Third-Party Integrations from decisions. Existing path: also fill the Dependencies and Feature Modules tables from the scan.
- Mark unresolved sections **TBD**.

### docs/decisions/ADR-0001-initial-architecture.md
Template `adr-template.md`. New/Fresh: Title "Initial Architecture Decisions"; Context = goals/constraints (lean on the blurb); Decision = resolved decisions incl. platforms + distribution; Consequences; Alternatives Considered (per core decision). Existing: Title "Existing Architecture Documentation"; Context = "observed and confirmed"; if ADR-0001 exists, create ADR-0002.

### CHANGELOG.md
Template `changelog-template.md`, version 0.1.0 (New/Fresh) or inferred (Existing, only if missing).

### .gitignore  *(new)*
If absent, write the standard Swift/Xcode ignore set. If present, merge missing entries (don't drop existing ones). Core entries:
```
# Xcode / Swift
.DS_Store
build/
DerivedData/
*.xcuserstate
xcuserdata/
*.xcscmblueprint
*.xccheckout
# Swift Package Manager
.build/
.swiftpm/
Package.resolved
# CocoaPods / Carthage (only if used)
Pods/
Carthage/Build/
# Secrets / local config
*.xcconfig.local
.env
# Claude / local docs trail
.claude/memory.md   # keep or remove per the user's preference
```
Ask whether to track or ignore `.claude/memory.md` rather than guessing.

### LICENSE  *(new, conditional)*
- **Open source:** ask which license (MIT ⭐ / Apache-2.0 / GPL-3.0 / BSD-3-Clause / other) and write the full standard text, filling the current year and copyright holder (from git config `user.name`, confirm). Add a matching License section to README.
- **Commercial / proprietary:** write a short `Copyright (c) <year> <holder>. All rights reserved.` notice, or skip entirely if the user prefers no file. Don't invent permissive terms for a commercial app.

### README.md  *(new)*
Generate from the blurb + decisions (generate-if-missing; diff-and-merge if present):
- **Title** = project name; one-line description from the blurb.
- **Platforms** line (the selected set) and minimum deployment targets.
- **Features** — a short list from the blurb (mark "see PROJECT-BRIEF.md" since the brief comes next).
- **Tech stack** — database, networking, auth, key integrations.
- **Getting started** — clone, open the `.xcodeproj`/`.xcworkspace`, build & run; any setup steps for chosen services.
- **License** — the chosen license (or "Proprietary").

### VIEW-INVENTORY.md (project root)
Copy `view-inventory-template.md`, replace `{{ProjectName}}` / `{{YYYY-MM-DD}}`. New/Fresh: keep example rows as illustrations. Existing: delete examples, populate from the B1 scan; merge if it exists.

### Backlog.md (optional)
Ask if wanted. New/Fresh: seed from decisions (folder structure + coordinator; NetworkService if networking; auth flow + Keychain + biometrics if auth; DB models if database; sync/offline tasks; one task per integration). Existing: seed from observed gaps (`// TODO:`s, missing tests, missing `PrivacyInfo.xcprivacy`, SwiftLint setup, `@ObservableObject`→`@Observable`, `NavigationView`→`NavigationStack`).

---

## Section D — Validate, Hint, Hand Off (both paths)

### D1 — Validation
Cross-check: CLAUDE.md ↔ ARCHITECTURE.md (decisions match), CLAUDE.md ↔ ADR, Backlog ↔ decisions, memory has an entry per decision, README/LICENSE reflect the chosen distribution. Fix silently unless ambiguous.

### D2 — Context7 & Framework Guide Hints
1. **Context7** (`resolve-library-id` → `query-docs`): current setup docs for each chosen/detected 3rd-party service; note recommended version + critical steps in the ADR References. Existing path: flag outdated deps.
2. **Framework skill hints** for each technology with a matching specialist skill in the catalog:
   | Decision | Skill |
   |----------|-------|
   | SwiftData | `swiftdata` |
   | RealmSwift | `realmswift` |
   | CloudKit sync | `cloudkit` |
   | Apple Sign-In | `authenticationservices` |
   | Firebase Auth | `firebase` |
   | Biometrics | `localauthentication` |
   | RevenueCat | `revenuecat` |
   | Push notifications | `usernotifications` |
   | WidgetKit | `widgetkit` |
   | CoreLocation | `corelocation` |
   | HealthKit | `healthkit` |
   List only skills matching actual choices (and only ones present in the installed catalog). For macOS targets, point to the `appkit` skill.

### D3 — Wrap Up & Handoff
- List everything created/updated (incl. `.gitignore`, `LICENSE`, `README.md`); note skipped (already existed). Existing path: list tech-debt items.
- Suggest `git add` to stage them.
- **Offer `/ios-brief` handoff:** write `docs/.ios-init-decisions.json` (schema below), then invoke `/ios-brief` directly — don't make the user re-run it.

```json
{
  "source": "ios-init",
  "date": "YYYY-MM-DD",
  "description": "<the user's raw 1–5 sentence blurb, verbatim>",
  "project_name": "...",
  "bundle_id": "...",
  "platforms": ["iOS", "iPadOS"],
  "deployment_targets": { "iOS": "18.0" },
  "distribution": "open-source | commercial",
  "license": "MIT | Apache-2.0 | proprietary | none",
  "audience": "B2C | B2B | internal",
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

---

## Template Locations

| Template | Path |
|----------|------|
| Project Memory | `~/.claude/docs/templates/project-memory-template.md` |
| Architecture | `~/.claude/docs/templates/architecture-template.md` |
| ADR | `~/.claude/docs/templates/adr-template.md` |
| Changelog | `~/.claude/docs/templates/changelog-template.md` |
| Backlog | `~/.claude/docs/templates/backlog-template.md` |
| View Inventory | `~/.claude/docs/templates/view-inventory-template.md` |

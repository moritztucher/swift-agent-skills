---
name: ios-init
description: Initialize an iOS project with the standard documentation set (CLAUDE.md, memory, ARCHITECTURE.md, first ADR, changelog, view inventory). Detects whether the directory is greenfield or an existing codebase — for greenfield it runs a guided tech-decision Q&A; for existing code it scans and pre-fills everything observable, asking only about gaps.
user_invocable: true
---

# /ios-init — iOS Project Initialization

Initialize an iOS project with the standard configuration and documentation files. This skill handles **both** a brand-new project and an existing codebase — it auto-detects which and adapts.

> **Next step:** after init, hand off to `/ios-brief` to define scope and epics. This skill offers that handoff automatically.

---

## Step 0 — Detect Mode

Before anything else, determine which path to run:

1. **Scan for existing code:** look for `*.xcodeproj`, `*.xcworkspace`, `Package.swift`, or any `*.swift` files.
   - **Code found → Existing path** (Section B). Observe first, ask second.
   - **No code found → Greenfield path** (Section A). Guided Q&A.
2. **Existing-init guard:** check for `CLAUDE.md`, `ARCHITECTURE.md`, `.claude/memory.md`, or `docs/decisions/ADR-0001-initial-architecture.md`. If any exist, warn the user before proceeding:
   > "This project already has init files: [list]. Options: **Update** (merge new decisions, keep existing content), **Overwrite** (replace), **Cancel**."
   - **Update:** read existing values, only fill gaps / add missing sections, never clobber content added after init.
   - **Overwrite:** proceed normally.
   - **Cancel:** stop.

Announce the detected mode in one line, then proceed to the matching section. Both paths converge at **Section C — Generate Files**.

---

## Section A — Greenfield Path (no existing code)

### A1 — Project Setup

Ask with AskUserQuestion:
- **Database:** SwiftData / RealmSwift / CoreData / None
- **iOS Target:** iOS 18+ / iOS 26+
- **Git Prefix:** text input for commit prefixes (e.g., P66, APP)
- **Bundle ID:** text input (e.g., com.company.appname)

### A2 — Technical Architecture Brainstorm

Introduce a **Tech Confidence Level** that tracks how ready the technical foundation is. Iterate through named batches until confidence reaches **90%** or the user says "done."

**How confidence works:**
- Starts at **~30%** after A1 (database, target, prefix, bundle ID known)
- Each batch of resolved decisions increases it
- Core decisions (networking, auth, navigation) are weighted heavily (~15% each)
- Follow-ups (sync, offline, biometrics) are lighter (~5–10% each)
- At the end of each batch, present current confidence and remaining open questions
- When fewer than 3 minor questions remain, suggest answers and ask the user to confirm

Present each batch as a numbered list with concrete options. Mark recommended options with ⭐.

#### Batch 1 — Core Stack (~30% → ~75%)
Always ask these three together:
1. **Networking:** REST ⭐ / GraphQL / None (local-only)
2. **Auth:** Apple Sign-In / Firebase Auth / Custom / None
3. **Navigation:** Simple (single NavigationStack) / Multi-tab (TabView + stacks) ⭐ / Deep linking required

#### Batch 2 — Data Strategy (ask only what's relevant to Batch 1)
- **If database chosen** → Sync: Local-only ⭐ / CloudKit / Custom backend
- **If networking chosen** → Offline: Online-only ⭐ / Offline-first with sync / Cache-only
- **If auth chosen** → Biometrics for sensitive actions? Yes ⭐ / No

#### Batch 3 — Integrations & Polish (reach 90%)
- **3rd-party services:** RevenueCat, Firebase Analytics, push, etc.?
- **Concurrency model:** Heavy background work expected? Yes / No ⭐
- **Keychain usage:** Sensitive credentials beyond auth tokens? (auto-yes if auth chosen)
- **Accessibility priority:** Standard ⭐ / High

**Each batch:** present open questions → read answers → move to resolved → surface new questions triggered by answers → update and print confidence (`Tech Confidence: XX% | Remaining: …`). At ≥90%, proceed to Section C.

**If the user says "done" before 90%:** accept it, mark remaining as **TBD** in generated files, proceed.

Then in Section C, **scaffold the standard folder structure** (Greenfield only):

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
bip/                    # Build-in-public trail — see CLAUDE.md → Build in Public
  BUILD-LOG.md
```

---

## Section B — Existing Path (code detected)

**Core principle: observe first, ask second.** Scan silently, pre-fill everything derivable, only ask about genuine gaps.

### B1 — Silent Codebase Scan
Perform all of these before presenting anything:

- **Structure:** top-level dirs; MVVM/MVC/other; presence of `App/`, `Core/`, `Features/`, `ViewComponents/`, `Resources/`; note non-standard layout.
- **Xcode project:** `*.xcodeproj`/`*.xcworkspace` → schemes, targets, bundle ID, deployment target, test targets.
- **Dependencies:** `Package.swift`, `Podfile`, `Cartfile` → list with inferred purpose.
- **Tech-stack detection** (scan imports/patterns):
  | What | How to detect |
  |------|---------------|
  | Database | `import SwiftData` / `RealmSwift` / `CoreData` |
  | Networking | `Alamofire`, `URLSession`, `Apollo` (GraphQL) |
  | Auth | `AuthenticationServices`, `FirebaseAuth`, custom auth services |
  | State mgmt | `@Observable` vs `@ObservableObject`/`@Published` vs Combine |
  | Concurrency | `async/await` vs Combine vs completion handlers |
  | Navigation | `NavigationStack`/`NavigationPath` vs `NavigationView` vs `NavigationLink(destination:)` |
  | UI framework | SwiftUI / UIKit / mixed |
  | DI | Environment vs singletons vs manual injection |
  | Offline/sync | CloudKit, sync services, `NWPathMonitor` |
  | Biometrics | `import LocalAuthentication` |
  | Push | `UNUserNotificationCenter` |
  | Analytics | Firebase Analytics, Mixpanel, custom |
  | Payments | StoreKit, RevenueCat |
  | Location | `CoreLocation`, `MapKit` |
- **Architecture patterns:** ViewModel style; business logic leaking into Views; NavigationCoordinator; service/manager layer; protocol abstractions.
- **Existing docs:** `CLAUDE.md`, `ARCHITECTURE.md`, `.claude/memory.md`, `README.md`, `docs/` — note current vs stale.
- **Git:** age (`git log --reverse --format='%ai' | head -1`), recent activity (`git log --oneline -10`), branch, uncommitted changes.
- **Quality signals:** `.swiftlint.yml`, tests, `PrivacyInfo.xcprivacy`, `.gitignore` completeness.
- **View inventory scan** (for `VIEW-INVENTORY.md`): shared components under `ViewComponents/`; feature components under `Features/*/Views/ViewComponents/`; top-level `*View` screens under `Features/*/Views/`; custom `ViewModifier`/`ButtonStyle`/`LabelStyle`/`ToggleStyle`/`TextFieldStyle`. For each capture: type name, path, public init signature, one-line purpose. Group by feature.

### B2 — Present Findings
Summarize: project (name, bundle ID, deployment target, schemes), architecture (pattern, navigation, DI), tech stack, dependencies, integrations, structure, existing docs, code quality, git state. Then ask: _"Does this look accurate? Anything I missed or got wrong?"_ Wait for confirmation.

### B3 — Fill Gaps (ask ONLY what code can't reveal)
- **Always:** Git prefix; any corrections to the scan.
- **Only if undetectable:** sync strategy (if DB found but unclear); offline support; accessibility priority (Standard/High); planned-but-not-yet-coded integrations.
- **Never ask** about anything already detected — those are settled facts.

In Section C, **do NOT scaffold folders** — document the existing structure in ARCHITECTURE.md instead. Pre-fill `VIEW-INVENTORY.md` from the B1 scan (delete example rows, populate tables). Mark generated decisions as "Observed from existing codebase" rather than "Decided." For files that already exist, present a diff and ask merge-vs-overwrite (for ADR-0001, if it exists, create ADR-0002 "Architecture Documentation Update" instead).

---

## Section C — Generate Files (both paths)

Create these from all gathered/observed facts.

### CLAUDE.md (project root)

**First line must be the iOS guide import** so the project opts into the global iOS rules:
```
@~/.claude/docs/ios/ios-guide.md
```

**`## Role`:**
```
## Role

You are a senior iOS engineer. Apply the judgment of someone who has shipped production apps for years — question requirements that conflict with platform conventions, prefer Apple-native APIs, and call out work that would not pass a senior code review.
```

**`## View Inventory`:**
```
## View Inventory

Read `VIEW-INVENTORY.md` before implementing any new View, ViewModifier, or shared UI component. If a matching component already exists, reuse or extend it. When you add, rename, or delete a shared component, update `VIEW-INVENTORY.md` in the same diff.
```

**`## Build in Public`** (Greenfield also scaffolds `bip/BUILD-LOG.md`):
```
## Build in Public

This project is built in public. The unit of capture is the **postable step** — any meaningful moment worth showing (a new screen, a fixed bug, a shipped feature, a milestone), *not* the session. One session may produce several postable steps or none; capture per step.

All build-in-public material lives in `bip/`:
- `bip/BUILD-LOG.md` — running log. Per postable step, append: date · what the step was · screenshot filename(s) · one line on the *why* / what was interesting or hard — that line is the post angle.
- `bip/screenshots/` — **1–3 screenshots per step, when the step is visual** (skip for non-visual steps). Claude captures these directly from the iOS Simulator.

**Bank for quiet days.** Building is lumpy — a heavy day yields several postable steps, a quiet day none. Capture everything as it happens and post it spread thin; never dump it all at once, never go silent because "nothing happened today."

Posting itself stays dumb-simple — one honest post, no production. `bip/` is the raw material, not a content pipeline.
```

Then project-specific config: project name, bundle ID, iOS target, git prefix, database, and a **`## Technical Decisions`** section capturing every resolved/detected choice (networking, auth, navigation, sync, offline, integrations). Mark unresolved as **TBD**. On the Existing path, note "Generated from existing codebase scan."

**If CLAUDE.md already exists:** present a diff, merge vs overwrite. When merging, ensure the import line, `## Role`, and `## View Inventory` are present.

### .claude/memory.md
Template: `~/.claude/docs/templates/project-memory-template.md`. Pre-fill Decisions with each choice:
```
- [YYYY-MM-DD] Networking: REST — standard choice for the backend API
- [YYYY-MM-DD] Auth: Apple Sign-In — simplest for iOS-only app
- [YYYY-MM-DD] Navigation: Multi-tab — 3+ distinct sections
```
Existing path: label as "Observed from existing codebase."

### ARCHITECTURE.md
Template: `~/.claude/docs/templates/architecture-template.md`. Fill navigation, networking, auth, data-storage table, third-party integrations, data-flow (sync/cache layer if relevant). Existing path: also fill dependencies table, feature-modules table, and update the system-architecture diagram to reflect actual layers. Mark unresolved sections **TBD**. If it already exists, merge vs overwrite.

### docs/decisions/ADR-0001-initial-architecture.md
Template: `~/.claude/docs/templates/adr-template.md`.
- Greenfield: Title "Initial Architecture Decisions"; Context = project goals/constraints; Decision = all resolved decisions; Consequences = pros/cons; Alternatives Considered = per core decision; Date = today.
- Existing: Title "Existing Architecture Documentation"; Context = "observed from the existing codebase and confirmed by the team"; Decision = detected choices. If ADR-0001 exists, create ADR-0002 instead.

### CHANGELOG.md
Template: `~/.claude/docs/templates/changelog-template.md`, version 0.1.0 (Greenfield) or inferred current version (Existing). Existing path: only create if missing.

### VIEW-INVENTORY.md (project root)
Copy `~/.claude/docs/templates/view-inventory-template.md`, replace `{{ProjectName}}` and `{{YYYY-MM-DD}}`.
- Greenfield: leave example rows as illustrations.
- Existing: delete example rows, populate Shared Components / Feature Components / Screens / View Modifiers & Styles from the B1 scan. Purpose ≤8 words; Key Inputs = trimmed public init params. If it exists, merge vs overwrite.

### Backlog.md (optional)
Ask if wanted. Pre-seed:
- Greenfield (from decisions): folder structure + navigation coordinator; `NetworkService` (if networking); auth flow + Keychain + biometrics (if auth); DB models + persistence (if database); sync + conflict resolution (if sync); offline cache + reachability (if offline); one task per 3rd-party integration. Place under **Features > High Priority**.
- Existing (from observed gaps): `// TODO:` comments found in code; missing test coverage; missing `PrivacyInfo.xcprivacy`; SwiftLint setup; `@ObservableObject`→`@Observable` migrations; `NavigationView`→`NavigationStack` migrations.

---

## Section D — Validate, Hint, Hand Off (both paths)

### D1 — Post-Init Validation
1. CLAUDE.md ↔ ARCHITECTURE.md — every tech decision matches.
2. CLAUDE.md ↔ ADR — decisions consistent.
3. Backlog ↔ Tech Decisions — every non-None choice / observed gap has a task.
4. memory.md — an entry per resolved/detected decision.
Fix inconsistencies silently unless genuinely ambiguous.

### D2 — Context7 & Framework Guide Hints
1. **Context7** (`resolve-library-id` → `query-docs`): fetch current setup docs for each chosen/detected 3rd-party service (RevenueCat, Firebase Auth, …). Add a note in the ADR References with the recommended version and critical setup steps. Existing path: flag dependencies that are outdated vs current.
2. **Print framework guide hints** for each technology with a matching guide:
   ```
   Relevant framework guides for your stack:
   - [Technology]: ~/.claude/docs/ios/[category]/[guide].md
   ```
   | Decision | Guide |
   |----------|-------|
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
   List only guides matching actual choices.

### D3 — Wrap Up & Handoff
- List all created/updated files and folders; note any skipped (already existed). Existing path: list detected tech-debt items.
- Suggest `git add` to stage them.
- **Offer `/ios-brief` handoff:** ask if the user wants to continue with `/ios-brief` to define scope and epics. If yes, write `docs/.ios-init-decisions.json` so the brief can read it, then invoke `/ios-brief` directly — don't ask the user to run it manually.

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

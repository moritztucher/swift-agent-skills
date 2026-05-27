---
name: ios-init-existing
description: Scan an existing iOS codebase, detect tech stack and patterns, then generate all standard documentation files (CLAUDE.md, ARCHITECTURE.md, memory, ADR) pre-filled with observed facts. Only asks about what can't be derived from code.
user_invocable: true
---

# /ios-init-existing - Initialize Documentation for Existing iOS Project

Scan an existing iOS codebase, detect the tech stack and architectural patterns, then generate all standard documentation files pre-filled with what can be observed. Only ask about what can't be derived from code.

## Core Principle

**Observe first, ask second.** Scan the entire codebase silently before presenting anything. Pre-fill everything you can. Only ask about gaps that genuinely can't be derived from reading the code.

---

## Phase 1 — Silent Codebase Scan

Perform all of these silently before presenting anything to the user:

### 1.1 Project Structure
- Scan top-level directories and key subdirectories
- Identify if it follows MVVM, MVC, or another pattern
- Check for `App/`, `Core/`, `Features/`, `ViewComponents/`, `Resources/` (standard structure)
- Note any non-standard organization

### 1.2 Xcode Project
- Find `*.xcodeproj` or `*.xcworkspace`
- Read the project file for: scheme names, targets, bundle ID, deployment target
- Check for test targets

### 1.3 Dependencies (Package.swift / Podfile / Cartfile)
- Read `Package.swift` for SPM dependencies
- Read `Podfile` if it exists
- List all 3rd-party dependencies with their purpose (infer from package name)

### 1.4 Tech Stack Detection

Scan Swift files for imports and patterns to detect:

| What | How to Detect |
|------|--------------|
| **Database** | `import SwiftData`, `import RealmSwift`, `import CoreData` |
| **Networking** | `import Alamofire`, `URLSession` usage, `import Apollo` (GraphQL) |
| **Auth** | `import AuthenticationServices` (Apple Sign-In), `import FirebaseAuth`, custom auth services |
| **State management** | `@Observable` vs `@ObservableObject`/`@Published` vs Combine |
| **Concurrency** | `async/await` vs `Combine` vs completion handlers |
| **Navigation** | `NavigationStack`/`NavigationPath` vs `NavigationView` vs `NavigationLink(destination:)` |
| **UI framework** | SwiftUI vs UIKit vs mixed |
| **DI pattern** | Environment vs singletons vs manual injection |
| **Offline/sync** | CloudKit imports, sync services, Reachability/NWPathMonitor |
| **Biometrics** | `import LocalAuthentication` |
| **Push notifications** | `UNUserNotificationCenter` usage |
| **Analytics** | Firebase Analytics, Mixpanel, custom analytics |
| **Payments** | StoreKit, RevenueCat imports |
| **Location** | `import CoreLocation`, `import MapKit` |

### 1.5 Architecture Patterns
- Check if ViewModels exist and follow `@Observable` or `@ObservableObject`
- Check if Views contain business logic (look for network calls, data manipulation in View structs)
- Check if there's a NavigationCoordinator or central navigation pattern
- Check for service/manager layer (`*Service.swift`, `*Manager.swift`)
- Check for protocol-based abstractions

### 1.6 Existing Documentation
- Check for `CLAUDE.md`, `ARCHITECTURE.md`, `.claude/memory.md`, `README.md`, `docs/` folder
- Read any that exist — note if they're current or stale

### 1.7 Git History
- Project age: `git log --reverse --format='%ai' | head -1`
- Recent activity: `git log --oneline -10`
- Current branch: `git branch --show-current`
- Uncommitted changes: `git status --short`

### 1.8 Code Quality Signals
- Check for SwiftLint config (`.swiftlint.yml`)
- Check for test files and test coverage patterns
- Check for `PrivacyInfo.xcprivacy`
- Check for `.gitignore` completeness

### 1.9 View Inventory Scan

Catalogue existing UI building blocks so they can be pre-filled into `VIEW-INVENTORY.md`:

- **Shared components:** every Swift file under `ViewComponents/` (or equivalent root-level shared UI folder)
- **Feature components:** every Swift file under `Features/*/Views/ViewComponents/`
- **Top-level screens:** Views named `*View` directly under `Features/*/Views/` (not in a `ViewComponents/` subfolder)
- **Custom modifiers/styles:** types conforming to `ViewModifier`, `ButtonStyle`, `LabelStyle`, `ToggleStyle`, `TextFieldStyle`, etc.

For each, capture: type name, file path, the public init signature (key inputs), and a one-line purpose inferred from the struct's body or any leading doc comment. Group by feature.

---

## Phase 2 — Present Findings

Present a clear summary to the user:

> "Here's what I found in the codebase..."

Include:
- **Project:** name, bundle ID, deployment target, schemes
- **Architecture:** detected pattern (MVVM/MVC/etc.), navigation approach, DI pattern
- **Tech Stack:** database, networking, auth, state management, concurrency model
- **Dependencies:** list with inferred purpose
- **3rd-party integrations:** analytics, payments, push, location, etc.
- **Project structure:** directory layout overview
- **Existing docs:** what documentation already exists
- **Code quality:** SwiftLint, tests, privacy manifest
- **Git:** age, recent activity, current state

Then ask: _"Does this look accurate? Anything I missed or got wrong?"_

Wait for the user to confirm or correct before proceeding.

---

## Phase 3 — Fill Gaps

After confirmation, ask ONLY about things that can't be observed in code:

**Always ask:**
- **Git prefix:** What prefix for commits? (e.g., P66, APP)
- **Anything the scan got wrong** — user corrections override observations

**Ask only if not detectable:**
- **Sync strategy** — if database was found but sync pattern is unclear
- **Offline support** — if unclear from code whether the app is online-only
- **Accessibility priority** — Standard or High (can't reliably detect from code)
- **Any planned integrations** — services that aren't in the code yet but are planned

**Do NOT ask about things already detected** — database, networking approach, auth, navigation pattern, etc. are settled facts from the scan.

---

## Phase 4 — Generate Files

Generate all documentation files pre-filled with observed + confirmed facts:

### CLAUDE.md (project root)

**First line must be the iOS guide import** so the project opts into the global iOS rules (the user's global `~/.claude/CLAUDE.md` is now slim and domain-agnostic):

```
@~/.claude/docs/ios/ios-guide.md
```

**Second, a `## Role` section** with the senior-engineer framing:

```
## Role

You are a senior iOS engineer. Apply the judgment of someone who has shipped production apps for years — question requirements that conflict with platform conventions, prefer Apple-native APIs, and call out work that would not pass a senior code review.
```

**Third, a `## View Inventory` section**:

```
## View Inventory

Read `VIEW-INVENTORY.md` before implementing any new View, ViewModifier, or shared UI component. If a matching component already exists, reuse or extend it. When you add, rename, or delete a shared component, update `VIEW-INVENTORY.md` in the same diff.
```

Then the project-specific config:
- Project name, bundle ID, iOS target (from scan)
- Database, networking, auth, navigation (from scan)
- Git prefix (from user)
- `## Technical Decisions` section with all detected choices
- Note: "Generated from existing codebase scan by `/ios-init-existing`"

**If CLAUDE.md already exists:** Present a diff of what would change and ask the user whether to merge (add missing sections) or overwrite. When merging, ensure the `@~/.claude/docs/ios/ios-guide.md` import is present at the top — if missing, add it. Also ensure the `## Role` and `## View Inventory` sections are present; if missing, add them.

### .claude/memory.md

Use template from `~/.claude/docs/templates/project-memory-template.md`, pre-fill Decisions section with all detected tech choices and today's date. Mark them as "Observed from existing codebase" rather than "Decided."

### ARCHITECTURE.md

Use template from `~/.claude/docs/templates/architecture-template.md`, filled with:
- Project name, database, iOS target (from scan)
- **Navigation section:** actual pattern detected
- **Networking section:** actual approach detected (REST/GraphQL, offline strategy)
- **Auth section:** actual provider detected
- **Data Storage table:** actual database and sync choices
- **Dependencies table:** all SPM/CocoaPods dependencies with purpose
- **Third-Party Integrations:** all detected services
- **Feature Modules table:** list detected feature directories with brief descriptions
- **System Architecture diagram:** update the ASCII diagram to reflect actual layers

**If ARCHITECTURE.md already exists:** Ask whether to merge or overwrite.

### docs/decisions/ADR-0001-initial-architecture.md

Generate the first ADR documenting the observed tech decisions:
- **Title:** "Existing Architecture Documentation"
- **Status:** Accepted
- **Context:** "This project was already in development. These decisions were observed from the existing codebase and confirmed by the team."
- **Decision:** All detected tech choices in a structured list
- **Date:** Today

**If ADR-0001 already exists:** Skip. Create ADR-0002 instead, titled "Architecture Documentation Update."

### CHANGELOG.md

Only create if it doesn't exist. Use template with current version (infer from project settings or ask).

### VIEW-INVENTORY.md (project root)

Copy `~/.claude/docs/templates/view-inventory-template.md` to the project root as `VIEW-INVENTORY.md`. Replace `{{ProjectName}}` and `{{YYYY-MM-DD}}` placeholders. Then **delete the example rows** and **populate the tables** from the Phase 1.9 scan:

- **Shared Components** table: every file found under `ViewComponents/`
- **Feature Components** sections: one per feature folder, listing components found under `Features/[Feature]/Views/ViewComponents/`
- **Screens** table: every top-level `*View` under `Features/*/Views/`, paired with its ViewModel if one exists
- **View Modifiers & Styles** table: every detected `ViewModifier`/`ButtonStyle`/etc.

For the **Purpose** column, infer from a leading doc comment if present, otherwise from the struct body in 8 words or fewer. For **Key Inputs**, use the public init's parameter list (trim to the most relevant 2-4 params).

**If VIEW-INVENTORY.md already exists:** Ask whether to merge (append missing components) or overwrite.

### Backlog.md (optional)

Ask if the user wants a backlog. If yes, pre-seed with obvious items observed from the codebase:
- [ ] TODOs found in code (scan for `// TODO:` comments)
- [ ] Missing test coverage for key features
- [ ] Missing `PrivacyInfo.xcprivacy` (if not found)
- [ ] SwiftLint setup (if not configured)
- [ ] Any `@ObservableObject` → `@Observable` migrations needed
- [ ] Any `NavigationView` → `NavigationStack` migrations needed

### Project Folder Structure

**Do NOT scaffold directories** — the project already has a structure. Instead, document the existing structure in ARCHITECTURE.md.

---

## Phase 5 — Post-Init Validation

Cross-reference all generated files for consistency (same as `/ios-init` Step 3):
1. CLAUDE.md ↔ ARCHITECTURE.md — tech decisions match
2. CLAUDE.md ↔ ADR — decisions documented consistently
3. Backlog ↔ Tech Decisions — tasks match observed gaps
4. memory.md — has entries for all detected decisions

Fix inconsistencies silently.

---

## Phase 6 — Context7 & Framework Guide Hints

Same as `/ios-init` Step 4:

1. **Use Context7** for any detected 3rd-party services to fetch latest docs. Note current versions vs what's in Package.swift — flag if outdated.

2. **Print framework guide hints** for each detected technology that has a matching guide in `~/.claude/docs/ios/`:

   ```
   Relevant framework guides for your stack:
   - [Technology]: ~/.claude/docs/ios/[category]/[guide].md
   ```

   Only list guides that match detected technologies.

---

## Phase 7 — Wrap Up & Handoff

After creating all files:
- List all created/updated files
- Note any files that were skipped because they already existed
- List detected tech debt items (old patterns, missing configs)
- Suggest running `git add` to stage new files
- Ask if the user wants to continue with `/project-brief-existing` to build a full project brief

**If the user says yes to project-brief:** Write `docs/.ios-init-decisions.json` (same format as `/ios-init`) so `/project-brief` can read it, then invoke `/project-brief-existing` directly.

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

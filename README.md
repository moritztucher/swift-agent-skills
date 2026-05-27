# Claude Code — iOS Setup

A curated Claude Code setup for iOS developers — skills, agents, slash commands, and configuration for shipping SwiftUI apps faster.

By **Moritz Tucher** · [GitHub](https://github.com/moritztucher) · [LinkedIn](https://www.linkedin.com/in/moritz-tucher/)

`34 skills · 4 agents · 3 hooks · 77 iOS framework guides`

---

## What this is

A working, opinionated `~/.claude/` setup focused on shipping production iOS apps with Claude Code. It encodes a full TDD-style workflow — from project brief → epic detail → preflight → TDD implement → verify — alongside specialist skills for SwiftUI craft, design audits, onboarding, paywalls, App Store optimization, and simulator automation.

It's the configuration I use day-to-day. The skills compose into pipelines (e.g. `/project-brief` → `/epic-detail` → `/preflight-check` → `/ios-implement-epic` → `/ios-verify`), but each one stands on its own. Drop into any iOS project and they pick up the local `CLAUDE.md` for context.

## What this isn't

- Not a fork of every public Claude Code skill — it's curated, not comprehensive
- Not a framework — it's a config snapshot you copy into `~/.claude/`
- Not a substitute for thinking about your architecture — the skills surface decisions, you still make them
- Not affiliated with Anthropic — Claude Code is Anthropic's product; this repo provides community-contributed configuration

---

## Installation

```bash
# 1. Clone into a working directory
git clone https://github.com/moritztucher/claude-code-ios-setup.git
cd claude-code-ios-setup

# 2. Back up anything you already have
[ -d ~/.claude/skills ] && mv ~/.claude/skills ~/.claude/skills.backup
[ -d ~/.claude/agents ] && mv ~/.claude/agents ~/.claude/agents.backup
[ -d ~/.claude/docs ] && mv ~/.claude/docs ~/.claude/docs.backup
[ -d ~/.claude/hooks ] && mv ~/.claude/hooks ~/.claude/hooks.backup

# 3. Drop the pieces in
mkdir -p ~/.claude
cp -R skills ~/.claude/
cp -R agents ~/.claude/
cp -R docs ~/.claude/
cp -R hooks ~/.claude/
chmod +x ~/.claude/hooks/*.sh

# 4. Optional: copy the global CLAUDE.md (won't overwrite existing without `-i`)
cp -i CLAUDE.md ~/.claude/CLAUDE.md

# 5. Optional: copy settings.json (review first — it enables specific plugins and hooks)
cp -i settings/settings.json.example ~/.claude/settings.json
cp -i statusline-command.sh ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
```

To opt a project into the iOS guide, add this as the first line of the project's `CLAUDE.md`:

```
@~/.claude/docs/ios/ios-guide.md
```

`/ios-init` and `/ios-init-existing` add this automatically when they scaffold a new project's `CLAUDE.md`.

---

## Skills

### iOS development workflow

| Skill | What it does |
|-------|--------------|
| `/load-ios` | Load the iOS guide into an ad-hoc chat that has no project `CLAUDE.md` |
| `/ios-init` | Scaffold a new iOS project: `CLAUDE.md`, memory, architecture doc, first ADR, changelog |
| `/ios-init-existing` | Scan an existing iOS codebase and generate the same docs pre-filled with observed facts |
| `/project-brief` | Build a structured project brief through guided Q&A |
| `/project-brief-existing` | Same, but pre-fills from an existing codebase first |
| `/epic-detail` | Expand a brief epic into an implementation doc with [UI]/[UX]/[ARCH] questions |
| `/preflight-check` | Cross-validate brief + epics for contradictions and missing dependencies |
| `/ios-implement-epic` | Full TDD epic delivery — write XCTests, implement, verify ACs, fix gaps |
| `/ios-verify` | Run XCTests, map to epic ACs, produce coverage matrix + gap report |
| `/ios-build` | Build the Xcode project and report results |
| `/ios-test` | Run unit and UI tests |
| `/ios-commit` | Create a well-formed commit following project conventions |
| `/ios-review` | Thorough code review on changes or specified files |
| `/ios-audit` | Holistic project audit through PM, UX, UI, ARCH lenses |
| `/ios-agents` | List all available subagents |
| `axe` | iOS Simulator automation via the AXe CLI — tap, swipe, type, screenshot, video |

### Design + UX

| Skill | What it does |
|-------|--------------|
| `/ios-design-brief` | Establish a project-wide design system through iterative in-document Q&A |
| `/ios-design-audit` | Visual craft audit — color, typography, motion, hierarchy — with elevation suggestions |
| `/ios-design-elevate` | Implement design elevation across an app, view by view, without touching business logic |
| `/ios-onboarding-audit` | Audit (or design from scratch) an onboarding flow for activation psychology and time-to-value |
| `/onboarding-cro` | Optimize post-signup onboarding and first-run experience |
| `/paywall-upgrade-cro` | Create or optimize in-app paywalls, upgrade screens, and feature gates |

### App Store

| Skill | What it does |
|-------|--------------|
| `/aso-audit` | Audit an App Store or Google Play listing against competitors |
| `/aso-review` | Review an active Apple Search Ads campaign and suggest next-week adjustments |
| `/appstore-whatsnew` | Summarize git commits between two version tags into a paste-ready release note |

### SwiftUI + Swift craft

| Skill | What it does | Source |
|-------|--------------|--------|
| `swiftui-pro` | Comprehensive SwiftUI code review — modern APIs, performance, accessibility | [Paul Hudson](https://www.hackingwithswift.com/) (MIT) |
| `swift-concurrency` | Diagnose concurrency issues, refactor to async/await, guide Swift 6 migration | Community |

### Git + PR workflow

| Skill | What it does |
|-------|--------------|
| `/pr-to-develop` | Create a PR from current branch into develop with a structured template |
| `/pr-to-main` | Create a release PR from develop into main |

### Meta + productivity

| Skill | What it does |
|-------|--------------|
| `/compact-summary` | Compress the current session into a reusable context primer for the next chat |
| `/skill-creator` | Create, edit, optimize, and evaluate skills |
| `/mcp-builder` | Guide for building high-quality MCP servers in Python or TypeScript |
| `/doc-coauthoring` | Structured workflow for co-authoring docs, specs, and proposals |
| `/init-custom` | Initialize a non-iOS project with the standard doc set |

---

## Agents

Specialists invoked via the Task tool from inside skills. They advise; the parent decides.

| Agent | Role |
|-------|------|
| `ios-onboarding-advisor` | Onboarding strategy — activation psychology, permission timing, progressive disclosure |
| `ios-ux-advisor` | UX patterns, HIG compliance, component choices, interaction flow |
| `ios-ui-design-advisor` | Visual craft — color, typography, motion, hierarchy, emotional design |
| `context7-docs-writer` | Generates framework integration docs using Context7's live library data |

---

## Hooks

Shell hooks that run automatically. Configured in `settings/settings.json.example`.

| Hook | When | What it does |
|------|------|--------------|
| `swiftlint-autofix.sh` | After every Edit/Write to a `.swift` file | Runs `swiftlint lint --fix` quietly |
| `notify-done.sh` | When Claude stops | macOS notification with the Glass sound |
| `definition-of-done.sh` | On task completion | Builds the Xcode project, runs tests, checks SwiftLint — blocks completion if any fails |

---

## iOS framework guides

77 reference guides under `docs/ios/`, organized by domain:

- **swiftui/** — Liquid Glass adoption, AttributedString, TipKit, Charts, performance, webview, design craft patterns
- **appkit/** — AppKit guide, AppKit Liquid Glass
- **data/** — SwiftData, Core Spotlight, CloudKit, RealmSwift
- **commerce/** — StoreKit, RevenueCat (incl. iOS 26 paywall fix), PassKit, Firebase
- **system/** — WidgetKit, ActivityKit, AppIntents, AlarmKit, BackgroundTasks, UserNotifications, HealthKit, MapKit, CarPlay, AuthenticationServices, EventKit, Contacts, PhotosUI, CoreLocation, MessageUI, SafariServices, Translation, RelevanceKit, PermissionKit, IdentityDocumentServices, DeclaredAgeRange, GameSave, PaperKit, AlarmKit, AVFoundation, Span/InlineArray, LocalAuthentication
- **hardware/** — CoreBluetooth, WiFi Aware, AccessorySetupKit, CoreHaptics, WatchConnectivity, EnergyKit
- **screen-time/** — Screen Time API, DeviceActivity, FamilyControls, ManagedSettings
- **ai/** — Foundation Models, CoreML, Speech Analyzer, Visual Intelligence
- **rules/** — Architecture, ViewModels, SwiftUI Views, SwiftUI patterns, Swift style, security, testing

Plus the top-level `ios-guide.md` (the consolidated entry point loaded via `@import`) and `ios-coding-standards.md` / `architecture-patterns.md` reference docs.

---

## Templates

`docs/templates/` contains the doc skeletons used by `/ios-init`, `/epic-detail`, and the brief workflow:

- `project-brief-template.md`
- `architecture-template.md`
- `epic-detail-template.md`
- `adr-template.md`
- `backlog-template.md`
- `changelog-template.md`
- `design-system-template.md`
- `view-inventory-template.md`
- `preflight-report-template.md`
- `project-memory-template.md`

---

## Architecture

The setup splits into three layers:

1. **Skills** are slash-commands the user invokes (`/ios-init`, `/aso-audit`, etc.). Each is a `SKILL.md` with frontmatter and instructions. Some have evals (`evals/evals.json`) for measuring trigger accuracy.
2. **Agents** are specialists Claude spawns via the Task tool. They have a narrower scope and toolset than the main thread. Skills like `/ios-design-audit` and `/ios-onboarding-audit` spawn the design and onboarding advisors for parallel analysis.
3. **Docs + templates** are the reference layer. The iOS guide loads via `@~/.claude/docs/ios/ios-guide.md` in a project's `CLAUDE.md`. Framework guides are read on demand. Templates feed `/ios-init` and `/epic-detail`.

The workflow composes left-to-right: brief → epic detail → preflight → TDD implement → verify → commit → PR. Each step writes a deliverable to `docs/` in the project so the next step has structured input.

---

## Requirements

- macOS (some hooks use `osascript` and `xcodebuild`)
- [Claude Code](https://docs.claude.com/claude-code) installed and authenticated
- Xcode and `xcodebuild` on PATH for iOS skills
- `swiftlint` (optional, for the autofix hook)
- [AXe](https://github.com/cameroncooke/AXe) CLI (optional, for the `axe` simulator-automation skill)
- `gh` CLI (optional, for PR-creation skills)

---

## Disclaimer

Not affiliated with Anthropic. Claude Code is Anthropic's product; this repo provides community-contributed skills and configuration. `swiftui-pro` is reproduced under its MIT license — full attribution in the skill's frontmatter.

---

## License

MIT — see [LICENSE](LICENSE).

---

By [Moritz Tucher](https://github.com/moritztucher) · iOS developer building for the App Store with AI-native workflows. Connect on [LinkedIn](https://www.linkedin.com/in/moritz-tucher/).

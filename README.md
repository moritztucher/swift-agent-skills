# Claude Code — iOS Setup

A curated Claude Code setup for iOS developers — skills, agents, slash commands, and configuration for shipping SwiftUI apps faster.

By **Moritz Tucher** · [GitHub](https://github.com/moritztucher) · [LinkedIn](https://www.linkedin.com/in/moritz-tucher/)

`22 skills · 4 agents · 3 hooks · 77 iOS framework guides`

---

## What this is

A working, opinionated `~/.claude/` setup focused on shipping production iOS apps with Claude Code. It encodes a light, **UI-first** workflow across five phases — **Setup → Plan → Build → Verify → Ship** — alongside specialist skills for SwiftUI craft, design audits, onboarding, and simulator automation. Plan with a living brief, build the flow before the logic, ship.

It's the configuration I use day-to-day. The skills compose into one pipeline (`/ios-init` → `/ios-brief` → build features UI-first → `/ios-review` → `/ios-commit` → `/pr-to-develop`), but each one stands on its own. Not sure what to run next? Type **`/ios`** — the orchestrator detects where your project is and routes you to the right step. Drop into any iOS project and they pick up the local `CLAUDE.md` for context.

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

`/ios-init` adds this automatically when it scaffolds a project's `CLAUDE.md` (it auto-detects new vs. existing codebases).

---

## Skills

The 26 skills group into the lifecycle phases. **`/ios` is the front door** — run it to see where a project is and what to do next.

### Setup

| Skill | What it does |
|-------|--------------|
| `/ios` | Orchestrator — detects project state, shows a status map, routes to the next step |
| `/ios-load` | Load the iOS guide into an ad-hoc chat that has no project `CLAUDE.md` |
| `/ios-init` | Initialize a project — describe it in a few sentences, then it generates the doc set + `.gitignore`, `LICENSE`, `README`. Auto-detects new / fresh-scaffold / existing and asks only about gaps |

### Plan

| Skill | What it does |
|-------|--------------|
| `/ios-brief` | Build & maintain the living project brief — features split into UI + Logic/Backend, MVP vs Later (draft-first; reads the init description) |
| `/ios-design-brief` | Establish the visual design system — looks at the running app, proposes a direction in chat, writes implementable specs |

Then **build features UI-first** — write the UI layer so the flow feels good, then layer in logic & backend — using the Build tools below.

### Build

| Skill | What it does |
|-------|--------------|
| `/ios-design-elevate` | Apply the design system view by view, verifying each screen visually (build → screenshot → compare → iterate); never touches business logic |
| `/ios-build` | Build the Xcode project and report results |
| `/ios-test` | Run unit and UI tests |
| `/ios-automate` | iOS Simulator automation via the AXe CLI — tap, swipe, type, screenshot, video |

### Verify

| Skill | What it does |
|-------|--------------|
| `/ios-review` | Thorough code review on changes or specified files |
| `/ios-audit` | Holistic project audit through PM, UX, UI, ARCH lenses |
| `/ios-design-audit` | Visual craft audit — screenshots the running app and judges the real screens — with severity-rated findings + elevation suggestions |
| `/ios-onboarding-audit` | Audit (or design from scratch) an onboarding flow for activation psychology and time-to-value |

### Ship

| Skill | What it does |
|-------|--------------|
| `/ios-commit` | Create a well-formed commit following project conventions |
| `/pr-to-develop` | Create a PR from current branch into develop with a structured template |
| `/pr-to-main` | Create a release PR from develop into main |
| `/ios-release-notes` | Summarize git commits between two version tags into a paste-ready App Store "What's New" |

### SwiftUI + Swift craft (model-invoked)

These trigger automatically while you read, write, or review SwiftUI and concurrency code — they aren't part of the linear path.

| Skill | What it does | Source |
|-------|--------------|--------|
| `swiftui-pro` | Comprehensive SwiftUI code review — modern APIs, performance, accessibility | [twostraws/SwiftUI-Agent-Skill](https://github.com/twostraws/SwiftUI-Agent-Skill) (Paul Hudson, MIT) |
| `swiftui-expert-skill` | SwiftUI guidance incl. iOS 26 Liquid Glass + Instruments `.trace` analysis | [AvdLee/SwiftUI-Agent-Skill](https://github.com/AvdLee/SwiftUI-Agent-Skill) (Antoine van der Lee) |
| `swift-concurrency` | Diagnose concurrency issues, refactor to async/await, guide Swift 6 migration | [AvdLee/Swift-Concurrency-Agent-Skill](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill) (Antoine van der Lee) |

### Meta

| Skill | What it does |
|-------|--------------|
| `/ios-agents` | List all available subagents |
| `/compact-summary` | Compress the current session into a reusable context primer for the next chat |

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

`docs/templates/` contains the doc skeletons used by `/ios-init` and `/ios-brief`:

- `project-brief-template.md`
- `architecture-template.md`
- `adr-template.md`
- `backlog-template.md`
- `changelog-template.md`
- `design-system-template.md`
- `view-inventory-template.md`
- `project-memory-template.md`

---

## Architecture

The setup splits into three layers:

1. **Skills** are slash-commands the user invokes (`/ios-init`, `/ios-brief`, etc.), grouped by lifecycle phase (Setup → Plan → Build → Verify → Ship). Each is a `SKILL.md` with frontmatter and instructions. `/ios` is the orchestrator that reads project state and routes to the right phase. Some skills carry evals (`evals/evals.json`) for measuring trigger accuracy.
2. **Agents** are specialists Claude spawns via the Task tool. They have a narrower scope and toolset than the main thread. Skills like `/ios-design-audit` and `/ios-onboarding-audit` spawn the design and onboarding advisors for parallel analysis.
3. **Docs + templates** are the reference layer. The iOS guide loads via `@~/.claude/docs/ios/ios-guide.md` in a project's `CLAUDE.md`. Framework guides are read on demand. Templates feed `/ios-init` and `/ios-brief`.

The workflow composes left-to-right: init → brief → build features UI-first → review → commit → PR. The brief is a living source of truth — it decomposes each feature into a UI layer and a Logic & Backend layer so you can build the flow before the logic. `/ios` reads project state and points you to the next step.

---

## Requirements

- macOS (some hooks use `osascript` and `xcodebuild`)
- [Claude Code](https://docs.claude.com/claude-code) installed and authenticated
- Xcode and `xcodebuild` on PATH for iOS skills
- `swiftlint` (optional, for the autofix hook)
- [AXe](https://github.com/cameroncooke/AXe) CLI (optional, for the `/ios-automate` simulator-automation skill)
- `gh` CLI (optional, for PR-creation skills)

---

## Disclaimer

Not affiliated with Anthropic. Claude Code is Anthropic's product. Third-party skills are reproduced under their own licenses with full attribution in each skill's frontmatter — `swiftui-pro` from [Paul Hudson](https://github.com/twostraws/SwiftUI-Agent-Skill) (MIT), `swiftui-expert-skill` and `swift-concurrency` from [Antoine van der Lee](https://github.com/AvdLee).

---

## License

MIT — see [LICENSE](LICENSE).

---

By [Moritz Tucher](https://github.com/moritztucher) · iOS developer building for the App Store with AI-native workflows. Connect on [LinkedIn](https://www.linkedin.com/in/moritz-tucher/).

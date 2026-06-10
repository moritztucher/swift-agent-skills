# Swift Agent Skills

Currency-checked agent skills for shipping **SwiftUI** apps — a SwiftUI-first lifecycle, craft specialists, and Apple-framework experts. **SwiftUI-first, not UIKit.** Built for Claude Code; installs into any [Agent Skills](https://agentskills.io)–compatible agent.

By **Moritz Tucher** · [GitHub](https://github.com/moritztucher) · [LinkedIn](https://www.linkedin.com/in/moritz-tucher/)

`68 skills · 4 agents · 4 hooks · 3 iOS reference guides`

---

## What this is

A working, opinionated `~/.claude/` setup focused on shipping production **SwiftUI** apps with Claude Code. It's SwiftUI-first throughout — views are SwiftUI, state is `@Observable`, navigation is `NavigationStack`; UIKit/AppKit appear only where you genuinely must bridge (a few system pickers, AppKit for macOS targets). It encodes a light, **UI-first** workflow across five phases — **Setup → Plan → Build → Verify → Ship** — alongside specialist skills for SwiftUI craft, design audits, onboarding, and simulator automation. Plan with a living brief, build the flow before the logic, ship.

It's built around the mistakes Claude makes on iOS by default — and corrects them. It won't nest a `NavigationStack` inside another `NavigationStack` and break your back button. It reaches for `@Observable` instead of `@Published` / `ObservableObject`, because it's 2026. It won't ship a tappable control without an `.accessibilityLabel`. The taste is baked into the skills, not bolted on after.

It's the configuration I use day-to-day. The skills compose into one pipeline (`/ios-init` → `/ios-brief` → build features UI-first → `/ios-review` → `/ios-commit` → `/pr-to-develop`), but each one stands on its own. Not sure what to run next? Type **`/ios`** — the orchestrator detects where your project is and routes you to the right step. Drop into any iOS project and they pick up the local `CLAUDE.md` for context.

## What this isn't

- Not a UIKit toolkit — it's **SwiftUI-first**; UIKit only shows up where you must bridge (MessageUI, PhotosPicker, etc.), and AppKit only for macOS
- Not a fork of every public Claude Code skill — it's curated, not comprehensive
- Not a framework — it's a config snapshot you copy into `~/.claude/`
- Not a substitute for thinking about your architecture — the skills surface decisions, you still make them
- Not affiliated with Anthropic — Claude Code is Anthropic's product; this repo provides community-contributed configuration

---

## Installation

Fastest path — install the skills + agents as a Claude Code plugin:

```bash
/plugin marketplace add moritztucher/swift-agent-skills
/plugin install swift-skills@swift-agent-skills
```

These skills follow the open [Agent Skills](https://agentskills.io) format (a `SKILL.md` per skill + `references/`), so they also install into any other skills-compatible agent — Cursor, Codex, Gemini CLI, Kiro, and [others](https://agentskills.io/clients) — via the community CLI:

```bash
npx skills add moritztucher/swift-agent-skills
```

The Claude plugin path gives you the 68 skills and 4 agents, namespaced under the plugin. For the **full setup** — skills, agents, the framework reference guides (loaded via `@import`), the hooks, and the example settings — one command drops the pieces into `~/.claude/`, backing up anything already there:

```bash
npx swift-agent-skills
```

It never overwrites an existing `CLAUDE.md`, `settings.json`, or `statusline-command.sh`; run with `--dry-run` to preview, or `--yes` to skip the prompt. Prefer to do it by hand? The equivalent manual steps:

```bash
# 1. Clone into a working directory
git clone https://github.com/moritztucher/swift-agent-skills.git
cd swift-agent-skills

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

### Skill context budget (Claude Code)

Claude Code lists every skill's name + description in context, but caps the listing at ~1% of the context window (`skillListingBudgetFraction`, default `0.01`) — with 68 skills that budget overflows, and descriptions of less-used skills get silently dropped (names stay). Rather than raising the budget and paying ~10k tokens in every session, `settings.json.example` ships a curated `skillOverrides` block:

- **49 skills are deliberately `"name-only"`** — their names are framework-literal triggers (`healthkit`, `storekit`, `widgetkit`, the explicitly-invoked `/ios-*` workflow skills, …), so the description adds little at listing time. They still auto-trigger on framework mentions and load their full content on invocation.
- **19 skills keep full descriptions** — the ones whose triggers are indirect: "Live Activity" → `activitykit`, "glass effect / iOS 26 design language" → `liquid-glass`, "Sign in with Apple" / "passkeys" → `authenticationservices`, "Face ID" → `localauthentication`, "Apple Pay" → `passkit`, "Siri/Shortcuts" → `appintents`, "OCR / Live Text" → `visual-intelligence`, plus the routing/disambiguation skills (`storekit` vs `revenuecat`, `cloudkit` vs `swiftdata`, `reactivity`, `controls-controlwidget`, …). These now fit comfortably inside the default budget.

A skill-routing rule in `AGENTS.md` backs this up: before implementing any Apple framework feature, the agent checks the catalog for a matching specialist by name. Run `/doctor` to verify no descriptions are truncated. If you'd rather keep every description in context, delete the `skillOverrides` block and set `"skillListingBudgetFraction": 0.05` instead.

To opt a project into the iOS guide, add this as the first line of the project's `CLAUDE.md`:

```
@~/.claude/docs/ios/ios-guide.md
```

`/ios-init` adds this automatically when it scaffolds a project's `CLAUDE.md` (it auto-detects new vs. existing codebases).

### Non-Claude users (Codex, Cursor, Gemini CLI, Kiro, …)

The skill catalog is fully portable — install it on any [Agent Skills](https://agentskills.io/clients)–compatible agent:

```bash
npx skills add moritztucher/swift-agent-skills
```

What you get, and what's Claude-enhanced:

- **All 68 skills work everywhere** — they're plain `SKILL.md` + `references/` in the open Agent Skills format, including the `/ios-*` workflow and every framework specialist.
- **House rules:** Claude Code loads them via `@import`; on other agents, copy [`AGENTS.md`](AGENTS.md) from this repo into your iOS project root — it carries the same stack, architecture, style, security, and testing rules in the agent-neutral `AGENTS.md` convention.
- **Advisor guidance** (UX, UI design, onboarding, docs-writing) ships in both forms: as Claude subagents in `agents/` and as portable skills (`ios-ux-advisor`, `ios-ui-design-advisor`, `ios-onboarding-advisor`, `context7-docs-writer`) that any client can invoke.
- **The fan-out skills degrade gracefully** — `/ios-audit`, `/ios-design-audit`, `/ios-onboarding-audit`, `/ios-design-elevate` spawn parallel advisor subagents on Claude Code; on agents without subagent support they run the same advisor passes inline. Same findings, sequential instead of parallel.
- **Hooks:** `swiftlint-autofix` is also available as a standard git pre-commit hook (`hooks/pre-commit.swiftlint`) — see [Hooks](#hooks). `notify-done.sh` and the `settings.json` wiring are Claude-specific.

**Kiro CLI caveat — auto-activation is not at parity.** The skill descriptions are already written as trigger lists, but Kiro's automatic skill loading is best-effort: it matches your request against skill descriptions once, with nothing forcing the model to act on a match, and with 68 skills in the catalog relevance dilutes. Also, only Kiro's *default* agent auto-loads skills at all — custom agents must list each skill explicitly as a `skill://` resource. Two mitigations:

1. **Invoke skills explicitly** when it matters: `/activitykit`, `/ios-review`, etc. Treat auto-activation as a convenience, not a guarantee.
2. **Add a router steering rule** so Kiro checks the catalog before writing framework code. Save as `.kiro/steering/skill-router.md`:

   ```markdown
   ---
   inclusion: always
   ---

   Before implementing or reviewing any iOS framework feature (Live Activities,
   widgets, HealthKit, StoreKit, App Intents, …), check the installed skills for
   a matching specialist and load it first. Prefer a loaded skill over answering
   from memory.
   ```

---

## Skills

The 68 skills group into the lifecycle phases. **`/ios` is the front door** — run it to see where a project is and what to do next.

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
| `/ios-automate` | iOS Simulator automation via the AXe CLI — tap, swipe, type, screenshot, video |

Building and testing run through `xcodebuild` directly — no wrapper skill needed.

### Verify

| Skill | What it does |
|-------|--------------|
| `/ios-review` | Thorough code review on changes or specified files |
| `/ios-audit` | Holistic project audit through PM, UX, ARCH lenses (code evidence; visual craft → `/ios-design-audit`) |
| `/ios-design-audit` | Visual craft audit — screenshots the running app and judges the real screens — with severity-rated findings + elevation suggestions |
| `/ios-onboarding-audit` | Walk the real onboarding flow in the simulator (or design one from scratch) — activation psychology, permission timing, measured time-to-value |

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
| `swiftui-pro` | Comprehensive SwiftUI code review — modern APIs, performance, accessibility. Majority based on Paul Hudson's skill, with reference-guide additions (performance, Liquid Glass design, previews) by the repo author | [twostraws/SwiftUI-Agent-Skill](https://github.com/twostraws/SwiftUI-Agent-Skill) (Paul Hudson, MIT; adapted) |
| `swiftui-tabview` | iOS 26 TabView — value-based `Tab`/`TabSection`, sidebar-adaptable, bottom accessory, minimize behavior, `.search` tab, customization | Moritz Tucher |
| `swiftui-toolbar` | The toolbar system — `ToolbarItem`/`Group`, all placements, `ToolbarSpacer`, iOS 26 shared glass + `sharedBackgroundVisibility` | Moritz Tucher |
| `keyboard-accessory` | A view docked above the keyboard — input accessory bars and a custom IME candidate strip (matcher / strip / wiring) | Moritz Tucher |
| `swiftui-expert-skill` | SwiftUI guidance incl. iOS 26 Liquid Glass + Instruments `.trace` analysis | [AvdLee/SwiftUI-Agent-Skill](https://github.com/AvdLee/SwiftUI-Agent-Skill) (Antoine van der Lee) |
| `swift-concurrency` | Diagnose concurrency issues, refactor to async/await, guide Swift 6 migration | [AvdLee/Swift-Concurrency-Agent-Skill](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill) (Antoine van der Lee) |
| `swift-testing` | Swift Testing — `@Test`/`#expect`/`#require`/`@Suite`, parameterized + async tests, XCTest migration | Moritz Tucher |
| `reactivity` | Combine vs Observation vs async — `@Observable`, `@Published`, publishers, cancellable lifecycle, migration | Moritz Tucher |

### Framework & engineering (model-invoked)

These trigger on framework and workflow keywords while you build. Each bundles a lean decision layer — numbered dials, an anti-rationalization table, and a pre-ship verification gate — over a deep API reference in the skill's `references/`. All currency-checked against Apple/vendor docs via Context7.

| Skill | Triggers on |
|-------|-------------|
| `storekit` | in-app purchase, IAP, subscription, StoreKit, Transaction, entitlement |
| `revenuecat` | RevenueCat, paywall, offerings, entitlements, Purchases SDK |
| `widgetkit` | widget, home/lock screen widget, WidgetKit, TimelineProvider, interactive widget |
| `liquid-glass` | Liquid Glass, glass effect, `glassEffect`, iOS 26 glass material |
| `foundation-models` | on-device AI, Apple Intelligence, Foundation Models, guided generation, `@Generable` |
| `appintents` | Siri, Shortcuts, App Intents, AppShortcut, AppEntity |
| `swiftdata` | SwiftData, persistence, `@Model`, `@Query`, Core Data migration |
| `activitykit` | Live Activity, Dynamic Island, ActivityKit |
| `backgroundtasks` | background refresh, BGTask, background processing |
| `watchconnectivity` | Apple Watch, watchOS, WCSession, paired device |
| `usernotifications` | push/local notification, UNUserNotificationCenter, APNs, badge |
| `healthkit` | HealthKit, health data, workout, steps, heart rate |
| `cloudkit` | CloudKit, CKRecord, iCloud sync, private database, CKShare |
| `corelocation` | Core Location, CLLocationManager, GPS, geofencing, location permission |
| `corebluetooth` | Core Bluetooth, BLE, CBCentralManager, peripheral, characteristic |
| `authenticationservices` | Sign in with Apple, passkeys, ASWebAuthenticationSession, OAuth |
| `localauthentication` | Face ID, Touch ID, biometrics, LAContext, app lock |
| `tipkit` | TipKit, tips, feature discovery, `popoverTip` |
| `swift-charts` | Swift Charts, chart, graph, data visualization, `BarMark` |
| `coreml` | Core ML, on-device inference, `.mlmodel`, MLModel, Vision model |
| `mapkit` | MapKit, map, Marker, MapCameraPosition, MKLocalSearch, geocoding |
| `avfoundation-audio` | audio playback/recording, AVAudioSession, AVAudioEngine, microphone |
| `attributed-string` | AttributedString, rich/styled text, AttributeContainer, Markdown |
| `swiftui-webview` | WebView, WKWebView, WebPage, embed web content, JS bridge |
| `translation` | Translation, translate text, TranslationSession, on-device translation |
| `alarmkit` | AlarmKit, alarm, timer, scheduled alert (iOS 26) |
| `speech-analyzer` | speech to text, transcription, SpeechAnalyzer, SpeechTranscriber (iOS 26) |
| `visual-intelligence` | Visual Intelligence, visual/camera search, semantic content (iOS 26) |
| `passkit` | PassKit, Apple Wallet pass, PKPass, Apple Pay, PKPaymentRequest |
| `firebase` | Firebase, Firestore, Auth, Cloud Messaging, Crashlytics (Google SDK) |
| `realmswift` | Realm, RealmSwift, `@Persisted`, object database (third-party) |
| `screen-time` | Screen Time, parental controls, app limits, FamilyControls, ManagedSettings, DeviceActivity, shield |
| `privacy-manifest` | PrivacyInfo.xcprivacy, required-reason API, App Store privacy rejection |
| `oslog-logging` | OSLog/Logger, structured logging, signposts, MetricKit observability |
| `universal-links` | universal links, associated domains, apple-app-site-association, deep linking |
| `avkit-videoplayer` | video playback, VideoPlayer, AVPlayer, HLS streaming, Picture in Picture |
| `pencilkit` | PencilKit, PKCanvasView, drawing, Apple Pencil, ink, PKDrawing |
| `core-motion` | Core Motion, accelerometer, gyroscope, device motion, pedometer, step count |
| `controls-controlwidget` | Control Center / Lock Screen control, ControlWidget, Action Button (iOS 18) |
| `app-store-submission` | archive/export/upload, `xcodebuild exportArchive`, TestFlight, code signing, review rejection |

### Meta

| Skill | What it does |
|-------|--------------|
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

Each advisor also ships as a portable skill of the same name (`skills/ios-ux-advisor/`, etc.), so non-Claude agents get the same lenses — the audit skills fall back to running them inline when no subagent support exists.

---

## Hooks

Shell hooks that run automatically. The first two are wired up in `settings/settings.json.example`; `definition-of-done.sh` ships ready to use but is **opt-in** (not enabled in the example — add it as a `Stop` hook if you want it).

| Hook | When | What it does | In example? |
|------|------|--------------|-------------|
| `swiftlint-autofix.sh` | After every Edit/Write to a `.swift` file | Runs `swiftlint lint --fix` quietly | ✅ |
| `notify-done.sh` | When Claude stops | macOS notification with the Glass sound | ✅ |
| `definition-of-done.sh` | On stop (if wired) | Builds the Xcode project and checks SwiftLint — blocks completion if either fails (tests stay in CI) | ⬜️ opt-in |

**Portable variant:** `pre-commit.swiftlint` is a tool-agnostic **git pre-commit hook** with the same lint-fix behavior — it runs `swiftlint --fix` on staged Swift files and re-stages them, so non-Claude users (or anyone who prefers commit-time fixing) get the same result without Claude's hook system. Install per project:

```bash
cp hooks/pre-commit.swiftlint /path/to/project/.git/hooks/pre-commit
chmod +x /path/to/project/.git/hooks/pre-commit
```

`notify-done.sh` and `definition-of-done.sh` depend on Claude Code's Stop event and have no portable equivalent.

---

3 reference guides under `docs/ios/`. All framework depth lives in the **framework-integration skills** above (each skill's `references/`), and the SwiftUI craft guides folded into `swiftui-pro`; what remains is the house-rules layer:

- `ios-guide.md` — the consolidated entry point a project loads via `@import`
- `ios-coding-standards.md` and `architecture-patterns.md` — the standards and architecture references it links

---

## Templates

`docs/templates/` contains the doc skeletons used by `/ios-init` and `/ios-brief`:

- `project-brief-template.md`
- `architecture-template.md`
- `adr-template.md`
- `changelog-template.md`
- `design-system-template.md`
- `view-inventory-template.md` (optional — projects opt in via `/ios-init`)

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

By [Moritz Tucher](https://github.com/moritztucher) · ~3 years shipping production iOS apps to the App Store, now building AI-native iOS workflows. Connect on [LinkedIn](https://www.linkedin.com/in/moritz-tucher/).

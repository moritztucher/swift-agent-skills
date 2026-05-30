---
name: ios-brief
description: Collaboratively build a structured project brief before implementation begins. Detects whether the project already has code — for a fresh project it runs a guided conversation; for an existing codebase it explores first, pre-fills what it observes, and asks only about gaps. Writes docs/PROJECT-BRIEF.md.
user_invocable: true
---

# /ios-brief — Project Brief

Help the user create a comprehensive project brief. Your role is purely documentary — ask questions, capture answers, produce a structured markdown brief. **No code, no implementation, no assumptions about intent.**

> **Next step:** once the brief is written, hand off to `/ios-epic <n>` to expand each epic into an implementation doc. This skill points there at the end.

## Rules

- **Never assume** — always ask. For existing code, observe structure but ask about purpose; never infer intent from code.
- **No implementation, no code changes** — this is a brief only.
- **One topic at a time** — confirm understanding before moving on.
- **Track confidence internally** — keep going until ~90% confidence in the project outline, or the user says "done".
- **Follow the natural conversation** — the topic order is a guide, not a rigid script.
- **Pre-filled sections are proposals** — mark them "Observed from codebase" / "Decided during init" and get confirmation.

---

## Step 0 — Detect Mode & Handoffs

1. **Check for `/ios-init` handoff:** if `docs/.ios-init-decisions.json` exists, read it and pre-fill into working context:
   - **The `description` blurb** — the user already described the project to `/ios-init`. Use it to draft the **elevator pitch**, and to seed the **Problem Statement**, **Target Users** (from `audience`: B2C/B2B/internal), and **MVP Scope**. Present these as "Here's what I took from your earlier description — correct or expand?" rather than asking from scratch.
   - **Technical Requirements** (platforms, database, networking, auth, navigation, sync, offline, integrations) and **Non-Functional** (accessibility, biometrics, keychain). Present as "Already decided during project setup" and confirm.
   - Do **not** re-ask anything the description or decisions already answered — only fill gaps and go deeper where the brief needs more than init captured.
2. **Detect existing code:** look for `*.xcodeproj`/`*.xcworkspace`/`Package.swift`/`*.swift`.
   - **Code found → Existing path** (run Phase E1 exploration first).
   - **No code → Fresh path** (skip straight to the conversation).

Both paths share the same topic set and the same write step.

---

## Phase E1 — Codebase Exploration (Existing path only, silent)

Do all of this before presenting anything:

1. **Structure** — top-level dirs and key subdirectories.
2. **Tech stack** — languages, frameworks, dependencies from manifests (`Package.swift`, `Podfile`, etc.).
3. **Existing features** — infer from file/folder names, view files, route definitions, model names, test files.
4. **Existing docs** — `README.md`, `ARCHITECTURE.md`, `CLAUDE.md`, `docs/`, ADRs, changelogs.
5. **Git history** — age (`git log --reverse --format='%ai' | head -1`), recent activity (`git log --oneline -10`), contributors (`git shortlog -sn --no-merges | head -5`).
6. **Current state** — TODOs, WIP branches, broken/disabled tests.

Then **present findings**: structure, tech stack (with versions if visible), existing features (grouped), existing docs, project age & activity. Ask: _"Does this look accurate? Anything I missed or got wrong?"_ Wait for confirmation before proceeding.

---

## Conversation — Walk Through Topics

Greet briefly and explain: you'll ask questions to build `docs/PROJECT-BRIEF.md`; no code will be written. If init decisions were found, say so. If existing code was scanned, note you'll build on what you observed.

Cover these, one at a time, in whatever order feels natural. **Skip or confirm** anything already pre-filled from init or the scan; only ask what you can't derive.

- **Project Identity** — project name (confirm, don't assume from folder), 1–2 sentence elevator pitch.
- **Problem Statement** — what pain point does this solve? Why does it need to exist?
- **Target Users** — who is this for? Their needs, frustrations, goals.
- **Core Features** — prioritized list, one by one, scope clarified per feature. (Existing path: present observed features, ask about priority and what's missing/planned.)
- **Technical Requirements** — platform, stack, constraints, integrations, APIs, data storage. *(Skip/confirm if pre-filled from init or scan.)*
- **Non-Functional Requirements** — performance, security, accessibility, scalability, offline support. *(Skip/confirm if pre-filled.)*
- **MVP Scope** — what's in v1 vs. future? (Existing path: what's already shipped vs. still planned.)
- **Success Metrics** — how do we measure if this worked?
- **Open Questions** — unknowns, risks, dependencies, tech debt to research later.
- **Epics & Implementation Order** — propose epics (large work chunks) with ordered steps, dependencies, and which steps can run in parallel. (Existing path: distinguish **already built** / **in progress** / **planned**; list steps for planned work only.) Confirm before writing.

For each topic: ask → (present observation, if any) → listen → follow up → summarize → confirm before moving on.

---

## Wrap Up & Write

When you reach ~90% confidence or the user says "done":

1. Present a full summary of everything captured; ask for corrections/additions.
2. Read the template at `~/.claude/docs/templates/project-brief-template.md`.
3. Create `docs/` if it doesn't exist.
4. Write the completed brief to `docs/PROJECT-BRIEF.md`.
5. Remind: "This is a brief only — implementation starts separately."
6. **Offer the `/ios-epic` handoff** — suggest expanding the first epic with `/ios-epic 1`.

## Output

`docs/PROJECT-BRIEF.md` follows the template and contains only what the user explicitly provided or confirmed. Mark thin sections **TBD** rather than guessing.

- If init decisions were used, note in Technical Requirements: "Decided during project initialization (`/ios-init`)."
- **Existing path:** include an **Existing Codebase** section (between Non-Functional Requirements and MVP Scope) documenting structure, tech stack, confirmed features, and current state — factual, from scan + confirmation. In Epics, clearly separate already built / in progress / planned.
- For Epics generally: synthesize discussed features into logical epics with ordered steps, dependencies noted, and parallelizable steps called out. This is the one section where you propose structure — but confirm before writing.

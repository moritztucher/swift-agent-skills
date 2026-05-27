---
name: project-brief-existing
description: Explore an existing codebase, then collaboratively build a project brief — pre-filling what can be observed and asking only about gaps
user_invocable: true
---

# Project Brief (Existing Project) Skill

You are helping the user create a comprehensive project brief for an **existing project** that already has code. Your role is purely documentary — explore the codebase, present findings, ask questions about what you can't derive from code, and produce a structured markdown brief. **No code changes, no implementation, no assumptions about intent.**

## Rules

- **Never assume intent from code** — observe structure, ask about purpose.
- **No implementation, no code changes** — this is a brief only.
- **One topic at a time** — confirm understanding before moving on.
- **Pre-filled sections are proposals** — always mark as "Observed from codebase" and get user confirmation.
- **Track confidence internally** — keep going until you have ~90% confidence in the project outline, or the user says "done".
- **Follow the natural conversation** — the topic order below is a guide, not a rigid script. Follow the user's flow.
- **If existing docs (README, ARCHITECTURE.md, etc.) exist** — reference them but don't copy blindly. Ask if they're current and accurate.

## Flow

### Phase 1: Codebase Exploration (silent — no chat questions yet)

Perform all of these silently before presenting anything to the user:

1. **Project structure** — scan top-level directories and key subdirectories to understand layout
2. **Tech stack** — identify languages, frameworks, and dependencies from manifest files (Package.swift, package.json, Podfile, build.gradle, Cargo.toml, requirements.txt, Gemfile, etc.)
3. **Existing features** — infer from file/folder names, view files, route definitions, model names, test files
4. **Existing docs** — check for README.md, ARCHITECTURE.md, CLAUDE.md, docs/ folder, ADRs, changelogs
5. **Git history** — check project age (`git log --reverse --format='%ai' | head -1`), recent activity (`git log --oneline -10`), number of contributors (`git shortlog -sn --no-merges | head -5`)
6. **Current state** — look for TODOs, work-in-progress branches, broken/disabled tests

### Phase 2: Present Findings

Present a clear summary to the user:

> "Here's what I found in the codebase..."

Include:
- **Project structure** — directory layout overview
- **Tech stack** — languages, frameworks, key dependencies (with versions if visible)
- **Existing features** — what appears to be built (grouped logically)
- **Existing docs** — what documentation already exists
- **Project age & activity** — when started, recent commit activity, contributors

Then ask: _"Does this look accurate? Anything I missed or got wrong?"_

Wait for the user to confirm or correct before proceeding.

### Phase 3: Fill Gaps Conversationally

Cover these areas. **Skip or pre-fill** what was already derived from the codebase scan. Only ask about what you can't observe in code.

#### Always ask (can't derive from code):
- **Project name** — confirm, don't assume from folder/repo name
- **Elevator pitch** — 1-2 sentences describing what this project is
- **Problem Statement** — What pain point does this solve? Why does this need to exist?
- **Target Users** — Who is this for? What are their needs, frustrations, or goals?
- **Success Metrics** — How do we measure if this project worked?

#### Pre-fill and confirm:
- **Core Features** — present observed features, ask about priority, ask what's missing or planned
- **Technical Requirements** — pre-fill from scan (platform, stack, integrations, data storage), confirm and ask about constraints
- **Non-Functional Requirements** — pre-fill what's observable (e.g., offline support, auth patterns), ask about performance targets, accessibility, scalability

#### Ask with context:
- **MVP Scope** — ask what's already shipped vs. what's still planned for v1 vs. future versions
- **Open Questions** — capture unknowns, risks, tech debt, things to research
- **Epics & Implementation Order** — propose based on what exists vs. what's planned. Distinguish "already built" from "needs building"

For each topic:
1. Present what you observed (if applicable)
2. Ask an open-ended question about what you couldn't observe
3. Listen to the answer
4. Ask follow-ups if needed
5. Summarize what you captured
6. Confirm before moving on

### Phase 4: Write Brief

When you've reached ~90% confidence or the user says "done":

1. Present a full summary of everything captured
2. Ask for any corrections or additions
3. Read the template at `~/.claude/docs/templates/project-brief-template.md`
4. Create `docs/` directory if it doesn't exist
5. Write the completed brief to `docs/PROJECT-BRIEF.md`
6. Include the **Existing Codebase** section (between Non-Functional Requirements and MVP Scope)
7. Remind the user: "This is a brief only — implementation starts separately."

## Output

The final `docs/PROJECT-BRIEF.md` should follow the template structure and contain only information the user explicitly provided or confirmed. Mark any sections with insufficient information as "TBD" rather than guessing.

The **Existing Codebase** section documents what already exists — project structure, tech stack, confirmed features, and current state. This section is factual and based on the scan + user confirmation.

For the Epics section, clearly distinguish between:
- **Already built** — features/infrastructure that exist and work
- **In progress** — partially built or work-in-progress items
- **Planned** — new work to be done

List implementation steps for planned work only. Note dependencies and highlight which steps can be done in parallel. Confirm the proposed epics with the user before writing.

The generated date line should reference `/project-brief-existing` instead of `/project-brief`.

---
name: project-brief
description: Collaboratively build a structured project brief through conversation before any implementation begins
user_invocable: true
---

# Project Brief Skill

You are helping the user create a comprehensive project brief. Your role is purely documentary — ask questions, capture answers, and produce a structured markdown brief. **No code, no implementation, no assumptions.**

## Rules

- **Never assume** — always ask. If something is unclear, ask a follow-up.
- **No implementation, no code** — this is a brief only.
- **One topic at a time** — confirm understanding before moving on.
- **Track confidence internally** — keep going until you have ~90% confidence in the project outline, or the user says "done".
- **Follow the natural conversation** — the topic order below is a guide, not a rigid script. Follow the user's flow.

## Flow

### 0. Check for ios-init Handoff

Before starting, check if `docs/.ios-init-decisions.json` exists:

- **If it exists**, read it and pre-fill the following into your working context:
  - **Project name** — use as-is, confirm with user
  - **Technical Requirements** — pre-fill platform (iOS), database, networking, auth, navigation pattern, sync strategy, offline support, 3rd-party integrations. Present these as "Already decided during project setup:" and confirm, then skip to topics not yet covered.
  - **Non-Functional Requirements** — pre-fill accessibility priority, biometrics, keychain usage from the decisions file.
  - Do NOT re-ask any questions that are already answered in the decisions file.
  - Still ask all non-technical topics: Problem Statement, Target Users, Core Features, MVP Scope, Success Metrics, Open Questions, Epics.

- **If it does not exist**, proceed normally with the full flow below.

### 1. Greet and Explain
Briefly explain what you'll do: ask questions to build a project brief together. The output will be a `docs/PROJECT-BRIEF.md` file. No code will be written — implementation starts separately.

If ios-init decisions were found, mention: "I found your technical setup decisions from `/ios-init` — I'll use those as a starting point so we can focus on the product side."

### 2. Project Identity
Ask for:
- **Project name** (if not pre-filled from ios-init)
- **Elevator pitch** — 1-2 sentences describing what this project is

### 3. Walk Through Topics Conversationally

Cover these areas, one at a time, in whatever order feels natural:

- **Problem Statement** — What pain point does this solve? Why does this need to exist?
- **Target Users** — Who is this for? What are their needs, frustrations, or goals?
- **Core Features** — Build a prioritized list. Ask about features one by one. Clarify scope for each.
- **Technical Requirements** — Platform, stack, constraints, integrations, APIs, data storage. **(Skip or confirm if pre-filled from ios-init.)**
- **Non-Functional Requirements** — Performance, security, accessibility, scalability, offline support. **(Skip or confirm if pre-filled from ios-init.)**
- **MVP Scope** — What's in v1 vs. future versions? Where's the line?
- **Success Metrics** — How do we measure if this project worked? What does success look like?
- **Open Questions** — Capture unknowns, risks, dependencies, things to research later.
- **Epics & Implementation Order** — Based on everything discussed, propose epics (large work chunks) with implementation steps in a logical order. Show dependencies between steps and highlight which steps can be done in parallel.

For each topic:
1. Ask an open-ended question
2. Listen to the answer
3. Ask follow-ups if needed
4. Summarize what you captured for that topic
5. Confirm before moving on

### 4. Wrap Up

When you've reached ~90% confidence or the user says "done":
1. Present a full summary of everything captured
2. Ask for any corrections or additions
3. Read the template at `~/.claude/docs/templates/project-brief-template.md`
4. Create `docs/` directory if it doesn't exist
5. Write the completed brief to `docs/PROJECT-BRIEF.md`
6. Remind the user: "This is a brief only — implementation starts separately."

## Output

The final `docs/PROJECT-BRIEF.md` should follow the template structure and contain only information the user explicitly provided. Mark any sections with insufficient information as "TBD" rather than guessing.

If ios-init decisions were used, include them in the Technical Requirements section with a note: "Decided during project initialization (`/ios-init`)." This preserves the audit trail.

For the Epics section, synthesize the discussed features into logical epics. For each epic, list implementation steps in order, note dependencies (what must be done first), and call out which steps can be worked on in parallel. This is the one section where you should propose structure based on the conversation — but confirm it with the user before writing.

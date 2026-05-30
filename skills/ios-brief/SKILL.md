---
name: ios-brief
description: Build and maintain docs/PROJECT-BRIEF.md — the project's living source of truth. Drafts the brief from the ios-init description (and existing code), then refines by reaction instead of a long interview. Breaks features into UI vs Logic/Backend layers, bucketed MVP vs Later. Re-run anytime to update the brief in place.
user_invocable: true
---

# /ios-brief — Project Brief

Build and maintain `docs/PROJECT-BRIEF.md` — the project's **living source of truth**: concise, readable, and kept current as the app evolves. No code, no implementation.

> **Next step:** this is your living reference — start building against it (UI first, then logic), and re-run `/ios-brief` anytime to keep it current.

## How this works

- **Draft-first, not interrogation.** Propose a full draft from what's already known, then let the user correct it. Don't march through topics one question at a time.
- **Assume, then confirm.** Infer from the init description and any code; mark inferences as assumptions and let the user fix them. Don't refuse to assume.
- **Q&A stays in chat.** Never write questions into the document — keep it a clean reference.
- **It's a living document.** Re-running updates the existing brief in place rather than starting over.

---

## Step 0 — Gather Context (silent)

1. **`/ios-init` handoff:** if `docs/.ios-init-decisions.json` exists, read it. The `description` blurb seeds the elevator pitch, Problem, Target Users (from `audience`), and the MVP feature set; the technical decisions (platforms, database, networking, auth, sync, offline, integrations) fill Technical Requirements. Don't re-ask any of it.
2. **Update mode:** if `docs/PROJECT-BRIEF.md` already exists, read it — this run **revises it in place**. Preserve the user's wording and any sections they've edited; only change what's actually new or corrected.
3. **Existing code:** if there's a codebase, do a quick silent scan (structure, tech stack from manifests, existing features from file/folder names, current state from TODOs/WIP/broken tests). For an existing project, present a short "here's what I found" summary and confirm before drafting.

---

## Step 1 — Draft the Brief

From everything gathered, **draft every section at once** (see Output). Fill what you can confidently; mark genuine gaps `[TBD]` and clearly-inferred values as assumptions (e.g. "_assumed — correct me_"). For the **Features** section, propose the feature list, sort each into **MVP** or **Later**, and take a first pass at splitting each feature into its **UI** and **Logic & Backend** layers.

Present the draft to the user (or write a first version of `docs/PROJECT-BRIEF.md` and walk them through it) — whichever makes it easier to react.

---

## Step 2 — Refine (one batched round)

Ask only what you genuinely can't infer, **grouped into a single round** — let the user answer in any order, then iterate until they're happy or say "done." Typical gaps:

- **Problem / why** — if the description didn't make it explicit
- **Target users** — specifics beyond the audience tag
- **MVP line** — which proposed features are MVP vs Later
- **Feature breakdown** — for each feature, confirm/adjust the UI pieces and the Logic & Backend pieces (you propose the split; the user trims or adds)
- **Out of scope** — what's explicitly *not* being built
- **Success metrics** — how they'll know it worked
- **Risks / unknowns** — anything to flag

Don't gate on a confidence score; refine until the user is satisfied.

---

## Step 3 — Write / Update

1. Read the template at `~/.claude/docs/templates/project-brief-template.md`.
2. Create `docs/` if needed.
3. Write (or update in place) `docs/PROJECT-BRIEF.md`. Set the **Last updated** line to today.
4. In update mode, briefly note what changed since the last version.

---

## Output

`docs/PROJECT-BRIEF.md` follows the template and contains only what the user provided or confirmed. Mark thin sections `[TBD]` rather than guessing. Sections: Problem · Target Users · **Features** · Technical Requirements · Non-Functional · *(Existing Codebase — existing projects only)* · Success Metrics · Open Questions & Risks.

**The Features section is the work artifact.** It replaces formal epics/step planning:
- Features are grouped **MVP** and **Later** (this defines scope — there is no separate "MVP scope" section).
- Each feature is split into a **UI** layer and a **Logic & Backend** layer, so the UI can be built first and logic layered in after.
- **No implementation-order, dependency, or parallel tables** — the brief decomposes work, it doesn't sequence it.

If init decisions were used, note in Technical Requirements: "Decided during project initialization (`/ios-init`)." For an existing project, fill the **Existing Codebase** section from the scan + confirmation, and tag features as already built / in progress / planned within the MVP/Later grouping.

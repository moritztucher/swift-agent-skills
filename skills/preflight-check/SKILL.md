---
name: preflight-check
description: Validate project brief and all epic documents for contradictions, missing dependencies, and issues before implementation
user_invocable: true
---

# Preflight Check Skill

You audit the entire project planning surface — the project brief and all epic documents — for contradictions, dependency issues, gaps, and anything else that would cause problems during implementation. You produce a written report at `docs/PREFLIGHT-REPORT.md`.

**Input:** None. This skill always scans everything.

---

## Rules

- **Read everything first** — do not start reporting until you've read all documents.
- **No fixes** — report problems, don't solve them. Suggest which document to update.
- **Be specific** — cite the exact documents, sections, and conflicting statements.
- **No assumptions** — flag ambiguity as a finding rather than resolving it yourself.
- **Severity matters** — categorize every finding so the user knows what to fix first.

---

## Flow

### 1. Gather All Documents

1. Read `docs/PROJECT-BRIEF.md`. If it doesn't exist, tell the user to run `/project-brief` first and stop.
2. List all files in `docs/epics/` matching `EPIC-*.md`.
3. Read every epic document found.
4. Read `docs/DESIGN-SYSTEM.md` if it exists — note its confidence level.
5. Note which epics from the project brief **don't** have a corresponding detail document yet.

### 2. Run Checks

Perform each of the following checks across all documents. For every finding, record:
- **Severity** (Blocker / Warning / Info)
- **Location** — which document(s) and section(s)
- **Description** — what the issue is
- **Suggestion** — which document to update or what to clarify

#### A. Contradictions

Compare statements across all documents. Look for:
- **Brief vs. Epic conflicts** — an epic says something different from the project brief (e.g., brief says "offline-first" but an epic assumes always-online).
- **Epic vs. Epic conflicts** — two epics make incompatible assumptions (e.g., Epic 2 assumes a data model that Epic 1 defines differently).
- **Internal contradictions** — a single document contradicts itself (e.g., goals say X but acceptance criteria say Y).
- **Scope drift** — an epic includes work that the brief explicitly marked as "Future Versions" or "Out of Scope".

#### B. Dependency Issues

- **Missing dependencies** — an epic references data, models, APIs, or screens that no other epic produces and the brief doesn't cover.
- **Undeclared dependencies** — an epic uses outputs from another epic but doesn't list it as a dependency.
- **Circular dependencies** — epic A depends on B, B depends on A (or longer chains).
- **Ordering conflicts** — the implementation order in the brief conflicts with the dependencies declared in epic details.
- **Incomplete dependency chain** — an epic depends on another that is not yet at 90% confidence or doesn't have a detail document.

#### C. Coverage Gaps

- **Brief features not covered** — a core feature from the project brief has no corresponding epic or epic step.
- **Orphaned epics** — an epic exists that doesn't map to any feature in the brief.
- **Missing non-functional coverage** — the brief lists non-functional requirements (security, performance, accessibility) but no epic addresses them.
- **Unanswered questions** — epics still have open questions that block implementation.
- **Missing design system** — epics have `[UI]` questions but no `docs/DESIGN-SYSTEM.md` exists. (Warning)
- **Design system incomplete** — `docs/DESIGN-SYSTEM.md` exists but is below 90% confidence. (Warning)

#### D. Consistency

- **Naming mismatches** — the same concept is called different things across documents (e.g., "User" vs. "Account" vs. "Profile" for the same entity).
- **Tech stack conflicts** — different epics assume different technologies for the same concern.
- **Data model divergence** — overlapping models defined differently in separate epics.
- **Design system conflicts** — epic `[UI]` decisions contradict `docs/DESIGN-SYSTEM.md` (e.g., epic specifies colors or typography that differ from the design system). (Warning)

#### E. Implementation Readiness

- **Confidence gaps** — any epic below 90% confidence.
- **Vague acceptance criteria** — steps with no clear "done" definition.
- **Missing edge cases** — steps that handle only the happy path with no error handling notes.
- **Parallel work feasibility** — steps marked as parallelizable but actually having implicit dependencies.

### 3. Produce Report

1. Read the template at `~/.claude/docs/templates/preflight-report-template.md`.
2. Write findings to `docs/PREFLIGHT-REPORT.md`.
3. Include a summary verdict at the top:
   - **Ready** — no blockers, only minor warnings or info items.
   - **Needs Work** — blockers found that must be resolved before implementation.
4. Tell the user the result and where to find the report.

### 4. Summary in Chat

After writing the report, give a brief chat summary:
- Verdict (Ready / Needs Work)
- Count of findings by severity (e.g., "2 Blockers, 3 Warnings, 1 Info")
- List the blockers (if any) with one-line descriptions
- Point the user to `docs/PREFLIGHT-REPORT.md` for full details

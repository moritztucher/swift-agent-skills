---
name: ios-audit
description: Holistic project audit through three code-evidence lenses (PM, UX, ARCH). Scans an existing codebase and produces a severity-rated findings report with actionable suggestions. For rendered visual craft, use ios-design-audit; for the first-launch flow, ios-onboarding-audit.
user_invocable: true
argument-hint: <optional: feature name or path to scope the audit, e.g. "Auth" or "Features/Onboarding">
---

# iOS Project Audit

You perform a holistic audit of an existing iOS/SwiftUI project through three code-evidence lenses: Product (PM), UX, and Architecture (ARCH). You produce a structured report with severity-rated findings and suggestions.

Visual design craft is **out of scope** — judging look-and-feel from source code alone produces weak findings. Route the user to `/ios-design-audit` (which screenshots the running app) for that, and to `/ios-onboarding-audit` for the first-launch flow.

**Key constraint:** This skill **suggests, not decides**. Findings describe observations and trade-offs. Recommendations use "Consider:" framing.

**Input:** Optional scope — a feature name, directory path, or nothing (full project audit).

---

## Rules

- **Read before judging** — scan the full scope before writing any findings.
- **Three lenses, always** — every audit must cover PM, UX, and ARCH. If a lens has no findings, say so explicitly.
- **Spawn the UX advisor** — delegate the UX lens review to the `ios-ux-advisor` sub-agent (see below). On clients without subagent support, run that lens inline instead (see the no-subagent fallback).
- **Severity on every finding** — no unclassified observations.
- **Suggestions, not directives** — use "Consider:" framing. The user decides.
- **Cite locations** — every finding references specific files and lines.
- **No code changes** — this is an audit, not a fix. Offer to fix after the report.

---

## Sub-Agents

### UX Advisor

Spawn the `ios-ux-advisor` agent for the UX lens:

```
Audit the UX patterns in this iOS/SwiftUI project scope.

Scope: {SCOPE_DESCRIPTION}

Files to review:
{LIST OF VIEW AND VIEWMODEL FILES}

For each file, check:
- HIG alignment (navigation, controls, platform conventions)
- Accessibility (VoiceOver labels, Dynamic Type, reduce motion, contrast)
- Dark Mode support
- Loading/empty/error state handling
- User feedback (haptics, confirmations, progress indicators)
- Navigation clarity (back button, user orientation)
- Tap targets (44x44pt minimum)
- Consistency across the scope

Return findings as a numbered list. Each finding must include:
- Severity (Must fix / Should fix / Consider)
- File path and line number
- What you observed
- Suggestion (use "Consider:" framing)

Skip files with no UX concerns. No preamble.
```

**No-subagent fallback:** if your environment cannot spawn subagents (e.g. a non-Claude Agent Skills client with no Task tool), do not skip the UX lens. Read the portable lens skill — `skills/ios-ux-advisor/SKILL.md` — and apply it inline to the same file list with the same prompt and output format above. The findings contract is identical; you only lose the parallelism.

---

## Flow

### 1. Determine Scope

- If an argument is provided, scope to that feature/path.
- If no argument, audit the full project.

For the determined scope:
1. Read `CLAUDE.md` and `ARCHITECTURE.md` if they exist — understand project decisions.
2. Glob for all `.swift` files in scope.
3. Categorize files: Views, ViewModels, Models, Services/Managers, App entry point, Tests.
4. Note the file count per category — this shapes which lenses are most relevant.

### 2. Gather Context

Read architecturally significant files:
- App entry point (navigation setup, environment injection)
- All ViewModels in scope (business logic, state management, service usage)
- All Views in scope (UI patterns, state handling, accessibility)
- Services/Managers in scope (API layer, data access, error handling)
- Models in scope (data structures, relationships)

If the scope is large (>30 files), prioritize: entry points, navigation, the most complex ViewModels, and Views with the most lines of code.

### 3. Run Three-Lens Audit

**Spawn the UX advisor agent** (pass it the View and ViewModel files from Step 2).

While it runs, perform the PM and ARCH lens audits yourself:

#### `[PM]` Product Lens

Review for:
- **Feature completeness** — are there obvious gaps in user flows (screens that lead nowhere, unhandled states)?
- **User value clarity** — can you tell what the feature does for the user from reading the code?
- **Edge case coverage** — are error states, empty states, and boundary conditions handled?
- **Scope coherence** — does the feature scope match what ARCHITECTURE.md / PROJECT-BRIEF.md describes?
- **Onboarding / first-run** — if applicable, is there a first-use experience?

#### `[ARCH]` Architecture Lens

Review for:
- **MVVM compliance** — Views contain no business logic, ViewModels use `@Observable`, services behind protocols
- **Dependency injection** — Environment-based DI, no global singletons
- **Navigation** — `NavigationPath`-based coordination, no `NavigationLink(destination:)`
- **Concurrency** — async/await only, `@MainActor` where needed, no Combine/completion handlers
- **Security** — no hardcoded secrets, Keychain for credentials, HTTPS only, input validation
- **Error handling** — custom `LocalizedError` enums, no raw error strings
- **File organization** — correct placement in Features/, Core/, ViewComponents/
- **Testability** — protocol abstractions, mockable services, separation of concerns
- **Performance** — no unnecessary redraws, appropriate caching, pagination for large data

### 4. Integrate Sub-Agent Results

Collect the UX advisor's findings. Merge all three lenses into the report.

### 5. Classify Findings

Every finding gets a severity:

| Severity | Definition | Examples |
|----------|-----------|----------|
| **CRITICAL** | Security risk, crash potential, data loss | Hardcoded secret, force unwrap on API response, no Keychain |
| **HIGH** | Breaks architectural rule or significant UX issue | Business logic in View, missing loading states, broken navigation |
| **MEDIUM** | Convention divergence, tech debt, missed opportunity | Wrong file placement, duplicated service logic, inconsistent patterns |
| **LOW** | Minor style, small polish opportunity | Missing `// MARK:`, slight spacing inconsistency |

### 6. Generate Report

Write to `docs/AUDIT-REPORT.md` (or `docs/AUDIT-REPORT-{feature}.md` if scoped).

```markdown
# Project Audit — {scope}

**Date:** {YYYY-MM-DD}
**Scope:** {full project or feature/path}
**Auditor:** /ios-audit

---

## Summary

| Lens | CRITICAL | HIGH | MEDIUM | LOW | Total |
|------|----------|------|--------|-----|-------|
| [PM] | N | N | N | N | N |
| [UX] | N | N | N | N | N |
| [ARCH] | N | N | N | N | N |
| **Total** | **N** | **N** | **N** | **N** | **N** |

**Verdict:** {STRONG / SOLID / NEEDS WORK / CRITICAL ISSUES}
- STRONG: zero CRITICAL/HIGH, few MEDIUM
- SOLID: zero CRITICAL, minor HIGH findings
- NEEDS WORK: HIGH findings across multiple lenses
- CRITICAL ISSUES: one or more CRITICAL findings

---

## [PM] Product Findings

### PM-1: {Short title} — {SEVERITY}
- **Location:** `path/to/file.swift:line`
- **Observation:** {What you found}
- **Consider:** {Suggestion with trade-off}

...

## [UX] UX Findings

### UX-1: {Short title} — {SEVERITY}
- **Location:** `path/to/file.swift:line`
- **Observation:** {What you found}
- **Principle:** {HIG or UX principle}
- **Consider:** {Suggestion}

...

## [ARCH] Architecture Findings

### ARCH-1: {Short title} — {SEVERITY}
- **Location:** `path/to/file.swift:line`
- **Rule:** {Rule name and category}
- **Observation:** {What you found}
- **Consider:** {Suggestion}

...

---

## Strengths

{Bulleted list of what the project does well — organized by lens. Acknowledge good patterns.}

### [PM]
- ...

### [UX]
- ...

### [ARCH]
- ...

---

## Top Recommendations

{Prioritized list of the 3-5 most impactful improvements across all lenses. Each with lens tag, effort estimate (small/medium/large), and expected impact.}

1. `[LENS]` **{Title}** — {Description}. Effort: {small/medium/large}. Impact: {what improves}.
```

### 7. Summary in Chat

After writing the report:
- Verdict and finding count per lens
- List any CRITICAL findings with one-line descriptions
- Top 3 recommendations
- Point to the report file
- Offer to fix CRITICAL or HIGH issues

---

## Scoping Guidelines

| Scope | What to Audit | Typical File Count |
|-------|--------------|-------------------|
| Full project | Everything in the project | All .swift files |
| Feature (e.g., "Auth") | `Features/Auth/` + related Core/ services | 5-20 files |
| Directory path | Exact path provided | Whatever is there |

When auditing a feature, also check its integration points — how it connects to navigation, shared services, and other features.

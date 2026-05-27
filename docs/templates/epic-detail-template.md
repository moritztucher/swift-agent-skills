# Epic {{NUMBER}}: {{EPIC_NAME}}

> **Confidence:** {{XX}}%
> **Status:** {{In Progress / Ready for Implementation}}
> **Dependencies:** {{List of epic dependencies, or "None"}}
> **Last Updated:** {{DATE}}

---

## Overview

{{Brief description of what this epic delivers and why it matters, pulled from the project brief.}}

## Goals

- {{Goal 1 — what success looks like for this epic}}
- {{Goal 2}}

## Out of Scope

- {{What this epic explicitly does NOT cover}}

---

## Expected Outcome

_What this epic delivers from the user's/system's perspective. Refined progressively as questions are resolved._

- **New screens/views:** {{list or TBD}}
- **User flows:** {{key flows or TBD}}
- **System behavior changes:** {{background processes, integrations, data flows or TBD}}

---

## Implementation Steps

_Ordered by dependency. Steps that can run in parallel are grouped._

### Step {{N.1}}: {{Step Name}}

- **Description:** {{What needs to be built/done}}
- **Dependencies:** {{Other steps or epics this depends on}}
- **Inputs:** {{What data/state/APIs this step needs}}
- **Outputs:** {{What this step produces — screens, models, endpoints, etc.}}

> **Parallel group:** {{Can run alongside steps X.Y, X.Z — or "Sequential"}}

### Step {{N.2}}: {{Step Name}}

_Repeat structure above for each step._

---

## Acceptance Criteria

_Every major requirement must have a testable criterion. Each criterion is a binary pass/fail statement starting with a verb._

| AC | Criterion | Type | Test File |
|----|-----------|------|-----------|
| AC-1 | {{Testable statement starting with a verb}} | {{unit / integration / ui}} | {{FeatureTests.swift}} |
| AC-2 | {{...}} | {{...}} | {{...}} |

**Type guide:**
- `unit` — pure logic (ViewModels, services, utilities, data transformations)
- `integration` — service-layer logic with real dependencies (database, Keychain, network)
- `ui` — visible UI elements, navigation, user interactions, view state changes

---

## Data & Models

{{Data models, schemas, or structures this epic introduces or modifies. Leave as TBD if unknown — write a question instead.}}

## API & Integrations

{{External APIs, services, or internal interfaces this epic needs. Leave as TBD if unknown — write a question instead.}}

## UI & Navigation

{{Screens, flows, navigation changes. Leave as TBD if unknown — write a question instead.}}

## Edge Cases & Error Handling

{{Known edge cases and how to handle them. Leave as TBD if unknown — write a question instead.}}

---

## Human QA Checklist

_Things a human tester must verify on a real device that automated tests cannot cover. Refined as questions are resolved._

### Visual & Motion
- [ ] {{Visual fidelity check — e.g., "Gradient renders smoothly on all screen sizes"}}
- [ ] {{Animation check — e.g., "Completion animation feels satisfying, not sluggish"}}
- [ ] {{Dark mode — e.g., "All screens look intentional in dark mode, no contrast issues"}}

### Touch & Feel
- [ ] {{Haptic check — e.g., "Success haptic fires on streak milestone"}}
- [ ] {{Gesture check — e.g., "Swipe-to-dismiss feels natural, not fighting the user"}}
- [ ] {{Responsiveness — e.g., "No perceptible delay between tap and visual feedback"}}

### State & Data
- [ ] {{Empty state — e.g., "First-launch screen shows onboarding, not a blank list"}}
- [ ] {{Error state — e.g., "Network error shows retry option, not a crash"}}
- [ ] {{Edge data — e.g., "Long usernames truncate gracefully, don't break layout"}}

### Accessibility
- [ ] {{VoiceOver — e.g., "All interactive elements have meaningful labels"}}
- [ ] {{Dynamic Type — e.g., "Layout holds at largest accessibility text size"}}
- [ ] {{Reduce Motion — e.g., "Animations replaced with crossfade when reduce motion is on"}}

### Device & Environment
- [ ] {{Orientation — e.g., "Landscape layout is usable (or locked to portrait)"}}
- [ ] {{Interruptions — e.g., "Incoming call during flow doesn't lose state"}}
- [ ] {{Background/foreground — e.g., "Returning from background refreshes data"}}

---

## Open Questions

_Answer a question by changing its status to `Answered` and writing your choice + notes in the Answer field. Then run `/epic-detail {{NUMBER}}` again._

{{Questions go here — see question format in skill definition}}

---

## Resolved Questions

_Previously answered questions, kept for reference._

---

_Generated with `/epic-detail` from PROJECT-BRIEF.md_

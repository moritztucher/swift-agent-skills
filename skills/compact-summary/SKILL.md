---
name: compact-summary
description: Summarize and compact the current conversation into a reusable context primer. Use this skill when the user types /compact-summary or /compact, wants to summarize or compress the conversation, reduce context length, or prepare a handoff summary for a new session. Also trigger when the user says things like "summarize what we've done", "compact this conversation", "create a session summary", "I want to start fresh with context", or "too much context, summarize it". Use for any request to condense, compress, or snapshot the current session state.
user_invocable: true
---

# /compact — Conversation Compactor

Distil the current conversation into a tight, copy-pasteable context primer. The goal is to let the user open a new session with full context using the fewest possible tokens — like a handoff brief from one shift to the next.

## What to capture

Work through the conversation from start to finish and extract:

1. **Project context** — working directory, project name, key files/stack if mentioned
2. **Session goal** — what the user was originally trying to accomplish
3. **Work completed** — what was built, fixed, or changed (be specific: file names, function names, not vague summaries)
4. **Key decisions** — architectural choices, tradeoffs chosen, approaches rejected and why
5. **Current state** — where things stand right now: what's working, what's broken, what's in progress
6. **Open threads** — unresolved questions, TODO items, what comes next

Err toward specificity. "Added `AuthManager.swift` with JWT refresh logic" is more useful than "worked on auth."

## What to skip

- Conversational filler (greetings, "sounds good", clarifying back-and-forth)
- Intermediate failed attempts unless the failure itself is informative (e.g., "tried X, failed because Y, switched to Z")
- Tool call details unless they revealed something important
- Anything the user already knows from their own codebase

## Output format

Print this directly in chat. No preamble. No "here's your summary" intro. Just the block.

```
## Session Compact — {YYYY-MM-DD}

**Working directory:** {path or "not specified"}
**Project:** {project name or stack summary}

---

### Goal
{One or two sentences: what the user was trying to accomplish this session.}

### Work Done
- {Specific change 1 — file/function/feature, what it does}
- {Specific change 2}
- ...

### Key Decisions
- **{Decision}:** {Why it was made, alternatives considered if any}
- ...

### Current State
{2–4 sentences on where things stand. What's working. What's still open. Any known issues.}

### Next Steps
- {Concrete next action 1}
- {Concrete next action 2}
- ...
```

Omit any section that has nothing meaningful to say — don't pad with "N/A" or "none". If there were no notable decisions, skip that section entirely.

## Optional modifiers

If the user passed an argument:
- `/compact brief` — compress further: skip "Key Decisions" and "Next Steps", keep Goal + Work Done + Current State only
- `/compact detailed` — expand: add a "Files Modified" section listing each changed file with a one-line description of what changed

If no argument, use the standard format above.

## After printing

Offer one follow-up line (not a paragraph):

> "Copy this block to start a new session — or I can save it to `.claude/session-compact.md`."

If the user says save it, write it to `.claude/session-compact.md` in the working directory (create the `.claude/` dir if needed). Don't save it automatically without asking.

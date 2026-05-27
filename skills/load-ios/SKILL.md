---
name: load-ios
description: Load the iOS development guide into the current chat for ad-hoc iOS work. Use when the user types /load-ios, or asks to "load iOS context / iOS rules" in a session that isn't inside a project with a CLAUDE.md that already imports it. Typical trigger is a scratch iOS chat — a one-off SwiftUI snippet, paste-in code review, or answering a question about iOS patterns with no project root.
---

# /load-ios — Load iOS Context

Load the consolidated iOS development guide into the current chat session. Use this in chats that don't have a project `CLAUDE.md` to auto-import the iOS rules (core stack, naming, architecture, ViewModel/View rules, Swift style, security, testing, `/ios-*` workflow).

## When to use

- User explicitly invokes `/load-ios`
- Starting iOS work in a directory that has no `CLAUDE.md`
- Starting iOS work outside any iOS project (temp dir, home dir, scratch chat)

## When NOT to use

- The current project's `CLAUDE.md` already contains `@~/.claude/docs/ios/ios-guide.md` (it's already loaded)
- The work is inside `~/work` (team repos — iOS guide does not apply)
- The work is not iOS-related

## Instructions

1. **Read the iOS guide** — use the Read tool on `~/.claude/docs/ios/ios-guide.md` so its full content enters the context window.

2. **Confirm the load** to the user in one short sentence — list the top-level sections loaded (e.g., "iOS guide loaded: Core Stack, Naming, Architecture, ViewModel/View rules, Swift Style, Security, Testing, Workflow").

3. **Apply the rules** for the rest of the session as if they were in a project CLAUDE.md. Treat them with the same precedence as project-level instructions.

4. **If the user is actually in an iOS project** (spot a `*.xcodeproj`, `Package.swift`, or SwiftUI `*.swift` files in the current directory) and the project has a `CLAUDE.md` without the iOS guide import, offer to add `@~/.claude/docs/ios/ios-guide.md` to the top of that `CLAUDE.md` so future chats load it automatically. Do not modify the file without confirmation.

## Notes

- This skill is for ad-hoc loading. The durable pattern for iOS projects is `@~/.claude/docs/ios/ios-guide.md` as the first line of the project's `CLAUDE.md`.
- `/ios-init` and `/ios-init-existing` add that import automatically when scaffolding a new project.

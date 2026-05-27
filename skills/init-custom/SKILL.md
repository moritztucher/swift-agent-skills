---
description: Initialize a new project with standard configuration files (CLAUDE.md, memory, architecture, changelog)
---

# /init - Project Initialization

Initialize a new project with standard configuration files.

## Instructions

1. Detect the project type by examining the current directory:
   - Look for `*.xcodeproj`, `*.xcworkspace`, `Package.swift` (with iOS/macOS targets), or `*.swift` files -> **iOS/macOS project**
   - Look for `package.json`, `tsconfig.json`, or `node_modules/` -> **Web/Node.js project**
   - Look for `requirements.txt`, `pyproject.toml`, `setup.py`, or `*.py` files -> **Python project**
   - Look for `go.mod` -> **Go project**
   - Look for `Cargo.toml` -> **Rust project**
   - If nothing is detected or the directory is empty -> **Ask the user**

2. Based on the detected (or chosen) project type:

### iOS/macOS Project
Check if Swift source files already exist (beyond just the Xcode project template):
- **If the project has existing code** (multiple `.swift` files, feature directories, services): **Execute `/ios-init-existing`** — scans the codebase and generates docs pre-filled with observed facts.
- **If the project is new/empty** (just the Xcode template or no code yet): **Execute `/ios-init`** — asks setup questions and generates docs from scratch.

Invoke directly using the Skill tool — do not ask the user to run it separately.

### Other Project Types
Create the following standard files:

#### CLAUDE.md (project root)
Project-specific config with:
- Project name (infer from directory or ask)
- Tech stack detected
- Any project-specific rules

#### .claude/memory.md
A simple project memory file:
- Decisions made and why
- User preferences discovered
- Common issues and solutions

#### ARCHITECTURE.md
Basic architecture overview:
- Project name and description
- Tech stack
- Directory structure
- Key components

#### docs/decisions/.gitkeep
Create empty directory for ADR files.

#### CHANGELOG.md
Use template from `~/.claude/docs/templates/changelog-template.md` with initial version 0.1.0 (if template exists, otherwise create a basic one).

3. After creating all files:
   - List all created files
   - Suggest running `git add` to stage them
   - Remind about updating ARCHITECTURE.md with specific project details

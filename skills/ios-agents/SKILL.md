---
description: Display all available agent types that can be invoked via the Task tool
disable-model-invocation: true
---

# /agents - List Available Agents

Display all available agent types that can be invoked via the Task tool.

## Instructions

Present the following agent reference to the user:

---

## Available Agents

| Agent | Use Case |
|-------|----------|
| **Explore** | Codebase exploration, find files, search code, answer architecture questions |
| **Plan** | Design implementation plans, identify critical files, architectural decisions |
| **Bash** | Command execution, git operations, terminal tasks |
| **general-purpose** | Complex multi-step tasks, research, code search |

### Explore Agent

Fast codebase exploration. Use for:
- Finding files by pattern: `"Find all SwiftUI views"`
- Searching code: `"Where are API endpoints defined?"`
- Understanding architecture: `"How does authentication work?"`

Thoroughness levels: `quick`, `medium`, `very thorough`

### Plan Agent

Software architecture and planning. Use for:
- Implementation strategy: `"Plan adding push notifications"`
- Identifying affected files before changes
- Weighing architectural trade-offs

### Bash Agent

Command execution specialist. Use for:
- Git operations
- Running build commands
- System tasks

### General-Purpose Agent

Autonomous complex tasks. Use for:
- Multi-step research
- Tasks requiring multiple tool types
- When unsure which specialized agent fits

---

## How to Use

Agents are invoked automatically when appropriate. You can also request:
- "Use the Explore agent to find..."
- "Have the Plan agent design..."
- "Run this in parallel with multiple agents"

## iOS-Specific Tips

- **Explore** for finding Views, ViewModels, Services
- **Plan** before implementing new features
- **Bash** for xcodebuild, swiftlint, git operations

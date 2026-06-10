---
name: ios-agents
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

### This bundle's advisors

| Agent | Use Case |
|-------|----------|
| **ios-ux-advisor** | UX patterns, HIG compliance, component choices, interaction flow |
| **ios-ui-design-advisor** | Visual craft — color, typography, motion, hierarchy, emotional design |
| **ios-onboarding-advisor** | Onboarding strategy — activation, permission timing, progressive disclosure |
| **context7-docs-writer** | Project-specific framework integration docs via Context7 |

> **Portability:** these four advisors also ship as plain skills (`skills/ios-ux-advisor/`, `skills/ios-ui-design-advisor/`, `skills/ios-onboarding-advisor/`, `skills/context7-docs-writer/`). On clients without a Task tool / subagent support, invoke or read the skill and apply the lens inline — the built-in agents above are Claude Code–specific.

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

# Architecture Overview

> This document provides a high-level overview of the project architecture.
> Update when significant architectural changes occur.

## Project Summary

**App Name:** [Name]
**Bundle ID:** [com.company.appname]
**Platforms:** [iOS | iPadOS | macOS | visionOS | tvOS | watchOS]
**Deployment Targets:** [iOS 18.0, …]
**Database:** [SwiftData | RealmSwift | None]
**Distribution:** [Open source ([license]) | Commercial / proprietary]

## System Architecture

> Tailor this diagram to the project — it is a starting point, not a fixed shape.
> Draw only the layers that exist: drop **External Services → Network** for a
> local-only app, add a **Sync / CloudKit** box when sync is used, and add
> platform-specific scenes (e.g. a macOS `Settings` scene, a watchOS scene) for
> each selected platform. For an existing codebase, reflect the real layers found.

```
┌─────────────────────────────────────────────────────────┐
│                        App Layer                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │   Views     │  │ ViewModels  │  │   Models    │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
├─────────────────────────────────────────────────────────┤
│                      Core Layer                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │  Services   │  │  Managers   │  │   Helpers   │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
├─────────────────────────────────────────────────────────┤
│                   External Services                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │  Network    │  │  Database   │  │   Auth      │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
└─────────────────────────────────────────────────────────┘
```

## Key Components

### Navigation
- **Pattern:** [Simple (single NavigationStack) | Multi-tab (TabView + stacks) | Deep linking]
- **NavigationCoordinator:** Centralized navigation using NavigationPath
- Deep linking support: [Yes | No | Planned]

### Networking
- **Approach:** [REST | GraphQL | None (local-only)]
- **Offline strategy:** [Online-only | Offline-first with sync | Cache-only | N/A]
- All API calls go through `NetworkService` — Views and ViewModels never call URLSession directly

### Auth
- **Provider:** [Apple Sign-In | Firebase Auth | Custom | None]
- **Biometrics:** [Face ID/Touch ID enabled | No]
- **Keychain:** [Yes — credentials stored in Keychain | No]

### Sync Strategy
- **Approach:** [Local-only | CloudKit sync | Custom backend sync | N/A]

### Data Flow
1. Views observe ViewModels via @Observable
2. ViewModels call Services/Managers for business logic
3. Services handle external operations (API, database)
4. Data flows back through the same chain

### Dependencies
| Dependency | Purpose | ADR |
|------------|---------|-----|
| [Package]  | [Why]   | [Link to ADR if exists] |

## Feature Modules

| Feature | Location | Description |
|---------|----------|-------------|
| [Feature] | `Features/[Name]/` | [Brief description] |

## Architecture Decisions

See `docs/decisions/` for detailed ADRs.

| Decision | Summary | Date |
|----------|---------|------|
| [ADR-0001] | [Brief summary] | [Date] |

## Data Storage

| Data Type | Storage | Encryption |
|-----------|---------|------------|
| User credentials | Keychain | Yes |
| User preferences | UserDefaults | No |
| App data | [Database] | [Yes/No] |

## Third-Party Integrations

| Service | Purpose | Documentation |
|---------|---------|---------------|
| [Service] | [Purpose] | [Link] |

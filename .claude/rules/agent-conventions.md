---
paths:
  - ".claude/agents/**"
---

# Agent Communication Conventions

## Spawning Pattern
- The Architect is the ONLY agent that spawns other agents (runs as main thread)
- Exception: Mutagen can spawn Mutagen Discovery (Mutagen runs as top-level via SessionStart hook)
- Subagents cannot spawn sub-subagents — all orchestration goes through the Architect

## Agent Output Format
- Code Researcher: Returns structured Target Profile in markdown (<2000 chars)
- Web Researcher: Returns structured findings with URLs and recommendations
- Implementer: Returns summary of all files created/modified
- Reviewer: Returns structured verdict — APPROVE or CHANGES_REQUESTED with specific items
- Mutagen: Returns recommendations with security evaluations
- Mutagen Discovery: Returns structured discovery report with security metadata

## Feedback Loop Protocol
- The Implementer-Reviewer loop is orchestrated by the Architect
- Maximum 3 review cycles before forced completion
- Reviewer outputs: BLOCKING items (must fix) and IMPROVEMENTS (optional)
- If only IMPROVEMENTS remain (no BLOCKING), treat as implicit APPROVE

## Mutagen Integration
- The Architect MUST spawn Mutagen during every planning phase
- Mutagen is consulted before and after generation
- Post-generation: Mutagen records version history and collects user feedback

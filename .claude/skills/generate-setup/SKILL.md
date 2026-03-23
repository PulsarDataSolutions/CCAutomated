---
name: generate-setup
description: >
  Main entry point for CCAutomated. Analyzes a target repository and generates
  or updates the Claude Code configuration (agents, skills, rules, hooks, settings,
  CLAUDE.md, .mcp.json) tailored to that repo. Detects existing setups and presents
  strategy options (Update / Merge / Replace) before touching anything.
argument-hint: "<path-to-target-repo>"
user-invocable: true
model: opus
---

# Generate Setup

You have been invoked with `/generate-setup`. Your job is to generate or update a complete Claude Code setup for the target repository.

## Target Repository Path
`$ARGUMENTS`

## Pre-flight Checks

1. Verify the target path exists and is a directory
2. Check if it's a git repo (if yes, the Implementer will create a backup branch)

## Pipeline

### 1. Analyze
Spawn the Code Researcher to build a Target Profile. The profile MUST include a detailed **Existing Setup Analysis** section if any Claude Code config is detected (`.claude/`, `CLAUDE.md`, `.mcp.json`).

### 2. Research
Spawn in parallel:
- **Web Researcher** — framework best practices and available tools for the detected stack
- **Mutagen** — plugin recommendations, security evaluations, skill suggestions. If usage/reasoning logs exist from a previous setup, pass those for analysis.

### 3. Detect & Decide (Strategy Selection)

If the Code Researcher reports an existing setup, present the user with:

1. A summary of what currently exists (from the Existing Setup Analysis)
2. Three strategy options:

| Strategy | Behavior | When to use |
|----------|----------|-------------|
| **Update** (default) | Only touch files affected by detected changes — new deps, new dirs, stack drift. Preserve everything else untouched. | Setup exists and mostly works, repo just evolved |
| **Merge** | Generate the full ideal setup, then merge with existing — keep user customizations, add missing pieces, update stale parts. | Setup exists but is outdated or incomplete |
| **Replace** | Full regeneration. Back up existing to `pre-ccautomated` branch, then overwrite. | Setup is broken or user wants a clean slate |

3. Wait for the user's choice. Default to **Update** if no preference stated.

If **no existing setup** is detected, skip this step and proceed with full generation.

### 4. Plan
Synthesize all research into a generation plan. The plan MUST include a **per-file disposition table** showing what happens to each file:

```
| File | Exists? | Action | Rationale |
|------|---------|--------|-----------|
| CLAUDE.md | Yes (42 lines) | MERGE — append stack rules, keep existing | Has user-written context |
| settings.json | Yes | UPDATE — add missing hooks | Permissions look current |
| agents/researcher.md | Yes | KEEP — no changes | Already tailored |
| agents/mutagen.md | No | CREATE | Missing from setup |
| rules/tests.md | Yes | REPLACE — outdated | References old framework |
| .mcp.json | Yes | MERGE — add context7 | Has existing servers |
```

Valid per-file actions:
- **CREATE** — new file, doesn't exist yet
- **KEEP** — exists, no changes needed
- **UPDATE** — exists, apply targeted edits only
- **MERGE** — exists, generate ideal version, merge with existing (preserve user sections)
- **REPLACE** — exists, overwrite entirely

Present the plan to the user for approval.

### 5. Implement
Spawn the Implementer with:
- The approved plan including per-file disposition table
- The Target Profile
- The chosen strategy
- Any previous Reviewer feedback (if revision cycle)

### 6. Review
Spawn the Reviewer. If changes requested, iterate (max 3 cycles).

### 7. Record
Spawn Mutagen to log the generation in `.claude/mutagen-memory/version-history.md` and collect user feedback.

## What Gets Generated

For the target repo (subject to per-file actions above):
- `CLAUDE.md` — Project instructions tailored to the repo's stack
- `.claude/hooks/post-tool-use.sh` — Mutagen real-time usage logger (from template, made executable)
- `.claude/hooks/stop-session-metrics.sh` — Mutagen session metrics aggregator (from template, made executable)
- `.claude/settings.json` — Permissions, hooks referencing the scripts above, model config
- `.claude/agents/` — Agents tailored to the repo (including Mutagen + Mutagen Discovery)
- `.claude/skills/` — Stack-relevant skills
- `.claude/rules/` — Path-specific rules for the repo's structure
- `.mcp.json` — MCP servers relevant to the detected stack
- `.gitignore` additions — Ensure `.claude/`, `CLAUDE.md`, `.mcp.json` are gitignored

## Critical Requirements

- All generated agents must use `model: opus`
- The generated setup must be fully gitignored on the target repo
- Include a full Mutagen + Mutagen Discovery agent for autonomous evolution
- Include SessionStart, PostToolUse, and Stop hooks for the Mutagen system
- Security review is mandatory for all recommended plugins/MCP servers
- NEVER overwrite without user consent — always present the strategy choice first

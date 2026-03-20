# CCAutomated

CCAutomated is a meta-tool for generating optimal Claude Code setups on any repository. When you use Claude Code in this repo, it analyzes a target repository and generates the full Claude Code configuration (agents, skills, rules, hooks, settings, CLAUDE.md, .mcp.json) tailored to that repo.

## Architecture

- **Architect** runs as the main thread (configured via `"agent": "architect"` in settings.json)
- All agent spawning flows through the Architect — subagents cannot spawn sub-subagents
- The Implementer-Reviewer feedback loop is orchestrated by the Architect (max 3 cycles)

## Agents

| Agent | Role |
|-------|------|
| Architect | Entry-point orchestrator. Plans configs, spawns all other agents. |
| Code Researcher | Analyzes target repo codebase. Read-only, returns Target Profile. |
| Web Researcher | Searches web for best practices, MCP servers, plugins. |
| Implementer | Writes config files to target repo based on Architect's plan. |
| Reviewer | Reviews generated configs for quality, correctness, security. |
| Mutagen | Evolution engine. Advisory-only — discovers tools, proposes optimizations, creates skills. Never applies changes without user approval. |
| Mutagen Discovery | Web scout spawned by Mutagen to find new plugins/MCP servers/skills. |

## Core Rules

- **All agents use Opus 4.6** (or most recent version). No lesser models.
- The **Mutagen MUST be consulted** during every planning phase.
- Existing target configs require **strategy selection** (Update/Merge/Replace) — never overwrite without user consent. Default: Update (least invasive).
- **Security review is mandatory** for any recommended plugin/MCP server. Mutagen is advisory-only — all changes require user approval.
- Generated CLAUDE.md files must be **concise and succinct**.
- Templates in `templates/` are reference starting points — always customize per target.
- Generated `.claude/` setup is **fully gitignored** on target repos.

## Workflow

1. User runs `/generate-setup <path>` or describes target repo
2. Architect spawns Code Researcher → Target Profile (includes Existing Setup Analysis)
3. Architect spawns Web Researcher → best practices, available MCP servers
4. Architect spawns Mutagen → plugin recommendations, security evals, usage analysis
5. If existing setup detected → Architect presents strategy choice (Update / Merge / Replace, default: Update)
6. Architect synthesizes plan with per-file disposition table (CREATE/KEEP/UPDATE/MERGE/REPLACE), presents to user
7. Architect orchestrates Implementer → Reviewer feedback loop (max 3 cycles)
8. Architect spawns Mutagen to record version history and collect feedback

## Templates

Templates in `templates/` are used by the Implementer as starting points:
- `base/` — CLAUDE.md, settings.json, gitignore additions
- `stacks/` — Stack-specific fragments (TypeScript/Node, Python, Rust, Go, Monorepo)
- `agents/` — Template agent definitions generated into target repos

## Mutagen Evolution System

Each target repo gets a fully autonomous Mutagen agent with its own memory at `.claude/mutagen-memory/`. Mutagen is **advisory-only** — it never applies changes without explicit user approval.

It runs on SessionStart and:
- Reads its own plugin-registry, improvement-log, and pending-recommendations (no cross-repo dependency)
- Spawns Mutagen Discovery to search the web for new tools (skips already-evaluated ones)
- Analyzes usage logs for pruning candidates, skill opportunities, and high-frequency patterns
- For tools used 10+ times across sessions, runs efficiency analysis (faster alternatives, MCP equivalents, caching)
- Detects bash-to-builtin opportunities locally (e.g., `grep -r` → Grep tool)
- Writes ALL findings to `pending-recommendations.md` and greets the user with a summary
- User approves, rejects, or defers each recommendation — only then are changes applied
- Logs all evaluations to `plugin-registry.md` and all decisions to `improvement-log.md`

CCAutomated's own Mutagen memory is at `.claude/mutagen-memory/` (same structure, plus `version-history.md` and `user-feedback.md` for tracking generations).

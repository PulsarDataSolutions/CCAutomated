---
name: review-config
description: >
  Comprehensive review checklist for generated Claude Code configurations.
  Used by the Reviewer agent to validate quality, security, and completeness.
user-invocable: false
---

# Configuration Review Checklist

This skill provides the review framework for validating generated Claude Code setups.

## Validation Categories

### 1. Frontmatter Validation
For each `.md` file in `.claude/agents/` and `.claude/skills/*/SKILL.md`:
- Parse YAML frontmatter between `---` markers
- Verify required fields exist (name, description for agents; name for skills)
- Verify `model: opus` on all agents
- Verify tool names are valid Claude Code tools

### 2. JSON Validation
- `.claude/settings.json` must parse as valid JSON
- `.mcp.json` must parse as valid JSON
- All JSON keys must be documented Claude Code config keys

### 3. Security Scan
- Search all generated files for patterns: `password`, `secret`, `token`, `api_key`, `apiKey`, `API_KEY`
- Verify no file contains what looks like a credential
- Check permissions don't include `bypassPermissions`
- Check MCP server URLs don't contain embedded credentials

### 4. Consistency Check
- Agent names in frontmatter match the filename (e.g., `mutagen.md` has `name: mutagen`)
- Skills referenced in agent `skills:` lists exist in `.claude/skills/`
- MCP servers referenced in agent `mcpServers:` lists exist in `.mcp.json`

### 5. Gitignore Verification
- `.claude/` is in `.gitignore`
- `CLAUDE.md` is in `.gitignore`
- `.mcp.json` is in `.gitignore`

---
paths:
  - "templates/**"
  - ".claude/agents/**"
  - ".claude/skills/**"
---

# Configuration Quality Standards

- All agent `.md` files must have valid YAML frontmatter with at minimum: name, description, model
- The `model` field must always be set to `opus` (latest version)
- Agent descriptions must be clear enough for Claude to auto-delegate tasks to the right agent
- Tool lists in agent frontmatter must reference real Claude Code tools
- Skills must have proper frontmatter: name, description, argument-hint (if applicable)
- Generated CLAUDE.md files must be concise and succinct — no filler, no unnecessary verbosity
- Templates must use clear placeholder markers that the Implementer can find and replace
- Generated settings.json must use explicit permission allow-lists, not blanket access
- MCP server configs must specify valid server types (stdio, http, sse, ws)
- Hook configurations must use valid event names and matcher patterns
- Naming conventions: lowercase-with-hyphens for agents, skills, and rules

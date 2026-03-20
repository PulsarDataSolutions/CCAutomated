---
paths:
  - "**/*.md"
  - "**/*.json"
  - "**/*.tmpl"
---

# Security Rules

- NEVER include secrets, API keys, tokens, or credentials in generated configuration files
- NEVER set `permissionMode: bypassPermissions` in generated agent definitions
- NEVER enable plugins or MCP servers without a security evaluation by Mutagen
- All MCP servers must specify minimum required permissions — avoid overly broad access
- When generating `.claude/settings.json`, use explicit `allow` lists rather than blanket permissions
- Plugin security evaluation must check: source reputation, GitHub activity, permission requirements, data access scope
- Risk classification: LOW (auto-integrate), MEDIUM (flag for user review), HIGH (reject)
- Log all security decisions in `mutagen-history.md` with reasoning

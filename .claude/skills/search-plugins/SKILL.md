---
name: search-plugins
description: >
  Standalone plugin and MCP server discovery. Searches the web for Claude Code
  plugins, MCP servers, and skills relevant to a given tech stack. Can be used
  by Mutagen or invoked manually.
argument-hint: "<tech-stack e.g. 'typescript react next.js'>"
user-invocable: true
model: opus
---

# Search Plugins

Search for Claude Code plugins, MCP servers, and skills relevant to the specified tech stack.

## Tech Stack
`$ARGUMENTS`

## Search Sources

1. **Anthropic Official**
   - GitHub: `github.com/anthropics` — official MCP servers and plugins
   - Search: `anthropic MCP server $ARGUMENTS`

2. **GitHub**
   - Topics: `mcp-server`, `claude-code-plugin`, `claude-code-skill`
   - Search: `"mcp server" $ARGUMENTS`
   - Sort by: stars, recently updated

3. **Package Registries**
   - npm: `@modelcontextprotocol/*`, `claude-code-*`
   - PyPI: `mcp-server-*`

4. **Community**
   - Search: `claude code setup $ARGUMENTS`
   - Search: `claude code best practices $ARGUMENTS`
   - Blog posts and guides

## Output

For each finding:
- **Name** and source URL
- **Type**: MCP server / plugin / skill
- **Description**: What it does
- **Install**: How to install/configure
- **Metadata**: Stars, last commit, maintainer
- **Permissions**: What access it needs
- **Risk Assessment**: LOW / MEDIUM / HIGH with reasoning

## Security Notes
- Flag any tool requiring broad permissions (filesystem, network, shell)
- Note if maintainer is unknown or the project appears dormant
- Prefer official and well-established tools

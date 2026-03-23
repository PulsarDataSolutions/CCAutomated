---
name: dry-run
description: >
  Preview mode for CCAutomated. Runs the full analysis and planning pipeline
  for a target repository but does NOT write any files. Outputs what would be
  generated, allowing the user to review before committing to a full generation.
argument-hint: "<path-to-target-repo>"
user-invocable: true
model: opus
---

# Dry Run

You have been invoked with `/dry-run`. Run the full analysis pipeline but do NOT write any files.

## Target Repository Path
`$ARGUMENTS`

## Pipeline (Read-Only)

### 1. Analyze
Spawn Code Researcher to build a Target Profile for the repo.

### 2. Research
Spawn Web Researcher to find best practices and available tools for the detected stack.

### 3. Consult Mutagen
Spawn Mutagen for plugin recommendations and security evaluations.

### 4. Present Plan
Output a detailed preview of what `/generate-setup` would create:

```
## Dry Run Results for [repo-name]

### Target Profile
[Code Researcher's output]

### Files That Would Be Generated

#### CLAUDE.md
[Preview of contents — first 20 lines]

#### .claude/settings.json
[Preview of key settings]

#### .claude/agents/
- researcher.md — [description]
- implementer.md — [description]
- reviewer.md — [description]
- mutagen.md — [description]
- mutagen-discovery.md — [description]

#### .claude/skills/
- [skill-name] — [description]
- ...

#### .claude/rules/
- [rule-name] — [paths it applies to]
- ...

#### .mcp.json
- [server-name] — [type] — [description]
- ...

### Mutagen Recommendations
[Plugin/MCP recommendations with security evaluations]

### .gitignore Additions
[Lines that would be added]
```

## Important
- Do NOT write any files
- Do NOT create any directories in the target repo
- Do NOT modify the target repo in any way
- This is purely informational output

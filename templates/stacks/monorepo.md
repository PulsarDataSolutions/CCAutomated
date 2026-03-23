# Monorepo Stack Template

## Detection
- `nx.json` → Nx monorepo
- `turbo.json` → Turborepo
- `lerna.json` → Lerna
- `pnpm-workspace.yaml` → pnpm workspaces
- `package.json` with `workspaces` field → Yarn/npm workspaces
- Multiple `Cargo.toml` with workspace → Rust workspace
- Multiple `go.mod` → Go multi-module

## Recommended Permissions
Add permissions for the monorepo tool detected:
```json
"Bash(nx:*)", "Bash(turbo:*)", "Bash(lerna:*)"
```

## Agent Modifications

### Researcher
- Should map all workspace packages/apps
- Should detect shared libraries vs applications
- Should identify dependency graph between packages

### Implementer
- Should generate subdirectory `CLAUDE.md` files for major packages
- Should create path-specific rules for each workspace package
- Should configure agents to understand package boundaries

### Reviewer
- Should verify cross-package dependency consistency
- Should check that changes don't break other packages

## Recommended Skills

### /affected
Run affected/changed detection:
- Nx: `nx affected --target=test`
- Turbo: `turbo run test --filter=...[HEAD~1]`
- Lerna: `lerna changed`

### /graph
Show dependency graph: `nx graph` or `turbo run build --graph`

## Recommended Rules

### Per-package rules
Generate a rule file for each major package with its specific conventions, paths, and dependencies.

## CLAUDE.md Strategy
- Root `CLAUDE.md` describes overall architecture and shared conventions
- Each package gets a subdirectory `CLAUDE.md` with package-specific instructions
- Agents should be aware of package boundaries and shared code locations

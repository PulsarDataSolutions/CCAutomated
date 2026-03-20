# TypeScript/Node.js Stack Template

## Recommended MCP Servers
- **context7** — Documentation lookup for npm packages and frameworks
- **playwright** — Browser automation for testing (if frontend detected)

## Recommended Permissions
```json
"Bash(npm:*)", "Bash(npx:*)", "Bash(pnpm:*)", "Bash(yarn:*)",
"Bash(tsc:*)", "Bash(node:*)", "Bash(tsx:*)"
```

## Agent Modifications

### Researcher
- Should check `package.json` dependencies for framework detection
- Should read `tsconfig.json` for project configuration
- Should check for monorepo tools (nx, turbo, lerna)

### Implementer
- Should know about: ESLint, Prettier, Vitest/Jest, TypeScript strict mode
- Should use pnpm/npm/yarn as detected
- Common commands: `pnpm install`, `pnpm build`, `pnpm test`, `pnpm lint`

### Reviewer
- Should check for TypeScript strict mode compliance
- Should validate ESLint/Prettier configs are consistent
- Should check for proper type exports

## Recommended Skills

### /typecheck
Run `tsc --noEmit` to check types without building.

### /lint-fix
Run linter with auto-fix: `pnpm lint --fix` or `npx eslint --fix .`

### /test
Run test suite with coverage: `pnpm test` or `npx vitest run --coverage`

## Recommended Rules

### TypeScript files
```yaml
paths:
  - "**/*.ts"
  - "**/*.tsx"
```
- Use strict TypeScript — avoid `any` types
- Prefer `const` over `let`
- Use async/await over raw promises
- Export types explicitly

### React components (if detected)
```yaml
paths:
  - "**/*.tsx"
  - "**/components/**"
```
- Use functional components with hooks
- Props interfaces should be exported
- Use proper key props in lists

## Framework-Specific Notes

### Next.js
- App router vs Pages router detection (check for `app/` vs `pages/`)
- Server components vs client components (`"use client"` directive)
- API routes in `app/api/` or `pages/api/`

### Express/Fastify
- Route organization patterns
- Middleware chain awareness
- Error handling middleware

### NestJS
- Module/controller/service pattern
- Dependency injection awareness
- Decorator usage patterns

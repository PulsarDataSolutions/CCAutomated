# Go Stack Template

## Recommended MCP Servers
- **context7** — Documentation lookup for Go packages

## Recommended Permissions
```json
"Bash(go:*)", "Bash(golangci-lint:*)"
```

## Agent Modifications

### Researcher
- Should check `go.mod` for module name and dependencies
- Should detect web frameworks (Gin, Echo, Fiber) from imports
- Should identify project layout (standard Go project layout, flat, etc.)

### Implementer
- Should know about: golangci-lint, go vet, go test
- Common commands: `go build ./...`, `go test ./...`, `golangci-lint run`

## Recommended Skills

### /lint
Run `golangci-lint run` for comprehensive linting.

### /test
Run `go test ./... -v -race -cover` for tests with race detection and coverage.

## Recommended Rules

### Go files
```yaml
paths:
  - "**/*.go"
```
- Follow standard Go conventions (effective Go)
- Use error wrapping with `fmt.Errorf("context: %w", err)`
- Prefer interfaces for dependencies (testability)
- Use table-driven tests

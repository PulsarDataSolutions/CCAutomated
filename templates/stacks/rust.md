# Rust Stack Template

## Recommended MCP Servers
- **context7** — Documentation lookup for Rust crates

## Recommended Permissions
```json
"Bash(cargo:*)", "Bash(rustup:*)", "Bash(rustc:*)"
```

## Agent Modifications

### Researcher
- Should check `Cargo.toml` for dependencies and workspace config
- Should detect workspace members for monorepo setups
- Should identify web frameworks (Actix, Axum, Rocket) from dependencies

### Implementer
- Should know about: clippy, rustfmt, cargo test
- Common commands: `cargo build`, `cargo test`, `cargo clippy`, `cargo fmt`

## Recommended Skills

### /check
Run `cargo check` for fast compilation checking.

### /clippy
Run `cargo clippy -- -D warnings` for lint checking.

### /test
Run `cargo test` with optional `-- --nocapture` for output.

## Recommended Rules

### Rust files
```yaml
paths:
  - "**/*.rs"
```
- Follow Rust idioms — use Result/Option properly
- Prefer borrowing over cloning
- Use `#[derive(...)]` where appropriate
- Handle all error cases explicitly

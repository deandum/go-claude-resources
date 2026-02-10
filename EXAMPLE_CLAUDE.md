# Project: [PROJECT NAME]

> [One-line description of what this project does and why it exists.]

## Tech Stack

- **Language:** Go 1.23+
- **Router:** chi
- **Database:** MySQL with sqlx
- **Config:** envconfig (services) / Viper (CLI)
- **Logging:** slog (stdlib)
- **Metrics:** Prometheus
- **Tracing:** OpenTelemetry
- **Testing:** stdlib (default) or Ginkgo/Gomega (if adopted)
- **Linting:** golangci-lint

## Agent Workflow

**MANDATORY: Every user prompt MUST be routed to the go-critic agent first.** Do not begin any implementation, design, or analysis work until go-critic has analyzed the request and produced a structured task definition. No exceptions. If go-critic determines the task is already clear and well-scoped, it will say so and you may proceed immediately. If it finds gaps, resolve them before moving on.

After go-critic approves the task, use the appropriate agents:

1. **go-critic** - ALWAYS FIRST. Analyzes every prompt for clarity, completeness, and feasibility.
2. **go-architect** - Design phase. Package layout, interfaces, API surface. Use for new projects or structural changes.
3. **go-builder** - Implementation. Writes the application code following established patterns.
4. **go-cli-builder** - CLI-specific implementation with Cobra. Use instead of go-builder for CLI commands.
5. **go-tester** - Write and run tests after implementation.
6. **go-reviewer** - Code review. Read-only. Run after implementation and testing.
7. **go-shipper** - Containerization and observability. Dockerfile, logging, metrics, health checks.

## Do NOT

- Add features, abstractions, or "improvements" that weren't asked for
- Create helpers or utilities for one-time operations
- Add comments to code you didn't change or the code that is self documenting. Comments should be for critical decisions.
- Use `interface{}` / `any` when a concrete type or generic will do
- Run as root in containers
- Hardcode credentials, connection strings, or secrets
- Commit generated files, binaries, or `.env` files

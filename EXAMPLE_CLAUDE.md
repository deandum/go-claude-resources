# Project: [PROJECT NAME]

> [One-line description of what this project does and why it exists.]

## Tech Stack

<!-- Adjust for your language/framework -->
- **Language:** Go 1.24+
- **Router:** chi
- **Database:** MySQL with sqlx
- **Config:** envconfig (services) / Viper (CLI)
- **Logging:** slog (stdlib)
- **Metrics:** Prometheus
- **Tracing:** OpenTelemetry
- **Testing:** stdlib (default) or Ginkgo/Gomega (if adopted)
- **Linting:** golangci-lint

## Commands

```bash
# Build
go build -o bin/myservice ./cmd/myservice

# Test
go test -race -v ./...

# Lint
golangci-lint run

# Dev
go run ./cmd/myservice
```

## Agent Workflow

Use slash commands as entry points:

1. `/define` — ALWAYS FIRST. Clarifies requirements, generates structured spec.
2. `/plan` — Architecture and design. Package layout, interfaces.
3. `/build` — Implementation. Follows spec and established patterns.
4. `/test` — Tests after implementation. Prove-it pattern for bugs.
5. `/review` — Code review. Five axes, severity labels.
6. `/ship` — Docker, logging, metrics, health checks.
7. `/orchestrate` — Complex multi-step tasks. Decomposes into spec + waves.

## Boundaries

### Always do
- Run tests before commits
- Follow naming conventions from codebase
- Validate inputs at HTTP boundary
- Wrap errors with operation context
- Update spec if scope changes

### Ask first
- Database schema changes
- Adding external dependencies
- Changing CI/CD configuration
- Removing existing code or tests

### Never do
- Commit secrets, credentials, or .env files
- Run containers as root
- Hardcode connection strings
- Add features not in the spec
- Skip the critic/define step for non-trivial tasks

# Project: [PROJECT NAME]

> [One-line description of what this project does and why it exists.]

## Tech Stack

<!-- Adjust for your language/framework. Remove or add lines as needed. -->
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

<!-- These are the actual commands Claude should run. Keep them accurate. -->
```bash
# Build
go build -o bin/myservice ./cmd/myservice

# Test (with race detection)
go test -race -v ./...

# Lint
golangci-lint run

# Dev (local run)
go run ./cmd/myservice
```

## Agent Workflow

<!-- This maps slash commands to your project's workflow.
     Adjust if you skip certain phases or use them differently. -->

Use slash commands as entry points:

1. `/ideate` — Refine a vague idea into a clear task statement
2. `/define` — Clarify requirements, generate structured SPEC
3. `/plan` — Design architecture: package layout, interfaces, API surfaces
4. `/build` — Implement code following the SPEC and existing patterns
5. `/test` — Write tests after implementation. Prove-it pattern for bugs.
6. `/review` — Five-axis code review: correctness, readability, architecture, security, performance
7. `/ship` — Docker, logging, metrics, health checks
8. `/orchestrate` — Complex multi-step tasks: decompose into SPEC + waves
9. `/compact` — Adjust output verbosity: standard (default), compressed, or minimal

## Project Conventions

<!-- Add project-specific patterns that agents should follow.
     These help agents match your codebase style from the start. -->

- [e.g., All HTTP handlers live in internal/api/handlers/]
- [e.g., Repository interfaces are defined in the service package, not the repo package]
- [e.g., Error messages are lowercase, no punctuation]
- [e.g., Feature flags use the internal/flags package]

## Spec Files

<!-- Where SPEC files are stored and naming conventions. -->

- Location: `specs/` directory in project root
- Naming: `SPEC-[task-name].md` (kebab-case)
- Approved specs are committed to version control

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

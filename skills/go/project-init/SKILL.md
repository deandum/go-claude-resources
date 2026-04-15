---
name: go/project-init
description: >
  Go project scaffolding. Service/CLI/library directory structure,
  boilerplate, dependencies, tooling. Extends core/project-structure
  with Go-specific layouts and templates.
---

# Go Project Init

Scaffold production-ready Go projects with consistent structure and tooling.

## Workflow

1. Clarify project type (service, CLI, library)
2. Gather requirements (name, module path, database, API style)
3. Generate structure and boilerplate
4. Configure tooling (Makefile, Dockerfile, .golangci.yml)
5. Initialize module (`go mod init`, add dependencies)

## Service Structure

```
myservice/
├── cmd/myservice/main.go
├── internal/
│   ├── user/                     # Entity-focused package
│   │   ├── user.go               # Domain entity
│   │   ├── repository.go         # Interface (port)
│   │   ├── service.go            # Business logic
│   │   ├── http.go               # HTTP handlers
│   │   └── postgres.go           # Repository impl — uses connection from internal/postgres
│   ├── http/                     # Cross-cutting HTTP concerns
│   │   ├── middleware.go
│   │   └── router.go
│   ├── postgres/                 # Shared DB infrastructure
│   │   ├── conn.go               # Connection pool setup, exposed as *sqlx.DB
│   │   └── tx.go                 # Transaction helpers used by entity packages
│   └── config/config.go
├── migrations/
├── Makefile
├── Dockerfile
├── .golangci.yml
└── .gitignore
```

## CLI Structure

```
mytool/
├── cmd/mytool/main.go
├── internal/command/              # Cobra commands
│   ├── root.go
│   └── serve.go
├── Makefile
├── .goreleaser.yml
└── .golangci.yml
```

## Library Structure

```
mylib/
├── mylib.go                       # Public API
├── mylib_test.go
├── option.go                      # Functional options
├── internal/                      # Private implementation
└── examples/basic/main.go
```

## Dependencies

| Need | Recommended |
|------|-------------|
| HTTP router | `net/http` (stdlib) or `chi` |
| Logging | `log/slog` (stdlib) |
| Database | `pgx` (Postgres) or `sqlx` (generic SQL) |
| Migrations | `golang-migrate` |
| Config | `envconfig` |
| Validation | `go-playground/validator` |
| Testing | stdlib `testing` or Ginkgo/Gomega |
| CLI | Cobra |

**Principle:** a little copying is better than a little dependency.

## Boilerplate Templates

Use [templates/](templates/) — replace `{{.Module}}` and `{{.AppName}}` placeholders.

## Post-Scaffold Checklist

- `go mod tidy` runs cleanly
- `make lint` passes
- `make test` passes
- `make build` produces binary
- `docker build` succeeds
- README documents how to run locally

## Verification

- [ ] `go mod tidy` runs cleanly with no changes
- [ ] `make lint` passes with no warnings or errors
- [ ] `make test` passes with all tests green
- [ ] `make build` produces a working binary
- [ ] `docker build` succeeds and produces a valid image

---
name: go-project-init
description: >
  Scaffold a new Go project with clean architecture, proper structure,
  Makefile, Dockerfile, CI config, and linting setup. Use when starting
  a new Go service, CLI tool, or library from scratch.
---

# Go Project Init

Scaffold production-ready Go projects with consistent structure, tooling, and configuration.

## When to Apply

Use this skill when:
- Creating a new Go microservice or API
- Starting a new CLI tool
- Creating a new Go library
- Setting up a monorepo with multiple Go services
- The user says "new project", "init", "scaffold", or "bootstrap"

## Workflow

1. **Clarify project type** — service, CLI, or library
2. **Gather requirements** — name, module path, database, API style (REST/gRPC/both)
3. **Generate structure** — create directories and boilerplate files
4. **Configure tooling** — Makefile, Dockerfile, .golangci.yml, .gitignore
5. **Initialize module** — `go mod init`, add core dependencies
6. **Create entrypoint** — minimal `main.go` with proper wiring

## Project Types

### Service (HTTP/gRPC)

```
myservice/
├── cmd/
│   └── myservice/
│       └── main.go
├── internal/
│   ├── user/                     # Entity-focused package
│   │   ├── user.go               # Domain entity, value objects
│   │   ├── repository.go         # Repository interface (port)
│   │   ├── service.go            # Business logic / use cases
│   │   ├── http.go               # HTTP handlers for user
│   │   ├── grpc.go               # gRPC handlers (if applicable)
│   │   └── postgres.go           # Repository implementation
│   ├── order/                    # Another entity-focused package
│   │   ├── order.go
│   │   ├── service.go
│   │   ├── http.go
│   │   └── postgres.go
│   ├── http/                     # Cross-cutting: shared HTTP concerns
│   │   ├── middleware.go         # Auth, logging, CORS, etc.
│   │   ├── router.go             # Main router setup
│   │   └── errors.go             # Error handling utilities
│   ├── postgres/                 # Cross-cutting: DB infrastructure
│   │   ├── postgres.go           # Connection pooling, health checks
│   │   └── transaction.go        # Transaction utilities
│   ├── shared/                   # Cross-cutting: truly shared utilities
│   │   ├── validator.go          # Input validation
│   │   └── pagination.go         # Common pagination logic
│   └── config/
│       └── config.go             # Configuration from env/files
├── api/
│   └── openapi.yaml              # or proto/ for gRPC
├── migrations/
│   └── 001_init.up.sql
├── scripts/
│   └── dev-setup.sh
├── Makefile
├── Dockerfile
├── docker-compose.yml
├── .golangci.yml
├── .gitignore
├── go.mod
└── go.sum
```

#### Entity-Focused Package Philosophy

Each entity package (e.g., `user/`, `order/`) encapsulates:
- **Domain logic**: Entity types, value objects, validation rules
- **Ports**: Repository and service interfaces
- **Use cases**: Business logic and orchestration
- **Adapters**: HTTP handlers, gRPC handlers, database implementations

**Benefits**:
- High cohesion: related code lives together
- Low coupling: packages depend on each other via interfaces
- Easy navigation: working on "user" features means staying in `internal/user/`
- Natural scaling: adding entities doesn't bloat existing packages

**Cross-cutting packages** handle concerns that span multiple entities:
- `internal/http/`: Middleware, routing, error responses
- `internal/postgres/`: Connection pool, transaction helpers
- `internal/shared/`: Utilities genuinely used across entities (use sparingly)

**Dependency rules**:
- Entity packages can import other entity packages via interfaces
- Entity packages can import cross-cutting packages
- Cross-cutting packages should NOT import entity packages (avoid cycles)

### CLI Tool

```
mytool/
├── cmd/
│   └── mytool/
│       └── main.go
├── internal/
│   ├── command/                  # CLI commands
│   │   ├── root.go
│   │   └── serve.go
│   └── config/
│       └── config.go
├── Makefile
├── .goreleaser.yml
├── .golangci.yml
├── .gitignore
├── go.mod
└── go.sum
```

### Library

```
mylib/
├── mylib.go                     # Main package API
├── mylib_test.go
├── option.go                    # Functional options
├── internal/                    # Private implementation
│   └── parser/
├── examples/
│   └── basic/
│       └── main.go
├── .golangci.yml
├── .gitignore
├── go.mod
└── go.sum
```

## Boilerplate Files

### main.go (Service)

```go
package main

import (
    "context"
    "fmt"
    "log/slog"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"

    "{{.Module}}/internal/config"
)

func main() {
    if err := run(); err != nil {
        fmt.Fprintf(os.Stderr, "error: %v\n", err)
        os.Exit(1)
    }
}

func run() error {
    ctx, stop := signal.NotifyContext(context.Background(),
        syscall.SIGINT, syscall.SIGTERM)
    defer stop()

    cfg, err := config.Load("{{.AppName}}")
    if err != nil {
        return fmt.Errorf("loading config: %w", err)
    }

    var logLevel slog.Level
    if err := logLevel.UnmarshalText([]byte(cfg.LogLevel)); err != nil {
        return fmt.Errorf("invalid log level %q: %w", cfg.LogLevel, err)
    }

    logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
        Level: logLevel,
    }))
    slog.SetDefault(logger)

    // Initialize dependencies here:
    // db, err := postgres.New(ctx, cfg.DatabaseURL)
    // userRepo := user.NewPostgresRepository(db)
    // userSvc := user.NewService(userRepo)
    //
    // orderRepo := order.NewPostgresRepository(db)
    // orderSvc := order.NewService(orderRepo, userSvc)
    //
    // router := http.NewRouter(userSvc, orderSvc)

    srv := &http.Server{
        Addr:         cfg.Addr,
        // Handler:   router,
        ReadTimeout:  15 * time.Second,
        WriteTimeout: 15 * time.Second,
        IdleTimeout:  60 * time.Second,
    }

    errCh := make(chan error, 1)
    go func() {
        logger.Info("server starting", "addr", cfg.Addr)
        errCh <- srv.ListenAndServe()
    }()

    select {
    case err := <-errCh:
        return fmt.Errorf("server error: %w", err)
    case <-ctx.Done():
        logger.Info("shutting down gracefully")
    }

    shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
    defer cancel()

    return srv.Shutdown(shutdownCtx)
}
```

### config.go

```go
package config

import (
    "fmt"
    "time"

    "github.com/kelseyhightower/envconfig"
)

type Config struct {
    Addr        string        `default:":8080" split_words:"true"`
    LogLevel    string        `default:"info" split_words:"true"`
    DatabaseURL string        `required:"true" split_words:"true" envconfig:"DATABASE_URL"`
    Timeout     time.Duration `default:"15s" split_words:"true"`
}

// Load reads configuration from environment variables with the given prefix.
// For example, if prefix is "MYAPP", it will read MYAPP_ADDR, MYAPP_DATABASE_URL, etc.
func Load(prefix string) (*Config, error) {
    var cfg Config
    if err := envconfig.Process(prefix, &cfg); err != nil {
        return nil, fmt.Errorf("processing config: %w", err)
    }

    return &cfg, nil
}
```

### Makefile

```makefile
.PHONY: all build test lint run clean migrate

APP_NAME := {{.Name}}
BUILD_DIR := ./bin

all: lint test build

build:
	go build -o $(BUILD_DIR)/$(APP_NAME) ./cmd/$(APP_NAME)

run:
	go run ./cmd/$(APP_NAME)

test:
	go test -race -count=1 ./...

test-coverage:
	go test -race -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html

lint:
	golangci-lint run ./...

fmt:
	goimports -w .
	gofmt -s -w .

vet:
	go vet ./...

tidy:
	go mod tidy
	go mod verify

clean:
	rm -rf $(BUILD_DIR) coverage.out coverage.html

migrate-up:
	migrate -path migrations -database "$(DATABASE_URL)" up

migrate-down:
	migrate -path migrations -database "$(DATABASE_URL)" down 1

docker-build:
	docker build -t $(APP_NAME) .

docker-run:
	docker compose up -d
```

### Dockerfile (multi-stage)

```dockerfile
FROM golang:1.23-alpine AS builder

RUN apk add --no-cache git ca-certificates

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /app/bin/server ./cmd/{{.Name}}

FROM alpine:3.20

RUN apk add --no-cache ca-certificates tzdata
RUN adduser -D -g '' appuser

COPY --from=builder /app/bin/server /usr/local/bin/server

USER appuser

EXPOSE 8080

ENTRYPOINT ["server"]
```

### .gitignore

```
bin/
*.exe
*.out
coverage.out
coverage.html
.env
.env.local
vendor/
tmp/
```

### .golangci.yml

See the `go-style` skill for the recommended linting configuration.

## Dependencies to Consider

| Need | Recommended | Why |
|------|-------------|-----|
| HTTP router | `net/http` (stdlib) | Good enough for most cases since Go 1.22 |
| HTTP router (alternative) | `github.com/go-chi/chi/v5` | Lightweight, idiomatic, composable middleware, compatible with `net/http` |
| Structured logging | `log/slog` (stdlib) | Standard since Go 1.21, zero dependencies |
| Database (Postgres) | `github.com/jackc/pgx/v5` | Best Postgres driver for Go |
| Database (generic SQL) | `database/sql` + driver | Standard interface |
| Database extensions | `github.com/jmoiron/sqlx` | Extends `database/sql` with convenient helpers (Named queries, `Get`, `Select`) |
| Migrations | `github.com/golang-migrate/migrate` | Well-maintained, multiple DB support |
| Configuration | `github.com/kelseyhightower/envconfig` | Declarative config with struct tags, better than Viper for env-only config |
| Validation | `github.com/go-playground/validator/v10` | Powerful struct validation with tags, good for API input validation |
| gRPC | `google.golang.org/grpc` | Official gRPC implementation |
| Testing framework | stdlib `testing` | Table-driven tests are idiomatic |
| Testing framework (BDD) | `github.com/onsi/ginkgo/v2` + `github.com/onsi/gomega` | BDD-style testing with rich matchers, good for integration/e2e tests |
| Mocking | Interface-based manual mocks | Avoid heavy mocking frameworks |
| SQL mocking | `github.com/DATA-DOG/go-sqlmock` | Mock SQL driver for testing database interactions |

**Principle: a little copying is better than a little dependency.** Only add external dependencies when the stdlib cannot do the job, or the dependency genuinely augments it. 

## Post-Scaffold Checklist

- [ ] `go mod tidy` runs cleanly
- [ ] `make lint` passes
- [ ] `make test` passes
- [ ] `make build` produces a binary
- [ ] `docker build` succeeds
- [ ] README.md describes how to run locally
- [ ] `.env.example` documents required environment variables
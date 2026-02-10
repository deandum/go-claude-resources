---
name: go-style
description: >
  Idiomatic Go style, naming conventions, formatting with gofmt/goimports, and
  linting configuration. Use when questions arise about Go naming (package names,
  variable naming, initialisms), code organization (function length, receiver types,
  import grouping), interface design conventions, or when setting up golangci-lint.
  Also use for style-focused code reviews.
---

# Go Style

Apply idiomatic Go style and conventions derived from Effective Go, Google's Go Style Guide, Uber's Go Style Guide, and Go Code Review Comments.

## Contents

- [Go Style](#go-style)
  - [Contents](#contents)
  - [Core Principles](#core-principles)
  - [Formatting](#formatting)
  - [Naming](#naming)
    - [Packages](#packages)
    - [Variables and Functions](#variables-and-functions)
    - [Interfaces](#interfaces)
    - [Constants and Errors](#constants-and-errors)
  - [Struct Design](#struct-design)
    - [Make the zero value useful](#make-the-zero-value-useful)
    - [Constructor pattern](#constructor-pattern)
    - [Functional options for complex configuration](#functional-options-for-complex-configuration)
  - [Code Organization](#code-organization)
    - [Function length](#function-length)
    - [Receiver types](#receiver-types)
    - [Comments](#comments)
  - [Anti-Patterns to Flag](#anti-patterns-to-flag)
  - [Linting Configuration](#linting-configuration)

## Core Principles

**Clear is better than clever.** Every line of code should be immediately understandable to a new team member. Prefer explicit over implicit, boring over brilliant.

**Simplicity is not a starting point — it is a goal.** Don't add abstractions until the code demands them. Don't use generics when a concrete type suffices. Don't use channels when a mutex is clearer.

## Formatting

- Always use `gofmt` / `goimports` — this is non-negotiable
- Group imports in three blocks: stdlib, external, internal — separated by blank lines
- No manual alignment of struct fields or comments

```go
import (
    "context"
    "fmt"
    "net/http"

    "github.com/jackc/pgx/v5"
    "go.uber.org/zap"

    "github.com/myorg/myservice/internal/domain"
)
```

## Naming

### Packages
- Short, lowercase, single-word names: `user`, `order`, `auth`
- No underscores, no mixedCaps: `httputil` not `http_util` or `httpUtil`
- Package name describes what it *provides*, not what it *contains*
- Avoid `util`, `common`, `helpers`, `misc` — these are code smells
- The package name is part of the API: `http.Server` not `http.HTTPServer`

### Variables and Functions
- MixedCaps for exported names, mixedCaps for unexported
- Short names for narrow scopes: `i`, `r`, `w`, `ctx`
- Descriptive names for wider scopes: `userRepository`, `orderService`
- Getters: `Owner()` not `GetOwner()`. Setters: `SetOwner()`
- Initialisms are all caps: `URL`, `ID`, `HTTP`, `API` — `userID` not `userId`
- Boolean functions/methods: prefer `Is`, `Has`, `Can` prefixes
- Constructors: `NewServer()`, `NewClient(cfg Config)`

### Interfaces
- One-method interfaces: use method name + `-er` suffix: `Reader`, `Writer`, `Stringer`
- Keep interfaces small (1-5 methods ideal)
- Define interfaces where they are *used*, not where they are implemented. 
-  Exception: Standard library-style packages that provide foundational abstractions (like `io` or `http`) may define interfaces alongside implementations
- Accept interfaces, return concrete types

```go
// GOOD: interface defined by the consumer
package application

type UserRepository interface {
    FindByID(ctx context.Context, id string) (*domain.User, error)
}

type UserService struct {
    repo UserRepository
}

// BAD: interface defined alongside implementation
package postgres

type UserRepository interface { ... }
type userRepo struct { ... }
```

### Constants and Errors
- No `SCREAMING_SNAKE_CASE` — Go uses `MixedCaps` for constants too
- Error variables: `ErrNotFound`, `ErrTimeout`
- Error types: `*NotFoundError`, `*ValidationError`

```go
const MaxRetries = 3
const defaultTimeout = 30 * time.Second

var ErrNotFound = errors.New("not found")
```

## Struct Design

### Make the zero value useful
Design structs so that their zero value is valid and ready to use.

```go
// GOOD: zero value is a usable mutex
var mu sync.Mutex
mu.Lock()

// GOOD: zero value is an empty, usable buffer
var buf bytes.Buffer
buf.WriteString("hello")
```

### Constructor pattern
Use `New` functions when initialization is required:

```go
func NewServer(addr string, opts ...Option) *Server {
    s := &Server{
        addr:    addr,
        timeout: 30 * time.Second, // sensible default
    }
    for _, opt := range opts {
        opt(s)
    }
    return s
}
```

### Functional options for complex configuration

```go
type Option func(*Server)

func WithTimeout(d time.Duration) Option {
    return func(s *Server) { s.timeout = d }
}

func WithLogger(l *slog.Logger) Option {
    return func(s *Server) { s.logger = l }
}
```

## Code Organization

### Function length
- If a function is longer than ~100 lines, consider splitting it
- Each function should do exactly one thing well
- Early returns for error cases — keep the happy path at minimal indentation

```go
// GOOD: early returns, happy path unindented
func (s *Service) ProcessOrder(ctx context.Context, id string) error {
    order, err := s.repo.FindByID(ctx, id)
    if err != nil {
        return fmt.Errorf("finding order: %w", err)
    }

    if order.Status != StatusPending {
        return ErrOrderNotPending
    }

    // ... happy path continues at base indentation
}
```

### Receiver types
- If the method mutates the receiver: pointer receiver
- If the receiver is a large struct: pointer receiver
- If the receiver contains a sync.Mutex or similar: pointer receiver
- If the receiver is a map, func, or chan: value receiver
- If the receiver is a small struct or basic type with no mutation: value receiver
- Be consistent: if one method uses a pointer receiver, all methods should

### Comments
- All exported names must have doc comments
- Comments are full sentences starting with the name of the thing
- Comments explain *why*, not *what* (the code shows what)
- Package comments go in `doc.go` for multi-file packages

```go
// UserService coordinates user lifecycle operations including
// registration, authentication, and profile management.
type UserService struct { ... }

// FindByID retrieves a user by their unique identifier.
// It returns ErrNotFound if no user exists with the given ID.
func (s *UserService) FindByID(ctx context.Context, id string) (*User, error) {
```

## Anti-Patterns to Flag

- `interface{}` / `any` used when a concrete type would work
- God structs with more than 7-8 fields (consider splitting when appropriate)
- Interfaces with more than 5 methods (consider splitting when appropriate)
- Returning interfaces instead of concrete types
- `init()` functions — prefer explicit initialization
- Naked `bool` parameters — use named types or option structs
- Deep package nesting (more than 3 levels)

## Linting Configuration

Recommend this baseline `.golangci.yml` (a ready-to-use copy is available at [templates/golangci.yml](templates/golangci.yml)).

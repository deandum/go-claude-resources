---
name: go/style
description: >
  Go-specific style conventions. gofmt, naming, receiver types, import
  grouping, linting config. Extends core/style with Go idioms.
---

# Go Style

Derived from Effective Go, Google's Go Style Guide, Uber's Go Style Guide.

## Formatting

- Always use `gofmt`/`goimports` — non-negotiable. Local: `goimports -w ./...`. CI: `gofmt -l ./... | tee /dev/stderr` should produce no output (fail the build if it does).
- Import groups: stdlib, external, internal (separated by blank lines)

```go
import (
    "context"
    "fmt"

    "github.com/jackc/pgx/v5"

    "github.com/myorg/myservice/internal/domain"
)
```

## Naming

**Packages:** short, lowercase, single-word. No underscores/mixedCaps. `httputil` not `http_util`. Avoid `util`, `common`, `helpers`.

**Variables/Functions:** `MixedCaps` exported, `mixedCaps` unexported. Short for narrow scopes (`i`, `r`, `ctx`), descriptive for wide (`userRepository`).

**Initialisms:** all caps — `URL`, `ID`, `HTTP`, `API`. `userID` not `userId`.

**Getters/Setters:** `Owner()` not `GetOwner()`. `SetOwner()`.

**Interfaces:** `-er` suffix for single-method (`Reader`, `Writer`). Define where used, not implemented. Accept interfaces, return concrete types.

**Errors:** `ErrNotFound` (sentinel), `*NotFoundError` (type). No `SCREAMING_SNAKE_CASE`.

## Struct Design

- Make zero value useful: `var mu sync.Mutex; mu.Lock()`
- `New` constructors when init required
- Functional options for complex config: `WithTimeout(d)`, `WithLogger(l)`

## Receiver Types

- Mutates receiver → pointer
- Large struct → pointer
- Contains `sync.Mutex` → pointer
- Map, func, chan → value
- Small immutable struct → value
- **Be consistent across all methods on the same type.** If any method on `T` uses a pointer receiver (`*T`), every method on `T` should use a pointer receiver. Mixing pointer and value receivers on the same type is a bug waiting to happen — callers can silently lose writes, and method sets differ between `T` and `*T` in ways that break interface satisfaction.

## Code Organization

- Functions <100 lines. Early returns for errors. Happy path at minimal indentation.
- All exported names have doc comments (full sentences starting with name)
- Comments explain *why*, not *what*

## Anti-Patterns

- `any`/`interface{}` when concrete type works
- God structs (>7-8 fields)
- Interfaces >5 methods
- Returning interfaces instead of concrete types
- `init()` functions for business logic — acceptable only for side-effect registration (Cobra commands, flag parsers, test fixtures)
- Naked `bool` params (use named types)
- Deep package nesting (>3 levels)

## Linting

Use `.golangci.yml` from [templates/golangci.yml](templates/golangci.yml).

## Verification

- [ ] `gofmt -l ./...` produces no output
- [ ] `goimports -w ./...` has been run (import groups stdlib / external / internal)
- [ ] `golangci-lint run` passes with no warnings or errors
- [ ] Initialisms are all caps (`ID`, `URL`, `HTTP`, `API` — not `Id`, `Url`)
- [ ] All exported types, functions, and constants have doc comments
- [ ] Receiver types are consistent within each type (all pointer or all value)

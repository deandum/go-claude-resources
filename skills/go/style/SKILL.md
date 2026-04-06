---
name: go/style
description: >
  Go-specific style conventions. gofmt, naming, receiver types, import
  grouping, linting config. Extends core/style with Go idioms.
---

# Go Style

Derived from Effective Go, Google's Go Style Guide, Uber's Go Style Guide.

## Formatting

- Always use `gofmt`/`goimports` — non-negotiable
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
- Contains sync.Mutex → pointer
- Map, func, chan → value
- Small immutable struct → value
- Be consistent across all methods

## Code Organization

- Functions <100 lines. Early returns for errors. Happy path at minimal indentation.
- All exported names have doc comments (full sentences starting with name)
- Comments explain *why*, not *what*

## Anti-Patterns

- `any`/`interface{}` when concrete type works
- God structs (>7-8 fields)
- Interfaces >5 methods
- Returning interfaces instead of concrete types
- `init()` functions (prefer explicit init)
- Naked `bool` params (use named types)
- Deep package nesting (>3 levels)

## Linting

Use `.golangci.yml` from [templates/golangci.yml](templates/golangci.yml).

## Verification

- [ ] `gofmt`/`goimports` applied with no formatting diff
- [ ] `golangci-lint run` passes with no warnings or errors
- [ ] Initialisms are all caps (`ID`, `URL`, `HTTP`, `API` — not `Id`, `Url`)
- [ ] All exported types, functions, and constants have doc comments

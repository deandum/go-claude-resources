---
name: go-error-handling
description: >
  Structured error handling patterns for Go. Use when designing error
  strategies, wrapping errors, creating sentinel errors, custom error
  types, or when reviewing error handling in Go code.
---

# Go Error Handling

Errors are values. Don't just check errors — handle them gracefully.

## When to Apply

Use this skill when:
- Designing error handling strategy for a package or service
- Wrapping or propagating errors
- Creating custom error types or sentinel errors
- Reviewing code for proper error handling
- Deciding between `errors.New`, `fmt.Errorf`, and custom types

## Decision Framework

Ask these questions in order:

1. **Does the caller need to programmatically distinguish this error?**
   - Yes → sentinel error variable or custom error type
   - No → `fmt.Errorf` with `%w` wrapping is sufficient

2. **Is the error a static string with no runtime context?**
   - Yes → `errors.New` or sentinel `var Err...`
   - No → `fmt.Errorf` or custom type with fields

3. **Does the error carry structured data the caller needs?**
   - Yes → custom error type
   - No → wrapped error with context string

## Patterns

### Pattern 1: Simple Error Wrapping (Most Common)

The default. Add context as you propagate up the stack.

```go
func (s *UserService) Activate(ctx context.Context, id string) error {
    user, err := s.repo.FindByID(ctx, id)
    if err != nil {
        return fmt.Errorf("finding user %s: %w", id, err)
    }

    if err := s.mailer.SendWelcome(ctx, user.Email); err != nil {
        return fmt.Errorf("sending welcome email to %s: %w", user.Email, err)
    }

    return nil
}
```

**Rules for wrap messages:**
- Use lowercase, no trailing punctuation
- Describe the operation that failed: `"finding user"`, `"connecting to database"`
- Include relevant identifiers: `"finding user %s"` not just `"finding user"`
- Use `%w` to preserve the error chain for `errors.Is` / `errors.As`

### Pattern 2: Sentinel Errors

Use for errors the caller must detect and handle differently.

```go
package domain

import "errors"

var (
    ErrNotFound      = errors.New("not found")
    ErrAlreadyExists = errors.New("already exists")
    ErrForbidden     = errors.New("forbidden")
)
```

Callers check with `errors.Is`:

```go
user, err := svc.FindByID(ctx, id)
if errors.Is(err, domain.ErrNotFound) {
    http.Error(w, "user not found", http.StatusNotFound)
    return
}
if err != nil {
    http.Error(w, "internal error", http.StatusInternalServerError)
    return
}
```

**When to use sentinels:**
- The error represents a well-known condition (not found, conflict, unauthorized)
- Multiple callers need to branch on this condition
- The error message is static

### Pattern 3: Custom Error Types

Use when errors carry structured data the caller needs.

```go
type ValidationError struct {
    Field   string
    Message string
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("validation: %s: %s", e.Field, e.Message)
}

type NotFoundError struct {
    Resource string
    ID       string
}

func (e *NotFoundError) Error() string {
    return fmt.Sprintf("%s %s not found", e.Resource, e.ID)
}
```

Callers extract with `errors.As`:

```go
var notFound *domain.NotFoundError
if errors.As(err, &notFound) {
    http.Error(w, notFound.Error(), http.StatusNotFound)
    return
}

var valErr *domain.ValidationError
if errors.As(err, &valErr) {
    // Return structured validation error to the client
    writeJSON(w, http.StatusBadRequest, map[string]string{
        "field":   valErr.Field,
        "message": valErr.Message,
    })
    return
}
```

### Pattern 4: Multi-Error Collection

For operations that can fail in multiple independent ways:

```go
func (c *Config) Validate() error {
    var errs []error

    if c.Addr == "" {
        errs = append(errs, fmt.Errorf("addr is required"))
    }
    if c.Timeout <= 0 {
        errs = append(errs, fmt.Errorf("timeout must be positive"))
    }
    if c.MaxRetries < 0 {
        errs = append(errs, fmt.Errorf("max_retries must be non-negative"))
    }

    return errors.Join(errs...)
}
```

### Pattern 5: Error Handling in HTTP Handlers

Map domain errors to HTTP responses at the boundary:

```go
func (h *Handler) GetUser(w http.ResponseWriter, r *http.Request) {
    id := r.PathValue("id")

    user, err := h.svc.FindByID(r.Context(), id)
    if err != nil {
        h.handleError(w, r, err)
        return
    }

    writeJSON(w, http.StatusOK, user)
}

func (h *Handler) handleError(w http.ResponseWriter, r *http.Request, err error) {
    switch {
    case errors.Is(err, domain.ErrNotFound):
        writeJSON(w, http.StatusNotFound, errorResponse("not found"))
    case errors.Is(err, domain.ErrForbidden):
        writeJSON(w, http.StatusForbidden, errorResponse("forbidden"))
    default:
        var valErr *domain.ValidationError
        if errors.As(err, &valErr) {
            writeJSON(w, http.StatusBadRequest, valErr)
            return
        }

        h.logger.Error("unhandled error",
            "error", err,
            "method", r.Method,
            "path", r.URL.Path,
        )
        writeJSON(w, http.StatusInternalServerError, errorResponse("internal error"))
    }
}
```

## Anti-Patterns

### Don't panic
`panic` is for programmer bugs (invalid state, impossible conditions), never for runtime errors. Don't use it for "file not found" or "connection refused".

```go
// BAD
func MustParseConfig(path string) *Config {
    cfg, err := ParseConfig(path)
    if err != nil {
        panic(err) // Don't do this in libraries
    }
    return cfg
}

// ACCEPTABLE only in main() or test setup
func main() {
    cfg := MustParseConfig("config.yaml") // OK here, program can't continue
}
```

### Don't ignore errors

```go
// BAD
json.Unmarshal(data, &result)

// GOOD
if err := json.Unmarshal(data, &result); err != nil {
    return fmt.Errorf("unmarshaling response: %w", err)
}
```

### Don't use string matching

```go
// BAD
if strings.Contains(err.Error(), "not found") { ... }

// GOOD
if errors.Is(err, domain.ErrNotFound) { ... }
```

### Don't over-wrap

```go
// BAD: redundant wrapping
func (r *repo) FindByID(ctx context.Context, id string) (*User, error) {
    user, err := r.db.QueryRow(ctx, query, id)
    if err != nil {
        return nil, fmt.Errorf("error in FindByID: failed to query: %w", err)
        // "error in FindByID" is redundant — the caller knows which function it called
    }
}

// GOOD: add useful context only
func (r *repo) FindByID(ctx context.Context, id string) (*User, error) {
    user, err := r.db.QueryRow(ctx, query, id)
    if err != nil {
        return nil, fmt.Errorf("querying user %s: %w", id, err)
    }
}
```

### Don't log and return

```go
// BAD: error is logged twice — here and by the caller
if err != nil {
    log.Error("failed to find user", "error", err)
    return fmt.Errorf("finding user: %w", err)
}

// GOOD: return with context, let the caller decide whether to log
if err != nil {
    return fmt.Errorf("finding user: %w", err)
}
```

## Package-Level Error Strategy

Each package should document its error contract:

```go
// Package order manages order lifecycle operations.
//
// Errors:
//   - ErrNotFound: the requested order does not exist
//   - ErrAlreadyShipped: the order has already been shipped and cannot be modified
//   - *ValidationError: the order data is invalid (check Field and Message)
package order
```
---
name: go-error-handling
description: >
  Structured error handling patterns for Go. Use when designing error
  strategies, wrapping errors, creating sentinel errors, custom error
  types, using errors.Is/errors.As, mapping errors to HTTP responses,
  or when reviewing error handling in Go code.
---

# Go Error Handling

Errors are values. Don't just check errors — handle them gracefully.

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

### Pattern 1: Error Wrapping Rules

The default pattern. Wrap with `fmt.Errorf("operation: %w", err)` as you propagate up.

- Use lowercase, no trailing punctuation
- Describe the operation that failed: `"finding user"`, `"connecting to database"`
- Include relevant identifiers: `"finding user %s"` not just `"finding user"`
- Use `%w` to preserve the error chain for `errors.Is` / `errors.As`

### Pattern 2: Sentinel Errors

Use for well-known conditions that multiple callers need to branch on. Define in domain package, check with `errors.Is`:

```go
var (
    ErrNotFound      = errors.New("not found")
    ErrAlreadyExists = errors.New("already exists")
    ErrForbidden     = errors.New("forbidden")
)
```

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

- **Don't panic** — `panic` is for programmer bugs only (invalid state, impossible conditions). `Must*` functions are acceptable only in `main()` or test setup
- **Don't ignore errors** — Every error return must be checked
- **Don't use string matching** — Use `errors.Is`/`errors.As`, never `strings.Contains(err.Error(), ...)`
- **Don't over-wrap** — Add useful context, not redundant function names: `"querying user %s: %w"` not `"error in FindByID: failed to query: %w"`
- **Don't log and return** — Either log or return with context, never both (causes duplicate logging)

## Package-Level Error Strategy

Document each package's error contract:

```go
// Package order manages order lifecycle operations.
//
// Errors:
//   - ErrNotFound: the requested order does not exist
//   - ErrAlreadyShipped: the order has already been shipped and cannot be modified
//   - *ValidationError: the order data is invalid (check Field and Message)
package order
```
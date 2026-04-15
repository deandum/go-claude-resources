---
name: go/error-handling
description: >
  Go error handling patterns. Wrapping with fmt.Errorf, sentinel errors,
  custom types, errors.Is/As, HTTP error mapping. Extends core/error-handling
  with Go-specific implementations.
---

# Go Error Handling

Errors are values. Use `fmt.Errorf` with `%w` for wrapping. Check with `errors.Is`/`errors.As`.

## Pattern 1: Error Wrapping

```go
// Default: wrap with context as you propagate up
return fmt.Errorf("finding user %s: %w", id, err)
```

- Use `%w` to preserve chain for `errors.Is`/`errors.As`
- Lowercase, no trailing punctuation
- Describe operation + identifiers: `"finding user %s"` not `"error in FindByID"`

## Pattern 2: Sentinel Errors

```go
var (
    ErrNotFound      = errors.New("not found")
    ErrAlreadyExists = errors.New("already exists")
    ErrForbidden     = errors.New("forbidden")
)
```

Check with `errors.Is(err, ErrNotFound)`.

## Pattern 3: Custom Error Types

```go
type ValidationError struct {
    Field   string
    Message string
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("validation: %s: %s", e.Field, e.Message)
}
```

Extract with `errors.As`:

```go
var valErr *ValidationError
if errors.As(err, &valErr) {
    writeJSON(w, http.StatusBadRequest, map[string]string{
        "field": valErr.Field, "message": valErr.Message,
    })
    return
}
```

## Pattern 4: Multi-Error Collection

```go
func (c *Config) Validate() error {
    var errs []error
    if c.Addr == "" {
        errs = append(errs, fmt.Errorf("addr is required"))
    }
    if c.Timeout <= 0 {
        errs = append(errs, fmt.Errorf("timeout must be positive"))
    }
    return errors.Join(errs...)
}
```

`errors.Join` returns a single error that wraps all non-nil inputs. Callers can check for specific sentinels via `errors.Is` (which walks the full tree of joined errors). To enumerate all wrapped errors individually, type-assert to the `interface{ Unwrap() []error }` interface:

```go
err := cfg.Validate()
if err != nil {
    if joined, ok := err.(interface{ Unwrap() []error }); ok {
        for _, e := range joined.Unwrap() {
            logger.Error("config validation failed", "error", e)
        }
    }
    return err
}
```

Use this when the caller needs to report each failure individually (e.g., writing field-level validation errors to an HTTP response).

## Pattern 5: HTTP Error Mapping

Map domain errors to HTTP responses at the boundary:

```go
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
        h.logger.Error("unhandled error", "error", err, "path", r.URL.Path)
        writeJSON(w, http.StatusInternalServerError, errorResponse("internal error"))
    }
}
```

## Package-Level Error Contract

```go
// Package order manages order lifecycle operations.
//
// Errors:
//   - ErrNotFound: the requested order does not exist
//   - ErrAlreadyShipped: cannot modify shipped order
//   - *ValidationError: invalid order data (check Field and Message)
package order
```

## Anti-Patterns

- **Don't panic** — only for programmer bugs. `Must*` acceptable only in `main()` or test setup
- **Don't ignore errors** — every `err` return must be checked
- **Don't string match** — use `errors.Is`/`errors.As`, never `strings.Contains(err.Error(), ...)`
- **Don't over-wrap** — `"querying user %s: %w"` not `"error in FindByID: failed to query: %w"`
- **Don't log and return** — either log or return with context, never both

## Verification

- [ ] `go vet ./...` passes with no diagnostics
- [ ] No bare `return err` — all errors wrapped with `fmt.Errorf("context: %w", err)`
- [ ] `errors.Is`/`errors.As` used for error checks (no `strings.Contains(err.Error(), ...)`)
- [ ] Errors include operation context and relevant identifiers when wrapped

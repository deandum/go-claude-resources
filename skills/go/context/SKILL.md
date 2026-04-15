---
name: go/context
description: >
  Go context propagation, cancellation, timeouts, and value storage.
  Use when managing request lifecycles, implementing timeouts, or
  coordinating goroutine cancellation. 100% Go-specific.
---

# Go Context

Context is the first parameter, flows through call chains, never lives in structs.

## Decision Framework: Context Creation

| Create Context | Use Case |
|---|---|
| `context.Background()` | Top-level (main, tests, init) |
| `context.TODO()` | Placeholder when unclear |
| `WithTimeout(parent, d)` | Operations with time limits |
| `WithCancel(parent)` | Manual cancellation needed |
| `WithDeadline(parent, t)` | Absolute deadline |
| `WithValue(parent, k, v)` | Request-scoped data |
| `WithoutCancel(parent)` | Detach from parent cancellation (Go 1.21+) |

## Pattern 1: HTTP Handler with Timeout

```go
func (h *Handler) GetUser(w http.ResponseWriter, r *http.Request) {
    ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
    defer cancel()

    user, err := h.repo.FindByID(ctx, userID)
    if errors.Is(err, context.DeadlineExceeded) {
        http.Error(w, "request timeout", http.StatusGatewayTimeout)
        return
    }
}
```

## Pattern 2: Type-Safe Context Values

```go
type contextKey string
const traceIDKey contextKey = "trace_id"

func WithTraceID(ctx context.Context, id string) context.Context {
    return context.WithValue(ctx, traceIDKey, id)
}

func GetTraceID(ctx context.Context) (string, bool) {
    id, ok := ctx.Value(traceIDKey).(string)
    return id, ok
}
```

**Rules:** custom type for keys, accessor functions for type safety, context values = request-scoped immutable data only.

## When to Use Context Values vs Parameters

| Context Values | Explicit Parameters |
|---|---|
| Request metadata (trace IDs, correlation IDs) | Business logic parameters |
| Auth credentials (user ID, tokens) | Function behavior config |
| Cross-cutting concerns (logging, tracing) | Domain data and entities |

## Pattern 3: Detach from Cancellation (Go 1.21+)

```go
// Post-response async work that must not cancel with the HTTP request
go h.mailer.SendConfirmation(context.WithoutCancel(r.Context()), order)
```

Preserves parent's values (trace ID) but outlives parent's cancellation.

## Anti-Patterns

- **Storing context in struct** — always pass as first parameter
- **String keys** — use custom types to prevent collisions
- **Ignoring cancellation** — check `ctx.Done()` in loops
- **Background in inner functions** — pass parent context through

## Verification

- [ ] `context.Context` is the first parameter in every function that accepts one
- [ ] No `context.Context` stored in struct fields
- [ ] Custom key types used for context values (not bare `string`)
- [ ] `WithTimeout`/`WithCancel` always paired with `defer cancel()`

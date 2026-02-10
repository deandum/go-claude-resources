---
name: go-context
description: >
  Context propagation, cancellation, timeouts, and value storage patterns.
  Use when managing request lifecycles, implementing timeouts, storing
  context values with type-safe context keys, or coordinating goroutine
  cancellation across service boundaries.
---

# Go Context

Context is the first parameter, flows through call chains, never lives in structs.

## Decision Framework: Context Creation

| Create Context | Use Case | Example |
|---|---|---|
| `context.Background()` | Top-level (main, tests, initialization) | Program startup, test setup |
| `context.TODO()` | Placeholder when context unclear | Refactoring legacy code |
| `WithTimeout(parent, duration)` | Operations with time limits | HTTP calls, database queries |
| `WithCancel(parent)` | Manual cancellation needed | Worker pools, streaming |
| `WithDeadline(parent, time)` | Absolute deadline | Batch jobs, scheduled tasks |
| `WithValue(parent, key, val)` | Request-scoped data | Trace IDs, user context |
| `WithoutCancel(parent)` | Detach from parent cancellation (Go 1.21+) | Background work after response sent |

**Decision Rule**: Start with Background/TODO at boundaries, derive child contexts with timeouts/cancellation as needed.

## Pattern 1: HTTP Handler with Timeout

Every HTTP handler receives a context. Derive child contexts for downstream calls.

```go
func (h *Handler) GetUser(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context() // Always use request context

	// Add timeout for database query
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	user, err := h.repo.FindByID(ctx, userID)
	if err != nil {
		if errors.Is(err, context.DeadlineExceeded) {
			http.Error(w, "request timeout", http.StatusGatewayTimeout)
			return
		}
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	json.NewEncoder(w).Encode(user)
}
```

## Pattern 2: Type-Safe Context Values

Use custom types for context keys to avoid collisions.

```go
type contextKey string

const (
	traceIDKey  contextKey = "trace_id"
	userIDKey   contextKey = "user_id"
)

// Store value in context
func WithTraceID(ctx context.Context, traceID string) context.Context {
	return context.WithValue(ctx, traceIDKey, traceID)
}

// Retrieve value from context
func GetTraceID(ctx context.Context) (string, bool) {
	traceID, ok := ctx.Value(traceIDKey).(string)
	return traceID, ok
}

// Usage in middleware
func TracingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		traceID := r.Header.Get("X-Trace-ID")
		if traceID == "" {
			traceID = uuid.New().String()
		}

		ctx := WithTraceID(r.Context(), traceID)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}
```

**Rules:**
- Use custom type for keys (not string or int)
- Create accessor functions (WithX, GetX) for type safety
- Context values should be request-scoped, immutable data
- Avoid using context for optional parameters

## Goroutine Cancellation

For patterns on using context to coordinate goroutine lifecycle (errgroup, worker pools, fan-out), see the `go-concurrency` skill.

## Decision Framework: When to Use Context Values

| Use Context Values | Use Explicit Parameters |
|---|---|
| Request-scoped data (trace IDs, correlation IDs) | Business logic parameters |
| Authentication credentials (user ID, tokens) | Function behavior configuration |
| Cross-cutting concerns (logging, tracing) | Domain data and entities |
| Data that flows through middleware | Optional parameters |

**Decision Rule**: Ask "Is this data about the request itself, or is it a business parameter?" Request metadata → context. Business data → parameters.

## Pattern 3: Detaching from Cancellation (Go 1.21+)

Use `context.WithoutCancel` when work must continue after the parent context is cancelled, while preserving the parent's values.

```go
func (h *Handler) SubmitOrder(w http.ResponseWriter, r *http.Request) {
	order, err := h.orders.Create(r.Context(), req)
	if err != nil {
		http.Error(w, "failed", http.StatusInternalServerError)
		return
	}

	// Send confirmation email after responding — must not be cancelled
	// when the HTTP request ends. Values (trace ID, user ID) are preserved.
	go h.mailer.SendConfirmation(context.WithoutCancel(r.Context()), order)

	json.NewEncoder(w).Encode(order)
}
```

**When to use**: Post-response async work (emails, audit logs, cache warming) that needs the parent's values but must outlive the parent's cancellation. Prefer this over `context.Background()` to retain request-scoped values like trace IDs.

## Anti-Patterns

### Storing context in struct

```go
// BAD: Context stored in struct
type Service struct {
	ctx context.Context
	db  *sql.DB
}

func (s *Service) DoWork() error {
	return s.db.QueryRowContext(s.ctx, "SELECT ...") // Stale context!
}

// GOOD: Context passed as parameter
type Service struct {
	db *sql.DB
}

func (s *Service) DoWork(ctx context.Context) error {
	return s.db.QueryRowContext(ctx, "SELECT ...")
}
```

- **String keys for context values** — Use custom types (see Pattern 2), never bare strings or ints
- **Ignoring context cancellation** — Always check `ctx.Done()` in loops; use `select` with ticker instead of `time.Sleep`
- **Creating Background context in inner functions** — Never create `context.Background()` inside a call chain; pass the parent context through
- **Unrealistic timeouts** — Set timeouts based on expected operation duration, not arbitrary values


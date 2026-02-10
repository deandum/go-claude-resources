---
name: go-context
description: >
  Context propagation, cancellation, timeouts, and value storage patterns.
  Use when managing request lifecycles, implementing timeouts, or coordinating
  goroutine cancellation across service boundaries.
---

# Go Context

Context is the first parameter, flows through call chains, never lives in structs.

## When to Apply

Use this skill when:
- Implementing request-scoped cancellation or timeouts
- Propagating deadlines across service boundaries (HTTP, gRPC, database)
- Coordinating graceful shutdown of goroutines
- Storing request-scoped values (trace IDs, auth tokens)
- Reviewing code that uses context.Context

## Decision Framework: Context Creation

| Create Context | Use Case | Example |
|---|---|---|
| `context.Background()` | Top-level (main, tests, initialization) | Program startup, test setup |
| `context.TODO()` | Placeholder when context unclear | Refactoring legacy code |
| `WithTimeout(parent, duration)` | Operations with time limits | HTTP calls, database queries |
| `WithCancel(parent)` | Manual cancellation needed | Worker pools, streaming |
| `WithDeadline(parent, time)` | Absolute deadline | Batch jobs, scheduled tasks |
| `WithValue(parent, key, val)` | Request-scoped data | Trace IDs, user context |

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

**Rules:**
- Use `r.Context()` from HTTP request, never create new Background context
- Always defer cancel() immediately after creating context
- Check for context.DeadlineExceeded and context.Canceled errors
- Timeout should be less than HTTP server timeout

## Pattern 2: Database Queries with Context

Pass context to all database operations for cancellation support.

```go
type Repository struct {
	db *sqlx.DB
}

func (r *Repository) FindByID(ctx context.Context, id int64) (*User, error) {
	var user User

	// Use QueryRowContext, not QueryRow
	err := r.db.QueryRowContext(ctx,
		"SELECT id, name, email FROM users WHERE id = ?", id,
	).Scan(&user.ID, &user.Name, &user.Email)

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("user not found: %w", err)
	}
	if err != nil {
		return nil, fmt.Errorf("query failed: %w", err)
	}

	return &user, nil
}
```

**Rules:**
- Use QueryContext, ExecContext, not Query/Exec
- Context propagates cancellation to database driver
- Database will abort query if context is canceled
- Respect context errors (DeadlineExceeded, Canceled)

## Pattern 3: Type-Safe Context Values

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

## Pattern 4: Coordinating Goroutine Cancellation

Use context to signal shutdown to multiple goroutines.

```go
func (s *Service) Start(ctx context.Context) error {
	g, ctx := errgroup.WithContext(ctx)

	// Worker 1: Process queue
	g.Go(func() error {
		return s.processQueue(ctx)
	})

	// Worker 2: Health checks
	g.Go(func() error {
		return s.healthChecker(ctx)
	})

	return g.Wait() // Returns first error or nil
}

func (s *Service) processQueue(ctx context.Context) error {
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			if err := s.processItem(ctx); err != nil {
				return err
			}
		case <-ctx.Done():
			// Context canceled, shut down gracefully
			return ctx.Err()
		}
	}
}
```

**Rules:**
- Check ctx.Done() in loops to respect cancellation
- Use errgroup.WithContext for managing multiple goroutines
- Return ctx.Err() when context is done
- Ensure all goroutines can exit when context is canceled

## Pattern 5: Timeout Configuration by Layer

Different operations need different timeout values.

```go
const (
	// HTTP client timeouts
	httpDialTimeout      = 5 * time.Second
	httpRequestTimeout   = 10 * time.Second

	// Database timeouts
	dbQueryTimeout       = 3 * time.Second
	dbTransactionTimeout = 10 * time.Second

	// External API timeouts
	apiCallTimeout       = 15 * time.Second
)

func (c *Client) FetchUser(ctx context.Context, id int64) (*User, error) {
	// Create timeout for entire operation
	ctx, cancel := context.WithTimeout(ctx, apiCallTimeout)
	defer cancel()

	// Make HTTP request (will inherit parent timeout)
	req, _ := http.NewRequestWithContext(ctx, "GET",
		fmt.Sprintf("/users/%d", id), nil)

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()

	// Parse response...
	var user User
	if err := json.NewDecoder(resp.Body).Decode(&user); err != nil {
		return nil, fmt.Errorf("decode failed: %w", err)
	}

	return &user, nil
}
```

## Decision Framework: When to Use Context Values

| Use Context Values | Use Explicit Parameters |
|---|---|
| Request-scoped data (trace IDs, correlation IDs) | Business logic parameters |
| Authentication credentials (user ID, tokens) | Function behavior configuration |
| Cross-cutting concerns (logging, tracing) | Domain data and entities |
| Data that flows through middleware | Optional parameters |

**Decision Rule**: Ask "Is this data about the request itself, or is it a business parameter?" Request metadata → context. Business data → parameters.

## Pattern 6: Testing with Context

Control timeouts and cancellation in tests.

```go
func TestRepository_FindByID(t *testing.T) {
	t.Run("success", func(t *testing.T) {
		ctx := context.Background()
		repo := setupRepo(t)

		user, err := repo.FindByID(ctx, 1)
		require.NoError(t, err)
		assert.Equal(t, "Alice", user.Name)
	})

	t.Run("timeout", func(t *testing.T) {
		ctx, cancel := context.WithTimeout(context.Background(), 1*time.Nanosecond)
		defer cancel()

		time.Sleep(10 * time.Millisecond) // Ensure timeout

		repo := setupRepo(t)
		_, err := repo.FindByID(ctx, 1)
		assert.ErrorIs(t, err, context.DeadlineExceeded)
	})

	t.Run("cancellation", func(t *testing.T) {
		ctx, cancel := context.WithCancel(context.Background())
		cancel() // Cancel immediately

		repo := setupRepo(t)
		_, err := repo.FindByID(ctx, 1)
		assert.ErrorIs(t, err, context.Canceled)
	})
}
```

**Rules:**
- Use context.Background() in tests (clean slate)
- Test timeout scenarios with WithTimeout + sleep
- Test cancellation with WithCancel + immediate cancel
- Use errors.Is() to check for context errors

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

### Using string keys for context values

```go
// BAD: String keys can collide
ctx = context.WithValue(ctx, "user_id", 123)
userID := ctx.Value("user_id").(int) // Not type-safe

// GOOD: Custom type prevents collisions
type contextKey string
const userIDKey contextKey = "user_id"

ctx = context.WithValue(ctx, userIDKey, 123)
userID, ok := ctx.Value(userIDKey).(int)
```

### Ignoring context cancellation

```go
// BAD: Ignoring ctx.Done() in loop
func processForever(ctx context.Context) {
	for {
		process() // Never checks context
		time.Sleep(time.Second)
	}
}

// GOOD: Respect context cancellation
func process(ctx context.Context) error {
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			process()
		case <-ctx.Done():
			return ctx.Err()
		}
	}
}
```

### Creating Background context in inner functions

```go
// BAD: Creating new context instead of using passed one
func (s *Service) callAPI(userID int) error {
	ctx := context.Background() // Loses parent context!
	return s.client.Get(ctx, userID)
}

// GOOD: Pass context through call chain
func (s *Service) callAPI(ctx context.Context, userID int) error {
	return s.client.Get(ctx, userID)
}
```

### Timeout too short for operation

```go
// BAD: Timeout shorter than operation
ctx, cancel := context.WithTimeout(ctx, 10*time.Millisecond)
defer cancel()
result, err := complexDatabaseQuery(ctx) // Takes 2 seconds

// GOOD: Realistic timeout for operation
ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
defer cancel()
result, err := complexDatabaseQuery(ctx)
```

## Context Error Handling

Distinguish between context errors and other errors.

```go
func (s *Service) DoWork(ctx context.Context) error {
	result, err := s.repo.Query(ctx)
	if err != nil {
		// Check for context-specific errors first
		if errors.Is(err, context.DeadlineExceeded) {
			return fmt.Errorf("operation timed out: %w", err)
		}
		if errors.Is(err, context.Canceled) {
			return fmt.Errorf("operation canceled: %w", err)
		}
		// Other errors
		return fmt.Errorf("operation failed: %w", err)
	}

	return s.processResult(result)
}
```

## References

- [Go Blog: Context](https://go.dev/blog/context)
- [Package context documentation](https://pkg.go.dev/context)
- [Go Concurrency Patterns: Context](https://go.dev/blog/pipelines)

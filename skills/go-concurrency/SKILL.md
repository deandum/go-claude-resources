---
name: go-concurrency
description: >
  Safe concurrency patterns with goroutines, channels, and sync primitives.
  Use when implementing concurrent workflows, worker pools, fan-out/fan-in,
  or when reviewing code with goroutines.
---

# Go Concurrency

Don't communicate by sharing memory; share memory by communicating.
Concurrency is not parallelism. Channels orchestrate; mutexes serialize.

## When to Apply

Use this skill when:
- Implementing concurrent workflows or pipelines
- Creating worker pools
- Managing goroutine lifecycles
- Using channels or sync primitives
- Reviewing code that spawns goroutines

## Decision Framework: Channel vs Mutex

| Use Channels When | Use Mutexes When |
|---|---|
| Passing ownership of data | Protecting internal state |
| Coordinating goroutines | Simple counter or flag |
| Distributing work | Short critical sections |
| Signaling events | Cache access |

**If in doubt:** ask "am I transferring data or protecting data?" Transfer → channel. Protect → mutex.

## Pattern 1: Basic Goroutine with Cleanup

Every goroutine must have a clear shutdown path. Never leak goroutines.

```go
func (s *Server) Start(ctx context.Context) error {
    g, ctx := errgroup.WithContext(ctx)

    g.Go(func() error {
        return s.httpServer.Serve(ctx)
    })

    g.Go(func() error {
        return s.processQueue(ctx)
    })

    return g.Wait()
}
```

**Rules:**
- Every `go` statement must have a corresponding way to stop and wait
- Use `context.Context` for cancellation
- Use `errgroup.Group` for managing multiple goroutines with error propagation
- Use `sync.WaitGroup` when you don't need error collection

## Pattern 2: Worker Pool

```go
func ProcessItems(ctx context.Context, items []Item, workers int) error {
    g, ctx := errgroup.WithContext(ctx)
    work := make(chan Item)

    // Fan-out: start workers
    for range workers {
        g.Go(func() error {
            for item := range work {
                if err := process(ctx, item); err != nil {
                    return err
                }
            }
            return nil
        })
    }

    // Fan-in: send work
    g.Go(func() error {
        defer close(work)
        for _, item := range items {
            select {
            case work <- item:
            case <-ctx.Done():
                return ctx.Err()
            }
        }
        return nil
    })

    return g.Wait()
}
```

## Pattern 3: Fan-Out / Fan-In

```go
func FetchAll(ctx context.Context, urls []string) ([]Result, error) {
    results := make([]Result, len(urls))
    g, ctx := errgroup.WithContext(ctx)

    for i, url := range urls {
        g.Go(func() error {
            res, err := fetch(ctx, url)
            if err != nil {
                return fmt.Errorf("fetching %s: %w", url, err)
            }
            results[i] = res // Safe: each goroutine writes to a unique index
            return nil
        })
    }

    if err := g.Wait(); err != nil {
        return nil, err
    }

    return results, nil
}
```

## Pattern 4: Pipeline

```go
func Pipeline(ctx context.Context, input <-chan int) <-chan int {
    out := make(chan int)
    go func() {
        defer close(out)
        for n := range input {
            select {
            case out <- transform(n):
            case <-ctx.Done():
                return
            }
        }
    }()
    return out
}
```

## Pattern 5: Rate Limiter (Token Bucket)

Use `golang.org/x/time/rate` for production-ready rate limiting with burst support.

```go
import "golang.org/x/time/rate"

// NewRateLimiter creates a token bucket limiter
// rate: tokens per second
// burst: maximum number of tokens that can be accumulated
func NewRateLimiter(rps int, burst int) *rate.Limiter {
    return rate.NewLimiter(rate.Limit(rps), burst)
}

// Example: API client with rate limiting
type APIClient struct {
    limiter *rate.Limiter
}

func NewAPIClient(rps int) *APIClient {
    return &APIClient{
        limiter: rate.NewLimiter(rate.Limit(rps), rps), // burst = rps
    }
}

func (c *APIClient) Call(ctx context.Context, req Request) error {
    // Wait for rate limiter permit
    if err := c.limiter.Wait(ctx); err != nil {
        return fmt.Errorf("rate limit wait: %w", err)
    }

    return c.doRequest(ctx, req)
}

// For non-blocking checks
func (c *APIClient) TryCall(ctx context.Context, req Request) error {
    if !c.limiter.Allow() {
        return errors.New("rate limit exceeded")
    }

    return c.doRequest(ctx, req)
}
```

## Pattern 6: Protected Shared State (Mutex)

```go
type Cache struct {
    mu    sync.RWMutex
    items map[string]Item
}

func (c *Cache) Get(key string) (Item, bool) {
    c.mu.RLock()
    defer c.mu.RUnlock()
    item, ok := c.items[key]
    return item, ok
}

func (c *Cache) Set(key string, item Item) {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.items[key] = item
}
```

**Mutex rules:**
- Always `defer` the unlock immediately after the lock
- Use `sync.RWMutex` when reads vastly outnumber writes
- Never copy a mutex (pass by pointer, embed in struct)
- Keep critical sections short

## Pattern 7: Once Initialization

```go
type Client struct {
    initOnce sync.Once
    conn     *grpc.ClientConn
    initErr  error
}

func (c *Client) getConn() (*grpc.ClientConn, error) {
    c.initOnce.Do(func() {
        c.conn, c.initErr = grpc.Dial(c.addr)
    })
    return c.conn, c.initErr
}
```

## Context Rules

1. **Context is always the first parameter**: `func Foo(ctx context.Context, ...)`
2. **Never store context in a struct** — pass it through the call chain
3. **Respect cancellation** — check `ctx.Done()` in loops and selects
4. **Set timeouts at boundaries**:

```go
ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
defer cancel()

result, err := client.Call(ctx, req)
```

## Anti-Patterns

### Goroutine leak — no way to stop

```go
// BAD: goroutine runs forever
go func() {
    for {
        process()
        time.Sleep(time.Second)
    }
}()

// GOOD: respects context cancellation
go func() {
    ticker := time.NewTicker(time.Second)
    defer ticker.Stop()
    for {
        select {
        case <-ticker.C:
            process()
        case <-ctx.Done():
            return
        }
    }
}()
```

### Race condition — unsynchronized access

```go
// BAD: data race
var count int
for range 10 {
    go func() { count++ }()
}

// GOOD: use atomic or mutex
var count atomic.Int64
for range 10 {
    go func() { count.Add(1) }()
}
```

### Channel misuse — using channels when mutex is simpler

```go
// BAD: channel used as a mutex
var mu = make(chan struct{}, 1)
mu <- struct{}{}
// ... critical section
<-mu

// GOOD: just use a mutex
var mu sync.Mutex
mu.Lock()
// ... critical section
mu.Unlock()
```

### Unbounded goroutines

```go
// BAD: spawns unlimited goroutines
for _, item := range items {
    go process(item) // Could spawn millions of goroutines
}

// GOOD: bounded worker pool (see Pattern 2 above)
```

## Testing Concurrent Code

- Always run tests with `-race`: `go test -race ./...`
- Use `go.uber.org/goleak` to detect goroutine leaks in tests
- Use `t.Parallel()` for independent subtests
- Avoid `time.Sleep` in tests — use channels or sync primitives to synchronize

```go
func TestWorker(t *testing.T) {
    done := make(chan struct{})
    go func() {
        defer close(done)
        worker.Run()
    }()

    // Signal worker to stop
    worker.Stop()

    // Wait with timeout
    select {
    case <-done:
        // success
    case <-time.After(5 * time.Second):
        t.Fatal("worker did not stop within timeout")
    }
}
```
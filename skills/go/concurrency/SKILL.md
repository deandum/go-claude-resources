---
name: go/concurrency
description: >
  Go concurrency patterns with goroutines, channels, errgroup, and sync
  primitives. Extends core/concurrency with Go-specific implementations.
---

# Go Concurrency

Channels orchestrate; mutexes serialize. Use `errgroup` for managed goroutine coordination.

## Channel vs Mutex

| Channels | Mutexes |
|---|---|
| Passing ownership of data | Protecting internal state |
| Coordinating goroutines | Simple counter or flag |
| Distributing work | Short critical sections |

## Pattern 1: errgroup (Default)

```go
func (s *Server) Start(ctx context.Context) error {
    g, ctx := errgroup.WithContext(ctx)
    g.Go(func() error { return s.httpServer.Serve(ctx) })
    g.Go(func() error { return s.processQueue(ctx) })
    return g.Wait()
}
```

Every `go` statement needs a way to stop and wait. Use `errgroup.Group` for error propagation, `sync.WaitGroup` when errors not needed.

## Pattern 2: Worker Pool

```go
func ProcessItems(ctx context.Context, items []Item, workers int) error {
    g, ctx := errgroup.WithContext(ctx)
    g.SetLimit(workers) // Go 1.20+: simpler bounded concurrency

    for _, item := range items {
        g.Go(func() error { return process(ctx, item) })
    }
    return g.Wait()
}
```

Use `SetLimit` for simple fan-out. Use full channel-based pool for streaming input.

## Pattern 3: Fan-Out / Fan-In

```go
func FetchAll(ctx context.Context, urls []string) ([]Result, error) {
    results := make([]Result, len(urls))
    g, ctx := errgroup.WithContext(ctx)

    for i, url := range urls {
        g.Go(func() error {
            res, err := fetch(ctx, url)
            if err != nil { return fmt.Errorf("fetching %s: %w", url, err) }
            results[i] = res // Safe: unique index per goroutine
            return nil
        })
    }
    if err := g.Wait(); err != nil { return nil, err }
    return results, nil
}
```

## Pattern 4: Pipeline

```go
// Pipeline reads from input, transforms each value, and writes to out.
// The SENDER of `input` owns closing it; when input closes, the range
// loop exits and this stage closes `out` via the deferred close.
// Context cancellation exits immediately without draining input.
func Pipeline(ctx context.Context, input <-chan int) <-chan int {
    out := make(chan int)
    go func() {
        defer close(out)
        for n := range input {
            select {
            case out <- transform(n):
            case <-ctx.Done(): return
            }
        }
    }()
    return out
}
```

Pipeline stages chain by passing the output channel of one stage as the input of the next. Each stage is responsible for closing its own output; each stage expects its input to be closed by its sender. This is the key invariant — violating it causes goroutine leaks (blocked on send) or panics (send on closed channel).

## Pattern 5: Rate Limiter

```go
import "golang.org/x/time/rate"

limiter := rate.NewLimiter(rate.Limit(rps), burst)
if err := limiter.Wait(ctx); err != nil { return err } // blocking
if !limiter.Allow() { return errors.New("rate limited") }  // non-blocking
```

## Pattern 6: sync.Once, Singleflight, sync.Pool

```go
// Lazy init
c.initOnce.Do(func() { c.conn, c.initErr = grpc.Dial(c.addr) })

// Deduplicate concurrent calls
v, err, _ := c.group.Do(key, func() (any, error) { return c.db.Query(ctx, key) })

// Reuse temporary objects (profile first)
buf := bufPool.Get().(*bytes.Buffer)
defer func() { buf.Reset(); bufPool.Put(buf) }()
```

## Anti-Patterns

```go
// BAD: goroutine leak
go func() { for { process(); time.Sleep(time.Second) } }()
// GOOD: respect cancellation
go func() {
    ticker := time.NewTicker(time.Second); defer ticker.Stop()
    for { select { case <-ticker.C: process(); case <-ctx.Done(): return } }
}()

// BAD: race condition
var count int; go func() { count++ }()
// GOOD: use atomic
var count atomic.Int64; go func() { count.Add(1) }()

// BAD: unbounded goroutines
for _, item := range items { go process(item) }
// GOOD: use errgroup.SetLimit or worker pool
```

## Verification

- [ ] `go vet ./...` reports no issues
- [ ] `go test -race ./...` passes with no data races detected
- [ ] `errgroup` used for goroutine coordination with error propagation
- [ ] Channels closed by sender only, never by receiver
- [ ] Channels not misused as locks (use `sync.Mutex` instead)

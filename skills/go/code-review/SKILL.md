---
name: go/code-review
description: >
  Go-specific code review checklist items. Extends core/code-review with
  Go-specific correctness, style, and performance checks.
---

# Go Code Review

Go-specific checklist items to supplement the core review process.

## Correctness

- Every `error` return checked — no `_` for errors
- `defer` for resource cleanup (files, rows, transactions, mutexes)
- Goroutines have shutdown paths (context cancellation, errgroup)
- No goroutine leaks (blocked channels, infinite loops without ctx check)
- Nil pointer checks before dereferencing

## Style

- `gofmt`/`goimports` applied
- Initialisms all caps (`ID`, `URL`, `HTTP`)
- Interfaces defined at consumer, not provider
- No `init()` functions (except Cobra command registration)
- `got`/`want` in tests, not `actual`/`expected`

## Concurrency

- No data races (`go vet -race`, shared state protected)
- Channels properly closed (only by sender)
- `sync.Mutex` not copied (pass by pointer)
- `errgroup` or `sync.WaitGroup` for goroutine coordination

## Performance

- `context.Context` always first parameter
- Connection pools configured (not default)
- N+1 queries identified
- `sync.Pool` only when allocation pressure measured

## Security

- SQL parameterized (`?` placeholders, never string concat)
- No secrets in code or logs
- Input validation at HTTP boundary

Full detailed checklist: [checklist.md](references/checklist.md)

## Verification

- [ ] All Go-specific checklist categories reviewed (correctness, style, concurrency, performance, security)
- [ ] `go vet ./...` and `golangci-lint run` produce no findings
- [ ] Race detector findings addressed (`go test -race ./...` passes)

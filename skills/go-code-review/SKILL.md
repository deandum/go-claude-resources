---
name: go-code-review
description: >
  Systematic Go code review checklist covering style, correctness,
  performance, and security. Use when reviewing PRs, auditing code,
  or performing pre-commit checks on Go code.
---

# Go Code Review

A systematic checklist for reviewing Go code, synthesized from Go Code Review Comments, Google's and Uber's style guides, and production experience.

## When to Apply

Use this skill when:
- Reviewing a pull request with Go code
- Auditing an existing Go codebase
- Running a pre-commit or pre-merge check
- The user asks to "review", "audit", or "check" Go code

## Review Process

Work through these categories in order. Stop and report findings per category rather than dumping everything at once.

### 1. Correctness

**Error handling:**
- [ ] Every error is checked — no ignored return values
- [ ] Errors are wrapped with context using `fmt.Errorf("...: %w", err)`
- [ ] Sentinel errors use `errors.Is`, custom types use `errors.As`
- [ ] No `log + return` double handling
- [ ] No string matching on error messages

**Concurrency:**
- [ ] Every goroutine has a shutdown path (context, done channel, or WaitGroup)
- [ ] No goroutine leaks — verify with `go.uber.org/goleak` in tests
- [ ] Shared state is protected (mutex, atomic, or channel)
- [ ] No race conditions (check with `go test -race`)
- [ ] Channel operations have `ctx.Done()` cases in selects
- [ ] Deferred unlocks immediately follow locks

**Resource management:**
- [ ] `defer` used for cleanup (Close, Unlock, Cancel)
- [ ] `context.WithTimeout`/`WithCancel` paired with `defer cancel()`
- [ ] HTTP response bodies are closed: `defer resp.Body.Close()`
- [ ] Database connections returned to pool (rows.Close, tx.Rollback)

**Nil safety:**
- [ ] Pointer receivers checked for nil where appropriate
- [ ] Slices checked before indexing
- [ ] Map access uses comma-ok pattern when needed
- [ ] Interface values checked for nil before method calls

### 2. Style and Naming

**Formatting:**
- [ ] Code passes `gofmt` / `goimports`
- [ ] Imports grouped: stdlib, external, internal

**Naming:**
- [ ] Package names are short, lowercase, no underscores
- [ ] No packages named `util`, `common`, `helpers`, `misc`
- [ ] Exported names have doc comments starting with the name
- [ ] Initialisms are all-caps: `ID`, `URL`, `HTTP` (not `Id`, `Url`)
- [ ] Getters are `Owner()` not `GetOwner()`
- [ ] Short variable names for narrow scopes, descriptive for wide scopes

**Interfaces:**
- [ ] Interfaces are small (1-5 methods)
- [ ] Interfaces defined at point of use, not alongside implementation
- [ ] Functions accept interfaces, return concrete types
- [ ] No unnecessary `interface{}` / `any` — use concrete types when possible

**Code organization:**
- [ ] Functions are under ~100 lines (context aware)
- [ ] Happy path is at minimal indentation (early returns for errors)
- [ ] No deep nesting (>3 levels of indentation)

### 3. Design

**Package design:**
- [ ] Package provides a clear, focused API
- [ ] No circular dependencies
- [ ] Internal implementation details are in `internal/`
- [ ] Dependencies point inward (adapter → application → domain)

**API surface:**
- [ ] Only what needs to be exported is exported
- [ ] Zero values are useful where possible
- [ ] Functional options for complex configuration
- [ ] Context is the first parameter of functions that need it

**Dependencies:**
- [ ] No unnecessary external dependencies (stdlib preferred)
- [ ] `go.mod` is tidy (`go mod tidy`)
- [ ] No `init()` functions (prefer explicit initialization)
- [ ] No global mutable state

### 4. Testing

- [ ] New code has corresponding tests
- [ ] Tests use table-driven pattern where appropriate
- [ ] Test names describe the scenario being tested
- [ ] Tests assert behavior, not implementation details
- [ ] No `time.Sleep` in tests — use synchronization
- [ ] Integration tests are build-tagged separately
- [ ] Test helpers use `t.Helper()`
- [ ] Tests run cleanly with `-race`

### 5. Performance (When Relevant)

- [ ] No allocations in hot loops (preallocate slices/maps with known sizes)
- [ ] `strings.Builder` for string concatenation in loops
- [ ] Bounded goroutine pools (no unbounded `go` spawning)
- [ ] HTTP clients and servers have timeouts configured
- [ ] Database queries use prepared statements or parameterized queries
- [ ] No N+1 query patterns

### 6. Security

- [ ] No hardcoded secrets, passwords, or API keys
- [ ] SQL uses parameterized queries (no string concatenation)
- [ ] User input is validated before use
- [ ] HTTP responses set appropriate Content-Type
- [ ] Sensitive data is not logged
- [ ] TLS configuration uses secure defaults
- [ ] No use of `unsafe` package without documented justification

## Review Output Format

When reporting review findings, structure them as:

```
## Review Summary

**Overall**: [APPROVE / REQUEST CHANGES / COMMENT]

### Critical (must fix)
- file.go:42 — goroutine leak: no shutdown path for background worker
- handler.go:15 — SQL injection: user input concatenated into query

### Important (should fix)
- service.go:28 — error not wrapped: `return err` should be `return fmt.Errorf("creating user: %w", err)`
- repo.go:55 — interface too large: UserRepository has 8 methods, consider splitting

### Suggestions (nice to have)
- config.go:10 — consider using functional options instead of 6 constructor parameters
- handler.go:70 — this function is 65 lines, consider extracting validation logic
```

## Quick Review Commands

For common review feedback, reference these resources:
- **Naming**: https://go.dev/wiki/CodeReviewComments#initialisms
- **Error handling**: https://go.dev/wiki/CodeReviewComments#dont-panic
- **Interfaces**: https://go.dev/wiki/CodeReviewComments#interfaces
- **Doc comments**: https://go.dev/wiki/CodeReviewComments#doc-comments
- **Receiver type**: https://go.dev/wiki/CodeReviewComments#receiver-type
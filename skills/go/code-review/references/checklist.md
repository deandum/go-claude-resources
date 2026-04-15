# Go Code Review Checklist

Standalone checklist for systematic Go code reviews.

## 1. Correctness

### Error handling
- [ ] Every error is checked — no ignored return values
- [ ] Errors are wrapped with context using `fmt.Errorf("...: %w", err)`
- [ ] Sentinel errors use `errors.Is`, custom types use `errors.As`
- [ ] No `log + return` double handling
- [ ] No string matching on error messages

### Concurrency
- [ ] Every goroutine has a shutdown path (context, done channel, or WaitGroup)
- [ ] No goroutine leaks — verify with `go.uber.org/goleak` in tests
- [ ] Shared state is protected (mutex, atomic, or channel)
- [ ] No race conditions (check with `go test -race`)
- [ ] Channel operations have `ctx.Done()` cases in selects
- [ ] Deferred unlocks immediately follow locks

### Resource management
- [ ] `defer` used for cleanup (Close, Unlock, Cancel)
- [ ] `context.WithTimeout`/`WithCancel` paired with `defer cancel()`
- [ ] HTTP response bodies are closed: `defer resp.Body.Close()`
- [ ] Database connections returned to pool (rows.Close, tx.Rollback)

### Nil safety
- [ ] Pointer receivers checked for nil where appropriate
- [ ] Slices checked before indexing
- [ ] Map access uses comma-ok pattern when needed
- [ ] Interface values checked for nil before method calls

## 2. Style and Naming

### Formatting
- [ ] Code passes `gofmt` / `goimports`
- [ ] Imports grouped: stdlib, external, internal

### Naming
- [ ] Package names are short, lowercase, no underscores
- [ ] No packages named `util`, `common`, `helpers`, `misc`
- [ ] Exported names have doc comments starting with the name
- [ ] Initialisms are all-caps: `ID`, `URL`, `HTTP` (not `Id`, `Url`)
- [ ] Getters are `Owner()` not `GetOwner()`
- [ ] Short variable names for narrow scopes, descriptive for wide scopes

### Interfaces
- [ ] Interfaces are small (1-5 methods)
- [ ] Interfaces defined at point of use, not alongside implementation
- [ ] Functions accept interfaces, return concrete types
- [ ] No unnecessary `interface{}` / `any` — use concrete types when possible

### Code organization
- [ ] Functions are under ~100 lines (context aware)
- [ ] Happy path is at minimal indentation (early returns for errors)
- [ ] No deep nesting (>3 levels of indentation)

## 3. Design

### Package design
- [ ] Package provides a clear, focused API
- [ ] No circular dependencies
- [ ] Internal implementation details are in `internal/`
- [ ] Dependencies point inward (adapter → application → domain)

### API surface
- [ ] Only what needs to be exported is exported
- [ ] Zero values are useful where possible
- [ ] Functional options for complex configuration
- [ ] Context is the first parameter of functions that need it

### Dependencies
- [ ] No unnecessary external dependencies (stdlib preferred)
- [ ] `go.mod` is tidy (`go mod tidy`)
- [ ] No `init()` functions (prefer explicit initialization)
- [ ] No global mutable state

## 4. Testing
- [ ] New code has corresponding tests
- [ ] Tests use table-driven pattern where appropriate
- [ ] Test names describe the scenario being tested
- [ ] Tests assert behavior, not implementation details
- [ ] No `time.Sleep` in tests — use synchronization
- [ ] Integration tests are build-tagged separately
- [ ] Test helpers use `t.Helper()`
- [ ] Tests run cleanly with `-race`

## 5. Performance (When Relevant)
- [ ] No allocations in hot loops (preallocate slices/maps with known sizes)
- [ ] `strings.Builder` for string concatenation in loops
- [ ] Bounded goroutine pools (no unbounded `go` spawning)
- [ ] HTTP clients and servers have timeouts configured
- [ ] Database queries use prepared statements or parameterized queries
- [ ] No N+1 query patterns

## 6. Security
- [ ] No hardcoded secrets, passwords, or API keys
- [ ] SQL uses parameterized queries (no string concatenation)
- [ ] User input is validated before use
- [ ] HTTP responses set appropriate Content-Type
- [ ] Sensitive data is not logged
- [ ] TLS configuration uses secure defaults
- [ ] No use of `unsafe` package without documented justification


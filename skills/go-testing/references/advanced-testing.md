# Advanced Testing Topics

## Contents

- [Benchmarks](#benchmarks)
- [Golden File Testing](#golden-file-testing)
- [Fuzzing](#fuzzing-go-118)
- [Test Coverage Analysis](#test-coverage-analysis)
- [Parallel Tests](#parallel-tests)
- [Makefile Targets](#makefile-targets)

## Benchmarks

```go
func BenchmarkParseAmount(b *testing.B) {
    for b.Loop() {
        ParseAmount("42.50")
    }
}

func BenchmarkParseAmount_Large(b *testing.B) {
    input := "999999999.99"
    for b.Loop() {
        ParseAmount(input)
    }
}
```

Run with: `go test -bench=. -benchmem ./...`

## Golden File Testing

For complex outputs (JSON, HTML, etc.), compare against golden files:

```go
func TestRender(t *testing.T) {
    got := Render(testInput)
    golden := filepath.Join("testdata", "golden", t.Name()+".json")

    if *update {
        os.MkdirAll(filepath.Dir(golden), 0o755)
        os.WriteFile(golden, got, 0o644)
        return
    }

    want, err := os.ReadFile(golden)
    if err != nil {
        t.Fatal(err)
    }
    if !bytes.Equal(got, want) {
        t.Errorf("output mismatch; run with -update to regenerate")
    }
}

var update = flag.Bool("update", false, "update golden files")
```

## Fuzzing (Go 1.18+)

Go's built-in fuzzing finds edge cases automatically:

```go
func FuzzParseAmount(f *testing.F) {
    // Seed corpus
    f.Add("42.50")
    f.Add("0")
    f.Add("999.99")

    f.Fuzz(func(t *testing.T, input string) {
        amount, err := ParseAmount(input)
        if err != nil {
            return // Invalid input is acceptable
        }
        // Verify invariants
        if amount < 0 {
            t.Errorf("ParseAmount(%q) = %d, should never be negative", input, amount)
        }
    })
}
```

Run with: `go test -fuzz=FuzzParseAmount`

## Test Coverage Analysis

Coverage metrics are useful but not a goal:
- **70-80% coverage** is reasonable for most projects
- **Focus on critical paths** (auth, payments, data integrity)
- **Don't test for coverage** - test for correctness
- **Low coverage** may indicate untestable code (refactor)
- **100% coverage** doesn't mean bug-free code

View coverage: `go test -coverprofile=coverage.out && go tool cover -html=coverage.out`

## Parallel Tests

Use `t.Parallel()` for independent tests that can run concurrently:

```go
func TestSlowOperation(t *testing.T) {
    t.Parallel() // Runs in parallel with other parallel tests

    // Test implementation
}
```

**When to use:**
- Tests that don't share state
- Integration tests with isolated data
- Tests with I/O or network delays

**When NOT to use:**
- Tests that modify global state
- Tests that depend on execution order
- Tests already fast enough (< 10ms)

## Makefile Targets

```makefile
# Run unit tests only (fast, no external dependencies)
test:
	go test -race -count=1 ./internal/...

# Run unit tests with coverage
test-coverage:
	go test -race -coverprofile=coverage.out ./internal/...
	go tool cover -func=coverage.out

# Run integration tests (requires external services)
test-integration:
	go test -race -count=1 ./test-integration/...

# Run all tests (unit + integration)
test-all:
	go test -race -count=1 ./...

# Run benchmarks
bench:
	go test -bench=. -benchmem ./...

# Run integration tests excluding slow e2e tests
test-integration-fast:
	go test -short -race -count=1 ./test-integration/...
```

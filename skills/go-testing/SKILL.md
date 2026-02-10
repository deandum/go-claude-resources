---
name: go-testing
description: >
  Go testing patterns including table-driven tests, subtests, test helpers,
  benchmarks, and integration tests. Use when writing tests, designing
  test strategy, creating mocks or test doubles, or reviewing test code in Go.
---

# Go Testing

Testing in Go is just programming. Use the stdlib `testing` package. Don't import a DSL or framework - you won't need it.

## Contents

- [Core Principles](#core-principles)
- [Table-Driven Tests](#table-driven-tests)
- [Test Helpers](#test-helpers)
- [Test Fixtures and Setup](#test-fixtures-and-setup)
- [Interface-Based Test Doubles](#interface-based-test-doubles)
- [Testing Anti-Patterns](#testing-anti-patterns)
- [Test File Organization](#test-file-organization)
- [Testing Strategy Summary](#testing-strategy-summary)
- [Additional Resources](#additional-resources)

## Core Principles

1. **Tests are code** — apply the same quality standards as production code
2. **Table-driven tests** — the default pattern for testing multiple cases
3. **No test frameworks** — `testing` + `t.Run` + `t.Helper` is sufficient
4. **Test behavior, not implementation** — test the public API
5. **Make it easy to add new test cases** — if adding a case is hard, refactor

## Table-Driven Tests

The standard Go testing pattern. Every set of related test cases should be a table.

```go
func TestParseAmount(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        want    int64
        wantErr bool
    }{
        {
            name:  "whole dollars",
            input: "42",
            want:  4200,
        },
        {
            name:  "with cents",
            input: "42.50",
            want:  4250,
        },
        {
            name:    "negative",
            input:   "-10",
            wantErr: true,
        },
        {
            name:    "empty string",
            input:   "",
            wantErr: true,
        },
    }

    for _, testCase := range tests {
        t.Run(testCase.name, func(t *testing.T) {
            got, err := ParseAmount(testCase.input)

            if testCase.wantErr {
                if err == nil {
                    t.Fatal("expected error, got nil")
                }
                return
            }
            if err != nil {
                t.Fatalf("unexpected error: %v", err)
            }
            if got != testCase.want {
                t.Errorf("ParseAmount(%q) = %d, want %d", testCase.input, got, testCase.want)
            }
        })
    }
}
```

**Table test guidelines:**
- Each test case has a descriptive `name`
- Use `got` / `want` naming convention (not `actual` / `expected`)
- Put the `name` field first for readability
- Group related cases together
- Test both happy paths and error cases
- Use `t.Fatal` for setup failures, `t.Error` for assertion failures

## Test Helpers

Use `t.Helper()` to make test output point to the right line:

```go
func assertNoError(t *testing.T, err error) {
    t.Helper()
    if err != nil {
        t.Fatalf("unexpected error: %v", err)
    }
}

func assertEqual[T comparable](t *testing.T, got, want T) {
    t.Helper()
    if got != want {
        t.Errorf("got %v, want %v", got, want)
    }
}

func assertError(t *testing.T, err, target error) {
    t.Helper()
    if !errors.Is(err, target) {
        t.Errorf("got error %v, want %v", err, target)
    }
}
```

## Test Fixtures and Setup

### `testdata/` directory

Go ignores `testdata/` directories during builds. Use them for test fixtures:

```
mypackage/
├── parser.go
├── parser_test.go
└── testdata/
    ├── valid_input.json
    ├── invalid_input.json
    └── golden/
        └── expected_output.json
```

```go
func TestParseFile(t *testing.T) {
    data, err := os.ReadFile("testdata/valid_input.json")
    if err != nil {
        t.Fatal(err)
    }
    // ...
}
```

### Setup and teardown

```go
func TestDatabase(t *testing.T) {
    db := setupTestDB(t) // t.Cleanup handles teardown

    t.Run("CreateUser", func(t *testing.T) {
        // test using db
    })

    t.Run("FindUser", func(t *testing.T) {
        // test using db
    })
}

func setupTestDB(t *testing.T) *sql.DB {
    t.Helper()
    db, err := sql.Open("postgres", testDSN)
    if err != nil {
        t.Fatal(err)
    }
    t.Cleanup(func() {
        db.Close()
    })
    return db
}
```

## Interface-Based Test Doubles

Don't use heavy mocking frameworks. Write simple test doubles by implementing interfaces.

### Decision Framework

When testing code with dependencies, ask these questions in order:

**1. Does the dependency cross a system boundary?**
- **Yes** → Mock it (database, HTTP client, message queue, external API)
- **No** → Use the real implementation (domain entities, value objects, pure functions)

**2. Do different tests need different behavior from this dependency?**
- **Yes** → Function-based mock (maximum flexibility per test)
- **No** → Struct-based stub (shared behavior, simpler)

**3. Do you need to verify how the dependency was called?**
- **Yes** → Function-based mock with capture variables
- **No** → Stub that returns test data

**Mock**: Database repositories, HTTP clients, message queues, external services
**Don't mock**: Domain entities, value objects, pure functions, internal packages

### Interface Declaration Pattern

Follow the `go-style` skill guidelines.

### Function-Based Mocks

Use function-based mocks for maximum flexibility. This pattern makes it trivial to customize behavior per test case:

```go
// UserRepositoryFunc is a mock implementation using function fields.
// It allows easy testing by providing custom function implementations.
type UserRepositoryFunc struct {
    FindByIDFunc func(ctx context.Context, id string) (*User, error)
    SaveFunc     func(ctx context.Context, user *User) error
}

// Compile-time interface check
var _ UserRepository = (*UserRepositoryFunc)(nil)

// FindByID delegates to FindByIDFunc.
func (m *UserRepositoryFunc) FindByID(ctx context.Context, id string) (*User, error) {
    return m.FindByIDFunc(ctx, id)
}

// Save delegates to SaveFunc.
func (m *UserRepositoryFunc) Save(ctx context.Context, user *User) error {
    return m.SaveFunc(ctx, user)
}

// Example showing stub behavior, error testing, and call verification
func TestUserService_Activate(t *testing.T) {
    users := map[string]*User{
        "user-1": {ID: "user-1", Status: StatusInactive},
    }
    var savedUser *User

    repo := &UserRepositoryFunc{
        FindByIDFunc: func(_ context.Context, id string) (*User, error) {
            u, ok := users[id]
            if !ok {
                return nil, ErrNotFound
            }
            return u, nil
        },
        SaveFunc: func(_ context.Context, user *User) error {
            savedUser = user  // Capture for verification
            users[user.ID] = user
            return nil
        },
    }

    svc := NewService(repo)
    err := svc.Activate(context.Background(), "user-1")
    if err != nil {
        t.Fatalf("unexpected error: %v", err)
    }

    // Verify the call was made and user was updated
    if savedUser == nil {
        t.Fatal("expected Save to be called")
    }
    if savedUser.Status != StatusActive {
        t.Errorf("status = %v, want %v", savedUser.Status, StatusActive)
    }
}
```

### When to Use Each Pattern

**Function-based mocks** (recommended):
- Maximum flexibility per test case
- Easy to verify specific method calls
- Clear test-by-test behavior
- No shared state between tests

**Struct-based stubs** (simpler cases):
```go
type stubUserRepo struct {
    users map[string]*User
    err   error
}

func (s *stubUserRepo) FindByID(_ context.Context, id string) (*User, error) {
    if s.err != nil {
        return nil, s.err
    }
    return s.users[id], nil
}
```
- Simpler for basic happy-path scenarios
- Reusable across multiple test cases
- Less verbose when behavior is consistent

## Testing Anti-Patterns

- **Testing private functions** — test the public API; private functions are implementation details
- **Test frameworks (testify, gomega)** — stdlib `testing` + table-driven tests cover 99% of needs
- **Complex test setup** — indicates tight coupling; simplify the design first
- **Mocking everything** — only mock at boundaries; over-mocking makes tests brittle
- **Integration tests mixed with unit tests** — use `test-integration/` for clear separation
- **Defining interfaces alongside implementations** — define interfaces where they're consumed (see `go-style`)
- **Heavy mocking frameworks** — use simple function-based mocks; avoid magic and complexity
- **Using `time.Sleep()` for synchronization** — use channels or WaitGroups; sleep is slow and non-deterministic
- **Asserting on log output** — test behavior, not logging side effects
- **Over-mocking internal packages** — internal packages should be fast to run directly
- **Shared mutable state between tests** — each test must be independent
- **Assertions in loops without `t.Run`** — use subtests to identify which iteration failed
- **Not using `t.Helper()`** — helper functions need it for accurate failure line numbers

## Test File Organization

### Entity-Level Structure (Unit Tests)

Following the entity-focused package structure from `go-project-init`, unit tests live alongside production code.

- Use `package foo_test` for black-box tests (preferred)
- Use `package foo` for white-box tests (when needed)
- Unit tests: co-located with code
- Integration tests: separate `test-integration/` directory

## Testing Strategy Summary

### Test Pyramid for Go Applications

1. **Unit Tests** (70-80%) — Fast, isolated, mock boundaries, test business logic
2. **Integration Tests** (15-25%) — Real adapters (DB, Kafka), verify infrastructure
3. **End-to-End Tests** (5-10%) — Full workflows, critical journeys only, keep minimal

### Decision: Unit vs Integration Test?

| Scenario | Test Type | Approach |
|----------|-----------|----------|
| Business logic | Unit | Mock dependencies |
| SQL queries | Integration | Real database |
| HTTP handlers | Unit | Mock service layer |
| Repository CRUD | Integration | Real database |
| External API calls | Unit | Mock HTTP client |
| Full API workflow | E2E | Real services |

### Mocking Boundaries

**Mock these** (cross system boundaries):
- Database repositories, HTTP clients, message queues
- Email/SMS services, cache clients

**Don't mock these** (internal to your app):
- Domain entities, value objects, pure functions

## Additional Resources

- For integration testing patterns and test-integration directory structure, see [integration-testing.md](references/integration-testing.md)
- For advanced topics (benchmarks, golden files, fuzzing, coverage, parallel tests, Makefile targets), see [advanced-testing.md](references/advanced-testing.md)
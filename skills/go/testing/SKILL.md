---
name: go/testing
description: >
  Go testing patterns with stdlib testing package. Table-driven tests,
  subtests, test helpers, function-based mocks. Extends core/testing
  with Go-specific implementations.
---

# Go Testing

Use stdlib `testing` package. No frameworks needed — `testing` + `t.Run` + `t.Helper` is sufficient.

## Table-Driven Tests

Default pattern for testing multiple cases:

```go
func TestParseAmount(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        want    int64
        wantErr bool
    }{
        {name: "whole dollars", input: "42", want: 4200},
        {name: "with cents", input: "42.50", want: 4250},
        {name: "negative", input: "-10", wantErr: true},
        {name: "empty string", input: "", wantErr: true},
    }

    for _, testCase := range tests {
        t.Run(testCase.name, func(t *testing.T) {
            got, err := ParseAmount(testCase.input)
            if testCase.wantErr {
                if err == nil { t.Fatal("expected error, got nil") }
                return
            }
            if err != nil { t.Fatalf("unexpected error: %v", err) }
            if got != testCase.want {
                t.Errorf("ParseAmount(%q) = %d, want %d", testCase.input, got, testCase.want)
            }
        })
    }
}
```

**Guidelines:** descriptive `name` first, `got`/`want` convention, `t.Fatal` for setup failures, `t.Error` for assertions.

## Test Helpers

```go
func assertNoError(t *testing.T, err error) {
    t.Helper()
    if err != nil { t.Fatalf("unexpected error: %v", err) }
}

func assertEqual[T comparable](t *testing.T, got, want T) {
    t.Helper()
    if got != want { t.Errorf("got %v, want %v", got, want) }
}
```

## Setup and Teardown

```go
func setupTestDB(t *testing.T) *sql.DB {
    t.Helper()
    db, err := sql.Open("postgres", testDSN)
    if err != nil { t.Fatal(err) }
    t.Cleanup(func() { db.Close() })
    return db
}
```

Use `testdata/` directories for test fixtures (Go ignores them during builds).

## Function-Based Mocks

Recommended pattern — maximum flexibility per test:

```go
type UserRepositoryFunc struct {
    FindByIDFunc func(ctx context.Context, id string) (*User, error)
    SaveFunc     func(ctx context.Context, user *User) error
}

var _ UserRepository = (*UserRepositoryFunc)(nil)

func (m *UserRepositoryFunc) FindByID(ctx context.Context, id string) (*User, error) {
    return m.FindByIDFunc(ctx, id)
}

func (m *UserRepositoryFunc) Save(ctx context.Context, user *User) error {
    return m.SaveFunc(ctx, user)
}
```

**Usage:**

```go
repo := &UserRepositoryFunc{
    FindByIDFunc: func(_ context.Context, id string) (*User, error) {
        if id == "user-1" { return &User{ID: "user-1"}, nil }
        return nil, ErrNotFound
    },
    SaveFunc: func(_ context.Context, user *User) error {
        savedUser = user // Capture for verification
        return nil
    },
}
```

## Test File Organization

- `package foo_test` for black-box tests (preferred)
- `package foo` for white-box tests (when needed)
- Unit tests co-located with code
- Integration tests in `test-integration/` directory

## Anti-Patterns

- Testing private functions — test public API only
- Test frameworks when not established — stdlib covers 99% of needs
- Heavy mocking frameworks — use function-based mocks
- `time.Sleep()` for sync — use channels or WaitGroups
- Not using `t.Helper()` — needed for accurate failure line numbers
- Assertions in loops without `t.Run` — use subtests

## Verification

- [ ] `go test -race -v ./...` passes with no failures or data races
- [ ] Table-driven tests used for functions with multiple input/output cases
- [ ] `t.Helper()` called at the start of every test helper function
- [ ] Bug fixes include a regression test that fails without the fix

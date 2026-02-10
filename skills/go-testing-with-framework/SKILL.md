---
name: go-testing-with-framework
description: >
  Go testing with Ginkgo (BDD framework) and Gomega (matcher library).
  Covers BDD-style tests, table-driven tests with DescribeTable, matchers,
  test organization, and integration testing. Use when writing tests in
  projects that use Ginkgo/Gomega instead of stdlib testing.
---

# Go Testing with Ginkgo and Gomega

Behavior-Driven Development (BDD) testing in Go using [Ginkgo](https://onsi.github.io/ginkgo/) as the testing framework and [Gomega](https://onsi.github.io/gomega/) as the matcher/assertion library.

## When to Apply

Use this skill when:
- Writing BDD-style tests in Go
- Working on projects that have adopted Ginkgo/Gomega
- You need expressive matchers and better test organization
- Writing integration or end-to-end tests with complex scenarios
- The team prefers descriptive test hierarchies

## Core Principles

1. **BDD-style organization** — Use Describe/Context/It for hierarchical test organization
2. **Expressive matchers** — Gomega provides readable assertions
3. **Table-driven tests** — DescribeTable for multiple test cases
4. **Test behavior, not implementation** — Focus on the public API
5. **Keep specs focused** — Each It block tests one behavior

## Setup and Installation

```bash
# Install Ginkgo CLI
go install github.com/onsi/ginkgo/v2/ginkgo@latest

# Install dependencies
go get github.com/onsi/ginkgo/v2
go get github.com/onsi/gomega

# Bootstrap a test suite
cd mypackage
ginkgo bootstrap
```

This creates a `mypackage_suite_test.go` file:

```go
package mypackage_test

import (
    "testing"

    . "github.com/onsi/ginkgo/v2"
    . "github.com/onsi/gomega"
)

func TestMypackage(t *testing.T) {
    RegisterFailHandler(Fail)
    RunSpecs(t, "Mypackage Suite")
}
```

## Basic Test Structure

Ginkgo organizes tests using Describe, Context, and It blocks:

```go
package parser_test

import (
    . "github.com/onsi/ginkgo/v2"
    . "github.com/onsi/gomega"

    "myservice/internal/parser"
)

var _ = Describe("ParseAmount", func() {
    Context("when given valid input", func() {
        It("parses whole dollars", func() {
            result, err := parser.ParseAmount("42")
            Expect(err).ToNot(HaveOccurred())
            Expect(result).To(Equal(int64(4200)))
        })

        It("parses dollars with cents", func() {
            result, err := parser.ParseAmount("42.50")
            Expect(err).ToNot(HaveOccurred())
            Expect(result).To(Equal(int64(4250)))
        })
    })

    Context("when given invalid input", func() {
        It("returns error for negative amounts", func() {
            _, err := parser.ParseAmount("-10")
            Expect(err).To(HaveOccurred())
        })

        It("returns error for empty string", func() {
            _, err := parser.ParseAmount("")
            Expect(err).To(HaveOccurred())
        })
    })
})
```

**Structure guidelines:**
- **Describe** — Describes a component, function, or feature
- **Context** — Describes a specific scenario or condition
- **It** — Describes expected behavior in that context
- Use descriptive strings that read like sentences
- Nest contexts to organize related scenarios

## Table-Driven Tests with DescribeTable

DescribeTable is the Ginkgo equivalent of table-driven tests:

```go
var _ = Describe("ParseAmount", func() {
    DescribeTable("parsing different inputs",
        func(input string, expected int64, shouldError bool) {
            result, err := parser.ParseAmount(input)

            if shouldError {
                Expect(err).To(HaveOccurred())
            } else {
                Expect(err).ToNot(HaveOccurred())
                Expect(result).To(Equal(expected))
            }
        },
        Entry("whole dollars", "42", int64(4200), false),
        Entry("with cents", "42.50", int64(4250), false),
        Entry("zero amount", "0", int64(0), false),
        Entry("large amount", "9999.99", int64(999999), false),
        Entry("negative amount", "-10", int64(0), true),
        Entry("empty string", "", int64(0), true),
        Entry("invalid format", "abc", int64(0), true),
    )
})
```

**DescribeTable guidelines:**
- First parameter is the table description
- Second parameter is the test function
- Each Entry is a test case with a descriptive name
- Parameters match the test function signature
- Use nil for unused parameters in error cases

### Advanced Table Testing

For complex scenarios, use PEntry (pending) and FEntry (focused) to control execution:

```go
DescribeTable("complex scenarios",
    func(input string, expected Result) {
        // test implementation
    },
    Entry("working case", "foo", expectedFoo),
    PEntry("not implemented yet", "bar", expectedBar), // Skipped
    FEntry("debug this case", "baz", expectedBaz),     // Only this runs when present
)
```

## Gomega Matchers

Gomega provides expressive matchers for assertions:

### Common Matchers

```go
// Equality
Expect(actual).To(Equal(expected))
Expect(actual).To(BeNumerically("==", expected))
Expect(actual).To(BeIdenticalTo(expected)) // pointer equality

// Nil checks
Expect(err).ToNot(HaveOccurred())
Expect(err).To(MatchError("expected error message"))
Expect(value).To(BeNil())
Expect(value).ToNot(BeNil())

// Boolean
Expect(condition).To(BeTrue())
Expect(condition).To(BeFalse())

// Numeric comparisons
Expect(value).To(BeNumerically(">", 10))
Expect(value).To(BeNumerically("<=", 100))
Expect(value).To(BeNumerically("~", 3.14, 0.01)) // within delta

// Strings
Expect(str).To(ContainSubstring("expected"))
Expect(str).To(HavePrefix("prefix"))
Expect(str).To(HaveSuffix("suffix"))
Expect(str).To(MatchRegexp(`\d{3}-\d{4}`))

// Collections
Expect(slice).To(HaveLen(5))
Expect(slice).To(BeEmpty())
Expect(slice).To(ContainElement("item"))
Expect(slice).To(ConsistOf("a", "b", "c")) // order doesn't matter
Expect(map).To(HaveKey("key"))
Expect(map).To(HaveKeyWithValue("key", "value"))

// Types
Expect(value).To(BeAssignableToTypeOf(MyType{}))

// Channels
Expect(ch).To(BeClosed())
Expect(ch).To(Receive())
Expect(ch).To(Receive(&result))

// Eventually and Consistently (async)
Eventually(func() int { return counter.Get() }).Should(Equal(10))
Eventually(fetchStatus).WithTimeout(5*time.Second).Should(Equal("ready"))
Consistently(isHealthy).WithTimeout(10*time.Second).Should(BeTrue())
```

### Custom Matchers

Create reusable custom matchers:

```go
func HaveStatusCode(expected int) types.GomegaMatcher {
    return &statusCodeMatcher{expected: expected}
}

type statusCodeMatcher struct {
    expected int
}

func (m *statusCodeMatcher) Match(actual interface{}) (bool, error) {
    resp, ok := actual.(*http.Response)
    if !ok {
        return false, fmt.Errorf("expected *http.Response, got %T", actual)
    }
    return resp.StatusCode == m.expected, nil
}

func (m *statusCodeMatcher) FailureMessage(actual interface{}) string {
    resp := actual.(*http.Response)
    return fmt.Sprintf("Expected status code %d, got %d", m.expected, resp.StatusCode)
}

func (m *statusCodeMatcher) NegatedFailureMessage(actual interface{}) string {
    resp := actual.(*http.Response)
    return fmt.Sprintf("Expected status code not to be %d", resp.StatusCode)
}

// Usage
Expect(response).To(HaveStatusCode(200))
```

## Setup and Teardown

Ginkgo provides several hooks for setup and teardown:

```go
var _ = Describe("UserService", func() {
    var (
        service *UserService
        repo    *mockUserRepo
        ctx     context.Context
    )

    BeforeEach(func() {
        // Runs before each It block
        repo = &mockUserRepo{users: make(map[string]*User)}
        service = NewUserService(repo)
        ctx = context.Background()
    })

    AfterEach(func() {
        // Runs after each It block
        // Cleanup resources
    })

    BeforeSuite(func() {
        // Runs once before the entire suite
        // Setup expensive resources (databases, etc.)
    })

    AfterSuite(func() {
        // Runs once after the entire suite
        // Cleanup expensive resources
    })

    It("creates a user", func() {
        user := &User{ID: "user-1", Name: "Alice"}
        err := service.Create(ctx, user)
        Expect(err).ToNot(HaveOccurred())
    })
})
```

### DeferCleanup

Use DeferCleanup for resource cleanup (similar to t.Cleanup):

```go
var _ = Describe("Database operations", func() {
    var db *sql.DB

    BeforeEach(func() {
        var err error
        db, err = sql.Open("postgres", testDSN)
        Expect(err).ToNot(HaveOccurred())

        DeferCleanup(func() {
            db.Close()
        })
    })

    It("performs query", func() {
        // Use db
    })
})
```

## Test Fixtures and testdata/

Use `testdata/` directories for test fixtures (same as stdlib testing):

```go
var _ = Describe("ParseFile", func() {
    It("parses valid JSON file", func() {
        data, err := os.ReadFile("testdata/valid_input.json")
        Expect(err).ToNot(HaveOccurred())

        result, err := parser.ParseJSON(data)
        Expect(err).ToNot(HaveOccurred())
        Expect(result).ToNot(BeNil())
    })
})
```

## Interface-Based Test Doubles

Follow the same principles as `go-testing` skill for mocking. Use simple test doubles by implementing interfaces.

### Decision Framework

Same as standard testing:

**1. Does the dependency cross a system boundary?**
- **Yes** → Mock it (database, HTTP client, external API)
- **No** → Use the real implementation

**2. Do different tests need different behavior?**
- **Yes** → Function-based mock
- **No** → Struct-based stub

### Function-Based Mocks (Recommended)

```go
// UserRepositoryFunc provides function-based mocking
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

var _ = Describe("UserService", func() {
    var (
        service *UserService
        repo    *UserRepositoryFunc
    )

    BeforeEach(func() {
        repo = &UserRepositoryFunc{}
        service = NewUserService(repo)
    })

    Describe("Activate", func() {
        var savedUser *User

        BeforeEach(func() {
            savedUser = nil
            repo.FindByIDFunc = func(_ context.Context, id string) (*User, error) {
                if id == "user-1" {
                    return &User{ID: "user-1", Status: StatusInactive}, nil
                }
                return nil, ErrNotFound
            }
            repo.SaveFunc = func(_ context.Context, user *User) error {
                savedUser = user
                return nil
            }
        })

        It("activates an inactive user", func() {
            err := service.Activate(context.Background(), "user-1")
            Expect(err).ToNot(HaveOccurred())
            Expect(savedUser).ToNot(BeNil())
            Expect(savedUser.Status).To(Equal(StatusActive))
        })

        It("returns error for non-existent user", func() {
            err := service.Activate(context.Background(), "user-999")
            Expect(err).To(MatchError(ErrNotFound))
        })
    })
})
```

### Struct-Based Stubs

For simpler scenarios:

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

var _ = Describe("UserService", func() {
    It("finds existing users", func() {
        repo := &stubUserRepo{
            users: map[string]*User{
                "user-1": {ID: "user-1", Name: "Alice"},
            },
        }
        service := NewUserService(repo)

        user, err := service.Get(context.Background(), "user-1")
        Expect(err).ToNot(HaveOccurred())
        Expect(user.Name).To(Equal("Alice"))
    })
})
```

## Integration Tests

Integration tests with Ginkgo follow similar patterns to unit tests but interact with real external services.

### Directory Structure

```
test-integration/
├── user/
│   ├── user_suite_test.go
│   └── postgres_test.go
├── helpers/
│   ├── postgres.go
│   └── kafka.go
└── README.md
```

### Integration Test Example

```go
// test-integration/user/user_suite_test.go
package user_test

import (
    "testing"

    . "github.com/onsi/ginkgo/v2"
    . "github.com/onsi/gomega"
)

func TestUser(t *testing.T) {
    RegisterFailHandler(Fail)
    RunSpecs(t, "User Integration Suite")
}
```

```go
// test-integration/user/postgres_test.go
package user_test

import (
    "context"

    . "github.com/onsi/ginkgo/v2"
    . "github.com/onsi/gomega"

    "myservice/internal/user"
    "myservice/test-integration/helpers"
)

var _ = Describe("UserRepository with Postgres", func() {
    var (
        db   *sql.DB
        repo user.Repository
        ctx  context.Context
    )

    BeforeSuite(func() {
        if testing.Short() {
            Skip("skipping integration test in short mode")
        }

        var err error
        db, err = helpers.SetupTestDB()
        Expect(err).ToNot(HaveOccurred())

        DeferCleanup(func() {
            db.Close()
        })
    })

    BeforeEach(func() {
        repo = user.NewPostgresRepository(db)
        ctx = context.Background()

        // Clean up test data
        _, err := db.Exec("TRUNCATE TABLE users CASCADE")
        Expect(err).ToNot(HaveOccurred())
    })

    Describe("Save and FindByID", func() {
        It("persists and retrieves a user", func() {
            u := &user.User{
                ID:    "test-user-1",
                Name:  "Alice",
                Email: "alice@example.com",
            }

            err := repo.Save(ctx, u)
            Expect(err).ToNot(HaveOccurred())

            retrieved, err := repo.FindByID(ctx, "test-user-1")
            Expect(err).ToNot(HaveOccurred())
            Expect(retrieved.Email).To(Equal("alice@example.com"))
            Expect(retrieved.Name).To(Equal("Alice"))
        })

        It("returns error for non-existent user", func() {
            _, err := repo.FindByID(ctx, "non-existent")
            Expect(err).To(MatchError(user.ErrNotFound))
        })
    })
})
```

### Shared Integration Helpers

```go
// test-integration/helpers/postgres.go
package helpers

import (
    "database/sql"
    "os"

    _ "github.com/jackc/pgx/v5/stdlib"
)

func SetupTestDB() (*sql.DB, error) {
    dsn := os.Getenv("TEST_DATABASE_URL")
    if dsn == "" {
        return nil, fmt.Errorf("TEST_DATABASE_URL not set")
    }

    db, err := sql.Open("pgx", dsn)
    if err != nil {
        return nil, fmt.Errorf("failed to open database: %w", err)
    }

    if err := db.Ping(); err != nil {
        return nil, fmt.Errorf("failed to ping database: %w", err)
    }

    return db, nil
}
```

## Running Tests

### Ginkgo CLI

```bash
# Run all tests in current directory
ginkgo

# Run tests recursively
ginkgo -r

# Run with verbose output
ginkgo -v

# Run specific specs by focusing
ginkgo --focus="UserService"

# Skip certain specs
ginkgo --skip="slow tests"

# Run tests in parallel
ginkgo -p

# Run with race detector
ginkgo --race

# Run only integration tests
ginkgo -r ./test-integration/...

# Skip integration tests with short flag
go test -short -v ./test-integration/...

# Watch mode (re-run on file changes)
ginkgo watch -r

# Generate test coverage
ginkgo -r --cover --coverprofile=coverage.out
```

### Focused and Pending Specs

Control which specs run during development:

```go
// FDescribe, FContext, FIt - Only these run when present
var _ = FDescribe("UserService", func() {
    FIt("only runs this test", func() {
        // This runs, others are skipped
    })
})

// PDescribe, PContext, PIt - Marked as pending, skipped
var _ = PDescribe("Future feature", func() {
    PIt("not implemented yet", func() {
        // This is skipped
    })
})

// XDescribe, XContext, XIt - Explicitly disabled
var _ = XDescribe("Broken tests", func() {
    XIt("temporarily disabled", func() {
        // This is skipped
    })
})
```

**Important**: Never commit focused specs (F-prefixed blocks). They cause all other tests to be skipped. Use them only during local development.

## Test Organization Patterns

### One File Per Function/Type

```go
// user_test.go
var _ = Describe("User", func() {
    Describe("Validate", func() {
        // Tests for Validate method
    })

    Describe("FullName", func() {
        // Tests for FullName method
    })
})
```

### Nested Contexts for Complex Logic

```go
var _ = Describe("CalculateDiscount", func() {
    Context("when user is a premium member", func() {
        Context("and purchase is over $100", func() {
            It("applies 20% discount", func() {
                // test
            })
        })

        Context("and purchase is under $100", func() {
            It("applies 10% discount", func() {
                // test
            })
        })
    })

    Context("when user is a regular member", func() {
        It("applies 5% discount", func() {
            // test
        })
    })
})
```

### Shared Examples

Extract common test patterns:

```go
// Define shared behavior
var ItBehavesLikeARepository = func() {
    It("saves and retrieves entities", func() {
        // common test
    })

    It("handles non-existent entities", func() {
        // common test
    })
}

// Use in multiple suites
var _ = Describe("UserRepository", func() {
    ItBehavesLikeARepository()

    It("has user-specific behavior", func() {
        // user-specific test
    })
})

var _ = Describe("ProductRepository", func() {
    ItBehavesLikeARepository()

    It("has product-specific behavior", func() {
        // product-specific test
    })
})
```

## Testing Anti-Patterns

- **Over-nesting contexts** — More than 3-4 levels becomes hard to read
- **Testing private functions** — Test public APIs, not implementation
- **Using Sleep for timing** — Use Eventually/Consistently for async operations
- **Not using DeferCleanup** — Resource leaks from unclosed connections
- **Focused specs in commits** — FIt, FDescribe should never reach main branch
- **Empty It blocks** — Either implement or mark as PIt (pending)
- **Assertions in BeforeEach** — Setup should not contain test assertions
- **Complex matchers for simple checks** — `Expect(x).To(Equal(true))` should be `Expect(x).To(BeTrue())`
- **Mocking everything** — Only mock at system boundaries
- **Not using DescribeTable** — Table tests are clearer than multiple Its
- **Matcher negation confusion** — Use `ToNot` instead of `NotTo` for consistency
- **Testing log output** — Test behavior, not logging side effects
- **Shared mutable state** — Each test must be independent

## Makefile Targets

```makefile
# Install Ginkgo CLI
install-ginkgo:
	go install github.com/onsi/ginkgo/v2/ginkgo@latest

# Run unit tests with Ginkgo
test:
	ginkgo -r --race --randomize-all --randomize-suites \
	       --skip-package=test-integration internal/

# Run unit tests with verbose output
test-verbose:
	ginkgo -r -v --race --randomize-all --randomize-suites \
	       --skip-package=test-integration internal/

# Run unit tests with coverage
test-coverage:
	ginkgo -r --race --randomize-all --randomize-suites \
	       --cover --coverprofile=coverage.out \
	       --skip-package=test-integration internal/
	go tool cover -func=coverage.out

# Run integration tests
test-integration:
	ginkgo -r --race --randomize-all --randomize-suites \
	       ./test-integration/...

# Run all tests
test-all:
	ginkgo -r --race --randomize-all --randomize-suites

# Run tests in parallel
test-parallel:
	ginkgo -r -p --race --randomize-all --randomize-suites

# Watch mode for development
test-watch:
	ginkgo watch -r --skip-package=test-integration internal/

# Run focused specs only (local dev only)
test-focus:
	ginkgo -r --focus="$(FOCUS)" internal/

# Generate test coverage HTML report
coverage-html: test-coverage
	go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report: coverage.html"
```

## Advanced Topics

### Asynchronous Testing

Use Eventually and Consistently for async operations:

```go
var _ = Describe("AsyncProcessor", func() {
    It("processes messages asynchronously", func() {
        processor := NewProcessor()
        processor.Start()
        defer processor.Stop()

        processor.Submit("message1")

        // Poll until condition is true
        Eventually(func() int {
            return processor.ProcessedCount()
        }).WithTimeout(5 * time.Second).
          WithPolling(100 * time.Millisecond).
          Should(Equal(1))

        // Verify condition stays true
        Consistently(func() bool {
            return processor.IsHealthy()
        }).WithTimeout(2 * time.Second).Should(BeTrue())
    })
})
```

### Testing HTTP Handlers

```go
var _ = Describe("HTTP Handlers", func() {
    var (
        router *http.ServeMux
        rec    *httptest.ResponseRecorder
    )

    BeforeEach(func() {
        router = http.NewServeMux()
        router.HandleFunc("/users", handlers.CreateUser)
        rec = httptest.NewRecorder()
    })

    It("creates a user", func() {
        body := `{"name":"Alice","email":"alice@example.com"}`
        req := httptest.NewRequest("POST", "/users", strings.NewReader(body))
        req.Header.Set("Content-Type", "application/json")

        router.ServeHTTP(rec, req)

        Expect(rec.Code).To(Equal(http.StatusCreated))

        var response map[string]string
        err := json.Unmarshal(rec.Body.Bytes(), &response)
        Expect(err).ToNot(HaveOccurred())
        Expect(response["id"]).ToNot(BeEmpty())
    })
})
```

### Parallel Specs

Enable parallel execution for independent tests:

```go
var _ = Describe("ParallelTests", func() {
    It("runs in parallel", func(ctx SpecContext) {
        // Tests with SpecContext automatically run in parallel
        // when using ginkgo -p
    })
})
```

Or use explicit labels:

```bash
ginkgo -r -p --label-filter="parallel"
```

```go
var _ = Describe("Tests", Label("parallel"), func() {
    It("test 1", func() { /* ... */ })
    It("test 2", func() { /* ... */ })
})
```

### Golden File Testing

```go
var _ = Describe("Render", func() {
    It("generates expected JSON output", func() {
        result := Render(testInput)
        golden := filepath.Join("testdata", "golden", "expected.json")

        if *updateGolden {
            err := os.WriteFile(golden, result, 0644)
            Expect(err).ToNot(HaveOccurred())
            Skip("golden file updated")
        }

        expected, err := os.ReadFile(golden)
        Expect(err).ToNot(HaveOccurred())
        Expect(result).To(MatchJSON(expected))
    })
})

var updateGolden = flag.Bool("update-golden", false, "update golden files")
```

## Testing Strategy Summary

### Test Pyramid

1. **Unit Tests (70-80%)** — Fast, isolated, BDD-organized with Ginkgo
2. **Integration Tests (15-25%)** — Real adapters, verify infrastructure
3. **E2E Tests (5-10%)** — Full workflows, critical paths only

### Unit vs Integration Decision

| Scenario | Test Type | Approach |
|----------|-----------|----------|
| Business logic | Unit | Mock dependencies with Gomega matchers |
| SQL queries | Integration | Real database |
| HTTP handlers | Unit | Mock service layer with httptest |
| Repository CRUD | Integration | Real database |
| External API | Unit | Mock HTTP client |
| Full workflow | E2E | Real services |

### Mocking Boundaries

**Mock these** (cross system boundaries):
- Database repositories, HTTP clients, message queues
- Email/SMS services, cache clients

**Don't mock these** (internal to your app):
- Domain entities, value objects, pure functions

## Migration from Standard Testing

If migrating from stdlib testing to Ginkgo:

1. **Install and bootstrap**: Run `ginkgo bootstrap` in each package
2. **Convert test functions**: Change `func TestX(t *testing.T)` to `Describe` blocks
3. **Convert assertions**: Change `if` + `t.Error` to `Expect().To()` matchers
4. **Convert table tests**: Use `DescribeTable` instead of slice + for loop
5. **Convert setup/teardown**: Use `BeforeEach`/`AfterEach` instead of helper functions
6. **Update CI/CD**: Replace `go test` with `ginkgo` commands

## Summary

- **Ginkgo** provides BDD-style test organization (Describe/Context/It)
- **Gomega** provides expressive matchers and assertions
- Use **DescribeTable** for table-driven tests
- Use **Eventually/Consistently** for async operations
- Use **BeforeEach/AfterEach** for setup and teardown
- Mock at system boundaries, not internal code
- Keep specs focused and descriptive
- Run with `ginkgo` CLI for better output and features
- Follow the same architectural principles as standard Go testing

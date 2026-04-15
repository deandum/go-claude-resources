---
name: go/testing-with-framework
description: >
  Go testing with Ginkgo (BDD) and Gomega (matchers). Describe/Context/It
  organization, DescribeTable, setup hooks, DeferCleanup. Use when project
  uses Ginkgo/Gomega instead of stdlib testing. 100% Go-specific.
---

# Go Testing with Ginkgo and Gomega

BDD-style testing. Use when project already adopted Ginkgo/Gomega.

## Setup

```bash
go install github.com/onsi/ginkgo/v2/ginkgo@latest
go get github.com/onsi/ginkgo/v2
go get github.com/onsi/gomega
ginkgo bootstrap  # Creates suite file
```

## Basic Structure

```go
var _ = Describe("ParseAmount", func() {
    Context("when given valid input", func() {
        It("parses whole dollars", func() {
            result, err := parser.ParseAmount("42")
            Expect(err).ToNot(HaveOccurred())
            Expect(result).To(Equal(int64(4200)))
        })
    })
    Context("when given invalid input", func() {
        It("returns error for negative amounts", func() {
            _, err := parser.ParseAmount("-10")
            Expect(err).To(HaveOccurred())
        })
    })
})
```

**Describe** = component/function. **Context** = scenario. **It** = expected behavior.

## DescribeTable (Table-Driven)

```go
DescribeTable("parsing inputs",
    func(input string, expected int64, shouldError bool) {
        result, err := parser.ParseAmount(input)
        if shouldError { Expect(err).To(HaveOccurred()) } else {
            Expect(err).ToNot(HaveOccurred())
            Expect(result).To(Equal(expected))
        }
    },
    Entry("whole dollars", "42", int64(4200), false),
    Entry("negative", "-10", int64(0), true),
)
```

`PEntry` = pending (skipped). `FEntry` = focused (only this runs).

## Setup/Teardown

```go
BeforeEach(func() { repo = &mockRepo{}; service = NewService(repo) })
AfterEach(func() { /* cleanup */ })
BeforeSuite(func() { /* expensive setup once */ })
DeferCleanup(func() { db.Close() }) // Like t.Cleanup
```

## Mock Wiring

Same function-based mocks as `go/testing`, wired in `BeforeEach`:

```go
BeforeEach(func() {
    repo.FindByIDFunc = func(_ context.Context, id string) (*User, error) {
        if id == "user-1" { return &User{ID: "user-1"}, nil }
        return nil, ErrNotFound
    }
})
```

## Async Assertions

For tests that wait for a condition to become true (timing-sensitive code, eventual consistency, background goroutines), use `Eventually` and `Consistently` instead of `time.Sleep`:

```go
It("marks the job complete within 5 seconds", func() {
    go worker.Process(jobID)
    Eventually(func() string {
        return worker.Status(jobID)
    }, 5*time.Second, 100*time.Millisecond).Should(Equal("complete"))
})

It("keeps the connection healthy for 10 seconds", func() {
    Consistently(func() bool {
        return client.IsConnected()
    }, 10*time.Second, 500*time.Millisecond).Should(BeTrue())
})
```

`Eventually` polls until the assertion passes or the timeout expires. `Consistently` fails if the assertion ever fails during the duration. Both take `(timeout, pollingInterval)` as trailing arguments. These replace `time.Sleep` in tests — sleeping is slow (takes the full duration) and flaky (may miss a fast state change).

## Running

```bash
ginkgo -r              # All tests recursively
ginkgo -v              # Verbose
ginkgo --focus="..."   # Filter specs
ginkgo -p --race       # Parallel + race detector
ginkgo -r --cover      # Coverage
```

## Anti-Patterns

- Over-nesting (>3-4 levels), FIt/FDescribe in commits, assertions in BeforeEach
- Testing private functions, sleep for timing (use Eventually), mocking everything

## Verification

- [ ] `ginkgo -r --race` passes with no failures or data races
- [ ] No `FIt`/`FDescribe`/`FContext`/`FEntry` left in committed code
- [ ] `DeferCleanup` used for resource teardown (DB connections, temp files)
- [ ] `DescribeTable` with `Entry` used for parameterized test cases

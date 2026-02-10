---
name: go-interface-design
description: >
  Interface design patterns following Go idioms: accept interfaces, return structs,
  consumer-side definition, and interface segregation. Use when designing APIs,
  creating testable code, choosing between generics and interfaces, or reviewing
  interface abstractions.
---

# Go Interface Design

The bigger the interface, the weaker the abstraction. Accept interfaces, return concrete types.

## Contents

- [Decision Framework: Should This Be an Interface?](#decision-framework-should-this-be-an-interface)
- [Pattern 1: Accept Interfaces, Return Concrete Types](#pattern-1-accept-interfaces-return-concrete-types)
- [Pattern 2: Interface Segregation (Small Interfaces)](#pattern-2-interface-segregation-small-interfaces)
- [Pattern 3: Standard Library Interfaces](#pattern-3-standard-library-interfaces)
- [Pattern 4: Interface Satisfaction Verification](#pattern-4-interface-satisfaction-verification)
- [Pattern 5: Empty Interface vs Generics](#pattern-5-empty-interface-vs-generics)
- [Decision Framework: Interface vs Generics vs Concrete](#decision-framework-interface-vs-generics-vs-concrete)
- [Pattern 6: Mock-Friendly Interface Design](#pattern-6-mock-friendly-interface-design)
- [Pattern 7: Embedded Interfaces](#pattern-7-embedded-interfaces)
- [Interface Naming Conventions](#interface-naming-conventions)
- [Additional Resources](#additional-resources)

## Decision Framework: Should This Be an Interface?

```
Do you have multiple implementations NOW?
├─ NO → Don't create interface yet (YAGNI)
└─ YES
    └─ Do consumers need flexibility to swap implementations?
        ├─ NO → Use concrete type
        └─ YES
            └─ Can you define a small interface (1-3 methods)?
                ├─ YES → Create interface at consumer side
                └─ NO → Consider splitting into smaller interfaces
```

**Golden Rule**: Don't create interfaces until you need them. Interfaces should be discovered, not designed upfront.

## Pattern 1: Accept Interfaces, Return Concrete Types

Functions should accept interfaces (flexible), return concrete types (specific).

```go
package user

// Concrete type returned
type User struct {
	ID    int64
	Name  string
	Email string
}

// Repository interface defined at consumer side (not with implementation)
type Repository interface {
	FindByID(ctx context.Context, id int64) (*User, error)
	Save(ctx context.Context, user *User) error
}

// Function accepts interface (flexible input)
// Returns concrete type (clear output contract)
func GetUserProfile(ctx context.Context, repo Repository, id int64) (*User, error) {
	user, err := repo.FindByID(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("find user: %w", err)
	}
	return user, nil
}
```

**Rules:**
- Parameters: use interfaces for flexibility
- Return values: use concrete types for clarity
- Define interfaces in consumer package, not provider
- Return pointers to structs, not interface pointers

## Pattern 2: Interface Segregation (Small Interfaces)

Keep interfaces small and focused. Prefer multiple small interfaces over one large interface.

```go
// BAD: Large interface with too many methods
type UserService interface {
	FindByID(ctx context.Context, id int64) (*User, error)
	FindByEmail(ctx context.Context, email string) (*User, error)
	Create(ctx context.Context, user *User) error
	Update(ctx context.Context, user *User) error
	Delete(ctx context.Context, id int64) error
	List(ctx context.Context, limit, offset int) ([]*User, error)
	Count(ctx context.Context) (int, error)
	Authenticate(ctx context.Context, email, password string) (*User, error)
}

// GOOD: Small, focused interfaces
type UserFinder interface {
	FindByID(ctx context.Context, id int64) (*User, error)
}

type UserCreator interface {
	Create(ctx context.Context, user *User) error
}

type UserAuthenticator interface {
	Authenticate(ctx context.Context, email, password string) (*User, error)
}

// Compose interfaces when needed
type UserRepository interface {
	UserFinder
	UserCreator
	Update(ctx context.Context, user *User) error
	Delete(ctx context.Context, id int64) error
}
```

**Rules:**
- Ideal: 1-3 methods per interface
- Questionable: 5+ methods
- Compose small interfaces when broader capability needed
- Name single-method interfaces with -er suffix (Finder, Creator, Reader)

## Pattern 3: Standard Library Interfaces

Leverage standard library interfaces for maximum compatibility.

```go
package report

import (
	"io"
	"encoding/json"
)

// Accept io.Writer instead of *os.File or *bytes.Buffer
func GenerateReport(w io.Writer, data *Report) error {
	encoder := json.NewEncoder(w)
	return encoder.Encode(data)
}

// Works with any io.Writer: files, buffers, HTTP responses
f, _ := os.Create("report.json")
defer f.Close()
GenerateReport(f, &report)

var buf bytes.Buffer
GenerateReport(&buf, &report)

// In an HTTP handler: GenerateReport(w, &report)
```

**Common stdlib interfaces:**
- `io.Reader`, `io.Writer`, `io.Closer` - I/O operations
- `io.ReadWriter`, `io.ReadCloser`, `io.WriteCloser` - Composed I/O
- `fmt.Stringer` - String representation
- `error` - Error handling
- `sort.Interface` - Custom sorting

## Pattern 4: Interface Satisfaction Verification

Verify at compile-time that types implement interfaces.

```go
package storage

type Storage interface {
	Save(ctx context.Context, key string, value []byte) error
	Load(ctx context.Context, key string) ([]byte, error)
}

// Implementation
type FileStorage struct {
	baseDir string
}

// Compile-time check: FileStorage implements Storage
var _ Storage = (*FileStorage)(nil)

func (f *FileStorage) Save(ctx context.Context, key string, value []byte) error {
	// Implementation
	return nil
}

func (f *FileStorage) Load(ctx context.Context, key string) ([]byte, error) {
	// Implementation
	return nil, nil
}
```

**Rules:**
- Add verification line in same file as implementation
- Use pointer receiver if struct has pointer methods
- Fails at compile-time if interface not satisfied
- Documents intent: "This type implements this interface"

## Pattern 5: Empty Interface vs Generics

Choose between `any` (empty interface) and generics based on type safety needs.

```go
// Use any (interface{}) when type truly unknown at compile time
func PrintJSON(v any) error {
	data, err := json.Marshal(v)
	if err != nil {
		return err
	}
	fmt.Println(string(data))
	return nil
}

// Use generics when type must be consistent
type Cache[T any] struct {
	items map[string]T
}

func NewCache[T any]() *Cache[T] {
	return &Cache[T]{items: make(map[string]T)}
}

func (c *Cache[T]) Get(key string) (T, bool) {
	item, ok := c.items[key]
	return item, ok
}

func (c *Cache[T]) Set(key string, value T) {
	c.items[key] = value
}

// Usage: type-safe cache
cache := NewCache[*User]()
cache.Set("alice", &User{Name: "Alice"})
user, ok := cache.Get("alice") // Returns *User, not any
```

## Decision Framework: Interface vs Generics vs Concrete

| Use Interface | Use Generics | Use Concrete Type |
|---|---|---|
| Multiple implementations exist | Type-safe containers needed | Single implementation |
| Behavior abstraction needed | Algorithms work across types | No abstraction needed |
| Testing with mocks/fakes | Type safety without reflection | Simplicity preferred |
| Standard library compatibility | Collections (slice, map wrappers) | Clear, simple code |

**Decision Rule**: Default to concrete types. Add interface when testing or multiple implementations needed. Use generics for type-safe data structures.

## Pattern 6: Mock-Friendly Interface Design

Design interfaces that are easy to mock for testing.

```go
package order

// Small, focused interface
type PaymentProcessor interface {
	Charge(ctx context.Context, amount int64, currency string) (string, error)
}

// Service depends on interface
type OrderService struct {
	payments PaymentProcessor
}

func (s *OrderService) PlaceOrder(ctx context.Context, order *Order) error {
	transactionID, err := s.payments.Charge(ctx, order.Total, "USD")
	if err != nil {
		return fmt.Errorf("payment failed: %w", err)
	}
	order.TransactionID = transactionID
	return nil
}

// Test with mock
type MockPaymentProcessor struct {
	ChargeFunc func(ctx context.Context, amount int64, currency string) (string, error)
}

func (m *MockPaymentProcessor) Charge(ctx context.Context, amount int64, currency string) (string, error) {
	return m.ChargeFunc(ctx, amount, currency)
}

func TestOrderService_PlaceOrder(t *testing.T) {
	mock := &MockPaymentProcessor{
		ChargeFunc: func(ctx context.Context, amount int64, currency string) (string, error) {
			return "txn_123", nil
		},
	}

	svc := &OrderService{payments: mock}
	err := svc.PlaceOrder(context.Background(), &Order{Total: 5000})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
}
```

**Rules:**
- Keep interfaces small (easier to mock)
- Pass interfaces via struct fields or parameters
- Use function-based mocks (see `go-testing` skill for patterns)
- Mock only external dependencies (databases, APIs, payment processors)

## Pattern 7: Embedded Interfaces

Compose interfaces from smaller interfaces (see also Pattern 2 for domain-specific composition).

```go
type Store interface {
	Reader
	Writer
	Closer
}

// Implementations satisfy all embedded interfaces
var _ Store = (*FileStore)(nil)
var _ Reader = (*FileStore)(nil)
```

## Interface Naming Conventions

- Single-method interfaces: `-er` suffix (`Reader`, `Writer`, `Closer`, `Stringer`)
- Multi-method interfaces: descriptive noun (`FileSystem`, `UserRepository`)
- Avoid redundant `Interface` suffix: `UserRepository` not `UserRepositoryInterface`

## Additional Resources

- For common interface anti-patterns (premature abstraction, wrong package, returning interfaces), see [anti-patterns.md](references/anti-patterns.md)

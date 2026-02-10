---
name: go-interface-design
description: >
  Interface design patterns following Go idioms: accept interfaces, return structs,
  consumer-side definition, and interface segregation. Use when designing APIs,
  creating testable code, or reviewing interface abstractions.
---

# Go Interface Design

The bigger the interface, the weaker the abstraction. Accept interfaces, return concrete types.

## When to Apply

Use this skill when:
- Designing function signatures and APIs
- Creating abstractions for testing (mocks, fakes)
- Reviewing interface definitions (too big? too early?)
- Deciding between interfaces and generics
- Implementing dependency injection patterns

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

// Usage with different writers
func Example() {
	// Write to file
	f, _ := os.Create("report.json")
	defer f.Close()
	GenerateReport(f, report)

	// Write to buffer
	var buf bytes.Buffer
	GenerateReport(&buf, report)

	// Write to HTTP response
	GenerateReport(w http.ResponseWriter, report)
}
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

func (c *Cache[T]) Get(key string) (T, bool) {
	item, ok := c.items[key]
	return item, ok
}

func (c *Cache[T]) Set(key string, value T) {
	c.items[key] = value
}

// Usage: type-safe cache
cache := &Cache[*User]{}
cache.Set("alice", &User{Name: "Alice"})
user, ok := cache.Get("alice") // Returns *User, not any
```

## Decision Framework: Interface vs Generics vs Concrete

| Use Interface | Use Generics (Go 1.18+) | Use Concrete Type |
|---|---|---|
| Multiple implementations exist | Type-safe containers needed | Single implementation |
| Behavior abstraction needed | Algorithms work across types | No abstraction needed |
| Testing with mocks/fakes | Type safety without reflection | Simplicity preferred |
| Standard library compatibility | Collections (slice, map wrappers) | Clear, simple code |

**Decision Rule**: Default to concrete types. Add interface when testing or multiple implementations needed. Use generics for type-safe data structures.

## Pattern 6: Type Assertions and Type Switches

Safely work with interface values.

```go
// Type assertion
func ProcessValue(v any) error {
	// Check type with comma-ok idiom
	if str, ok := v.(string); ok {
		fmt.Println("String:", str)
		return nil
	}

	// Type switch for multiple types
	switch val := v.(type) {
	case string:
		fmt.Println("String:", val)
	case int, int64:
		fmt.Println("Integer:", val)
	case *User:
		fmt.Printf("User: %s (%s)\n", val.Name, val.Email)
	case io.Reader:
		// Can use interface type too
		data, _ := io.ReadAll(val)
		fmt.Println("Reader data:", string(data))
	default:
		return fmt.Errorf("unsupported type: %T", v)
	}
	return nil
}
```

**Rules:**
- Use comma-ok idiom for single type assertion
- Use type switch for multiple type checks
- Include default case in type switches
- Avoid type assertions in performance-critical code

## Pattern 7: Mock-Friendly Interface Design

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
	assert.NoError(t, err)
}
```

**Rules:**
- Keep interfaces small (easier to mock)
- Pass interfaces via struct fields or parameters
- Consider testify/mock or gomock for complex mocks
- Mock only external dependencies (databases, APIs, payment processors)

## Pattern 8: Embedded Interfaces

Compose interfaces from smaller interfaces.

```go
// Small interfaces
type Reader interface {
	Read(ctx context.Context, key string) ([]byte, error)
}

type Writer interface {
	Write(ctx context.Context, key string, value []byte) error
}

type Closer interface {
	Close() error
}

// Composed interface
type Store interface {
	Reader
	Writer
	Closer
}

// Implementation satisfies all embedded interfaces
type FileStore struct {
	file *os.File
}

func (f *FileStore) Read(ctx context.Context, key string) ([]byte, error) {
	// Implementation
	return nil, nil
}

func (f *FileStore) Write(ctx context.Context, key string, value []byte) error {
	// Implementation
	return nil
}

func (f *FileStore) Close() error {
	return f.file.Close()
}

// Verify implements all interfaces
var _ Store = (*FileStore)(nil)
var _ Reader = (*FileStore)(nil)
var _ Writer = (*FileStore)(nil)
```

## Anti-Patterns

### Premature interface abstraction

```go
// BAD: Interface created "just in case"
type UserRepository interface {
	FindByID(ctx context.Context, id int64) (*User, error)
}

type MySQLUserRepository struct{} // Only implementation

// GOOD: Start with concrete type, add interface when second implementation appears
type UserRepository struct {
	db *sqlx.DB
}

func (r *UserRepository) FindByID(ctx context.Context, id int64) (*User, error) {
	// Implementation
	return nil, nil
}
```

### Defining interface with implementation

```go
// BAD: Interface defined in provider package
package mysql

type Repository interface { // Wrong package!
	FindByID(ctx context.Context, id int64) (*User, error)
}

type MySQLRepository struct{}

// GOOD: Interface defined at consumer side
package service

type UserRepository interface { // Consumer defines interface
	FindByID(ctx context.Context, id int64) (*User, error)
}

type UserService struct {
	repo UserRepository // Accepts any implementation
}
```

### Returning interface instead of concrete type

```go
// BAD: Returning interface reduces flexibility
func NewUserService() UserRepository { // Returns interface
	return &MySQLUserRepository{}
}

// GOOD: Return concrete type, accept interface
func NewUserService(repo UserRepository) *UserService { // Accepts interface
	return &UserService{repo: repo} // Returns concrete type
}
```

### Interface with too many methods

```go
// BAD: God interface
type Service interface {
	GetUser(id int64) (*User, error)
	CreateUser(user *User) error
	UpdateUser(user *User) error
	DeleteUser(id int64) error
	ListUsers(limit int) ([]*User, error)
	SendEmail(to, subject, body string) error
	LogAction(action string) error
}

// GOOD: Separate interfaces by concern
type UserManager interface {
	GetUser(id int64) (*User, error)
	CreateUser(user *User) error
}

type Notifier interface {
	SendEmail(to, subject, body string) error
}

type Logger interface {
	LogAction(action string) error
}
```

### Using interface{} when specific type known

```go
// BAD: Losing type safety
func Calculate(a, b interface{}) interface{} {
	return a.(int) + b.(int) // Runtime panic risk
}

// GOOD: Use concrete types or generics
func Calculate(a, b int) int {
	return a + b
}

// Or with generics for multiple numeric types
func Add[T int | int64 | float64](a, b T) T {
	return a + b
}
```

## Interface Naming Conventions

```go
// Single-method interfaces: use -er suffix
type Reader interface { Read(p []byte) (n int, err error) }
type Writer interface { Write(p []byte) (n int, err error) }
type Closer interface { Close() error }
type Stringer interface { String() string }

// Multi-method interfaces: descriptive noun
type FileSystem interface {
	Open(name string) (File, error)
	Create(name string) (File, error)
	Remove(name string) error
}

// Avoid redundant "Interface" suffix
type UserRepository interface {} // Good
type UserRepositoryInterface interface {} // Bad
```

## References

- [Effective Go: Interfaces](https://go.dev/doc/effective_go#interfaces)
- [Go Proverbs: Interface Segregation](https://go-proverbs.github.io/)
- [Uber Go Style Guide: Interfaces](https://github.com/uber-go/guide/blob/master/style.md#interfaces)

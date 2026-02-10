# Interface Design Anti-Patterns

Common mistakes when working with interfaces in Go.

## Premature interface abstraction

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

## Defining interface with implementation

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

## Returning interface instead of concrete type

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

## Interface with too many methods

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

## Using interface{} when specific type known

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

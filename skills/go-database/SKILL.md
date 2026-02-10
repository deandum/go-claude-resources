---
name: go-database
description: >
  MySQL database patterns with sqlx and go-sqlmock. Connection pooling, query patterns,
  transactions, and testing. Use when building MySQL-backed services, implementing
  repositories, or reviewing database access code.
---

# Go Database (MySQL)

Always use context-aware methods. Close rows. Defer transaction rollback. Parameterize queries.

## When to Apply

Use this skill when:
- Connecting to MySQL databases with sqlx
- Implementing repository patterns for data access
- Managing transactions and connection pooling
- Testing database code with go-sqlmock
- Reviewing MySQL query patterns and error handling

## Decision Framework: sqlx vs database/sql

| Feature | database/sql | sqlx |
|---|---|---|
| Struct scanning | Manual (Scan) | Automatic (Get, Select) |
| Named parameters | Not supported | Supported (NamedExec, NamedQuery) |
| IN clause | Manual expansion | `sqlx.In()` helper |
| Boilerplate | More verbose | Less verbose |
| Dependencies | Stdlib only | External (jmoiron/sqlx) |
| **Recommendation** | Simple projects | **Production services (recommended)** |

**Decision Rule**: Use sqlx for production services. The reduced boilerplate and struct mapping outweigh the external dependency.

## Pattern 1: MySQL Connection with sqlx

Configure connection pooling for production workloads.

```go
package database

import (
	"fmt"
	"time"

	_ "github.com/go-sql-driver/mysql"
	"github.com/jmoiron/sqlx"
)

type Config struct {
	Host     string
	Port     int
	User     string
	Password string
	Database string
}

func Connect(cfg Config) (*sqlx.DB, error) {
	// MySQL DSN format
	dsn := fmt.Sprintf("%s:%s@tcp(%s:%d)/%s?parseTime=true&charset=utf8mb4&collation=utf8mb4_unicode_ci",
		cfg.User, cfg.Password, cfg.Host, cfg.Port, cfg.Database)

	db, err := sqlx.Connect("mysql", dsn)
	if err != nil {
		return nil, fmt.Errorf("connect to mysql: %w", err)
	}

	// Connection pool configuration
	db.SetMaxOpenConns(25)                 // Maximum open connections
	db.SetMaxIdleConns(5)                  // Maximum idle connections
	db.SetConnMaxLifetime(5 * time.Minute) // Connection lifetime
	db.SetConnMaxIdleTime(10 * time.Minute) // Idle connection lifetime

	// Verify connection
	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("ping database: %w", err)
	}

	return db, nil
}
```

**DSN Parameters:**
- `parseTime=true` - Parse DATE/DATETIME into time.Time
- `charset=utf8mb4` - Full Unicode support (including emojis)
- `collation=utf8mb4_unicode_ci` - Case-insensitive Unicode collation

**Pool Configuration:**
- `MaxOpenConns`: Total connections (DB + app)
- `MaxIdleConns`: Reusable connections (lower = less memory)
- `ConnMaxLifetime`: Prevents stale connections
- `ConnMaxIdleTime`: Cleans up idle connections

## Pattern 2: Query Patterns with sqlx

Use `Get` for single rows, `Select` for multiple rows.

```go
package repository

import (
	"context"
	"database/sql"
	"fmt"

	"github.com/jmoiron/sqlx"
)

type User struct {
	ID        int64     `db:"id"`
	Name      string    `db:"name"`
	Email     string    `db:"email"`
	CreatedAt time.Time `db:"created_at"`
}

type UserRepository struct {
	db *sqlx.DB
}

// Get: Single row query (returns sql.ErrNoRows if not found)
func (r *UserRepository) FindByID(ctx context.Context, id int64) (*User, error) {
	var user User
	err := r.db.GetContext(ctx, &user,
		"SELECT id, name, email, created_at FROM users WHERE id = ?", id)

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("user not found: %w", err)
	}
	if err != nil {
		return nil, fmt.Errorf("query user: %w", err)
	}

	return &user, nil
}

// Select: Multiple rows query
func (r *UserRepository) FindByEmail(ctx context.Context, email string) ([]*User, error) {
	var users []*User
	err := r.db.SelectContext(ctx, &users,
		"SELECT id, name, email, created_at FROM users WHERE email LIKE ?",
		"%"+email+"%")

	if err != nil {
		return nil, fmt.Errorf("query users: %w", err)
	}

	return users, nil
}

// Exec: INSERT/UPDATE/DELETE operations
func (r *UserRepository) Create(ctx context.Context, user *User) error {
	result, err := r.db.ExecContext(ctx,
		"INSERT INTO users (name, email, created_at) VALUES (?, ?, ?)",
		user.Name, user.Email, time.Now())

	if err != nil {
		return fmt.Errorf("insert user: %w", err)
	}

	id, _ := result.LastInsertId()
	user.ID = id
	return nil
}
```

**Rules:**
- Use `GetContext` for single row (errors if 0 or >1 rows)
- Use `SelectContext` for multiple rows (returns empty slice if 0 rows)
- Use `ExecContext` for mutations (INSERT/UPDATE/DELETE)
- Always use context-aware methods (*Context variants)
- Tag struct fields with `db:"column_name"`

## Pattern 3: Named Queries with Struct Binding

Use named parameters for cleaner code with many parameters.

```go
type UpdateUserParams struct {
	ID    int64  `db:"id"`
	Name  string `db:"name"`
	Email string `db:"email"`
}

func (r *UserRepository) Update(ctx context.Context, params UpdateUserParams) error {
	query := `UPDATE users SET name = :name, email = :email WHERE id = :id`

	result, err := r.db.NamedExecContext(ctx, query, params)
	if err != nil {
		return fmt.Errorf("update user: %w", err)
	}

	rows, _ := result.RowsAffected()
	if rows == 0 {
		return fmt.Errorf("user not found: %w", sql.ErrNoRows)
	}

	return nil
}

// Named query (SELECT with named parameters)
func (r *UserRepository) FindByNameAndEmail(ctx context.Context, name, email string) ([]*User, error) {
	query := `SELECT id, name, email, created_at FROM users
	          WHERE name = :name AND email = :email`

	params := map[string]interface{}{
		"name":  name,
		"email": email,
	}

	var users []*User
	rows, err := r.db.NamedQueryContext(ctx, query, params)
	if err != nil {
		return nil, fmt.Errorf("query users: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var user User
		if err := rows.StructScan(&user); err != nil {
			return nil, fmt.Errorf("scan user: %w", err)
		}
		users = append(users, &user)
	}

	return users, nil
}
```

**Rules:**
- Use `:paramName` syntax in query
- Pass struct or map with matching field names
- Use `NamedExecContext` for mutations
- Use `NamedQueryContext` when you need to iterate rows

## Pattern 4: IN Clause Handling

Use `sqlx.In()` to expand slices into IN clauses.

```go
import "github.com/jmoiron/sqlx"

func (r *UserRepository) FindByIDs(ctx context.Context, ids []int64) ([]*User, error) {
	if len(ids) == 0 {
		return []*User{}, nil
	}

	query := "SELECT id, name, email, created_at FROM users WHERE id IN (?)"

	// Expand IN clause and rebind for MySQL
	query, args, err := sqlx.In(query, ids)
	if err != nil {
		return nil, fmt.Errorf("expand IN clause: %w", err)
	}
	query = r.db.Rebind(query) // Convert ? to ? (MySQL uses ?, not $1)

	var users []*User
	if err := r.db.SelectContext(ctx, &users, query, args...); err != nil {
		return nil, fmt.Errorf("query users: %w", err)
	}

	return users, nil
}
```

**Rules:**
- Check for empty slice before query
- Use `sqlx.In()` to expand slice
- Use `db.Rebind()` to convert placeholders to MySQL format
- Pass `args...` (spread) to query

## Pattern 5: Transaction Management

Always defer rollback. Commit explicitly on success.

```go
func (r *UserRepository) Transfer(ctx context.Context, fromID, toID int64, amount int64) error {
	tx, err := r.db.BeginTxx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin transaction: %w", err)
	}
	defer tx.Rollback() // Always rollback (no-op if committed)

	// Deduct from sender
	_, err = tx.ExecContext(ctx,
		"UPDATE accounts SET balance = balance - ? WHERE user_id = ? AND balance >= ?",
		amount, fromID, amount)
	if err != nil {
		return fmt.Errorf("deduct balance: %w", err)
	}

	// Add to receiver
	_, err = tx.ExecContext(ctx,
		"UPDATE accounts SET balance = balance + ? WHERE user_id = ?",
		amount, toID)
	if err != nil {
		return fmt.Errorf("add balance: %w", err)
	}

	// Commit transaction
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("commit transaction: %w", err)
	}

	return nil
}
```

**Transaction Isolation Levels:**
```go
tx, err := r.db.BeginTxx(ctx, &sql.TxOptions{
	Isolation: sql.LevelReadCommitted, // Default for MySQL
	ReadOnly:  false,
})
```

**Rules:**
- Always `defer tx.Rollback()` immediately after BeginTxx
- Rollback is no-op after Commit (safe to defer)
- Use `ExecContext`, `GetContext`, `SelectContext` on tx
- Commit explicitly on success path

## Pattern 6: Repository Pattern with Dependency Injection

Wrap database in repository struct for clean architecture.

```go
package repository

type UserRepository struct {
	db *sqlx.DB
}

func NewUserRepository(db *sqlx.DB) *UserRepository {
	return &UserRepository{db: db}
}

// Interface for testing (defined at consumer side, not here)
type UserFinder interface {
	FindByID(ctx context.Context, id int64) (*User, error)
}

// Service depends on interface
package service

type UserService struct {
	repo repository.UserFinder // Interface, not concrete type
}

func NewUserService(repo repository.UserFinder) *UserService {
	return &UserService{repo: repo}
}
```

**Rules:**
- Repository wraps `*sqlx.DB`
- Constructor accepts `*sqlx.DB` parameter
- Return concrete repository type, not interface
- Consumer defines interface for testing

## Pattern 7: Error Handling (MySQL-Specific)

Handle MySQL-specific errors like duplicate keys and foreign key violations.

```go
import (
	"database/sql"
	"errors"

	"github.com/go-sql-driver/mysql"
)

func (r *UserRepository) Create(ctx context.Context, user *User) error {
	_, err := r.db.ExecContext(ctx,
		"INSERT INTO users (email, name) VALUES (?, ?)",
		user.Email, user.Name)

	if err != nil {
		// Check for MySQL-specific errors
		var mysqlErr *mysql.MySQLError
		if errors.As(err, &mysqlErr) {
			switch mysqlErr.Number {
			case 1062: // Duplicate entry
				return fmt.Errorf("email already exists: %w", err)
			case 1452: // Foreign key constraint fails
				return fmt.Errorf("foreign key violation: %w", err)
			}
		}
		return fmt.Errorf("insert user: %w", err)
	}

	return nil
}

// Distinguish sql.ErrNoRows from other errors
func (r *UserRepository) FindByEmail(ctx context.Context, email string) (*User, error) {
	var user User
	err := r.db.GetContext(ctx, &user,
		"SELECT id, name, email FROM users WHERE email = ?", email)

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("user not found: %w", err)
	}
	if err != nil {
		return nil, fmt.Errorf("query user: %w", err)
	}

	return &user, nil
}
```

**Common MySQL Error Codes:**
- `1062`: Duplicate entry (unique constraint)
- `1452`: Foreign key constraint fails
- `1048`: Column cannot be null

## Pattern 8: Testing with go-sqlmock

Mock database interactions without real database.

```go
package repository_test

import (
	"context"
	"database/sql"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/jmoiron/sqlx"
	"github.com/stretchr/testify/assert"
)

func TestUserRepository_FindByID(t *testing.T) {
	// Create mock DB
	mockDB, mock, err := sqlmock.New()
	assert.NoError(t, err)
	defer mockDB.Close()

	db := sqlx.NewDb(mockDB, "mysql")
	repo := NewUserRepository(db)

	t.Run("success", func(t *testing.T) {
		rows := sqlmock.NewRows([]string{"id", "name", "email", "created_at"}).
			AddRow(1, "Alice", "alice@example.com", time.Now())

		mock.ExpectQuery("SELECT (.+) FROM users WHERE id = ?").
			WithArgs(1).
			WillReturnRows(rows)

		user, err := repo.FindByID(context.Background(), 1)
		assert.NoError(t, err)
		assert.Equal(t, "Alice", user.Name)
		assert.NoError(t, mock.ExpectationsWereMet())
	})

	t.Run("not found", func(t *testing.T) {
		mock.ExpectQuery("SELECT (.+) FROM users WHERE id = ?").
			WithArgs(999).
			WillReturnError(sql.ErrNoRows)

		_, err := repo.FindByID(context.Background(), 999)
		assert.ErrorIs(t, err, sql.ErrNoRows)
		assert.NoError(t, mock.ExpectationsWereMet())
	})
}

func TestUserRepository_Create(t *testing.T) {
	mockDB, mock, _ := sqlmock.New()
	defer mockDB.Close()

	db := sqlx.NewDb(mockDB, "mysql")
	repo := NewUserRepository(db)

	mock.ExpectExec("INSERT INTO users").
		WithArgs("Alice", "alice@example.com", sqlmock.AnyArg()).
		WillReturnResult(sqlmock.NewResult(1, 1))

	user := &User{Name: "Alice", Email: "alice@example.com"}
	err := repo.Create(context.Background(), user)

	assert.NoError(t, err)
	assert.Equal(t, int64(1), user.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}
```

**Rules:**
- Use `sqlmock.New()` to create mock DB
- Use `sqlx.NewDb()` to wrap mock
- Set expectations before calling repository method
- Use `mock.ExpectationsWereMet()` to verify all expectations called
- Use `sqlmock.AnyArg()` for dynamic values like timestamps

## Migration Strategies (Brief)

Use golang-migrate for schema versioning.

```bash
# Install
go install -tags 'mysql' github.com/golang-migrate/migrate/v4/cmd/migrate@latest

# Create migration
migrate create -ext sql -dir db/migrations -seq create_users_table

# Run migrations
migrate -path db/migrations -database "mysql://user:pass@tcp(localhost:3306)/db" up
```

**Migration file example** (`000001_create_users_table.up.sql`):
```sql
CREATE TABLE users (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

## Decision Framework: When to Use Transactions

| Use Transaction | No Transaction Needed |
|---|---|
| Multiple related writes (transfer, order) | Single row INSERT/UPDATE |
| Data consistency critical | Read-only queries (SELECT) |
| Rollback needed on partial failure | Independent operations |
| Cross-table updates that must succeed together | Idempotent operations |

**Decision Rule**: If operation modifies multiple rows/tables and partial success would corrupt data, use transaction.

## Anti-Patterns

### Not using context-aware methods

```go
// BAD: No context propagation
rows, err := db.Query("SELECT * FROM users")

// GOOD: Context propagates cancellation
rows, err := db.QueryContext(ctx, "SELECT * FROM users")
```

### Forgetting to close rows

```go
// BAD: Resource leak
rows, _ := db.QueryContext(ctx, "SELECT * FROM users")
for rows.Next() {
	// ...
}

// GOOD: Always defer close
rows, err := db.QueryContext(ctx, "SELECT * FROM users")
if err != nil {
	return err
}
defer rows.Close() // Must close rows

for rows.Next() {
	// ...
}
```

### Transaction without defer rollback

```go
// BAD: Rollback only on error path
tx, _ := db.BeginTxx(ctx, nil)
if err := doWork(tx); err != nil {
	tx.Rollback()
	return err
}
tx.Commit()

// GOOD: Defer rollback (safe after commit)
tx, _ := db.BeginTxx(ctx, nil)
defer tx.Rollback() // No-op if committed

if err := doWork(tx); err != nil {
	return err
}
return tx.Commit()
```

### Hardcoded connection strings

```go
// BAD: Secrets in code
db, _ := sqlx.Connect("mysql", "root:password123@tcp(localhost:3306)/mydb")

// GOOD: Load from environment
cfg := Config{
	Host:     os.Getenv("DB_HOST"),
	User:     os.Getenv("DB_USER"),
	Password: os.Getenv("DB_PASSWORD"),
	Database: os.Getenv("DB_NAME"),
}
db, _ := Connect(cfg)
```

### SQL injection via string concatenation

```go
// BAD: SQL injection vulnerability
query := "SELECT * FROM users WHERE email = '" + email + "'"
db.Query(query)

// GOOD: Parameterized query
db.QueryContext(ctx, "SELECT * FROM users WHERE email = ?", email)
```

### N+1 query problem

```go
// BAD: N+1 queries (1 + N lookups)
orders, _ := db.QueryContext(ctx, "SELECT id, user_id FROM orders")
for orders.Next() {
	// Query for each order (N queries)
	user, _ := db.QueryContext(ctx, "SELECT name FROM users WHERE id = ?", userID)
}

// GOOD: Single query with JOIN
query := `
	SELECT o.id, o.user_id, u.name
	FROM orders o
	JOIN users u ON o.user_id = u.id
`
rows, _ := db.QueryContext(ctx, query)
```

## Connection Pool Sizing Guidelines

| Workload | MaxOpenConns | MaxIdleConns | Rationale |
|---|---|---|---|
| Low traffic API | 10-25 | 2-5 | Minimize idle connections |
| High traffic API | 50-100 | 10-20 | Handle spikes, reuse connections |
| Background jobs | 5-10 | 2-5 | Low concurrency |
| Mixed (API + jobs) | 25-50 | 5-10 | Balance both workloads |

**Formula**: MaxOpenConns ≤ MySQL max_connections / number of app instances

## References

- [sqlx documentation](https://jmoiron.github.io/sqlx/)
- [go-sqlmock documentation](https://github.com/DATA-DOG/go-sqlmock)
- [MySQL Driver (go-sql-driver)](https://github.com/go-sql-driver/mysql)
- [Organizing Database Access in Go](https://www.alexedwards.net/blog/organising-database-access)

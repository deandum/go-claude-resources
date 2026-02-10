---
name: go-database
description: >
  MySQL database patterns with sqlx and go-sqlmock. Connection pooling, query patterns,
  transactions, and testing. Use when building MySQL-backed services, implementing
  repositories, or reviewing database access code.
---

# Go Database (MySQL)

Always use context-aware methods. Close rows. Defer transaction rollback. Parameterize queries.

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

## Pattern 2: sqlx Query Patterns

Tag struct fields with `db:"column_name"` for automatic scanning:

```go
type User struct {
	ID        int64     `db:"id"`
	Name      string    `db:"name"`
	Email     string    `db:"email"`
	CreatedAt time.Time `db:"created_at"`
}
```

**Method selection:**

| Method | Use When | Notes |
|---|---|---|
| `GetContext` | Single row | Returns `sql.ErrNoRows` if not found |
| `SelectContext` | Multiple rows | Returns empty slice if 0 rows |
| `ExecContext` | INSERT/UPDATE/DELETE | Returns `sql.Result` for LastInsertId/RowsAffected |
| `NamedExecContext` | Mutations with many params | Uses `:paramName` syntax with struct or map |
| `NamedQueryContext` | SELECT with many params | Returns rows iterator, must `defer rows.Close()` |

**Rules:**
- Always use `*Context` variants (never `Query`, always `QueryContext`)
- Handle `sql.ErrNoRows` explicitly for single-row lookups
- For IN clauses: use `sqlx.In()` to expand, then `db.Rebind()` for MySQL placeholders
- Check for empty slice before IN queries

## Pattern 3: Transaction Management

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

## Pattern 4: Repository Pattern with Dependency Injection

Wrap database in repository struct for clean architecture.

```go
package repository

type UserRepository struct {
	db *sqlx.DB
}

func NewUserRepository(db *sqlx.DB) *UserRepository {
	return &UserRepository{db: db}
}

// Service defines the interface it needs (consumer-side)
package service

// UserFinder is defined where it's consumed, not alongside the implementation.
type UserFinder interface {
	FindByID(ctx context.Context, id int64) (*User, error)
}

type UserService struct {
	repo UserFinder
}

func NewUserService(repo UserFinder) *UserService {
	return &UserService{repo: repo}
}
```

**Rules:**
- Repository wraps `*sqlx.DB`
- Constructor accepts `*sqlx.DB` parameter
- Define interfaces at the consumer (service) side, not the provider (repository) side
- Consumer defines interface for testing

## Pattern 5: Error Handling (MySQL-Specific)

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

## Decision Framework: When to Use Transactions

| Use Transaction | No Transaction Needed |
|---|---|
| Multiple related writes (transfer, order) | Single row INSERT/UPDATE |
| Data consistency critical | Read-only queries (SELECT) |
| Rollback needed on partial failure | Independent operations |
| Cross-table updates that must succeed together | Idempotent operations |

**Decision Rule**: If operation modifies multiple rows/tables and partial success would corrupt data, use transaction.

## Connection Pool Sizing Guidelines

| Workload | MaxOpenConns | MaxIdleConns | Rationale |
|---|---|---|---|
| Low traffic API | 10-25 | 2-5 | Minimize idle connections |
| High traffic API | 50-100 | 10-20 | Handle spikes, reuse connections |
| Background jobs | 5-10 | 2-5 | Low concurrency |
| Mixed (API + jobs) | 25-50 | 5-10 | Balance both workloads |

**Formula**: MaxOpenConns ≤ MySQL max_connections / number of app instances

## Additional Resources

- For database testing with go-sqlmock, see [sqlmock-testing.md](references/sqlmock-testing.md)
- For migration strategies with golang-migrate, see [migration-guide.md](references/migration-guide.md)
- For common anti-patterns (context, rows, transactions, SQL injection, N+1), see [anti-patterns.md](references/anti-patterns.md)

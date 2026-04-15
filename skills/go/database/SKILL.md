---
name: go/database
description: >
  MySQL database patterns with sqlx. Connection pooling, query patterns,
  transactions, repository pattern, error handling. 100% Go-specific.
---

# Go Database (MySQL)

Always use context-aware methods. Close rows. Defer transaction rollback. Parameterize queries.

## sqlx vs database/sql

Use sqlx for production services. Reduced boilerplate and struct mapping outweigh the dependency.

## Connection Setup

```go
func Connect(cfg Config) (*sqlx.DB, error) {
    dsn := fmt.Sprintf("%s:%s@tcp(%s:%d)/%s?parseTime=true&charset=utf8mb4&collation=utf8mb4_unicode_ci",
        cfg.User, cfg.Password, cfg.Host, cfg.Port, cfg.Database)

    db, err := sqlx.Connect("mysql", dsn)
    if err != nil { return nil, fmt.Errorf("connect to mysql: %w", err) }

    db.SetMaxOpenConns(25)
    db.SetMaxIdleConns(5)
    db.SetConnMaxLifetime(5 * time.Minute)
    db.SetConnMaxIdleTime(10 * time.Minute)
    return db, db.Ping()
}
```

## Query Patterns

Tag structs: `db:"column_name"`. Method selection:

| Method | Use When |
|---|---|
| `GetContext` | Single row (returns `sql.ErrNoRows` if missing) |
| `SelectContext` | Multiple rows (empty slice if 0) |
| `ExecContext` | INSERT/UPDATE/DELETE |
| `NamedExecContext` | Mutations with many params |

Always use `*Context` variants. The non-context methods (`Exec`, `Query`, `Get`, `Select`) do not honor context cancellation or timeouts — a slow query keeps running even after the request is cancelled, holding a connection and a row-level lock. This is the most common Go database bug. Handle `sql.ErrNoRows` for single-row lookups. Use `sqlx.In()` + `db.Rebind()` for IN clauses.

### Anti-pattern: non-context methods

```go
// BAD — no timeout, no cancellation
rows, err := db.Query("SELECT * FROM users WHERE active = ?", true)

// GOOD — honors ctx deadline and cancellation
rows, err := db.QueryContext(ctx, "SELECT * FROM users WHERE active = ?", true)
```

Use a linter rule (e.g., `sqlrows` or a custom `grep` in CI) to prevent the non-context methods from being called at all.

## Transactions

```go
tx, err := r.db.BeginTxx(ctx, nil)
if err != nil { return fmt.Errorf("begin transaction: %w", err) }
defer tx.Rollback() // No-op after commit

_, err = tx.ExecContext(ctx, "UPDATE accounts SET balance = balance - ? WHERE user_id = ?", amount, fromID)
if err != nil { return fmt.Errorf("deduct balance: %w", err) }

return tx.Commit()
```

## Repository Pattern

```go
type UserRepository struct { db *sqlx.DB }
func NewUserRepository(db *sqlx.DB) *UserRepository { return &UserRepository{db: db} }

// Interface defined at consumer side
type UserFinder interface { FindByID(ctx context.Context, id int64) (*User, error) }
```

## MySQL Error Handling

```go
var mysqlErr *mysql.MySQLError
if errors.As(err, &mysqlErr) {
    switch mysqlErr.Number {
    case 1062: return fmt.Errorf("duplicate entry: %w", err)
    case 1452: return fmt.Errorf("foreign key violation: %w", err)
    }
}
```

## Pool Sizing

| Workload | MaxOpenConns | MaxIdleConns |
|---|---|---|
| Low traffic | 10-25 | 2-5 |
| High traffic | 50-100 | 10-20 |
| Background jobs | 5-10 | 2-5 |

Formula: MaxOpenConns <= MySQL max_connections / app instances

## Additional Resources

- [sqlmock-testing.md](references/sqlmock-testing.md), [migration-guide.md](references/migration-guide.md), [anti-patterns.md](references/anti-patterns.md)

## Verification

- [ ] `*Context` method variants used everywhere (never `Exec`, `Query`, `Get` without context)
- [ ] `defer tx.Rollback()` present immediately after every `BeginTxx` call
- [ ] All queries use parameterized placeholders (`?`) — no string concatenation of user input
- [ ] Connection pool configured (`SetMaxOpenConns`, `SetMaxIdleConns`, `SetConnMaxLifetime`)

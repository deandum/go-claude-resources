# Database Anti-Patterns

Common mistakes when working with MySQL/sqlx in Go.

## Contents

- [Not using context-aware methods](#not-using-context-aware-methods)
- [Forgetting to close rows](#forgetting-to-close-rows)
- [Transaction without defer rollback](#transaction-without-defer-rollback)
- [Hardcoded connection strings](#hardcoded-connection-strings)
- [SQL injection via string concatenation](#sql-injection-via-string-concatenation)
- [N+1 query problem](#n1-query-problem)

## Not using context-aware methods

```go
// BAD: No context propagation
rows, err := db.Query("SELECT * FROM users")

// GOOD: Context propagates cancellation
rows, err := db.QueryContext(ctx, "SELECT * FROM users")
```

## Forgetting to close rows

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

## Transaction without defer rollback

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

## Hardcoded connection strings

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

## SQL injection via string concatenation

```go
// BAD: SQL injection vulnerability
query := "SELECT * FROM users WHERE email = '" + email + "'"
db.Query(query)

// GOOD: Parameterized query
db.QueryContext(ctx, "SELECT * FROM users WHERE email = ?", email)
```

## N+1 query problem

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

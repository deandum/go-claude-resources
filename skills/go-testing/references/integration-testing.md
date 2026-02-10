# Integration Tests

Integration tests live in the `test-integration/` directory at the project root, organized by entity:

```go
// test-integration/user/postgres_test.go
package user_test

import (
    "context"
    "testing"

    "myservice/internal/user"
    "myservice/test-integration/helpers"
)

func TestUserRepository_Create(t *testing.T) {
    if testing.Short() {
        t.Skip("skipping integration test")
    }

    db := helpers.SetupTestDB(t)
    repo := user.NewPostgresRepository(db)

    ctx := context.Background()
    u := &user.User{
        ID:    "test-user-1",
        Name:  "Alice",
        Email: "alice@example.com",
    }

    err := repo.Save(ctx, u)
    if err != nil {
        t.Fatalf("Save failed: %v", err)
    }

    got, err := repo.FindByID(ctx, "test-user-1")
    if err != nil {
        t.Fatalf("FindByID failed: %v", err)
    }

    if got.Email != u.Email {
        t.Errorf("email = %q, want %q", got.Email, u.Email)
    }
}
```

## Shared Test Helpers

Create reusable helpers in `test-integration/helpers/`:

```go
// test-integration/helpers/postgres.go
func SetupTestDB(t *testing.T) *sql.DB {
    t.Helper()

    dsn := os.Getenv("TEST_DATABASE_URL")
    if dsn == "" {
        t.Skip("TEST_DATABASE_URL not set")
    }

    db, err := sql.Open("pgx", dsn)
    if err != nil {
        t.Fatalf("failed to open database: %v", err)
    }

    t.Cleanup(func() {
        db.Close()
    })

    return db
}
```

## Running Integration Tests

```bash
# Run only integration tests
go test ./test-integration/...

# Skip slow tests with -short flag
go test -short ./test-integration/...
```

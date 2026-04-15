# Testing with go-sqlmock

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

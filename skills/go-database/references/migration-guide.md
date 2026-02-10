# Migration Strategies

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

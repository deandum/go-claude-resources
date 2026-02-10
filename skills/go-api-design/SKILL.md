---
name: go-api-design
description: >
  HTTP and gRPC API design patterns for Go using go-chi router. Use when building REST APIs,
  gRPC services, middleware, or HTTP handlers. Covers routing, request
  validation, response formatting, and graceful shutdown.
---

# Go API Design

Design clear, consistent APIs using the go-chi router for idiomatic HTTP handling.

## When to Apply

Use this skill when:
- Building HTTP REST APIs
- Building gRPC services
- Designing middleware chains
- Structuring HTTP handlers
- Implementing request validation and response formatting

## HTTP Handler Structure

### Handler as a Struct with Dependencies

```go
type Handler struct {
    svc    *application.UserService
    logger *slog.Logger
}

func NewHandler(svc *application.UserService, logger *slog.Logger) *Handler {
    return &Handler{svc: svc, logger: logger}
}

func (h *Handler) Routes() http.Handler {
    r := chi.NewRouter()

    // Apply middleware
    r.Use(RequestID)
    r.Use(Logging(h.logger))
    r.Use(Recover(h.logger))

    // API routes
    r.Route("/api/v1", func(r chi.Router) {
        r.Get("/users", h.ListUsers)
        r.Post("/users", h.CreateUser)
        r.Get("/users/{id}", h.GetUser)
        r.Put("/users/{id}", h.UpdateUser)
        r.Delete("/users/{id}", h.DeleteUser)
    })

    return r
}
```

### Handler Method Pattern

Every handler follows the same structure: parse → validate → execute → respond.

```go
func (h *Handler) CreateUser(w http.ResponseWriter, r *http.Request) {
    // 1. Parse request
    var req CreateUserRequest
    if err := decodeJSON(r, &req); err != nil {
        writeError(w, http.StatusBadRequest, "invalid request body")
        return
    }

    // 2. Validate
    if err := req.Validate(); err != nil {
        writeError(w, http.StatusBadRequest, err.Error())
        return
    }

    // 3. Execute business logic
    user, err := h.svc.Create(r.Context(), req.ToDomain())
    if err != nil {
        h.handleError(w, r, err)
        return
    }

    // 4. Respond
    writeJSON(w, http.StatusCreated, toUserResponse(user))
}

func (h *Handler) GetUser(w http.ResponseWriter, r *http.Request) {
    // Extract URL parameter
    id := chi.URLParam(r, "id")
    if id == "" {
        writeError(w, http.StatusBadRequest, "user id is required")
        return
    }

    user, err := h.svc.GetByID(r.Context(), id)
    if err != nil {
        h.handleError(w, r, err)
        return
    }

    writeJSON(w, http.StatusOK, toUserResponse(user))
}
```

### Request and Response Types

Keep HTTP-layer types separate from domain types:

```go
// Request DTO
type CreateUserRequest struct {
    Name  string `json:"name"`
    Email string `json:"email"`
}

func (r *CreateUserRequest) Validate() error {
    var errs []error
    if r.Name == "" {
        errs = append(errs, fmt.Errorf("name is required"))
    }
    if r.Email == "" {
        errs = append(errs, fmt.Errorf("email is required"))
    }
    return errors.Join(errs...)
}

func (r *CreateUserRequest) ToDomain() *domain.User {
    return &domain.User{Name: r.Name, Email: r.Email}
}

// Response DTO
type UserResponse struct {
    ID        string    `json:"id"`
    Name      string    `json:"name"`
    Email     string    `json:"email"`
    CreatedAt time.Time `json:"created_at"`
}

func toUserResponse(u *domain.User) UserResponse {
    return UserResponse{
        ID:        u.ID,
        Name:      u.Name,
        Email:     u.Email,
        CreatedAt: u.CreatedAt,
    }
}
```

## JSON Helpers

```go
func decodeJSON(r *http.Request, v any) error {
    dec := json.NewDecoder(r.Body)
    dec.DisallowUnknownFields()
    if err := dec.Decode(v); err != nil {
        return fmt.Errorf("decoding JSON: %w", err)
    }
    return nil
}

func writeJSON(w http.ResponseWriter, status int, v any) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(status)
    if err := json.NewEncoder(w).Encode(v); err != nil {
        // Log but don't try to write another response
        slog.Error("encoding response", "error", err)
    }
}

type errorBody struct {
    Error string `json:"error"`
}

func writeError(w http.ResponseWriter, status int, msg string) {
    writeJSON(w, status, errorBody{Error: msg})
}
```

## Middleware

### Middleware Signature

Chi middleware uses the standard `func(http.Handler) http.Handler` signature. Apply middleware with `r.Use()`:

```go
r := chi.NewRouter()
r.Use(RequestID)
r.Use(Logging(logger))
r.Use(Recover(logger))

// Or apply to specific route groups
r.Route("/api/v1", func(r chi.Router) {
    r.Use(AuthMiddleware)  // Only for this group
    r.Get("/users", h.ListUsers)
})
```

### Request ID

```go
func RequestID(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        id := r.Header.Get("X-Request-ID")
        if id == "" {
            id = uuid.NewString()
        }
        ctx := context.WithValue(r.Context(), requestIDKey, id)
        w.Header().Set("X-Request-ID", id)
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}
```

### Logging Middleware

```go
func Logging(logger *slog.Logger) Middleware {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            start := time.Now()
            sw := &statusWriter{ResponseWriter: w, status: http.StatusOK}

            next.ServeHTTP(sw, r)

            logger.Info("request",
                "method", r.Method,
                "path", r.URL.Path,
                "status", sw.status,
                "duration", time.Since(start),
                "request_id", RequestIDFrom(r.Context()),
            )
        })
    }
}

type statusWriter struct {
    http.ResponseWriter
    status int
}

func (w *statusWriter) WriteHeader(status int) {
    w.status = status
    w.ResponseWriter.WriteHeader(status)
}
```

### Recovery Middleware

```go
func Recover(logger *slog.Logger) Middleware {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            defer func() {
                if rec := recover(); rec != nil {
                    logger.Error("panic recovered",
                        "panic", rec,
                        "stack", string(debug.Stack()),
                        "path", r.URL.Path,
                    )
                    writeError(w, http.StatusInternalServerError, "internal error")
                }
            }()
            next.ServeHTTP(w, r)
        })
    }
}
```

## Server Configuration

Never use the default `http.Client` or `http.Server` in production:

```go
srv := &http.Server{
    Addr:         ":8080",
    Handler:      handler,
    ReadTimeout:  15 * time.Second,
    WriteTimeout: 15 * time.Second,
    IdleTimeout:  60 * time.Second,
}
```

```go
client := &http.Client{
    Timeout: 10 * time.Second,
    Transport: &http.Transport{
        MaxIdleConns:        100,
        MaxIdleConnsPerHost: 10,
        IdleConnTimeout:     90 * time.Second,
    },
}
```

## Graceful Shutdown

See the `go-project-init` skill for the complete `main.go` pattern with signal handling and graceful shutdown.

## API Versioning

- Use URL path versioning: `/api/v1/users`
- Keep v1 handlers when introducing v2
- Use separate handler structs per major version if APIs diverge significantly

## Health Check Endpoint

```go
r.Get("/healthz", func(w http.ResponseWriter, r *http.Request) {
    writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
})

r.Get("/readyz", func(w http.ResponseWriter, r *http.Request) {
    if err := db.PingContext(r.Context()); err != nil {
        writeError(w, http.StatusServiceUnavailable, "database unavailable")
        return
    }
    writeJSON(w, http.StatusOK, map[string]string{"status": "ready"})
})
```

## Chi Route Groups and Sub-routers

Chi's `Route()` method creates route groups with shared prefixes and middleware:

```go
func (h *Handler) Routes() http.Handler {
    r := chi.NewRouter()
    r.Use(RequestID, Logging(h.logger), Recover(h.logger))

    // Public routes
    r.Get("/healthz", h.HealthCheck)

    // API v1 with versioned prefix
    r.Route("/api/v1", func(r chi.Router) {
        // Public API endpoints
        r.Post("/auth/login", h.Login)
        r.Post("/auth/register", h.Register)

        // Protected endpoints (requires auth)
        r.Group(func(r chi.Router) {
            r.Use(h.AuthMiddleware)

            r.Route("/users", func(r chi.Router) {
                r.Get("/", h.ListUsers)
                r.Post("/", h.CreateUser)

                r.Route("/{id}", func(r chi.Router) {
                    r.Get("/", h.GetUser)
                    r.Put("/", h.UpdateUser)
                    r.Delete("/", h.DeleteUser)
                })
            })

            r.Route("/posts", func(r chi.Router) {
                r.Get("/", h.ListPosts)
                r.Post("/", h.CreatePost)
            })
        })
    })

    return r
}
```

## Chi Built-in Middleware

Chi provides useful built-in middleware:

```go
import "github.com/go-chi/chi/v5/middleware"

r := chi.NewRouter()
r.Use(middleware.RequestID)      // Generates request ID
r.Use(middleware.RealIP)         // Sets RemoteAddr from X-Real-IP or X-Forwarded-For
r.Use(middleware.Logger)         // Logs requests
r.Use(middleware.Recoverer)      // Recovers from panics
r.Use(middleware.Timeout(60 * time.Second))  // Request timeout
r.Use(middleware.Compress(5))    // Gzip compression
```

## Swagger/OpenAPI Integration

Use go-swagger for automatic API documentation and validation.

### Code-First Approach: Annotate Go Code

```go
// Package classification User API.
//
// Documentation for User API
//
//	Schemes: http, https
//	BasePath: /api/v1
//	Version: 1.0.0
//	Contact: support@example.com
//
//	Consumes:
//	- application/json
//
//	Produces:
//	- application/json
//
// swagger:meta
package api

// swagger:parameters createUser
type CreateUserRequest struct {
	// User data to create
	// in: body
	// required: true
	Body struct {
		// User's full name
		// required: true
		// example: John Doe
		Name string `json:"name"`
		// User's email address
		// required: true
		// example: john@example.com
		Email string `json:"email"`
	}
}

// swagger:response userResponse
type UserResponse struct {
	// in: body
	Body struct {
		ID    int64  `json:"id"`
		Name  string `json:"name"`
		Email string `json:"email"`
	}
}

// swagger:route POST /users users createUser
//
// Create a new user
//
// Creates a new user in the system with the provided details.
//
// responses:
//   201: userResponse
//   400: errorResponse
func (h *Handler) CreateUser(w http.ResponseWriter, r *http.Request) {
	// Implementation
}
```

### Generate Swagger Specification

```bash
# Install go-swagger
go install github.com/go-swagger/go-swagger/cmd/swagger@latest

# Generate swagger.json from annotations
swagger generate spec -o ./swagger.json

# Serve Swagger UI
swagger serve -F swagger ./swagger.json
```

**Makefile targets:**
```makefile
.PHONY: swagger
swagger:
	swagger generate spec -o ./swagger.json --scan-models

.PHONY: swagger-serve
swagger-serve: swagger
	swagger serve -F swagger ./swagger.json
```

### Swagger Validation Middleware

Integrate swagger validation with chi router:

```go
import (
	"github.com/go-openapi/loads"
	"github.com/go-openapi/runtime/middleware"
)

func setupSwagger(r chi.Router) error {
	// Load swagger spec
	swaggerSpec, err := loads.Analyzed(SwaggerJSON, "")
	if err != nil {
		return err
	}

	// Serve swagger.json
	r.Get("/swagger.json", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write(SwaggerJSON)
	})

	// Serve Swagger UI
	opts := middleware.RedocOpts{SpecURL: "/swagger.json"}
	r.Handle("/docs", middleware.Redoc(opts, nil))

	return nil
}
```

### Decision Framework: Spec-First vs Code-First

| Approach | Spec-First | Code-First (Recommended) |
|---|---|---|
| **Workflow** | Write OpenAPI spec → Generate code | Write Go code → Generate spec |
| **Pros** | Contract-first, language-agnostic | Leverages existing Go code, less duplication |
| **Cons** | Code generation overhead, synchronization | Annotations can be verbose |
| **Best For** | Multi-language teams, strict API contracts | Go-only teams, rapid iteration |

**Recommendation**: Use code-first with go-swagger for Go-centric teams. Use spec-first when API contract must be language-agnostic.

## References

- [go-chi router](https://github.com/go-chi/chi)
- [go-swagger](https://github.com/go-swagger/go-swagger)
- [OpenAPI Specification](https://swagger.io/specification/)
---
name: go-api-design
description: >
  HTTP API design patterns for Go using go-chi router. Use when building REST APIs,
  middleware, or HTTP handlers. Covers routing, request
  validation, response formatting, and graceful shutdown.
---

# Go API Design

Design clear, consistent APIs using the go-chi router for idiomatic HTTP handling.

## Contents

- [HTTP Handler Structure](#http-handler-structure)
- [JSON Helpers](#json-helpers)
- [Middleware](#middleware)
- [Server Configuration](#server-configuration)
- [Graceful Shutdown](#graceful-shutdown)
- [API Versioning](#api-versioning)
- [Health Check Endpoint](#health-check-endpoint)
- [Chi Route Groups and Sub-routers](#chi-route-groups-and-sub-routers)
- [Chi Built-in Middleware](#chi-built-in-middleware)
- [Additional Resources](#additional-resources)

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
```

All handlers follow this same parse → validate → execute → respond structure. Extract URL parameters with `chi.URLParam(r, "id")`.

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

// handleError maps domain/application errors to HTTP status codes.
// Adapt the error types to match your application's error package.
func (h *Handler) handleError(w http.ResponseWriter, r *http.Request, err error) {
    switch {
    case errors.Is(err, domain.ErrNotFound):
        writeError(w, http.StatusNotFound, "resource not found")
    case errors.Is(err, domain.ErrConflict):
        writeError(w, http.StatusConflict, "resource already exists")
    case errors.Is(err, domain.ErrValidation):
        writeError(w, http.StatusUnprocessableEntity, err.Error())
    default:
        h.logger.Error("internal error",
            "error", err,
            "path", r.URL.Path,
            "request_id", RequestIDFrom(r.Context()),
        )
        writeError(w, http.StatusInternalServerError, "internal error")
    }
}
```

## Middleware

### Middleware Signature

Chi middleware uses the standard `func(http.Handler) http.Handler` signature:

```go
type Middleware = func(http.Handler) http.Handler
```

Apply middleware with `r.Use()`:

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

See the `go-observability` skill for health check patterns (`/healthz` and `/readyz` with dependency checks).

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

Chi provides middleware via `github.com/go-chi/chi/v5/middleware`: `RequestID`, `RealIP`, `Logger`, `Recoverer`, `Timeout`, `Compress`, and more. Prefer the custom implementations above when you need structured logging or custom behavior.

## Additional Resources

- For Swagger/OpenAPI integration with go-swagger (code-first annotations, spec generation, validation middleware), see [swagger-openapi.md](references/swagger-openapi.md)


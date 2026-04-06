---
name: go/api-design
description: >
  Go HTTP API patterns with chi router. Handlers, middleware, JSON helpers,
  server config, graceful shutdown. Extends core/api-design with Go
  implementation patterns.
---

# Go API Design

Use chi router for idiomatic HTTP handling. Handlers as struct methods with dependencies.

## Handler Structure

```go
type Handler struct {
    svc    *application.UserService
    logger *slog.Logger
}

func (h *Handler) Routes() http.Handler {
    r := chi.NewRouter()
    r.Use(RequestID, Logging(h.logger), Recover(h.logger))
    r.Route("/api/v1", func(r chi.Router) {
        r.Get("/users/{id}", h.GetUser)
        r.Post("/users", h.CreateUser)
    })
    return r
}
```

## Handler Method (parse -> validate -> execute -> respond)

```go
func (h *Handler) CreateUser(w http.ResponseWriter, r *http.Request) {
    var req CreateUserRequest
    if err := decodeJSON(r, &req); err != nil {
        writeError(w, http.StatusBadRequest, "invalid request body"); return
    }
    if err := req.Validate(); err != nil {
        writeError(w, http.StatusBadRequest, err.Error()); return
    }
    user, err := h.svc.Create(r.Context(), req.ToDomain())
    if err != nil { h.handleError(w, r, err); return }
    writeJSON(w, http.StatusCreated, toUserResponse(user))
}
```

## JSON Helpers

```go
func decodeJSON(r *http.Request, v any) error {
    dec := json.NewDecoder(r.Body); dec.DisallowUnknownFields()
    return dec.Decode(v)
}

func writeJSON(w http.ResponseWriter, status int, v any) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(status)
    json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, msg string) {
    writeJSON(w, status, map[string]string{"error": msg})
}
```

## Middleware Pattern

`func(http.Handler) http.Handler` — chi standard signature.

```go
func RequestID(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        id := r.Header.Get("X-Request-ID")
        if id == "" { id = uuid.NewString() }
        ctx := context.WithValue(r.Context(), requestIDKey, id)
        w.Header().Set("X-Request-ID", id)
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}
```

## Server Configuration

```go
srv := &http.Server{
    Addr: ":8080", Handler: handler,
    ReadTimeout: 15 * time.Second, WriteTimeout: 15 * time.Second, IdleTimeout: 60 * time.Second,
}
```

URL params: `chi.URLParam(r, "id")`. Route groups: `r.Route("/api/v1", func(r chi.Router) { ... })`.

Chi built-in middleware: `middleware.RequestID`, `RealIP`, `Logger`, `Recoverer`, `Timeout`, `Compress`.

## Additional Resources

- [swagger-openapi.md](references/swagger-openapi.md) — go-swagger annotations, spec generation

## Verification

- [ ] Server timeouts configured (`ReadTimeout`, `WriteTimeout`, `IdleTimeout`)
- [ ] Middleware applied in correct order (RequestID, Logging, Recover)
- [ ] Chi URL params extracted with `chi.URLParam(r, "param")`
- [ ] JSON decoding uses `DisallowUnknownFields` to reject unexpected fields

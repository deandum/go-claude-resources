---
name: go-observability
description: >
  Logging, metrics, and tracing patterns for Go services. Use when
  adding structured logging, instrumenting services, setting up
  distributed tracing, configuring health checks, implementing alerting,
  or propagating correlation IDs across microservices.
---

# Go Observability

Log only actionable information. Where logging is expensive, instrumentation is cheap.

## Structured Logging with slog

Use `log/slog` (stdlib). No external logging libraries needed.

### Setup

```go
func setupLogger(level slog.Level, format string) *slog.Logger {
    var handler slog.Handler
    opts := &slog.HandlerOptions{Level: level}

    switch format {
    case "json":
        handler = slog.NewJSONHandler(os.Stdout, opts)
    default:
        handler = slog.NewTextHandler(os.Stdout, opts)
    }

    logger := slog.New(handler)
    slog.SetDefault(logger)
    return logger
}
```

### Logging Guidelines

**Log levels:**
- `Info` — significant state changes, request completion, startup/shutdown
- `Error` — failures that need human attention or automated alerting
- `Debug` — detailed diagnostic information for development
- `Warn` — unusual situations that might indicate problems

**Rules:**
- Log at service boundaries, not inside every function
- Include structured fields, not string interpolation
- Never log sensitive data (passwords, tokens, PII)
- Use `Info` and `Error` in production; `Debug` only with explicit opt-in
- Each log line should be independently useful

```go
// GOOD: structured, actionable
logger.Info("order processed",
    "order_id", order.ID,
    "user_id", order.UserID,
    "total", order.Total,
    "duration", time.Since(start),
)

logger.Error("payment failed",
    "order_id", order.ID,
    "error", err,
    "provider", "stripe",
)

// BAD: unstructured, not actionable
log.Printf("Processing order %s for user %s...", order.ID, order.UserID)
log.Printf("ERROR: something went wrong: %v", err)
```

### Context-Aware Logging

Carry request-scoped fields through context:

```go
type ctxKey string

const logFieldsKey ctxKey = "log_fields"

func WithLogFields(ctx context.Context, fields ...any) context.Context {
    existing, _ := ctx.Value(logFieldsKey).([]any)
    return context.WithValue(ctx, logFieldsKey, append(existing, fields...))
}

func LogFromCtx(ctx context.Context, logger *slog.Logger) *slog.Logger {
    fields, _ := ctx.Value(logFieldsKey).([]any)
    if len(fields) == 0 {
        return logger
    }
    return logger.With(fields...)
}
```

Usage in middleware:

```go
func RequestLogging(logger *slog.Logger) Middleware {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            ctx := WithLogFields(r.Context(),
                "request_id", RequestIDFrom(r.Context()),
                "method", r.Method,
                "path", r.URL.Path,
            )
            next.ServeHTTP(w, r.WithContext(ctx))
        })
    }
}
```

## Metrics

### Prometheus-Style Metrics

```go
import "github.com/prometheus/client_golang/prometheus"

var (
    httpRequestsTotal = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "http_requests_total",
            Help: "Total number of HTTP requests",
        },
        []string{"method", "path", "status"},
    )

    httpRequestDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "http_request_duration_seconds",
            Help:    "HTTP request latency in seconds",
            Buckets: prometheus.DefBuckets,
        },
        []string{"method", "path"},
    )

    dbQueryDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "db_query_duration_seconds",
            Help:    "Database query latency in seconds",
            Buckets: []float64{.001, .005, .01, .025, .05, .1, .25, .5, 1},
        },
        []string{"query"},
    )
)

// RegisterMetrics registers all application metrics with Prometheus.
// Call this during application startup.
func RegisterMetrics() {
    prometheus.MustRegister(httpRequestsTotal, httpRequestDuration, dbQueryDuration)
}
```

### Metrics Middleware

```go
func Metrics(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()
        sw := &statusWriter{ResponseWriter: w, status: http.StatusOK}

        next.ServeHTTP(sw, r)

        duration := time.Since(start).Seconds()
        status := strconv.Itoa(sw.status)
        pattern := r.Pattern // Matched route pattern

        httpRequestsTotal.WithLabelValues(r.Method, pattern, status).Inc()
        httpRequestDuration.WithLabelValues(r.Method, pattern).Observe(duration)
    })
}
```

### What to Instrument

Follow the **RED method** for services:
- **R**ate — requests per second
- **E**rrors — failed requests per second
- **D**uration — latency distributions

Follow the **USE method** for resources:
- **U**tilization — how full is the resource
- **S**aturation — how much queued work
- **E**rrors — error count

## Correlation IDs

Track requests across microservices with unique identifiers. See [correlation-ids.md](references/correlation-ids.md) for complete patterns including generation, HTTP propagation, logging integration, and OpenTelemetry alignment.

## Distributed Tracing with OpenTelemetry

```go
import (
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/trace"
)

var tracer = otel.Tracer("myservice")

func (s *UserService) FindByID(ctx context.Context, id string) (*User, error) {
    ctx, span := tracer.Start(ctx, "UserService.FindByID",
        trace.WithAttributes(
            attribute.String("user.id", id),
        ),
    )
    defer span.End()

    user, err := s.repo.FindByID(ctx, id)
    if err != nil {
        span.RecordError(err)
        span.SetStatus(codes.Error, err.Error())
        return nil, err
    }

    return user, nil
}
```

## Health Checks

```go
func (h *Handler) RegisterHealth(mux *http.ServeMux) {
    mux.HandleFunc("GET /healthz", h.healthz)
    mux.HandleFunc("GET /readyz", h.readyz)
}

// healthz: is the process alive?
func (h *Handler) healthz(w http.ResponseWriter, r *http.Request) {
    writeJSON(w, http.StatusOK, map[string]string{"status": "alive"})
}

// readyz: is the service ready to accept traffic?
func (h *Handler) readyz(w http.ResponseWriter, r *http.Request) {
    checks := map[string]error{
        "database": h.db.PingContext(r.Context()),
        "cache":    h.cache.Ping(r.Context()),
    }

    status := http.StatusOK
    result := make(map[string]string)

    for name, err := range checks {
        if err != nil {
            status = http.StatusServiceUnavailable
            result[name] = err.Error()
        } else {
            result[name] = "ok"
        }
    }

    writeJSON(w, status, result)
}
```

## Anti-Patterns

- **Logging everything** — log at boundaries, not inside every function
- **fmt.Printf in production** — use structured logging
- **High-cardinality labels** — don't use user IDs or request IDs as metric labels
- **Missing error logs** — unhandled errors in the top-level handler should always be logged
- **Logging sensitive data** — never log passwords, tokens, credit cards, or PII
- **No timeouts** — every external call should have a context timeout

## Additional Resources

- For alerting best practices (golden signals, Prometheus rules, severity levels, fatigue prevention), see [alerting.md](references/alerting.md)
- For correlation ID patterns (generation, propagation, logging integration), see [correlation-ids.md](references/correlation-ids.md)
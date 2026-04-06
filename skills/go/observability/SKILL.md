---
name: go/observability
description: >
  Go observability with slog, Prometheus, and OpenTelemetry. Structured
  logging, metrics middleware, tracing, health checks. Extends
  core/observability with Go SDK patterns.
---

# Go Observability

Use `log/slog` (stdlib) for logging. Prometheus for metrics. OpenTelemetry for tracing.

## Structured Logging (slog)

```go
func setupLogger(level slog.Level, format string) *slog.Logger {
    var handler slog.Handler
    opts := &slog.HandlerOptions{Level: level}
    switch format {
    case "json": handler = slog.NewJSONHandler(os.Stdout, opts)
    default: handler = slog.NewTextHandler(os.Stdout, opts)
    }
    logger := slog.New(handler); slog.SetDefault(logger)
    return logger
}
```

```go
logger.Info("order processed", "order_id", order.ID, "duration", time.Since(start))
logger.Error("payment failed", "order_id", order.ID, "error", err)
```

## Context-Aware Logging

```go
func WithLogFields(ctx context.Context, fields ...any) context.Context {
    existing, _ := ctx.Value(logFieldsKey).([]any)
    return context.WithValue(ctx, logFieldsKey, append(existing, fields...))
}

func LogFromCtx(ctx context.Context, logger *slog.Logger) *slog.Logger {
    fields, _ := ctx.Value(logFieldsKey).([]any)
    if len(fields) == 0 { return logger }
    return logger.With(fields...)
}
```

## Prometheus Metrics

```go
var (
    httpRequestsTotal = prometheus.NewCounterVec(
        prometheus.CounterOpts{Name: "http_requests_total", Help: "Total HTTP requests"},
        []string{"method", "path", "status"},
    )
    httpRequestDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{Name: "http_request_duration_seconds", Buckets: prometheus.DefBuckets},
        []string{"method", "path"},
    )
)
```

## OpenTelemetry Tracing

```go
var tracer = otel.Tracer("myservice")

func (s *UserService) FindByID(ctx context.Context, id string) (*User, error) {
    ctx, span := tracer.Start(ctx, "UserService.FindByID",
        trace.WithAttributes(attribute.String("user.id", id)))
    defer span.End()

    user, err := s.repo.FindByID(ctx, id)
    if err != nil { span.RecordError(err); span.SetStatus(codes.Error, err.Error()); return nil, err }
    return user, nil
}
```

## Health Checks

```go
func (h *Handler) healthz(w http.ResponseWriter, r *http.Request) {
    writeJSON(w, http.StatusOK, map[string]string{"status": "alive"})
}

func (h *Handler) readyz(w http.ResponseWriter, r *http.Request) {
    checks := map[string]error{"database": h.db.PingContext(r.Context())}
    status := http.StatusOK; result := make(map[string]string)
    for name, err := range checks {
        if err != nil { status = http.StatusServiceUnavailable; result[name] = err.Error() } else { result[name] = "ok" }
    }
    writeJSON(w, status, result)
}
```

## Additional Resources

- [alerting.md](references/alerting.md), [correlation-ids.md](references/correlation-ids.md)

## Verification

- [ ] `slog` structured logging configured with appropriate level and format
- [ ] Prometheus metrics registered and exposed at `/metrics` endpoint
- [ ] Health endpoints (`/healthz`, `/readyz`) respond with HTTP 200 when healthy
- [ ] No PII (emails, passwords, tokens) present in log output

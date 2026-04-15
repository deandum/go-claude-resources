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

**Test isolation.** `slog.SetDefault(logger)` mutates global state. Tests that replace the default logger should restore it afterwards, otherwise later tests inherit a broken global:

```go
func TestSomething(t *testing.T) {
    prev := slog.Default()
    t.Cleanup(func() { slog.SetDefault(prev) })
    slog.SetDefault(slog.New(slog.NewTextHandler(io.Discard, nil)))
    // ... test code
}
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

func init() {
    prometheus.MustRegister(httpRequestsTotal, httpRequestDuration)
}
```

Expose the `/metrics` endpoint on your HTTP server:

```go
import "github.com/prometheus/client_golang/prometheus/promhttp"

mux.Handle("/metrics", promhttp.Handler())
```

Keep `/metrics` on a separate admin port if your service is internet-facing — you do not want Prometheus scrape traffic hitting the same listener as user requests, and you do not want the metric endpoint exposed publicly.

## OpenTelemetry Tracing

Set up the tracer provider once at startup and register it globally:

```go
import (
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
    sdktrace "go.opentelemetry.io/otel/sdk/trace"
    "go.opentelemetry.io/otel/sdk/resource"
    semconv "go.opentelemetry.io/otel/semconv/v1.24.0"
)

func initTracer(ctx context.Context, serviceName, otlpEndpoint string) (func(context.Context) error, error) {
    exporter, err := otlptracegrpc.New(ctx,
        otlptracegrpc.WithEndpoint(otlpEndpoint),
        otlptracegrpc.WithInsecure(),
    )
    if err != nil {
        return nil, fmt.Errorf("otlp exporter: %w", err)
    }
    res, _ := resource.New(ctx, resource.WithAttributes(semconv.ServiceName(serviceName)))
    tp := sdktrace.NewTracerProvider(
        sdktrace.WithBatcher(exporter),
        sdktrace.WithResource(res),
    )
    otel.SetTracerProvider(tp)
    return tp.Shutdown, nil
}
```

Call `initTracer` at startup and `defer shutdown(ctx)` in `main`. Then use the global tracer in request handling:

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

- [alerting.md](../../../references/alerting.md), [correlation-ids.md](references/correlation-ids.md)

## Verification

- [ ] `slog` structured logging configured with appropriate level and format
- [ ] Prometheus metrics registered via `prometheus.MustRegister` and exposed at `/metrics` (ideally on a separate admin port)
- [ ] OpenTelemetry tracer initialized at startup with a real exporter and resource attributes; shutdown deferred in `main`
- [ ] Health endpoints (`/healthz`, `/readyz`) respond with HTTP 200 when healthy
- [ ] No PII (emails, passwords, tokens) present in log output
- [ ] Tests that call `slog.SetDefault` restore the previous default via `t.Cleanup`

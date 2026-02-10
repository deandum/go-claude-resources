---
name: go-observability
description: >
  Logging, metrics, and tracing patterns for Go services. Use when
  adding structured logging, instrumenting services, setting up
  distributed tracing, or configuring health checks.
---

# Go Observability

Log only actionable information. Where logging is expensive, instrumentation is cheap.

## When to Apply

Use this skill when:
- Setting up structured logging for a service
- Adding metrics and instrumentation
- Implementing distributed tracing
- Configuring health check endpoints
- Reviewing observability practices

## Structured Logging with slog

Use `log/slog` (stdlib since Go 1.21). No external logging libraries needed.

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

func init() {
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
        pattern := r.Pattern // Go 1.22+ matched route pattern

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

Correlation IDs (also called request IDs or trace IDs) are unique identifiers that track a request as it flows through multiple microservices. They're essential for debugging distributed systems.

### Why Correlation IDs Matter

- **End-to-end tracing** — link logs across all services in a request chain
- **Debugging** — quickly find all logs related to a specific user request
- **Performance analysis** — measure total latency across service boundaries
- **Support** — users can provide an ID to help troubleshoot specific issues

### Generating Correlation IDs

Use UUIDs or similar globally unique identifiers:

```go
import (
    "github.com/google/uuid"
)

func generateCorrelationID() string {
    return uuid.New().String()
}
```

### Propagating Through HTTP Headers

**Standard header:** Use `X-Correlation-ID` or follow OpenTelemetry conventions with `traceparent`.

```go
const CorrelationIDHeader = "X-Correlation-ID"

type ctxKey string

const correlationIDKey ctxKey = "correlation_id"

// Middleware to extract or generate correlation ID
func CorrelationID(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        correlationID := r.Header.Get(CorrelationIDHeader)
        if correlationID == "" {
            correlationID = uuid.New().String()
        }

        // Add to response headers for client visibility
        w.Header().Set(CorrelationIDHeader, correlationID)

        // Store in context
        ctx := context.WithValue(r.Context(), correlationIDKey, correlationID)
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}

func CorrelationIDFrom(ctx context.Context) string {
    if id, ok := ctx.Value(correlationIDKey).(string); ok {
        return id
    }
    return ""
}
```

### Propagating to Downstream Services

Always forward correlation IDs when making HTTP calls to other services:

```go
func (c *Client) Call(ctx context.Context, req *Request) (*Response, error) {
    httpReq, err := http.NewRequestWithContext(ctx, req.Method, req.URL, req.Body)
    if err != nil {
        return nil, err
    }

    // Forward correlation ID to downstream service
    if correlationID := CorrelationIDFrom(ctx); correlationID != "" {
        httpReq.Header.Set(CorrelationIDHeader, correlationID)
    }

    resp, err := c.httpClient.Do(httpReq)
    // ... handle response
}
```

### Including in Logs

Always include correlation IDs in structured logs:

```go
func RequestLogging(logger *slog.Logger) Middleware {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            start := time.Now()

            correlationID := CorrelationIDFrom(r.Context())

            // Add correlation ID to all logs for this request
            ctx := WithLogFields(r.Context(),
                "correlation_id", correlationID,
                "method", r.Method,
                "path", r.URL.Path,
            )

            next.ServeHTTP(w, r.WithContext(ctx))

            // Log request completion with correlation ID
            LogFromCtx(ctx, logger).Info("request completed",
                "status", w.(*statusWriter).status,
                "duration", time.Since(start),
            )
        })
    }
}
```

Example log output across services:

```json
// Service A (API Gateway)
{"level":"info","msg":"request started","correlation_id":"550e8400-e29b-41d4-a716-446655440000","service":"api-gateway"}

// Service B (User Service)
{"level":"info","msg":"fetching user","correlation_id":"550e8400-e29b-41d4-a716-446655440000","service":"user-service"}

// Service C (Auth Service)
{"level":"info","msg":"validating token","correlation_id":"550e8400-e29b-41d4-a716-446655440000","service":"auth-service"}
```

### Integration with Distributed Tracing

If using OpenTelemetry, correlation IDs should align with trace IDs:

```go
import (
    "go.opentelemetry.io/otel/trace"
)

func CorrelationIDFromSpan(ctx context.Context) string {
    span := trace.SpanFromContext(ctx)
    if span.SpanContext().IsValid() {
        return span.SpanContext().TraceID().String()
    }
    return ""
}
```

### Best Practices

- **Generate at entry point** — the first service in the chain creates the ID
- **Propagate everywhere** — pass to all downstream services and async jobs
- **Log consistently** — include in every log line within a request context
- **Return to client** — include in response headers for client-side debugging
- **Keep it simple** — UUIDs are sufficient; no need for complex schemes
- **Don't use for metrics** — correlation IDs are too high-cardinality for metric labels
- **Store for support** — persist IDs with completed transactions for customer support
- **Document your header** — clearly document which header name you use

### Common Pitfalls

- **Missing propagation** — forgetting to pass IDs to background jobs or message queues
- **Inconsistent naming** — mixing different header names across services
- **Overwriting IDs** — generating new IDs in downstream services instead of reusing
- **Not logging IDs** — having IDs in headers but not in log output
- **Using as security token** — correlation IDs are for observability, not authentication

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

## Alerting Best Practices

Alert on symptoms, not causes. Make alerts actionable.

### What to Alert On: Golden Signals

Focus on user-facing symptoms:

**1. Latency** - Request duration exceeding SLO
**2. Traffic** - Unusual traffic patterns (spike or drop)
**3. Errors** - Error rate exceeding threshold
**4. Saturation** - Resource utilization approaching limits

### Decision Framework: Should This Be an Alert?

```
Can you take action on this?
├─ NO → Don't alert (use dashboard or log instead)
└─ YES
    └─ Does it impact users directly?
        ├─ NO → Reduce severity (warning, not critical)
        └─ YES
            └─ Is it happening NOW?
                ├─ NO → Use metrics/trends, not alerts
                └─ YES → Create actionable alert
```

### Prometheus Alerting Rules

```yaml
# alerts.yml
groups:
  - name: api_alerts
    interval: 30s
    rules:
      # High error rate
      - alert: HighErrorRate
        expr: |
          (
            rate(http_requests_total{status=~"5.."}[5m])
            /
            rate(http_requests_total[5m])
          ) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate on {{ $labels.instance }}"
          description: "Error rate is {{ $value | humanizePercentage }} (threshold: 5%)"
          runbook: "https://wiki.company.com/runbooks/high-error-rate"

      # High latency (p99)
      - alert: HighLatency
        expr: |
          histogram_quantile(0.99,
            rate(http_request_duration_seconds_bucket[5m])
          ) > 1.0
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High p99 latency on {{ $labels.instance }}"
          description: "p99 latency is {{ $value }}s (SLO: 1s)"

      # Service down
      - alert: ServiceDown
        expr: up{job="api"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Service {{ $labels.instance }} is down"
          description: "Health check failing for 1 minute"

      # High memory usage
      - alert: HighMemoryUsage
        expr: |
          (
            process_resident_memory_bytes
            /
            node_memory_MemTotal_bytes
          ) > 0.90
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"
          description: "Memory usage is {{ $value | humanizePercentage }} (threshold: 90%)"
```

### Alert Severity Levels

| Severity | Response Time | Impact | Examples |
|---|---|---|---|
| **Critical** | Immediate (page on-call) | User-facing outage | Service down, high error rate (>5%) |
| **Warning** | Business hours | Degraded performance | High latency, elevated error rate (2-5%) |
| **Info** | No immediate action | Informational | Deployment completed, scaling event |

### Alert Fatigue Prevention

**Rules:**
- Alert only on symptoms (user impact), not causes
- Include runbook links in annotations
- Set appropriate `for` duration to avoid flapping
- Use recording rules to pre-compute expensive queries
- Alert on rate of change, not absolute values (for error rates)

**Anti-Patterns:**
- Alerting on low disk space when there's auto-scaling
- Alerting on individual request failures (alert on rate)
- Alerts without clear action items
- Too many severity levels (3 is enough: critical, warning, info)

## Anti-Patterns

- **Logging everything** — log at boundaries, not inside every function
- **fmt.Printf in production** — use structured logging
- **High-cardinality labels** — don't use user IDs or request IDs as metric labels
- **Missing error logs** — unhandled errors in the top-level handler should always be logged
- **Logging sensitive data** — never log passwords, tokens, credit cards, or PII
- **No timeouts** — every external call should have a context timeout
# Correlation IDs

Correlation IDs (also called request IDs or trace IDs) are unique identifiers that track a request as it flows through multiple microservices. They're essential for debugging distributed systems.

## Contents

- [Why Correlation IDs Matter](#why-correlation-ids-matter)
- [Generating Correlation IDs](#generating-correlation-ids)
- [Propagating Through HTTP Headers](#propagating-through-http-headers)
- [Propagating to Downstream Services](#propagating-to-downstream-services)
- [Including in Logs](#including-in-logs)
- [Integration with Distributed Tracing](#integration-with-distributed-tracing)
- [Best Practices](#best-practices)
- [Common Pitfalls](#common-pitfalls)

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

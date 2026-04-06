---
name: observability
description: >
  Observability principles: logging, metrics, tracing. Use when adding
  instrumentation, structured logging, health checks, or alerting.
  Pair with language-specific observability skill.
---

# Observability

Log only actionable information. Where logging is expensive, instrumentation is cheap.

## When to Use

- Adding structured logging to a service
- Instrumenting HTTP/gRPC/DB with metrics
- Setting up distributed tracing
- Adding health check endpoints
- Designing alerting rules

## When NOT to Use

- Early prototyping where observability is premature
- Writing language-specific instrumentation code (use lang/observability)

## Core Process

1. **Start with logging** — structured logging at service boundaries is the foundation
2. **Add health checks** — liveness (/healthz) and readiness (/readyz) before anything else
3. **Instrument boundaries** — HTTP middleware, DB calls, external service calls
4. **Add metrics** — RED method for services, USE method for resources
5. **Add tracing** — spans at service boundaries and significant operations
6. **Configure alerting** — alert on symptoms (error rate, latency), not causes

## Three Pillars

| Pillar | Purpose | Granularity |
|--------|---------|-------------|
| **Logs** | Discrete events, debugging | Per-request |
| **Metrics** | Aggregated measurements, dashboards | Per-interval |
| **Traces** | Request flow across services | Per-request |

Logs answer "what happened?" Metrics answer "how much?" Traces answer "where did time go?"

## Structured Logging

### Log Levels

| Level | Use For | Production |
|-------|---------|------------|
| Error | Failures needing attention or alerting | Always on |
| Warn | Unusual situations, potential problems | Always on |
| Info | State changes, request completion, startup/shutdown | Always on |
| Debug | Detailed diagnostics | Off by default |

### Logging Rules

- Log at service boundaries, not inside every function
- Use structured fields, not string interpolation
- Never log sensitive data (passwords, tokens, PII)
- Each log line independently useful (include request ID, operation, relevant IDs)
- Either log OR return error — never both (duplicate logging)

## Metrics

### RED Method (for services)

- **R**ate — requests per second
- **E**rrors — failed requests per second
- **D**uration — latency distributions (histograms, not averages)

### USE Method (for resources)

- **U**tilization — how full (CPU, memory, connections)
- **S**aturation — queued work
- **E**rrors — error count

### Metric Types

| Type | Use For | Example |
|------|---------|---------|
| Counter | Totals that only increase | http_requests_total |
| Histogram | Distributions (latency, size) | http_request_duration_seconds |
| Gauge | Current value that goes up/down | active_connections |

### Rules

- No high-cardinality labels (no user IDs or request IDs as labels)
- Use histograms for latency, never averages
- Instrument at boundaries: HTTP middleware, DB calls, external services

## Distributed Tracing

- Create spans at service boundaries and significant operations
- Propagate trace context across service calls (HTTP headers, gRPC metadata)
- Record errors on spans
- Add relevant attributes (IDs, operation names, key parameters)

## Health Checks

- **Liveness** (`/healthz`): process alive? Always 200 if running. No dependency checks.
- **Readiness** (`/readyz`): ready for traffic? Check dependencies (DB, cache, downstream services).

## Alerting Philosophy

- Alert on symptoms (high error rate, high latency) — not causes
- Every alert must be actionable — if you can't do anything, don't alert
- Use severity levels: critical (wake someone up) vs warning (review next business day)
- Avoid alert fatigue — fewer, higher-quality alerts beat noisy dashboards

## Common Rationalizations

| Shortcut | Reality |
|----------|---------|
| "We'll add logging later" | Debugging without logs is guessing. Add structured logging from day one. |
| "Log everything to be safe" | Noise hides signal. Log at boundaries with structured fields. |
| "Metrics are overkill for this" | You can't improve what you can't measure. RED method is cheap to implement. |
| "Averages are good enough" | Averages hide outliers. Use histograms for latency — p50/p95/p99 matter. |

## Red Flags

- No structured logging (using printf/println)
- Logging inside every function (should be at boundaries)
- High-cardinality metric labels (user ID, request ID as label)
- No health check endpoints
- Sensitive data in logs (passwords, tokens, PII)
- Averages used for latency instead of histograms/percentiles

## Verification

- [ ] Structured logging at service boundaries with correlation IDs
- [ ] Health check endpoints present (/healthz and /readyz)
- [ ] Metrics follow RED method for services (rate, errors, duration)
- [ ] No high-cardinality metric labels
- [ ] No sensitive data in logs
- [ ] Alerting rules are symptom-based and actionable

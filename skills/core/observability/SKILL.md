---
name: observability
description: >
  Observability principles — structured logging, metrics (RED/USE),
  distributed tracing, health checks, alerting philosophy. Use when
  adding instrumentation to a service, debugging a production
  incident that exposes blind spots, designing alerting rules,
  setting up Prometheus / OpenTelemetry / slog, or writing
  `/healthz` and `/readyz` endpoints. Trigger on any task mentioning
  "logging", "metrics", "traces", "observability", "dashboards",
  "alerts", "pagerduty", "SLO", "golden signals", or "why is this
  service slow?". Pair with language-specific observability skill
  for instrumentation code.
---

# Observability

Log only actionable information. Where logging is expensive, instrumentation is cheap.

## When to Use

- Adding structured logging to a service
- Instrumenting HTTP/gRPC/DB with metrics
- Setting up distributed tracing
- Adding health check endpoints
- Designing alerting rules
- Debugging a production incident where the existing signals are missing

## When NOT to Use

- Early prototyping where observability is premature
- Writing language-specific instrumentation code (use lang/observability)

## Core Process

1. **Start with logging** — structured logging at service boundaries is the foundation
2. **Implement health checks** — `/healthz` (liveness) and `/readyz` (readiness) before anything else
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

- No high-cardinality labels — a label with 10k distinct values becomes 10k separate time series; scrape cost scales linearly, storage quadratically. Put high-cardinality data in logs or traces, not metric labels.
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

- **Alert on symptoms, not causes.** A symptom is something a user notices and you can act on. A cause is internal state that may or may not matter.
  - Good: `error_rate > 5% for 5 minutes` (users are seeing failures — act)
  - Bad: `instance restart detected` (may be a planned deploy — may not need action)
- **Every alert must be actionable.** If the oncall cannot do anything about it, do not alert on it.
- **Every alert has a runbook.** A link to concrete remediation steps. If there is no runbook, you have a dashboard item, not an alert.
- Use severity levels: critical (wake someone up) vs warning (review next business day)
- Avoid alert fatigue — fewer, higher-quality alerts beat noisy dashboards

For the full golden-signals decision framework, severity calibration, and alert-fatigue prevention, see [references/alerting.md](../../../references/alerting.md).

## Common Rationalizations

| Shortcut | Reality |
|----------|---------|
| "We'll add logging later" | Debugging without logs is guessing. Add structured logging from day one. |
| "Log everything to be safe" | Noise hides signal. Log at boundaries with structured fields. |
| "High-cardinality labels won't hurt" | Cardinality explodes — a label with 10k values becomes 10k time series. Scrape cost scales linearly, storage quadratically. Put high-cardinality data in logs or traces, not metric labels. |
| "We'll sample logs to save costs" | Head-based sampling loses the exact trace you need to debug an incident. Use request-level sampling with biased retention (always keep errors, sample success). |
| "Metrics are overkill for this" | You cannot improve what you cannot measure. RED method is cheap to implement. |
| "Averages are good enough" | Averages hide outliers. Use histograms for latency — p50/p95/p99 matter. |

## Red Flags

- No structured logging (using printf/println)
- Logging inside every function (should be at boundaries)
- High-cardinality metric labels (user ID, request ID as label)
- No health check endpoints
- Sensitive data in logs (passwords, tokens, PII)
- Averages used for latency instead of histograms/percentiles
- Alerts on causes ("restart detected") instead of symptoms ("error rate high")
- Alerts with no runbook (the oncall cannot act → should not alert)

## Verification

- [ ] Structured logging at service boundaries with correlation IDs
- [ ] Health check endpoints present (`/healthz` and `/readyz`)
- [ ] Metrics follow RED method for services (rate, errors, duration)
- [ ] No high-cardinality metric labels
- [ ] No sensitive data in logs
- [ ] Alerting rules are symptom-based and actionable
- [ ] Every alert has a runbook link pointing to concrete remediation steps

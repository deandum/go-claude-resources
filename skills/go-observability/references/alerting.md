# Alerting Best Practices

Alert on symptoms, not causes. Make alerts actionable.

## Contents

- [What to Alert On: Golden Signals](#what-to-alert-on-golden-signals)
- [Decision Framework: Should This Be an Alert?](#decision-framework-should-this-be-an-alert)
- [Prometheus Alerting Rules](#prometheus-alerting-rules)
- [Alert Severity Levels](#alert-severity-levels)
- [Alert Fatigue Prevention](#alert-fatigue-prevention)

## What to Alert On: Golden Signals

Focus on user-facing symptoms:

**1. Latency** - Request duration exceeding SLO
**2. Traffic** - Unusual traffic patterns (spike or drop)
**3. Errors** - Error rate exceeding threshold
**4. Saturation** - Resource utilization approaching limits

## Decision Framework: Should This Be an Alert?

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

## Prometheus Alerting Rules

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

## Alert Severity Levels

| Severity | Response Time | Impact | Examples |
|---|---|---|---|
| **Critical** | Immediate (page on-call) | User-facing outage | Service down, high error rate (>5%) |
| **Warning** | Business hours | Degraded performance | High latency, elevated error rate (2-5%) |
| **Info** | No immediate action | Informational | Deployment completed, scaling event |

## Alert Fatigue Prevention

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

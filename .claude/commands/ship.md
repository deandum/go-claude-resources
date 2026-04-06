---
description: Containerize and add observability for production
---

Use the shipper agent. Audit what observability and containerization exists.

Follow this order:
1. Structured logging at service boundaries
2. Health checks (/healthz liveness, /readyz readiness)
3. Metrics at boundaries (RED method: rate, errors, duration)
4. Multi-stage Dockerfile (distroless, non-root, pinned versions)
5. Verify: build image, check size, test health endpoint

Every service needs logging, health checks, and metrics before it ships.

---
description: Containerize and add observability for production
---

## Task

Spawn the `shipper` agent with this task: $ARGUMENTS

The shipper has `core/docker` and `core/observability` skills loaded, plus language-specific deployment skills from session-start context (e.g., `go/docker`, `go/observability`).

Audit what exists first. Then add in order:
1. Structured logging → 2. Health checks → 3. Metrics → 4. Dockerfile
Verify: build image, check size, test health endpoint.

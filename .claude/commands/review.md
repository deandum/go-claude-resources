---
description: Review code for correctness, security, and quality
---

Use the reviewer agent. Get the diff first (git diff or git diff --staged).
Read surrounding context — don't review lines in isolation.

Walk the five axes in order:
1. Correctness (errors, concurrency, resources, nil safety)
2. Readability (naming, structure, comments)
3. Architecture (boundaries, coupling, patterns)
4. Security (input validation, injection, secrets)
5. Performance (N+1, unbounded ops, timeouts)

Label every finding with severity: Critical, Important, Suggestion, Nit, or FYI.
Acknowledge strengths briefly. Never approve with Critical issues.

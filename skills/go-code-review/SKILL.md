---
name: go-code-review
description: >
  Systematic Go code review checklist covering style, correctness,
  performance, and security. Use when reviewing PRs, auditing code,
  or performing pre-commit checks on Go code.
---

# Go Code Review

A systematic checklist for reviewing Go code, synthesized from Go Code Review Comments, Google's and Uber's style guides, and production experience.

## Review Process

Work through these categories in order. Stop and report findings per category rather than dumping everything at once.

1. **Correctness** — error handling, concurrency, resource management, nil safety
2. **Style and Naming** — formatting, naming, interfaces, code organization
3. **Design** — package design, API surface, dependencies
4. **Testing** — coverage, table-driven tests, race safety
5. **Performance** — allocations, goroutine pools, timeouts, N+1 queries
6. **Security** — secrets, SQL injection, input validation, TLS

Full checklist with detailed items per category: [checklist.md](references/checklist.md)

## Review Output Format

When reporting review findings, structure them as:

```
## Review Summary

**Overall**: [APPROVE / REQUEST CHANGES / COMMENT]

### Critical (must fix)
- file.go:42 — goroutine leak: no shutdown path for background worker
- handler.go:15 — SQL injection: user input concatenated into query

### Important (should fix)
- service.go:28 — error not wrapped: `return err` should be `return fmt.Errorf("creating user: %w", err)`
- repo.go:55 — interface too large: UserRepository has 8 methods, consider splitting

### Suggestions (nice to have)
- config.go:10 — consider using functional options instead of 6 constructor parameters
- handler.go:70 — this function is 65 lines, consider extracting validation logic
```

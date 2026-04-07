---
name: error-handling
description: >
  Error handling strategy and decision framework. Use when designing
  error types, propagation patterns, or reviewing error handling.
  Pair with language-specific error-handling skill.
---

# Error Handling

Errors are values. Handle them gracefully, not just check them.

## When to Use

- Designing error strategy for a new package or service
- Deciding between sentinel errors, custom types, or wrapping
- Mapping domain errors to transport responses (HTTP, gRPC, CLI)
- Reviewing error handling in existing code

## When NOT to Use

- Writing language-specific error code (use `<lang>/error-handling` skill)
- Simple scripts with no error propagation needs

## Core Process

1. **Identify error sources** — What operations can fail? List them.
2. **Classify each error** — Use the decision framework below to choose error type.
3. **Design propagation** — How does each error flow up the call stack? Add context at each level.
4. **Map at boundaries** — Domain errors → transport responses at the outermost layer only.
5. **Document contracts** — Each package declares what errors it returns and when.
6. **Verify** — Walk the error path from origin to user-facing response. Is context preserved? Is the response correct?

## Decision Framework

Ask in order:

1. **Caller needs to programmatically distinguish this error?**
   - Yes → sentinel error or custom error type
   - No → wrapped error with context string

2. **Error is a static condition with no runtime data?**
   - Yes → sentinel error constant/variable
   - No → custom error type with fields, or wrapped error

3. **Error carries structured data the caller needs?**
   - Yes → custom error type
   - No → wrapped error with context string

## Error Categories

| Category | When | Example |
|----------|------|---------|
| Sentinel errors | Well-known conditions, multiple callers branch on it | NotFound, AlreadyExists, Forbidden |
| Custom error types | Caller needs structured data (field, code, resource) | ValidationError, NotFoundError |
| Wrapped errors | Default — add context as you propagate up | "finding user %s: %w" |
| Multi-error | Operation fails in multiple independent ways | Config validation, batch processing |

## Propagation Rules

- **Wrap with context** — describe the operation that failed, not the function name
- **Include identifiers** — "finding user %s" not "finding user"
- **Lowercase, no punctuation** — error messages are fragments, not sentences
- **Preserve the chain** — callers must be able to inspect the original error
- **One handler per error** — either log OR return with context, never both

## Boundary Mapping

Map domain errors to transport responses at the boundary only. Domain code stays transport-agnostic.

| Domain Error | HTTP | gRPC | CLI Exit |
|-------------|------|------|----------|
| NotFound | 404 | NOT_FOUND | 3 |
| Validation | 400/422 | INVALID_ARGUMENT | 2 |
| Conflict | 409 | ALREADY_EXISTS | 1 |
| Forbidden | 403 | PERMISSION_DENIED | 4 |
| Internal | 500 (log, return generic) | INTERNAL | 1 |

## Common Rationalizations

| Shortcut | Reality |
|----------|---------|
| "Just return the error" | Bare returns lose context. Callers can't diagnose without wrapping. |
| "Log it and return it" | Causes duplicate logging. Pick one: log OR return with context. |
| "Panic is simpler" | Panic crashes the process. Reserve for true programmer bugs only. |
| "String matching is fine" | Strings are fragile. Use typed/value error checking — strings break on rewording. |

## Red Flags

- Errors returned without any context added
- Same error logged at multiple levels (duplicate logging)
- String matching on error messages instead of type/value checks
- Panic used for expected failure conditions (not found, validation)
- Domain errors leaking transport details (HTTP status codes in service layer)
- No error documentation for package's public API

## Verification

- [ ] Every error return is checked — no ignored errors
- [ ] Errors are wrapped with operation context at each level
- [ ] No log-and-return patterns (either log or return, not both)
- [ ] Domain errors mapped to transport responses at the boundary only
- [ ] Package error contracts documented (which errors, when, how to handle)

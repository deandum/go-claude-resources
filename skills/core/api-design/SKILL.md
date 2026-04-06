---
name: api-design
description: >
  HTTP/gRPC API design principles. Use when building APIs, designing
  handlers, planning middleware, or reviewing API surfaces. Pair with
  language-specific api-design skill.
---

# API Design

Design clear, consistent APIs. Separate transport from domain logic.

## When to Use

- Building new HTTP or gRPC endpoints
- Designing handler structure and middleware chains
- Planning request/response DTOs and validation
- Reviewing API surface for consistency
- Adding versioning, pagination, or error responses

## When NOT to Use

- Internal-only code with no API surface
- CLI tools (use cli-builder agent)
- Implementation details (use lang/api-design)

## Core Process

1. **Define the resource** — what entity does this endpoint manage?
2. **Design routes** — RESTful paths, HTTP methods, consistent naming
3. **Define DTOs** — request and response types separate from domain
4. **Plan validation** — reject bad input at the boundary, not deep in the stack
5. **Map errors** — domain errors → HTTP status codes at the handler layer
6. **Add middleware** — cross-cutting concerns (auth, logging, metrics, CORS)
7. **Document** — OpenAPI/Swagger spec or equivalent

## Handler Pattern

Every handler follows: **parse → validate → execute → respond**.

1. **Parse** — decode body, extract URL params, parse query strings
2. **Validate** — check required fields, format, ranges. Reject with 400 early.
3. **Execute** — call service layer. Handler has no business logic.
4. **Respond** — map result to HTTP response. Success or error.

## Request/Response Separation

- **Request DTOs**: parse + validate input, convert to domain types
- **Response DTOs**: map domain types to API representation
- Never expose domain entities directly in API responses
- Never let transport types leak into the service layer

## Error Responses

Consistent error body format. Map domain errors at the boundary.

| Domain Error | HTTP Status | When |
|-------------|-------------|------|
| NotFound | 404 | Resource doesn't exist |
| Validation | 400/422 | Bad input |
| Conflict | 409 | Duplicate, version mismatch |
| Forbidden | 403 | Not allowed |
| Unauthorized | 401 | Not authenticated |
| Internal | 500 | Log error, return generic message |

## Middleware Stack

Order matters. Typical stack (outermost first):
1. Request ID (generate/propagate)
2. Logging (method, path, status, duration)
3. Recovery (panic → 500)
4. Auth (verify credentials, set user context)
5. Rate limiting
6. CORS

## Versioning

- URL path versioning: `/api/v1/users` (simplest, most explicit)
- Keep old version handlers when introducing new versions
- Separate handler structs per major version if APIs diverge

## Server Configuration

Never use defaults in production:
- Set read/write/idle timeouts
- Configure connection pool limits for HTTP clients
- Use graceful shutdown with signal handling

## Health Checks

- `/healthz` — is the process alive? Always 200 if running.
- `/readyz` — ready for traffic? Check dependencies (DB, cache).

## Common Rationalizations

| Shortcut | Reality |
|----------|---------|
| "We'll version later" | Versioning retrofits break clients. Design v1 from the start. |
| "Just expose the domain model" | Leaks internals. Transport DTOs decouple API from implementation. |
| "Validation can happen in the service" | Reject bad input at the boundary. Don't propagate garbage inward. |

## Red Flags

- Domain entities returned directly as API responses
- Business logic in handlers (handlers should only parse/validate/delegate/respond)
- Inconsistent error response format across endpoints
- Missing timeouts on server or HTTP clients
- No health check endpoints
- Validation happening deep in the service layer instead of at the boundary

## Verification

- [ ] Every handler follows parse → validate → execute → respond
- [ ] Request/response DTOs separate from domain types
- [ ] Error responses consistent across all endpoints
- [ ] Server timeouts configured (not defaults)
- [ ] Health check endpoints present (/healthz, /readyz)
- [ ] Middleware applied in correct order

---
name: project-structure
description: >
  Project structure principles. Use when starting a new project, major
  restructuring, or auditing package dependencies. Pair with
  language-specific project-init skill.
---

# Project Structure

Organize code by domain entity, not by technical layer.

## When to Use

- Starting a new project (service, CLI, library)
- Major restructuring or splitting a monolith
- Auditing package dependencies for cycles or coupling
- Reviewing project layout for new team members

## When NOT to Use

- Adding features to a well-established project (follow existing structure)
- Minor refactoring within a single package

## Core Process

1. **Clarify project type** — service, CLI, or library (different structures)
2. **Identify entities** — what are the core domain concepts?
3. **Design packages** — one package per entity, cross-cutting concerns separate
4. **Define dependency direction** — adapters → use cases → domain (inward)
5. **Set up tooling** — linter, formatter, Makefile, Dockerfile, CI
6. **Validate** — build, test, lint all pass on empty project

## Entity-Focused Architecture

Group code by business entity (user, order, product), not by type (controllers, models, services).

Each entity package encapsulates:
- **Domain logic**: entity types, value objects, validation rules
- **Ports**: repository and service interfaces
- **Use cases**: business logic and orchestration
- **Adapters**: HTTP handlers, DB implementations

### Benefits

- High cohesion: related code lives together
- Low coupling: packages depend on each other via interfaces
- Easy navigation: working on "user" features = one package
- Natural scaling: adding entities doesn't bloat existing packages

## Cross-Cutting Concerns

Shared infrastructure in dedicated packages:
- HTTP: middleware, routing, error responses
- Database: connection pool, transaction helpers
- Config: environment loading, validation
- Shared utilities (use sparingly — avoid "util" packages)

## Dependency Rules

- Entity packages import other entities via **interfaces only**
- Entity packages may import cross-cutting packages
- Cross-cutting packages must NOT import entity packages (avoids cycles)
- Dependencies flow inward: adapters → use cases → domain

## Project Types

| Type | Key Structure |
|------|--------------|
| Service (HTTP/gRPC) | `cmd/` + `internal/` (entity packages + cross-cutting) + `migrations/` |
| CLI Tool | `cmd/` + `internal/` (commands + config) |
| Library | root package API + `internal/` + `examples/` |

## Dependency Audit

Check periodically:
1. Are there import cycles? (tooling should catch these)
2. Do entity packages import concrete implementations? (should use interfaces)
3. Is the "shared/util" package growing? (likely code smells — relocate to domain packages)
4. Can a new developer find where "user" code lives? (if not, restructure)

## Common Rationalizations

| Shortcut | Reality |
|----------|---------|
| "Flat structure is simpler" | Flat becomes chaos at scale. Entity-focused packages scale naturally. |
| "We need a utils package" | Utils is a code smell. Put code where it belongs by domain. |
| "Layered architecture is standard" | Layers scatter related code. Entity-focused keeps related code together. |
| "We'll restructure later" | Structure is expensive to change. Get it right early. |

## Red Flags

- "util", "common", "helpers", "misc" packages (code smell)
- Entity packages importing concrete implementations (should use interfaces)
- Cross-cutting packages importing entity packages (creates cycles)
- All code in one package or in deeply nested packages (>3 levels)
- No clear entry point (main.go buried deep)

## Verification

- [ ] Entity-focused package layout (not layered)
- [ ] No dependency cycles
- [ ] Cross-cutting packages don't import entity packages
- [ ] No "util/common/helpers" packages
- [ ] Build, test, lint all pass
- [ ] New developer can find feature code by entity name

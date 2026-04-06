---
name: testing
description: >
  Testing strategy and methodology. Use when planning test strategy,
  choosing unit vs integration, defining mock boundaries, or fixing
  bugs. Pair with language-specific testing skill.
---

# Testing Strategy

Tests are code. Apply same quality standards as production code.

## When to Use

- Planning test strategy for a new feature or service
- Deciding unit vs integration for a specific scenario
- Choosing mock boundaries and test double types
- Fixing a bug (write failing test first — the prove-it pattern)
- Reviewing test quality and coverage

## When NOT to Use

- Writing language-specific test code (use lang/testing)
- Trivial getters/setters that don't warrant testing

## Core Process

### The RED-GREEN-REFACTOR Cycle

1. **RED** — Write a test that fails. The test defines the expected behavior.
2. **GREEN** — Write the minimum code to make the test pass. No more.
3. **REFACTOR** — Clean up. Tests still pass. No new behavior.
4. **Repeat** — Next behavior. Next test. Next cycle.

### The Prove-It Pattern (for bugs)

1. Reproduce the bug with a failing test
2. Test FAILS — confirms the bug exists
3. Implement the fix
4. Test PASSES — proves the fix works
5. Run full suite — no regressions

Every bug fix MUST come with a regression test. No exceptions.

## Test Pyramid

1. **Unit Tests** (70-80%) — fast, isolated, mock boundaries, test business logic
2. **Integration Tests** (15-25%) — real adapters (DB, queues), verify infrastructure
3. **End-to-End Tests** (5-10%) — full workflows, critical journeys only, keep minimal

## Decision: Unit vs Integration?

| Scenario | Test Type | Approach |
|----------|-----------|----------|
| Business logic | Unit | Mock dependencies |
| Database queries | Integration | Real database |
| HTTP handlers | Unit | Mock service layer |
| Repository CRUD | Integration | Real database |
| External API calls | Unit | Mock HTTP client |
| Full API workflow | E2E | Real services |

## Mocking Boundaries

**Mock these** (cross system boundaries):
- Database repositories, HTTP clients, message queues, email/SMS services, cache clients

**Don't mock these** (internal to app):
- Domain entities, value objects, pure functions, internal packages

### Mock Decision Framework

1. **Crosses a system boundary?** Yes → mock. No → use real implementation.
2. **Different tests need different behavior?** Yes → function-based mock. No → struct-based stub.
3. **Need to verify how it was called?** Yes → mock with capture. No → stub returning data.

### Test Double Hierarchy (prefer the simplest that works)

Real implementation → Fake → Stub → Mock

Use real implementations when fast enough. Fakes for complex dependencies (in-memory DB). Stubs for simple returns. Mocks only when verifying interactions.

## Test Principles

- **DAMP over DRY** — Descriptive And Meaningful Phrases. Test clarity beats deduplication. Repeating setup in each test is fine if it makes the test self-contained.
- **Test behavior, not implementation** — test the public API. Private functions are implementation details.
- **Each test is independent** — no shared mutable state between tests.
- **Arrange-Act-Assert** — setup, execute, verify. Clear structure in every test.

## Anti-Patterns

- Testing private/internal functions — test public API only
- Complex test setup — indicates tight coupling; simplify design first
- Mocking everything — only at boundaries; over-mocking makes tests brittle
- Mixing unit and integration tests — separate them clearly
- Using sleep for synchronization — use proper sync primitives
- Asserting on log output — test behavior, not logging side effects
- Shared mutable state — each test must be independent

## Test Organization

- Unit tests: co-located with production code
- Integration tests: separate directory (e.g., `test-integration/`)
- Each test file mirrors the file it tests

## Common Rationalizations

| Shortcut | Reality |
|----------|---------|
| "I'll add tests later" | Tests after code are documentation, not design. Later means never. |
| "This is too simple to test" | Simple today becomes complex tomorrow. Test the behavior now. |
| "Mocking everything is thorough" | Over-mocking makes tests brittle and coupled to implementation. |
| "The tests pass, so the code is correct" | Tests are necessary but not sufficient. They don't catch design or security issues. |

## Red Flags

- No tests for new behavior
- Bug fixes without regression tests
- Tests that pass when the feature is broken (testing the mock, not the code)
- Test suite takes minutes for unit tests (boundary leak — real deps in unit tests)
- Shared setup mutated across tests (order-dependent failures)
- 100% coverage with no meaningful assertions

## Verification

- [ ] Test pyramid ratios respected (70-80% unit, 15-25% integration, 5-10% e2e)
- [ ] Mocks only at system boundaries — no over-mocking
- [ ] Each test is independent (no shared mutable state)
- [ ] Bug fixes include regression tests
- [ ] Test names describe the behavior being tested
- [ ] All tests pass, including with race detection

---
name: concurrency
description: >
  Concurrency patterns and pitfalls. Use when implementing parallel
  work, choosing sync primitives, auditing concurrent code, or
  reviewing for races and leaks. Pair with language-specific skill.
---

# Concurrency

Don't communicate by sharing memory; share memory by communicating.
Concurrency is not parallelism.

## When to Use

- Implementing worker pools, fan-out, pipelines, or rate limiting
- Choosing between message passing and shared state
- Auditing existing code for races, leaks, or deadlocks
- Reviewing concurrent code for correctness

## When NOT to Use

- Single-threaded sequential code
- Simple request handlers with no background work
- Writing language-specific concurrent code (use `<lang>/concurrency` skill)

## Core Process

1. **Do you actually need concurrency?** Sequential is simpler. Only add concurrency when there's a measurable benefit (I/O wait, CPU parallelism, latency requirement).
2. **Choose the primitive** — message passing for data transfer, locks for data protection.
3. **Bound the concurrency** — never spawn unlimited workers. Set limits.
4. **Design the shutdown path** — every concurrent task must be cancellable and joinable.
5. **Protect shared state** — if two tasks touch the same data, synchronize access.
6. **Test with race detection** — race conditions are non-deterministic; tooling catches what reviews miss.

## Decision: Message Passing vs Shared State

| Message Passing (channels/queues) | Shared State (locks/atomics) |
|---|---|
| Transferring ownership of data | Protecting internal state |
| Coordinating workers | Simple counter or flag |
| Distributing work | Short critical sections |
| Signaling events | Cache access |

**Rule**: transferring data → message passing. Protecting data → shared state.

## Pattern Catalog

| Pattern | Use When | Key Rule |
|---------|----------|----------|
| Worker Pool | Fixed concurrency over a stream | Bound the worker count |
| Fan-Out/Fan-In | Independent tasks, collect results | Each task writes to unique slot |
| Pipeline | Sequential stages connected by queues | Close channels to signal completion |
| Rate Limiter | Throttle operations (API, DB) | Token bucket or leaky bucket |
| Once Init | Lazy init exactly once | Safe for concurrent callers |
| Deduplication | Suppress duplicate concurrent calls | Cache stampede prevention |
| Object Pool | Reuse temp objects under pressure | Reset before return; profile first |

## Concurrency Audit Checklist

When reviewing concurrent code, check:

1. **Shutdown path** — Can every goroutine/thread/task be stopped? Is there a join point?
2. **Bounded concurrency** — Is the number of concurrent tasks limited?
3. **Shared state** — Is every shared variable protected (lock, atomic, channel)?
4. **Channel ownership** — Only the sender closes. Receiver never closes.
5. **Context cancellation** — Do loops check for cancellation?
6. **Error propagation** — Do errors from concurrent tasks reach the caller?
7. **Resource lifecycle** — Are connections/files closed even on cancellation?

## Anti-Patterns

- **Resource leak** — task with no shutdown path (runs forever)
- **Race condition** — unsynchronized access to shared state
- **Message passing misuse** — using channels when a simple lock is clearer
- **Unbounded concurrency** — spawning unlimited tasks (memory exhaustion)
- **Deadlock** — circular wait on locks or full channels
- **Fire and forget** — launching tasks without waiting or error handling

## Common Rationalizations

| Shortcut | Reality |
|----------|---------|
| "It probably won't race" | Races are non-deterministic. "Probably" means "sometimes in production." |
| "One goroutine won't hurt" | Every unbounded task is a potential leak. Always provide a shutdown path. |
| "A channel is always better" | Channels transfer ownership. Locks protect state. Pick the right tool. |
| "We'll add cancellation later" | Cancellation is architectural. Retrofitting is 10x harder than designing it in. |

## Red Flags

- Concurrent task with no shutdown/cancellation mechanism
- Shared mutable state without synchronization
- Unbounded task spawning (could spawn millions)
- Channel used as a lock (misuse of the primitive)
- No race detection in test suite
- Error silently dropped from concurrent task

## Verification

- [ ] Every concurrent task has a shutdown path (cancellable and joinable)
- [ ] Concurrency is bounded (explicit limits on worker count)
- [ ] Shared state protected (lock, atomic, or channel ownership)
- [ ] Race detection enabled in test suite
- [ ] Errors from concurrent tasks propagated to caller
- [ ] No fire-and-forget patterns

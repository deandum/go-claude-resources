---
name: performance
description: >
  Performance discipline: profile before optimize, benchmark, N+1
  detection, hot-path analysis. Use when responding to a measured
  performance issue OR designing a high-throughput path. Pair with
  core/code-review §5 (review-time checklist).
---

# Performance

Performance optimization without measurement is ritual. This skill is the design-time and response-time discipline for choosing *what* to optimize and *how much*. For the review-time checklist, see `core/code-review` §5 Performance.

## When to Use

- Responding to a measured, reproducible performance issue
- Designing a high-throughput path (request handling, batch jobs, pipelines)
- Budgeting latency for a new feature
- Investigating a regression
- Deciding whether an optimization is worth the complexity cost

## When NOT to Use

- "It might be slow" — measure first
- As a substitute for clarity — slower readable code usually wins
- When the throughput requirement is not defined — optimize to a target, not to infinity
- On code paths that run once, at startup, or off the critical path

## Core Process

### 1. Define the target, not the absolute

"Fast" is not a target. "p99 < 100ms at 1000 req/s" is. Before optimizing anything, know:

- What is the workload — throughput, concurrency, size distribution?
- What is the success criterion — p50, p95, p99, max latency; throughput floor?
- What is the budget — how much latency does each component own?

If you cannot state the target in numbers, you are not optimizing — you are guessing.

### 2. Measure before changing anything

Rules of measurement:

- Measure in conditions that resemble production — same data shape, same concurrency, same CPU shape
- Establish a baseline before the first change
- Use statistics, not single runs. Report percentiles, not averages. Averages hide tail latency.
- Micro-benchmark what you are optimizing; integration-benchmark what you are deploying

Without a baseline, "it's faster now" is a story, not evidence.

### 3. Profile, don't guess

Profilers find the real bottleneck. Intuition finds the bottleneck you remember from a different project. Always profile first.

Look for:

- Hot functions — where wall-clock time lives
- Allocation hot spots — where GC pressure lives
- Blocking — I/O, locks, channels
- Unexpected call counts — the N+1 query, the called-in-a-loop helper

If the profile does not match your mental model, the mental model is wrong.

### 4. Optimize the algorithm, then the implementation

Order of attack:

1. **Algorithmic** — O(n²) → O(n log n) dwarfs every other win. Reduce work.
2. **Architectural** — caching, batching, amortizing, eliminating redundant calls.
3. **Data layout** — reduce allocations, reuse buffers, flatten structures the hot path touches.
4. **Micro-tuning** — inlining, unrolling, branch prediction. Last resort. Easy to get wrong.

Most performance wins live at levels 1 and 2. Micro-tuning is where complexity metastasizes without payoff.

### 5. Prove the win

After any optimization, re-run the benchmark:

- Did the target metric move? By how much?
- Did any other metric regress? (latency fixes that cost throughput are easy to miss)
- Is the improvement statistically meaningful, or inside the noise?

A change that does not move the target number is a complexity add, not an optimization. Revert it.

### 6. The N+1 is the most common bug

Loops that issue one query (or one RPC, or one external call) per iteration are the most common performance bug. Always ask: is this operation inside a loop? Is each iteration independent? Can it be batched?

## Common Rationalizations

| Shortcut | Reality |
|----------|---------|
| "I know this is slow — profiling is overhead." | You don't. The profiler will surprise you. Run it. |
| "Premature optimization is the root of all evil — so I'll skip it." | Knuth's full quote: *"except for the 3% that matters."* Measure to find the 3%. |
| "The change is tiny, no need to benchmark." | Tiny changes can trigger huge regressions (cache misses, branch prediction, inlining). Benchmark. |
| "The optimization is obviously faster." | Obvious is not measured. "Obviously" is the word that precedes most regressions. |
| "I'll optimize everything to be safe." | Optimizing cold code is a complexity tax with zero return. Target the hot path. |

## Red Flags

- Optimizations committed with no benchmark
- Benchmarks that only report averages
- Benchmarks run on synthetic data that does not match production shape
- Optimizations to code outside the profile's hot path
- Nested loops with database/API calls in the inner body
- Caches with no invalidation strategy
- Code marked `// optimized` or `// fast path` without a baseline number nearby
- Performance bugs closed without a regression test

## Verification

- [ ] Target metric defined in numbers before any change
- [ ] Baseline measured under realistic conditions
- [ ] Profiler confirmed the bottleneck before optimization
- [ ] Optimization addressed algorithm/architecture before micro-tuning
- [ ] Post-change benchmark shows the target moved, within statistical confidence
- [ ] No other metric regressed silently
- [ ] Regression test locks in the improvement (catches future backslide)

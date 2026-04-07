---
name: skill-discovery
description: >
  Decision tree for routing tasks to the right agent and skills.
  Loaded on session start. Use when unsure which agent applies.
user-invocable: false
---

# Skill Discovery

Route tasks to the right agent. Follow the first matching branch.

## Decision Tree

```
Task arrives
│
├─ Vague idea / unclear requirements?
│  └─ critic → clarify before anything else
│
├─ Complex task spanning multiple concerns?
│  └─ lead → decomposes into spec, delegates to team
│
├─ New project / scaffold from scratch?
│  └─ architect → core/project-structure + lang/project-init
│
├─ Design change / restructure / define interfaces?
│  └─ architect → core/api-design + lang/interface-design
│
├─ Implement feature / write application code?
│  ├─ CLI command? → cli-builder → lang/cli
│  └─ Other code  → builder → core/error-handling + lang/*
│
├─ Write or fix tests?
│  └─ tester → core/testing + lang/testing
│
├─ Review code / PR review?
│  └─ reviewer → core/code-review + lang/code-review
│
├─ Containerize / add logging / metrics / tracing?
│  └─ shipper → core/docker + core/observability + lang/*
│
└─ Unsure?
   └─ critic → will clarify and route
```

## Agent Quick Reference

| Agent | When | Never |
|-------|------|-------|
| critic | First pass on any non-trivial task | Don't skip for "obvious" tasks |
| lead | Multi-step tasks, spec generation | Don't use for single-concern tasks |
| architect | Structure, interfaces, API design | Don't use for implementation |
| builder | Application code (handlers, services) | Don't use for tests or infra |
| cli-builder | CLI commands, flags, config | Don't use for non-CLI code |
| tester | Unit/integration tests, mocks | Don't modify app code |
| reviewer | Code review (read-only) | Don't use to fix code |
| shipper | Docker, logging, metrics, health | Don't modify business logic |

## Core Operating Behaviors (all agents)

1. **Surface assumptions** — state what you're assuming before implementing
2. **Manage confusion** — STOP and clarify inconsistencies; don't guess
3. **Push back** — honestly disagree on problematic approaches
4. **Enforce simplicity** — resist overcomplication
5. **Maintain scope** — touch only what's asked; no unsolicited renovation
6. **Verify, don't assume** — "seems right" is never sufficient; evidence required

## Verification

- [ ] Task routed to the correct agent based on the decision tree
- [ ] Language detected and appropriate language skills loaded
- [ ] Critic consulted first for non-trivial tasks

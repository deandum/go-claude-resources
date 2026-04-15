---
name: skill-discovery
description: >
  Decision tree for routing tasks to the right agent and skills.
  Loaded on session start. Use when unsure which agent applies.
user-invocable: false
---

<!-- meta-skill: skip-anatomy -->

# Skill Discovery

Route tasks to the right agent. Follow the first matching branch.

**Cross-cutting:** All agents load `core/token-efficiency` — compresses human-facing output, never specs or agent-to-agent artifacts. Use `/compact` to adjust level.

## How to Use This Tree

1. **Language detection is automatic.** The session-start hook emits `detected_languages` in the session context. Agents read it directly; the tree does not need to branch on language.
2. **Follow the first matching branch.** Branches are ordered roughly by specificity. When a task matches multiple branches, choose the **most specific** one (e.g., "write tests for a new feature" → `tester`, not `builder`; "design a new HTTP API" → `architect`, not `builder`; "debug the failing test" → `debugging` + `tester`, not just `tester`).
3. **External writes are gated.** Any task that pushes, creates PRs, publishes releases, or pushes container images requires `ops_enabled=true` in session context — the opt-in `ops-skills` plugin. If disabled, report the action as a follow-up; do not execute. See the "Push, PR, release" branch at the bottom of the tree.

## Decision Tree

When a task arrives, follow the first matching branch:

- **Vague idea or unclear requirements?**
  - Has a specific problem? → **critic** → clarify before anything else
  - Exploring or brainstorming? → **idea-refine** → then `/define`
- **Grounding a task in existing code before spec?**
  - **scout** → `core/discovery` → runs in parallel with critic during `/define`
- **Complex task spanning multiple concerns?**
  - **lead** → decomposes into spec, delegates to team
- **New project or scaffold from scratch?**
  - **architect** → `core/project-structure` + `lang/project-init`
- **Design change, restructure, or define interfaces?**
  - **architect** → `core/api-design` + `lang/interface-design`
- **Implement feature or write application code?**
  - CLI command? → **cli-builder** → `lang/cli`
  - Other code → **builder** → `core/error-handling` + `lang/*`
- **Write or fix tests?**
  - **tester** → `core/testing` + `lang/testing`
- **Review code or PR review?**
  - **reviewer** → `core/code-review` + `lang/code-review`
- **Containerize, add logging, metrics, or tracing?**
  - **shipper** → `core/docker` + `core/observability` + `lang/*`
- **Refactor, remove code, or simplify?**
  - **reviewer** (or **builder** if applying) → `core/simplification`
- **Debug a bug, failing test, or incident?**
  - **builder** → `core/debugging` + `core/testing`
- **Security design, threat model, authz/authn?**
  - **architect** → `core/security` (design-time); review-time covered by `core/code-review` §4
- **Performance issue, profiling, benchmark?**
  - **builder** or **reviewer** → `core/performance`
- **Write ADR, README, design doc?**
  - **architect** → `core/documentation`
- **Commit (local only)?**
  - **builder** or **shipper** → `core/git-workflow`
- **Push, PR, release, or registry push (external writes)?**
  - Requires `ops-skills` opt-in. Check `ops_enabled` in session context.
  - When `ops_enabled=true`: **shipper** → `ops/git-remote`, `ops/pull-requests`, `ops/release`, `ops/registry`
  - When `ops_enabled=false` (default): report as follow-up; do not execute
- **Unsure?**
  - **critic** → will clarify and route

## Agent Quick Reference

| Agent | When | Never |
|-------|------|-------|
| critic | First pass on any non-trivial task | Don't skip for "obvious" tasks |
| scout | Discovery of existing code during `/define` | Don't use for design or code writing |
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

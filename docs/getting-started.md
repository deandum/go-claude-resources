# Getting Started

Install the framework and walk through your first workflow.

## Prerequisites

- **Claude Code** CLI or IDE extension
- **Git** for plugin installation and project detection
- **Bash 4+** — hooks are pure bash, no python or other runtime required

## Recommended tools

None of these are required, but each unlocks behavior that the hooks and agents probe for via `session-start.sh`. When a tool is missing, agents fall back to a portable equivalent (e.g., `sed`/`grep`) and note the fallback in their output rather than failing. The `available_tools` and `missing_tools` fields in the session JSON show what was detected on your PATH.

**Search and navigation**

- **`ast-grep`** — structural (AST-level) code search. More precise than regex for refactors, interface discovery, and call-site analysis.
- **`rg`** (ripgrep) — fast recursive grep. Agents prefer it over `grep` when present.
- **`fd`** — fast `find` replacement. Used by scout for file discovery.

**Data parsing**

- **`jq`** — JSON parsing. Required for MCP server discovery in `session-start.sh` (without it, `mcp_servers` is empty).
- **`yq`** — YAML parsing. Useful for reading spec frontmatter and CI config.

**Concurrency**

- **`flock`** (util-linux) — advisory file locking used by `session-end.sh` around learning persistence. Without it the hook falls back to a `mkdir`-based spinlock with a 5 s timeout.

**DevOps and deployment**

- **`gh`** — GitHub CLI. Used by `shipper` for PRs, releases, issue linking when `ops_enabled=true`.
- **`docker`** — containerization. Used by `shipper` for image builds.
- **`kubectl`** — Kubernetes CLI. Used by `shipper` when the project targets Kubernetes.

## Installation

### As Claude Code plugin (recommended)

```bash
claude plugin add https://github.com/deandum/claude-resources
```

Registers the plugin, hooks, agents, and slash commands automatically.

### Git clone

```bash
git clone https://github.com/deandum/claude-resources.git
```

Then add the path as a local plugin in your Claude Code configuration.

### Git submodule

Add to an existing project:

```bash
git submodule add https://github.com/deandum/claude-resources.git .claude-resources
```

Keeps the framework versioned alongside your project.

## Customize for your project

The framework looks for a `CLAUDE.md` file in your project root. This file tells the framework about your specific project.

1. Copy `EXAMPLE_CLAUDE.md` from this repository to your project root as `CLAUDE.md`.
2. Fill in your tech stack, build/test/lint commands, project boundaries, and conventions.
3. The framework reads your `CLAUDE.md` and adapts agent behavior accordingly.

Your `CLAUDE.md` should include:

- Project structure overview
- Build, test, and lint commands (exact, copy-paste runnable)
- Boundaries: always do, ask first, never do
- Project-specific conventions

### Optional: project constitution

For projects that benefit from machine-enforced invariants (security-sensitive code, regulated domains, long-lived systems with many contributors), copy `EXAMPLE_CONSTITUTION.md` to `docs/constitution.md` and edit the invariant list. The session-start hook reads it automatically; reviewer checks every diff against the listed invariants and critic uses them as the Scope Hazards reference frame during `/define`.

Keep the list small (3–10 invariants) and use `critical` severity sparingly — `critical` blocks advancement, `important` only flags. See [`skills/core/constitution/SKILL.md`](../skills/core/constitution/SKILL.md) for authoring guidance.

## Your first workflow

The framework follows a spec-driven workflow. Here's a concrete walkthrough from idea to shipped code. For the full phase-by-phase reference, see [workflow.md](workflow.md).

### 1. Ideate

```
/ideate build a rate limiter for our API gateway
```

The critic agent takes your vague idea through three sub-phases: understand and expand, evaluate and converge, sharpen and ship. Output: a concrete task statement ready for specification.

### 2. Define

```
/define implement token bucket rate limiter with per-client limits
```

Lead spawns `critic` and `scout` in parallel. Critic challenges requirements and surfaces gaps (→ `critique.md`). Scout greps the codebase for prior art, patterns, and inherited gotchas (→ `discovery.md`). Lead synthesizes both into `docs/specs/rate-limiter/spec.md` — a structured spec with objective, scope, subtasks in groups, commands, boundaries, and success criteria.

You review and approve the spec (Group 0 sign-off) before anything gets built.

### 3. Plan

```
/plan
```

Architect reads the approved spec and designs the project structure: directory layout, package boundaries, dependency flow, and interface contracts.

### 4. Build

```
/build
```

Builder implements code following the spec's subtask groups. Group 1 tasks run in parallel; Group 2 starts only after Group 1 completes AND you sign off on Group 1 results. After every group, main Claude pauses via `AskUserQuestion` asking you to `approve`, `changes: <what>`, or `stop` before advancing.

If a session ends mid-execution, resume with `/orchestrate --resume rate-limiter` — the framework tracks execution state in `spec.md` frontmatter and picks up at the next pending group.

### 5. Test

```
/test
```

Tester writes and runs tests covering the implementation. Tests verify the spec's success criteria are met.

### 6. Review

```
/review
```

Reviewer performs a five-axis code review: correctness, security, performance, style, and maintainability. Critical or Important findings force `needs-input`.

### 7. Ship (optional)

```
/ship
```

Shipper adds Docker, structured logging, metrics, and health checks for production readiness.

## Token efficiency

All agents apply `core/token-efficiency` at the **standard** level by default — compressing human-facing output without affecting reasoning or spec fidelity. Switch levels with `/compact standard|compressed|minimal`. Specs and agent-to-agent reports are never compressed.

## Next steps

- [workflow.md](workflow.md) — the spec-driven workflow deep dive
- [reference.md](reference.md) — every command, agent, and skill the framework ships
- [extending.md](extending.md) — add your own skills, agents, or commands
- [operations.md](operations.md) — hooks, learning system, opt-in ops plugin

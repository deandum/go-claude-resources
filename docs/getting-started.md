# Getting Started

Onboarding guide for the claude-resources framework -- a multi-language, spec-driven development framework for Claude Code.

## Prerequisites

- **Claude Code** CLI or IDE extension installed and configured
- **Git** for plugin installation and project detection
- **Bash 4+** — hooks are pure bash; no python or other runtime required
- **ast-grep** for structural code search (optional but recommended)

## Installation

### As Claude Code plugin (recommended)

```bash
claude plugin add https://github.com/deandumitru/claude-resources
```

This registers the plugin, hooks, agents, and slash commands automatically.

### Git clone

Clone the repository and reference it as a local plugin:

```bash
git clone https://github.com/deandumitru/claude-resources.git
```

Then add the path as a local plugin in your Claude Code configuration.

### Git submodule

Add to an existing project as a submodule:

```bash
git submodule add https://github.com/deandumitru/claude-resources.git .claude-resources
```

This keeps the framework versioned alongside your project.

## Your First Workflow

The framework follows a spec-driven workflow. Here is a concrete walkthrough from idea to shipped code:

### 1. Ideate

```
/ideate build a rate limiter for our API gateway
```

The critic agent takes your vague idea through three phases: understand and expand, evaluate and converge, sharpen and ship. Output: a concrete task statement ready for specification.

### 2. Define

```
/define implement token bucket rate limiter with per-client limits
```

The lead agent spawns `critic` and `scout` in parallel. Critic challenges requirements and surfaces gaps (→ `critique.md`). Scout greps the codebase for prior art, patterns, and inherited gotchas (→ `discovery.md`). Lead synthesizes both into `docs/specs/rate-limiter/spec.md` — a structured spec with objective, scope, subtasks in groups, commands, boundaries, and success criteria. You review and approve the spec (Group 0 sign-off) before anything gets built.

### 3. Plan

```
/plan
```

The architect agent reads the approved spec and designs the project structure: directory layout, package boundaries, dependency flow, and interface contracts.

### 4. Build

```
/build
```

The builder agent implements code following the spec's subtask groups. Group 1 tasks run in parallel; Group 2 starts only after Group 1 completes AND the user signs off on Group 1 results. Each task targets specific files with clear acceptance criteria. After every group, the lead emits a `needs-input` report asking you to `approve`, `changes: <what>`, or `stop` before advancing.

If a session ends mid-execution, resume with `/orchestrate --resume rate-limiter` — the framework tracks execution state in `spec.md` frontmatter and picks up at the next pending group.

### 5. Test

```
/test
```

The tester agent writes and runs tests covering the implementation. Tests verify the spec's success criteria are met.

### 6. Review

```
/review
```

The reviewer agent performs a 5-axis code review: correctness, security, performance, style, and maintainability.

## Understanding Skill Tiers

### Core skills (language-agnostic)

20 workflow skills covering the full development lifecycle. These define *what* to do without prescribing *how* in any specific language. Examples: spec-generation, discovery, code-review, error-handling, testing, token-efficiency.

Core skills contain:
- Decision frameworks (when to use, when not to use)
- Step-by-step processes
- Common rationalizations and rebuttals
- Red flags and verification checklists

### Language skills (implementation-specific)

15 Go implementation skills (currently the only supported language tier). These extend core skills with concrete code patterns, anti-patterns, and language-specific verification checks. Examples: go-api-design, go-concurrency, go-error-handling.

Language skills contain:
- Code patterns with explanations
- Anti-patterns with rationale
- Language-specific verification checklists

### Automatic loading

Skills are loaded automatically based on project language detection. The `session-start.sh` hook checks for marker files in your project root:

| Marker file | Detected language |
|-------------|-------------------|
| `go.mod` | Go |
| `package.json` + `angular.json` | Angular |
| `package.json` (no angular) | Node |
| `Cargo.toml` | Rust |
| `pyproject.toml` or `requirements.txt` | Python |

When a language is detected, its skill tier is loaded alongside the core skills.

## Customizing for Your Project

The framework looks for a `CLAUDE.md` file in your project root. This file tells the framework about your specific project:

1. Copy `EXAMPLE_CLAUDE.md` from this repository to your project root as `CLAUDE.md`
2. Fill in your tech stack, build/test/lint commands, project boundaries, and conventions
3. The framework reads your `CLAUDE.md` and adapts agent behavior accordingly

Your `CLAUDE.md` should include:
- Project structure overview
- Build, test, and lint commands (exact, copy-paste runnable)
- Boundaries: always do, ask first, never do
- Project-specific conventions

## Selective Loading

Not every project needs all 35 skills. Choose what fits:

### Essential (3 skills)

For smaller projects or quick tasks:
- `spec-generation` -- structured specs prevent rework
- `error-handling` -- consistent error strategy
- `testing` -- test coverage and strategy

### Full lifecycle (all 35)

For greenfield projects or teams adopting the full workflow. All core and language skills active.

### Custom selection

Enable or disable individual skills in `marketplace.json`. Each skill is registered as a plugin entry and can be toggled independently.

## Token Efficiency

The framework is cost-aware by default. All agents apply `core/token-efficiency` at the **standard** level, reducing human-facing output tokens without affecting reasoning quality or spec fidelity.

### What gets compressed

- Agent responses to the user (terminal output)
- Status updates, summaries, explanations
- Commentary and narrative around code blocks

### What is never compressed

- **SPEC files** -- these are prompts for downstream agents. Full clarity is required.
- **Agent-to-agent reports** -- lead uses these for group progression decisions.
- **Code blocks, commands, file paths, error messages** -- unchanged at all levels.
- **Acceptance and success criteria** -- testable contracts between agents.

### Adjusting the level

Use `/compact` to switch between intensity levels:

```
/compact standard     → Default: drop articles, filler, pleasantries
/compact compressed   → Standard + abbreviations, fragments, tables over paragraphs
/compact minimal      → Bullet-only, paths + status, maximum brevity
```

The key principle: verbose output burns tokens without adding value, but specs stay full-fidelity because they're prompts for other agents, not output for humans.

## Troubleshooting

**Language not detected?**
Check that marker files exist in your project root. Detection runs in `session-start.sh` and emits `detected_languages` in the session JSON context. For Go, ensure `go.mod` is present. For Node, ensure `package.json` exists.

**Skills not loading?**
Verify the skill is registered in `.claude-plugin/marketplace.json`. Each skill needs an entry under the correct plugin group.

**Agent not finding skills?**
Check the Language Detection section in the agent file under `agents/`. Each agent has detection logic that maps marker files to language tiers.

**Learnings not appearing?**
Check that `~/.claude-resources/learnings/` directory exists. Verify the project slug matches your git root basename: `basename $(git rev-parse --show-toplevel)`. Confirm the JSONL file has one valid JSON object per line with a `learning` field.

**Hooks not running?**
Check `hooks/hooks.json` is properly formatted. The file registers `SessionStart` and `SessionEnd` lifecycle hooks. Verify the scripts are executable: `ls -la hooks/*.sh`.

For deeper troubleshooting on any of the above, see [troubleshooting.md](troubleshooting.md).

## Next Steps

Now that you have the framework installed and have walked through a workflow, these docs are the natural next reads:

- **[architecture.md](architecture.md)** — understand the four building blocks (skills, agents, commands, hooks) and how they connect
- **[commands.md](commands.md)** — full reference for all 10 slash commands
- **[agents.md](agents.md)** — full reference for all 8 specialist agents
- **[skills-catalog.md](skills-catalog.md)** — browse the 38 skills by tier and phase
- **[workflow.md](workflow.md)** — deep dive on the spec-driven workflow and SPEC file template
- **[extending.md](extending.md)** — add new skills, agents, or commands to your install

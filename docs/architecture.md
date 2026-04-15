# Architecture

High-level overview of how the framework is put together.

`claude-resources` is a spec-driven development framework for Claude Code. It turns a generalist AI coding assistant into a team of specialist agents that collaborate through structured specs and reports. The framework ships as three Claude Code plugins — `core-skills` and one language-specific plugin (currently `go-skills`), plus an opt-in `ops-skills` plugin for external-write actions.

## The four building blocks

The framework has four kinds of things. Understanding them is enough to understand the whole framework.

| Block | Lives in | Purpose |
|---|---|---|
| **Skills** | `skills/core/`, `skills/go/`, `skills/ops/` | Knowledge — how to think about a problem |
| **Agents** | `agents/` | Roles — specialist actors that load skills and do work |
| **Commands** | `.claude/commands/` | Entry points — the slash commands users type |
| **Hooks** | `hooks/` | Glue — shell scripts that run on session events |

A user types a slash command. The command spawns an agent. The agent loads skills from the session-start context. The agent does its work and returns a structured report. That is the entire flow.

## Plugins

The framework is packaged as three plugins in `.claude-plugin/marketplace.json`:

| Plugin | What it contains | Default |
|---|---|---|
| `core-skills` | 20 language-agnostic workflow skills | enabled |
| `go-skills` | 15 Go-specific implementation skills | enabled when `go.mod` is present |
| `ops-skills` | 4 external-write skills (push, PR, release, registry) | **opt-in** |

Users install each plugin separately:

```bash
claude plugin add core-skills
claude plugin add go-skills
claude plugin add ops-skills  # only if the project authorizes external writes
```

See [ops-skills.md](ops-skills.md) for why external writes are a separate plugin and how the opt-in mechanism works.

## Skill tiers

There are three tiers. Each answers a different question.

**Core skills** answer: *What should I do and why?* These are language-agnostic workflow skills. Examples: `spec-generation`, `code-review`, `debugging`, `security`. Every skill in this tier follows the same anatomy — When to Use, When NOT, Core Process, Common Rationalizations, Red Flags, Verification. See [skill-anatomy.md](skill-anatomy.md).

**Language skills** answer: *How do I do that in this specific language?* These extend core skills with language-specific implementation patterns, code examples, and anti-patterns. Currently only Go is supported. Language skills have a lighter structure — patterns and anti-patterns, no decision framework.

**Ops skills** answer: *How do I do that safely when it crosses the system boundary?* These cover external writes that affect things outside the local filesystem. They follow the full core-skill anatomy plus an extra rule: every ops skill refuses to execute when `ops_enabled=false` in session context.

For the full list of skills in each tier, see [skills-catalog.md](skills-catalog.md).

## Agents

The framework has 9 specialist agents. Each has a single bounded role.

| Agent | Role |
|---|---|
| `critic` | Task analyst — challenges requirements, surfaces gaps (adversarial) |
| `scout` | Discovery agent — grounds the spec in existing code (parallel with critic) |
| `lead` | Project lead — generates spec directories, orchestrates groups, per-group sign-off |
| `architect` | Designer — package structure, interfaces, API surfaces |
| `builder` | Application code implementer |
| `cli-builder` | CLI tool implementer |
| `tester` | Test author |
| `reviewer` | Code reviewer (read-only) |
| `shipper` | Deployment and observability |

All agents are **language-agnostic**. They do not detect language themselves — they read `detected_languages` from session context and load the matching skills from their `## Language-Specific Skills` section. This keeps language detection in one place (`session-start.sh`) and avoids drift across agent files.

All agents load `core/token-efficiency` by default. Beyond that, each agent's `skills:` frontmatter list is tailored to its role.

Agents that can run external-write commands (`builder`, `cli-builder`, `shipper`, `lead`) also contain an "External Side Effects" section that checks `ops_enabled` before executing push, PR, release, or registry commands.

For the full per-agent reference, see [agents.md](agents.md).

## Commands

The framework ships 10 slash commands. Each routes to exactly one agent (or runs as a utility with no agent).

| Command | Agent | Purpose |
|---|---|---|
| `/ideate` | critic | Refine a vague idea |
| `/define` | lead | Generate a SPEC file |
| `/plan` | architect | Design structure |
| `/build` | builder / cli-builder | Implement code |
| `/test` | tester | Write and run tests |
| `/review` | reviewer | Five-axis review |
| `/ship` | shipper | Containerize and instrument |
| `/orchestrate` | lead | Delegate to multiple agents |
| `/learn` | utility | Record a learning |
| `/compact` | utility | Set output compression |

Command files are small by design (10–25 lines each). They contain no language-detection logic — that lives in `session-start.sh`. A command file's job is to route, not to instruct; the agent owns the workflow details.

For the full per-command reference, see [commands.md](commands.md).

## Hooks

The framework uses three lifecycle hooks registered in `hooks/hooks.json`:

| Hook | Fires on | What it does |
|---|---|---|
| `session-start.sh` | SessionStart | Detects languages, lists skills, loads recent learnings, emits JSON context |
| `session-end.sh` | SessionEnd | Persists session learnings to `~/.claude-resources/learnings/` |
| `learn.sh` | Manual (via `/learn` or agents) | Writes a single learning to a `/tmp` buffer |

All three are pure bash. No python, no other runtime. Bash 4+ is required for parameter-expansion features.

The session-start hook is the framework's single source of truth for language detection and session context. The JSON it emits is visible to every agent in the session. See [hooks.md](hooks.md) for the full schema.

## How it fits together

A concrete flow, start to finish:

1. **A session starts.** Claude Code fires the `SessionStart` event. `session-start.sh` runs, detects the project language, lists available skills, loads recent operational learnings, scans `docs/specs/*/spec.md` for in-progress tasks (emits `active_specs`), and emits a JSON block into the session context.

2. **The user types a slash command.** Say `/define build a rate limiter`. The command file in `.claude/commands/define.md` instructs Claude to spawn the `lead` agent.

3. **The lead agent reads the session context.** It sees `detected_languages: "go"` and knows to load Go-specific skills from its `## Language-Specific Skills` section. It also checks `active_specs` — if any are in progress, it surfaces them before starting fresh work.

4. **The lead spawns critic AND scout in parallel.** Critic challenges the request (writes `critique.md`). Scout greps the codebase, reads similar features, cites file paths for every finding (writes `discovery.md`). They do not coordinate mid-task; lead synthesizes.

5. **The lead creates the spec directory.** It copies every file from `skills/core/spec-generation/references/` into `docs/specs/rate-limiter/`, then populates `spec.md` with frontmatter plus the template body — folding scout's findings into Assumptions and Technical Approach, and critic's findings into Out of Scope and Boundaries.

6. **The user approves the spec (Group 0).** Lead records the decision in `group-log.md` and updates frontmatter `status: approved`. Nothing proceeds without explicit approval.

7. **The user runs `/build`.** The command spawns the `builder` agent with `docs/specs/rate-limiter/spec.md` as context. The builder reads the spec literally — files to modify, acceptance criteria, commands to run.

8. **The builder implements the group.** It loads `core/error-handling`, `core/debugging`, `core/git-workflow`, `core/style`, plus `go/error-handling`, `go/context`, `go/concurrency`, `go/database`, `go/style`. It writes code, runs tests, and returns a structured report using the [agent-reporting.md](agent-reporting.md) schema.

9. **The lead parses the report and pauses for sign-off.** It writes a new Group N section to `group-log.md` and emits a `needs-input` report asking the user to `approve`, `changes: <what>`, or `stop`. Execution does not advance without explicit sign-off.

10. **A new learning surfaces.** During the work, the builder discovered that the project uses a non-obvious repository pattern. It calls `learn.sh` to record the learning to a `/tmp` buffer.

11. **The session ends.** `session-end.sh` collects the buffer files, appends them to `~/.claude-resources/learnings/<project-slug>.jsonl`, and prunes to the last 50 entries. The spec directory remains on disk with its current frontmatter state.

12. **Resumption.** When the user starts a new session, `session-start.sh` detects that `rate-limiter` is still in progress and emits `active_specs: "rate-limiter:2/4"`. Lead surfaces the in-progress spec on its first response. The user runs `/orchestrate --resume rate-limiter` and execution picks up at the next pending group.

The framework is this flow, repeated. Every command is an entry point. Every agent is a specialist. Every skill is a unit of knowledge the agent loads to do its work.

## Further reading

- [getting-started.md](getting-started.md) — install and first workflow
- [workflow.md](workflow.md) — the spec-driven workflow deep dive
- [agents.md](agents.md) — per-agent reference
- [commands.md](commands.md) — per-command reference
- [skills-catalog.md](skills-catalog.md) — all 38 skills by tier and phase
- [hooks.md](hooks.md) — lifecycle hooks and validators
- [ops-skills.md](ops-skills.md) — the opt-in external-writes plugin
- [extending.md](extending.md) — how to extend the framework
- [troubleshooting.md](troubleshooting.md) — common issues and fixes

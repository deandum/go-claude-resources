# Extending the Framework

How to add new skills, language tiers, agents, or slash commands. Start with the skill anatomy reference (every contribution touches a skill or follows the same shape), then pick the procedure for what you're adding.

## Skill anatomy

Every skill follows a consistent anatomy. There are two tiers:

- **Core skills** are language-agnostic workflows. They define *what* to do without prescribing *how* in any specific language. Live in `skills/core/`.
- **Language skills** extend core skills with implementation patterns, code examples, and language-specific verification. Live in `skills/<lang>/` (e.g., `skills/go/`).

Both tiers use YAML frontmatter and follow a predictable section structure so agents can parse and apply them reliably.

### Core skill template

```markdown
---
name: skill-name
description: >
  What it does. When to use it.
---

## When to Use
- [Specific scenario 1]
- [Specific scenario 2]

## When NOT to Use
- [Exclusion 1]
- [Exclusion 2]

## Core Process
1. [Step 1 — what to do, not how in any specific language]
2. [Step 2]
3. [Step 3]

## Decision Framework
| Situation | Choice | Why |
|-----------|--------|-----|
| [scenario] | [option] | [reasoning] |

## Common Rationalizations
> "It's too simple for this process"
Reality: [Why this shortcut fails]

## Red Flags
- [Observable indicator that the skill is being misapplied]

## Verification
- [ ] [Testable criterion 1]
- [ ] [Testable criterion 2]
```

### Language skill template

```markdown
---
name: skill-name
description: >
  What it does. When to use it.
---

## Patterns

### Pattern 1: [Name]
[Code example with explanation]

## Anti-Patterns
- [What NOT to do and why]

## Verification
- [ ] [Language-specific check 1]
```

### Section-by-section guide

**Frontmatter.** Required. `name` is kebab-case and matches the directory name. `description` says what the skill does AND when to use it — this is what skill-discovery reads to route tasks.

**When to Use / When NOT to Use.** Concrete scenarios, not abstract categories. "Multi-file changes" beats "complex tasks". Explicit exclusions prevent misapplication.

**Core Process.** Step-by-step methodology. Core skills: no code, describe *what* in language-agnostic terms. Language skills: include code examples showing *how*. Each step should produce an observable result.

**Decision Framework.** Tables or decision trees for choosing between approaches. Each row covers a specific scenario with a clear recommendation and rationale. Prevents agents from guessing under ambiguity.

**Common Rationalizations.** The most valuable section. Lists shortcuts that sound reasonable but are not, paired with factual rebuttals. See the guidance below.

**Red Flags.** Observable indicators that the skill is being misapplied. "Functions exceeding 50 lines with no extraction" is observable. "Code quality issues" is not.

**Verification.** Exit-criteria checklist. Every item must be answerable yes or no. "No function exceeds 40 lines" beats "code is well-structured."

### Writing good rationalizations

Rationalizations are the core defense against process shortcuts. Guidelines:

1. **Start with a direct quote** of what someone might say to skip the process. Natural language — real things engineers say.
2. **Follow with "Reality:"** and a factual rebuttal. Appeal to consequences, not authority.
3. **Focus on consequences.** "You'll spend 3x longer debugging" beats "the framework requires this step."
4. **Draw from real engineering incidents** when possible.
5. **Cover the most tempting shortcuts first** — time pressure, simplicity claims, "just this once."

Weak:

> "We don't need tests for this"
> Reality: Tests are required by the framework.

Strong:

> "We don't need tests for this"
> Reality: The code that "doesn't need tests" is the code that breaks in production at 2 AM. Untested code is unverified code — you're hoping it works, not knowing it works.

### Quality criteria

Every skill must be:

1. **Specific** — actionable steps, not general guidance. "Create a repository interface with Find, Create, Update, Delete methods" beats "design good interfaces."
2. **Verifiable** — clear completion criteria with observable evidence.
3. **Battle-tested** — from actual engineering practice, not theory.
4. **Minimal** — only essential information for agent guidance. Skills are not textbooks.

### Supporting files

**Core skills.** No supporting files unless content exceeds ~100 lines. If a core skill needs supplementary material, that's a signal it may be too broad.

**Language skills.** May have two types of subdirectories:

- **`references/`** — deep-dive documentation loaded on demand (e.g., `references/alerting.md` for the observability skill).
- **`templates/`** — scaffolding files agents copy and adapt (e.g., `templates/Dockerfile` for the docker skill).

Supporting files are loaded on demand — the main `SKILL.md` is always loaded first; supporting files are referenced from within it.

### Naming conventions

- Skill directories: `lowercase-kebab-case` (e.g., `error-handling`, `api-design`).
- Each skill: one `SKILL.md` file (always uppercase).
- Directory name matches the frontmatter `name` field.
- Language skill names may be prefixed with the language in the marketplace registry (e.g., `go-error-handling`) but the directory uses the bare name (e.g., `skills/go/error-handling/`).

## Add a new core skill

Core skills are language-agnostic workflow skills. They live in `skills/core/<name>/SKILL.md`.

1. **Create the directory and file:**
   ```bash
   mkdir -p skills/core/my-new-skill
   touch skills/core/my-new-skill/SKILL.md
   ```
2. **Write the SKILL.md** following the anatomy above.
3. **Register in the marketplace.** Open `.claude-plugin/marketplace.json` and add the path under the `core-skills` plugin's `skills` array — alphabetically. Do this **after** the SKILL.md file exists (the marketplace is strict-mode; missing paths break the plugin install).
4. **Wire into one or more agents.** Open the relevant `agents/<name>.md` file and add `- core/my-new-skill` to the `skills:` frontmatter list. Keep the list alphabetical.
5. **Update the routing tree.** Open `skills/core/skill-discovery/SKILL.md` and add a decision-tree branch that routes relevant tasks to your new skill.
6. **Update the catalog.** Add your skill to the appropriate phase section in [reference.md](reference.md) with a one-line purpose.

## Add a new language tier

Language tiers extend core skills with implementation patterns for a specific language.

1. **Create the directory:**
   ```bash
   mkdir -p skills/python
   ```
2. **Write language-specific skills.** Each SKILL.md extends a core counterpart with code patterns, anti-patterns, and language-specific verification. See `skills/go/*/SKILL.md` for examples. Language skills use a lighter anatomy — no full 5-section core anatomy required.
3. **Register as a new plugin group** in `.claude-plugin/marketplace.json`:
   ```json
   {
     "name": "python-skills",
     "description": "Python-specific implementation patterns for ...",
     "source": "./",
     "strict": true,
     "skills": [
       "./skills/python/error-handling",
       "./skills/python/testing"
     ]
   }
   ```
4. **Update session-start detection.** Open `hooks/session-start.sh` and add marker-file detection. Use existing patterns (`go.mod`, `package.json`, `Cargo.toml`) as templates.
5. **Update each agent's `## Language-Specific Skills` section.** For every agent in `agents/*.md`, add a line mapping the language to the skill list the agent should load. Example:
   ```markdown
   - **python** → `python/error-handling`, `python/testing`, `python/style`
   ```
6. **Update [reference.md](reference.md)** with the new tier's skills.

## Add a new slash command

Slash commands are the entry points for the workflow.

1. **Create the command file:**
   ```bash
   touch .claude/commands/my-command.md
   ```
2. **Write the frontmatter and body:**
   ```markdown
   ---
   description: One-line description of what this command does
   ---

   ## Task

   Spawn the `my-agent` agent with this task: $ARGUMENTS

   Brief workflow notes (3–5 lines).
   ```
3. **Spawn an existing agent by bare name.** No language-detection logic — that lives in the session-start hook.
4. **Keep the command file under 25 lines.** Commands are routing documents, not instruction manuals. The agent owns the workflow details.
5. **Update [reference.md](reference.md)** with the new command row.

## Add a new agent

Agents are specialist roles spawned by slash commands.

1. **Create the agent file:**
   ```bash
   touch agents/my-agent.md
   ```
2. **Write the frontmatter:**
   ```yaml
   ---
   name: my-agent
   description: >
     One-line role description. Use when [specific scenario].
   tools: Read, Grep, Glob, Bash
   model: inherit
   skills:
     - core/style
     - core/token-efficiency
   memory: project
   ---
   ```
3. **Write the body.** Include: Communication Rules, Language-Specific Skills section (map languages to skill lists if the agent loads any), What You Do, How You Work, Output Format (use the reporting schema below), Process Rules, What You Do NOT Do.
4. **Add an External Side Effects guard** if the agent could run `git push`, `gh pr create`, `docker push`, or any other external-write command. Copy the pattern from `agents/builder.md` or `agents/shipper.md`. See [operations.md](operations.md#ops-plugin-opt-in) for the policy.
5. **Wire into a slash command** that should spawn it. Open `.claude/commands/<name>.md` and update the "Spawn the `...` agent" line.
6. **Update [reference.md](reference.md)** with the new agent row.
7. **Update the skill-discovery decision tree** if the agent handles a new task category.

### Agent reporting

All code-writing and review agents — `builder`, `cli-builder`, `tester`, `reviewer`, `shipper`, `architect` — end their work with a structured report. Main Claude (running the `core/orchestration` skill) parses each report and validates results against the spec's success criteria before spawning the next group.

Every report has these sections in order. Use them literally as headings.

**Status.** One of:

- **`complete`** — task finished, acceptance criteria met, evidence attached.
- **`blocked`** — cannot proceed without outside intervention; Blockers section mandatory.
- **`needs-input`** — work done but a decision is required before finalizing. Used when:
  - Two viable designs, unclear spec, ambiguous slug when multiple specs are active.
  - Group sign-off pauses in multi-group orchestration — see `skills/core/orchestration/SKILL.md` Phase 3 (Steps 8–13).
  - Pre-spec findings review — main Claude presents raw critic + scout findings before synthesizing the spec (Gate 1).
  - **Test failures** — tester stops on first failure batch, lists failures in Blockers, does not auto-retry.
  - **Critical or Important review findings** — severity drives status; Critical/Important forces `needs-input` regardless of the reviewer's opinion of the issue's realness.

**Files touched.** A table. One row per file created, modified, or deleted.

| Path | Action | Summary |
|------|--------|---------|
| `pkg/service/user.go` | modified | added `GetByEmail` method |
| `pkg/service/user_test.go` | created | table-driven tests for `GetByEmail` |

If nothing on disk changed, write: `_None (read-only task)._`

**Evidence.** Specific, verifiable proof the task is done. Prefer command output over prose.

```
$ go build ./...
(exit 0, no output)

$ go test ./pkg/service/... -race
ok  	example/pkg/service	0.203s
```

For review tasks, Evidence is the full review with severity labels. For design tasks, Evidence is the proposed structure, interfaces, or architecture diagram.

**Follow-ups.** Issues discovered during the task that are out of scope for this subtask but worth tracking. One bullet per item. Write `_None._` if nothing to report — do not invent follow-ups to look thorough.

**Blockers.** Only when `status: blocked`. Omit this section entirely otherwise. State what stopped progress and what input is needed — one per bullet.

#### Example: builder report

```markdown
## Report: add GetByEmail method

### Status
complete

### Files touched
| Path | Action | Summary |
|------|--------|---------|
| `pkg/service/user.go` | modified | added `GetByEmail(ctx, email)`; wraps repository errors with context |
| `pkg/service/user_test.go` | modified | added 4 table-driven cases: found, not-found, db-error, canceled-ctx |

### Evidence
$ go build ./...
$ go test ./pkg/service/... -race
ok  	example/pkg/service	0.203s

### Follow-ups
- `UserRepository.FindByEmail` ignores context cancellation — file a separate task.
```

#### Why structured, not prose

- **Main Claude parses it.** In multi-group orchestration, main Claude reads each report and decides whether to proceed to the next group. Free-form prose is ambiguous.
- **The report doubles as a PR description.** `Status`/`Files touched`/`Evidence` is already the body of a good commit message.
- **Follow-ups persist.** A structured follow-up field prevents drift. Main Claude can fold them into the next group's spec instead of losing them in chat scrollback.
- **Blockers fail loud.** When status is `blocked`, the section is mandatory — agents can't quietly stall.

#### Rationalizations to avoid

| Shortcut | Reality |
|----------|---------|
| "I'll just describe what I did in a paragraph." | Lead can't parse paragraphs into group decisions. Use the schema. |
| "Evidence is obvious from the diff." | Evidence is the command output that *proves* the diff is correct. Paste it. |
| "No follow-ups needed." | Maybe. But did you really look? If nothing, write `_None._` — don't omit the section. |
| "I'll report success and mention the blocker in passing." | Split: either `complete` with follow-ups, or `blocked` with Blockers. Not both. |

## Authoring a project constitution

A constitution is the list of invariants reviewer and critic enforce on every diff. It lives at `docs/constitution.md` in the consumer project. The session-start hook reads it, emits `project_constitution` into session context, and agents grade against it without additional file reads.

1. **Copy the template:** `cp EXAMPLE_CONSTITUTION.md docs/constitution.md`.
2. **Edit the `invariants:` frontmatter list.** Each entry has `id` (kebab-case) and `severity` (`critical` or `important`).
3. **Write a body section per invariant** with `**Enforced by:**`, `**Scope:**`, `**Rationale:**`, `**Detection:**`. All four fields are required.
4. **Keep the list short.** 3–10 invariants. Anything longer is a checklist; split it into lints, skills, or CLAUDE.md conventions.
5. **Use `critical` sparingly.** `critical` blocks advancement — reviewer returns `needs-input`. `important` flags without blocking.

See [`skills/core/constitution/SKILL.md`](../skills/core/constitution/SKILL.md) for authoring guidance, severity semantics, and sunsetting rules.

## Parallelization markers in specs

Every subtask in `spec.md` carries a `[P]` prefix declaring "this task is safe to run simultaneously with every other task in this group." The marker makes the framework's parallel-by-group default explicit and auditable.

```markdown
### Group 1: Scaffold storage layer (parallel)
- [ ] **[P] builder** — create repository interface in pkg/user/repo.go
  - Files: pkg/user/repo.go
  - Done when: interface compiles with zero implementations
- [ ] **[P] builder** — create service interface in pkg/user/service.go
  - Files: pkg/user/service.go
  - Done when: interface compiles
```

If a task cannot honestly carry `[P]` (it reads files another task in the same group writes), split it into its own group. Reviewer audits the marker against the `Files:` list during mini-review — overlapping writes with `[P]` markers is a Critical finding.

## Contracts artifact structure

`docs/specs/<slug>/contracts.md` is an optional fifth spec artifact for API/data-heavy work. Lead copies it at Step 1 when the task description contains API/data markers (`REST`, `endpoint`, `schema`, `webhook`, `event`, `payload`, `migration`, `API`). Architect populates it after spec approval. Reviewer validates implementation against it during mini-review — mismatches are Critical findings.

Required sections:

| Section | Content |
|---------|---------|
| Endpoints | Table: Method, Path, Purpose, Auth |
| Request Schemas | JSON shape per endpoint; field types and constraints |
| Response Schemas | Success + error shapes |
| Error Codes | Table: Code, HTTP Status, Condition, Response `details` |
| Events | Per-event type and payload (if any) |
| Data Invariants | Cross-cutting rules (e.g., "email stored lowercase") |

If a section has no content for the current task, state `_None._` rather than deleting the heading — reviewer uses section presence as a checklist.

## Style rules for new skill content

Skills are parsed by agents at runtime. The writing style matters.

- **Imperative form.** "Wrap errors with `fmt.Errorf` and `%w`" not "Errors should be wrapped with..."
- **Explain WHY, not just WHAT.** The agent is a smart reader — giving it the reasoning lets it handle edge cases the skill does not enumerate.
- **Avoid ALL-CAPS MUST/NEVER** where softer reasoning works. Reserve it for genuine hard rules (security, data loss, irreversible actions).
- **Rationalizations table** must be domain-specific. Generic items ("We don't have time") are weak. Specific items ("We'll add auth later — it's internal for now") are strong.
- **Red Flags** should be observable patterns, not abstract principles. "Handler with no input validation" beats "security issues".
- **Verification** items must be objectively checkable. "All tests pass" beats "code is high quality".

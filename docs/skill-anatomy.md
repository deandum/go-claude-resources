# Skill Anatomy

Reference for writing and understanding skills in the claude-resources framework.

## Overview

Every skill follows a consistent anatomy. There are two tiers:

- **Core skills** are language-agnostic workflows and decision frameworks. They define *what* to do without prescribing *how* in any specific language. Located in `skills/core/`.
- **Language skills** extend core skills with implementation patterns, code examples, and language-specific verification. Located in `skills/<lang>/` (e.g., `skills/go/`).

Both tiers use YAML frontmatter and follow a predictable section structure so agents can parse and apply them reliably.

## Core Skill Template

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
1. [Step 1 -- what to do, not how in any specific language]
2. [Step 2]
3. [Step 3]

## Decision Framework
| Situation | Choice | Why |
|-----------|--------|-----|
| [scenario] | [option] | [reasoning] |

## Common Rationalizations
> "It's too simple for this process"
Reality: [Why this shortcut fails]

> "We're in a rush"
Reality: [Why skipping costs more time]

## Red Flags
- [Observable indicator that the skill is being misapplied]

## Verification
- [ ] [Testable criterion 1]
- [ ] [Testable criterion 2]
```

## Language Skill Template

```markdown
---
name: skill-name
description: >
  What it does. When to use it.
---

## Patterns

### Pattern 1: [Name]
[Code example with explanation]

### Pattern 2: [Name]
[Code example with explanation]

## Anti-Patterns
- [What NOT to do and why]

## Verification
- [ ] [Language-specific check 1]
- [ ] [Language-specific check 2]
```

## Section-by-Section Guide

### Frontmatter

```yaml
---
name: error-handling
description: >
  Structured error handling patterns. Use when designing error
  strategies, wrapping errors, or mapping errors to responses.
---
```

- **name**: Kebab-case identifier matching the directory name (e.g., `error-handling`, `spec-generation`)
- **description**: What the skill does AND when to use it. This is what skill-discovery reads to route tasks to the right skill.

The frontmatter is required. Agents use it for skill identification and routing.

### When to Use / When NOT to Use

```markdown
## When to Use
- Multi-file or multi-package changes
- New features or new projects
- Any task exceeding 30 minutes of work

## When NOT to Use
- Single-line fixes or typo corrections
- Tasks already specified with clear acceptance criteria
```

Explicit triggering conditions and exclusions. These sections prevent misapplication -- an agent reading a skill knows immediately whether the current task matches.

Write these as concrete scenarios, not abstract categories. "Multi-file changes" is better than "complex tasks".

### Core Process

```markdown
## Core Process
1. **Clarify** -- Spawn critic to identify gaps and assumptions
2. **Scope** -- Define what's in and explicitly what's out
3. **Surface assumptions** -- List every assumption for user validation
4. **Set success criteria** -- Testable, measurable, verifiable evidence
```

Step-by-step methodology the agent follows.

- Core skills: No code. Steps describe *what* to do in language-agnostic terms.
- Language skills: Include code examples showing *how* to implement patterns in the specific language.

Steps should be ordered, concrete, and actionable. Each step should produce an observable result.

### Decision Framework

```markdown
## Decision Framework
| Situation | Choice | Why |
|-----------|--------|-----|
| Error is actionable by caller | Return wrapped error | Caller can decide recovery strategy |
| Error is a programming bug | Panic | Fail fast, fix the bug |
| Error crosses API boundary | Map to status code | Callers outside your process need HTTP semantics |
```

Tables or decision trees for choosing between approaches. These prevent agents from guessing when faced with ambiguous situations. Each row should cover a specific scenario with a clear recommendation and rationale.

### Common Rationalizations

```markdown
## Common Rationalizations
> "It's obvious, no spec needed"
Reality: Obvious to you isn't obvious to agents. Specs surface
misunderstandings before code.

> "I'll write the spec after coding"
Reality: That's documentation, not specification. The value is in
forcing clarity before code.

> "The spec will slow us down"
Reality: A 15-minute spec prevents hours of rework. Debugging is
slower than specifying.
```

This is the most valuable section. It lists shortcuts that sound reasonable but are not, paired with factual rebuttals. This section prevents agents from finding loopholes in the process.

Each rationalization starts with a quoted excuse someone might use to skip the skill's process, followed by "Reality:" and a consequence-based rebuttal. Focus on what goes wrong, not on rules.

### Red Flags

```markdown
## Red Flags
- Vague requirements accepted without pushback
- No acceptance criteria defined
- Missing "Out of Scope" section
- Commands without exact flags
```

Observable indicators that the skill is being misapplied. These serve as an early warning system -- if an agent or reviewer sees these patterns, something has gone wrong.

Red flags should be specific and detectable. "Code quality issues" is too vague. "Functions exceeding 50 lines with no extraction" is observable.

### Verification

```markdown
## Verification
- [ ] Spec covers all template sections
- [ ] Assumptions explicitly stated and validated
- [ ] Success criteria are testable
- [ ] User has approved the spec before implementation begins
```

Exit criteria checklist. How to know the skill was applied correctly. Every item must be testable or observable -- someone should be able to check each item and answer yes or no.

Bad: "Code is well-structured"
Good: "No function exceeds 40 lines"

## Writing Good Rationalizations

Rationalizations are the core defense against process shortcuts. Guidelines for writing them:

1. **Start with a direct quote** of what someone might say to skip the process. Use natural language -- these should sound like real things engineers say.

2. **Follow with "Reality:"** and a factual rebuttal. Do not appeal to authority ("the process says so"). Appeal to consequences ("this leads to X").

3. **Focus on consequences, not rules.** "You'll spend 3x longer debugging" is more persuasive than "the framework requires this step".

4. **Draw from real engineering incidents when possible.** Concrete examples stick better than abstract principles.

5. **Cover the most tempting shortcuts first.** Time pressure, simplicity claims, and "just this once" are the most common.

Example of a weak rationalization:
> "We don't need tests for this"
Reality: Tests are required by the framework.

Example of a strong rationalization:
> "We don't need tests for this"
Reality: The code that "doesn't need tests" is the code that breaks in production at 2 AM. Untested code is unverified code -- you're hoping it works, not knowing it works.

## Quality Criteria

Every skill must be:

1. **Specific** -- Actionable steps, not general guidance. "Create a repository interface with Find, Create, Update, Delete methods" rather than "design good interfaces".

2. **Verifiable** -- Clear completion criteria with observable evidence. Every Verification item should be answerable with yes or no.

3. **Battle-tested** -- From actual engineering practice, not theory. Patterns should come from real codebases and real incidents.

4. **Minimal** -- Only essential information for agent guidance. Skills are not textbooks. Include what an agent needs to make the right decision, nothing more.

## Supporting Files

### Core skills

No supporting files unless content exceeds approximately 100 lines. Core skills should be self-contained in a single `SKILL.md` file. If a core skill needs supplementary material, that is a signal the skill may be too broad and should be split.

### Language skills

May have two types of supporting subdirectories:

- **`references/`** -- Deep-dive documentation on specific topics (e.g., `references/alerting.md` for the observability skill). These are loaded on-demand when an agent needs deeper guidance, not with the main skill.

- **`templates/`** -- Scaffolding files that agents copy and adapt (e.g., `templates/Dockerfile` for the docker skill). These provide starting points that follow the skill's patterns.

Supporting files are loaded on-demand. The main `SKILL.md` is always loaded first; supporting files are referenced from within it and fetched only when needed.

## Further Reading

- [skills-catalog.md](skills-catalog.md) — the full list of 38 skills by tier and phase, with one-line descriptions and links to each `SKILL.md`
- [extending.md](extending.md) — step-by-step walkthrough for adding a new skill to the framework

## Naming Conventions

- Skill directories: `lowercase-kebab-case` (e.g., `error-handling`, `api-design`)
- Each skill: one `SKILL.md` file (always uppercase)
- Directory name matches the frontmatter `name` field
- Language skill names may be prefixed with the language in the marketplace registry (e.g., `go-error-handling`) but the directory itself uses the bare name (e.g., `skills/go/error-handling/`)

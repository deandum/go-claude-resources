---
name: discovery
description: >
  Ground a task in the existing codebase before specification. Use when
  starting /define or /orchestrate to map relevant files, patterns, and
  inherited constraints. Prevents specs built on phantom assumptions.
---

# Discovery

The spec is only as good as its contact with reality. Discovery is the contact — the codebase scan that happens before the spec is drafted, so assumptions are validated instead of invented.

## When to Use

- At the start of `/define` or `/orchestrate`, in parallel with `critic`
- When a task touches code that already exists (even if the user framed it as "new")
- When learnings from prior sessions suggest prior art or inherited gotchas
- When the task involves an area of the codebase you have not read in this session

## When NOT to Use

- Single-line fixes where the file is already named in the request
- Greenfield projects with no existing code to scan
- Typo corrections or documentation-only changes
- Follow-ups to a recently completed task where the spec just ran

## Core Process

### 1. Scope the search

Identify the keywords, package names, and feature words from the task. Build a short list — five to ten terms — that will feed into grep.

Do not try to read the whole codebase. The goal is to check whether the task overlaps with existing code, not to produce a map of everything.

### 2. Grep for prior art

Run grep for each keyword across the repository. Skim the hits for:

- Functions or types that already implement what the task asks for
- Files named after the feature (`rate_limiter.go`, `auth_middleware.py`)
- Tests that cover similar behavior

Cite every hit with a file path and line number. If you cannot cite a path, you cannot claim the hit.

### 3. Read similar features

For the closest two or three prior-art matches, read the file. Note:

- The conventions used (naming, structure, error handling)
- The dependencies imported
- The tests colocated with the feature
- Any TODO, FIXME, or HACK comments that hint at known gotchas

### 4. Check learnings

Read `recent_learnings` from session-start context. Learnings flagged `gotcha` or `pattern` that relate to the task's area become Inherited Gotchas in the discovery artifact.

### 5. Write discovery.md

Populate the four sections of `docs/specs/<slug>/discovery.md`:

- **Existing Surface** — every file/function cited, with a one-line relevance note
- **Patterns to Follow** — each pattern with an example path
- **Inherited Gotchas** — each gotcha with evidence
- **Handoff to lead** — what should fold into Assumptions and Technical Approach

Stay terse. Headline findings only. Detailed forensic notes do not belong here.

## Common Rationalizations

| Shortcut | Reality |
|----------|---------|
| "It's a new feature, nothing exists yet." | You have not grepped. The codebase has surprised you before. Grep first, then claim. |
| "I already read this codebase last week." | Memory fades. Files change. A five-minute grep catches what memory misses. |
| "The task description is clear — no discovery needed." | Clear tasks still touch existing code. Clear does not mean isolated. |
| "I'll just list the file paths I think are relevant." | Without citations, your list is speculation. Every entry needs a path you actually opened. |
| "Critic already checks for existing code." | Critic's role was narrowed. Discovery is your job now. Do it. |

## Red Flags

- A finding asserted without a file path
- "Existing Surface" section left empty on a non-greenfield task
- Patterns claimed without an example path
- No mention of learnings despite `recent_learnings` being populated
- Handoff section rewriting the task — you are not here to redesign, only to surface
- Discovery artifact longer than the spec it precedes

## Verification

- [ ] Every claim in `discovery.md` cites a file path
- [ ] At least one grep was run for each keyword extracted from the task
- [ ] Similar-feature files were read, not just skimmed for names
- [ ] `recent_learnings` were checked for gotchas in the task's area
- [ ] Handoff section names specific items to fold into the spec, not general advice
- [ ] Discovery artifact is shorter than the spec template — not a second spec

Pair with: `core/skill-discovery`, `core/spec-generation`.

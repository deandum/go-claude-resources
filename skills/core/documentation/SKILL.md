---
name: documentation
description: >
  When to write prose, ADRs, READMEs, and inline comments. Use when
  recording design decisions, maintaining READMEs, or deciding whether
  a comment is worth writing. Pair with core/style for comment policy.
---

# Documentation

Most documentation rots. The remainder is load-bearing. The skill is knowing which kind you are writing and protecting the load-bearing material from rot.

## When to Use

- Recording an architectural decision
- Writing or updating a project README
- Writing setup/onboarding steps
- Documenting a public API or contract
- Deciding whether a comment is worth writing

## When NOT to Use

- To restate what the code does — name the function better
- To summarize a PR inside the code — that's what the PR description is for
- To document every field in a struct — only the non-obvious ones
- To write a tutorial for a feature nobody has asked about

## Core Process

### 1. Code first, comments second

A well-named function, type, or variable beats a comment every time. Before writing a comment, ask: can I rename this to make the comment unnecessary?

Write comments only when the WHY is non-obvious:

- A hidden constraint
- A subtle invariant
- A workaround for a specific bug
- Behavior that would surprise a reader

Never comment what the code already says. Never reference the current task, PR, or author.

### 2. READMEs answer five questions

A good README answers:

1. **What is this?** — one-sentence description
2. **Why does it exist?** — the problem it solves, in plain language
3. **How do I run it?** — minimal setup and launch command
4. **How do I contribute?** — tests, linting, branch strategy, review expectations
5. **Where do I go next?** — links to deeper docs, architecture, ADRs

Anything more than the top of the file is exile material for `docs/`.

### 3. ADRs capture decisions, not plans

Architecture Decision Records (ADRs) are short, immutable notes about choices that shaped the system. Format:

```
# ADR-NNN: <decision>

## Context
<what was the pressure, the constraint, the question>

## Decision
<what we chose>

## Consequences
<what becomes easier, what becomes harder, what we have to watch>
```

Rules:

- Once written and merged, ADRs are immutable. A new decision that supersedes an old one gets its own ADR that references the previous number.
- Write the ADR *when the decision is made*, not weeks later. Memories fade.
- ADRs document WHY, not WHAT. The code shows what.

### 4. API docs are contracts

Public interfaces need:

- **Purpose** — what it does, in one sentence
- **Contract** — inputs, outputs, errors, side effects, invariants
- **Example** — at least one working call site

If the contract is not documented, nothing prevents a refactor from breaking callers. Internal APIs can rely on the test suite as their contract; external APIs cannot.

### 5. Keep docs next to the code

Every file you write is a place docs can rot. Minimize:

- ADRs live in `docs/adr/`
- README lives at repo root
- Onboarding lives in the README or a single `CONTRIBUTING.md`
- API docs live in source, generated from doc-comments

If it lives somewhere strange, nobody updates it.

## Common Rationalizations

| Shortcut | Reality |
|----------|---------|
| "I'll comment everything so it's easy to read." | Over-commenting hides the code. Rename first. |
| "Nobody reads the README anyway." | Your future self reads it. Write for them. |
| "We'll write the ADR later." | You won't. Write it now, while the decision is fresh. |
| "The tests are the documentation." | Tests are a lower bound. They tell you what *must* work, not *why* it was built. |
| "I'll duplicate the README in the wiki for discoverability." | Now you have two READMEs to keep in sync. One source of truth. |

## Red Flags

- Comments that describe WHAT the next line does
- READMEs with dead links, outdated setup steps, or references to tools you no longer use
- ADRs that describe plans instead of decisions
- Public API functions with no doc comment
- Setup instructions that do not work on a fresh clone
- Docs in three places — repo, wiki, confluence — all drifted

## Verification

- [ ] Every comment explains WHY or a non-obvious constraint, never WHAT
- [ ] README answers the five questions; setup steps run successfully on a fresh clone
- [ ] Every public API function has a doc comment with contract and example
- [ ] Decisions made in this task are recorded as ADRs (if significant)
- [ ] No duplicated docs across multiple storage locations

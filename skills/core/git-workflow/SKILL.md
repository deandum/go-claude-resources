---
name: git-workflow
description: >
  Local git discipline — commit hygiene, branch naming, rebase vs
  merge, drafting PR body content, versioning scheme selection. Use
  when staging a commit, writing a commit message, naming a branch,
  splitting a large change into smaller commits, drafting a PR
  description locally (the file content, not the `gh pr create`
  mechanics), or choosing a versioning scheme (semver vs calvert).
  Trigger on phrases like "commit this", "write the commit message",
  "split this up", "draft the PR description", "rebase onto main",
  or "what version do we bump?". Remote-write actions — push, PR
  creation, release publishing, registry push — live in the opt-in
  `ops-skills` plugin (`ops/git-remote`, `ops/pull-requests`,
  `ops/release`, `ops/registry`).
---

# Git Workflow

Git history is the project's autobiography. Commits are not just undo points — they are the narrative someone will read in six months when they are trying to understand what you did and why.

**Scope:** this skill covers **local** git discipline. Remote-write actions — `git push`, `gh pr create`, tag push, release publishing, container registry push — live in the opt-in `ops-skills` plugin:

- `ops/git-remote` — push, force-push policy, tag push
- `ops/pull-requests` — PR creation with `gh pr create`, review response, merge strategy
- `ops/release` — tagging, changelog generation, GitHub Releases
- `ops/registry` — `docker push`, tag strategy, image signing

When `ops_enabled=false` in session context (the default), agents execute only the local discipline from this skill; any remote action is reported as a follow-up.

## When to Use

- Staging a change before committing
- Writing a commit message
- Reviewing a commit log for bisect-readiness
- Deciding between rebase and merge for a local integration
- Splitting a large change into smaller commits
- Choosing a versioning scheme for a new project

## When NOT to Use

- Pushing, opening a PR, cutting a release, or pushing an image — see the `ops/*` skills listed above
- In a scratch repo nobody else will read
- When the team has an explicit convention that differs from this skill — follow the team

## Core Process

### 1. One logical change per commit

A commit should do one thing. If the imperative summary needs "and" or a semicolon, split it. Small commits:

- Are easier to review
- Are easier to revert
- Make bisect work
- Force you to separate concerns

Refactors and behavior changes do not belong in the same commit. Do the refactor first, prove nothing changed, then make the behavior change.

### 2. Write commit messages for the reader, not the writer

Format:

```
<verb>: <summary in imperative, under 72 chars>

<why this change is being made, not what — the diff shows what>
<any tradeoffs, constraints, or future-you notes>
```

- Subject in the imperative: "add", "fix", "remove" — not "added" or "adding"
- The body answers *why*. The diff already answers *what*.
- Reference issues/specs by ID but do not rely on them for explanation — links rot.
- If the body is empty, the subject must be complete on its own

### 3. Branch naming

- `feature/<slug>` — new work
- `fix/<slug>` — bug fix
- `chore/<slug>` — refactor, rename, deps
- Avoid personal branches named after the author — they do not describe the work

### 4. Rebase for linear local history

On a local feature branch, rebase onto the base branch before integrating. This keeps history linear and makes bisect useful. Exceptions:

- The branch has been shared with reviewers — rebase breaks their references; merge instead
- The team has a merge-commit convention — follow it

Force-push policy and the rules around rewriting published history are covered in `ops/git-remote` §3.

### 5. Drafting PR body content (local)

When preparing a PR description locally — before running `gh pr create`, which belongs to `ops/pull-requests` — the body should answer:

- **What** changed — brief, not the diff
- **Why** it changed — motivation from the spec or issue
- **How** to test — exact commands
- **What** to review for — specific axes, risks, or areas of uncertainty

This is local drafting discipline: you write the body content as text, no network action. The mechanics of creation, template selection, review response, and merge strategy live in `ops/pull-requests`.

### 6. Versioning strategy

Pick one versioning scheme and stick to it:

- **Semantic versioning** (semver) for libraries and APIs — explicit breaking-change signal
- **Calendar versioning** (calvert) for services and apps — release cadence signal

Record the choice in an ADR (`core/documentation`). The mechanics of actually cutting a release — tagging, changelog, publishing — are covered in `ops/release`.

## Common Rationalizations

| Shortcut | Reality |
|----------|---------|
| "I'll squash everything at the end." | Squashing hides the history you would want for bisect and review. Commit cleanly as you go. |
| "The diff is obvious, no body needed." | The *what* is obvious; the *why* almost never is. Write the body. |
| "Quick fix, commit message doesn't matter." | Every commit is read 10× more than it is written. Invest. |
| "I'll mix the refactor and the feature — saves a PR." | You save a PR and lose a decade of reviewability. Split. |
| "I'll pick the versioning scheme once we need to release." | You'll pick it under pressure, badly. Decide now. |

## Red Flags

- Commit messages like "fix", "wip", "update", "misc"
- Commits that mix refactors and behavior changes
- Long-lived feature branches that have not been rebased
- PR descriptions that only say "see diff"
- Versioning scheme decided ad-hoc, no ADR, no team agreement

## Verification

- [ ] Each commit does one logical thing — subject has no "and"
- [ ] Commit body explains *why*, not *what*
- [ ] Feature branch is rebased onto current base before integrating (or merge commit, per team convention)
- [ ] PR description answers What / Why / How to test / Review focus
- [ ] Versioning scheme chosen and documented for the project
- [ ] No remote-write actions executed without ops-skills opt-in (checks `ops_enabled` first)

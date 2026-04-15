---
name: ops/git-remote
description: >
  Remote git write discipline: push, force-push policy, upstream
  tracking, tag push. Part of the opt-in ops-skills plugin. Use ONLY
  when session context has ops_enabled=true. Pair with
  core/git-workflow for local discipline.
---

# Git Remote

Pushing to a remote is the first irreversible step — branches become visible to collaborators, tags become references for builds, and force-pushes can destroy other people's work. This skill covers the discipline for those moments. For local git hygiene (commits, branches, rebase), see `core/git-workflow`.

## When to Use

- Pushing a branch to a remote for the first time
- Updating a remote branch with new commits
- Pushing tags (releases, milestones)
- Deciding whether a force-push is safe
- Setting upstream tracking on a new branch

## When NOT to Use

- Session context has `ops_enabled=false` — **do not push**, report the intended push as a follow-up instead
- The change has not been committed yet — see `core/git-workflow` first
- The branch is a scratch branch nobody else will see — you probably do not need a remote

## Core Process

### 1. Push only deliberate work

Before `git push`, confirm:

- Every commit is intentional — no WIP, no "fix" commits slipped in
- The branch is rebased onto current base (or the team's merge-commit convention applies)
- Local tests pass — you do not push a known-broken branch
- You are pushing from the expected working directory and branch

Pushing is publication. Treat it accordingly.

### 2. Set upstream deliberately

First push of a new branch: `git push -u origin feature/slug`. The `-u` (or `--set-upstream`) is intentional — it links the local branch to the remote. Subsequent pushes can use bare `git push`.

If you omit `-u` on the first push, you will get a reminder. Do not copy-paste the reminder blindly — confirm the branch name matches before running it.

### 3. Force-push policy

Force-push (`git push --force` or `--force-with-lease`) rewrites remote history. The blast radius:

- **Safe:** your own unshared branch, no collaborators, no CI/PR references
- **Risky:** shared branch with an open PR, reviewers have pulled, CI is running
- **Forbidden:** any protected branch (main, release/*, any branch with branch protection rules)

Rules:

- **Never** force-push `main`, `master`, `release/*`, or any branch with protection rules
- **Never** force-push a branch without checking `git log origin/<branch>` first — you might overwrite work you haven't seen
- Prefer `--force-with-lease` over `--force` — it aborts if the remote moved since your last fetch
- If the branch has an open PR, announce the force-push to reviewers before running it

### 4. Push tags separately and by name

Tags are not pushed by default. After `git tag v1.2.3`, the tag exists only locally. To publish: `git push origin v1.2.3` (not `--tags`, which pushes every local tag including scratch tags).

Never move a published tag. If the release was wrong, cut a new version. Moved tags break checksums, builds, and downstream consumers.

### 5. Abort, don't paper over

If a push is rejected (non-fast-forward, protected branch, hook failure), **stop and investigate**. Do not retry with `--force`. The rejection is information. Fix the cause — usually by fetching, rebasing, and re-running — not by overriding the check.

## Common Rationalizations

| Shortcut | Reality |
|----------|---------|
| "I'll force-push to clean up — nobody else is on this branch." | Check `git log origin/<branch>` first. You might be wrong about "nobody else". |
| "The PR reviewers can just re-pull after my force-push." | They won't — their review comments will orphan. Announce first. |
| "I'll push tags with `--tags` to save a step." | You'll push every local tag, including scratch tags. Push specific tags by name. |
| "The push was rejected — let me `--force` through." | The rejection is usually protecting you. Read the error first. |
| "I'll push now and fix the CI failure later." | Everyone on the team gets the broken state. Fix locally, then push. |

## Red Flags

- `git push --force` on `main`, `master`, or any protected branch
- `git push --tags` (usually pushes too many)
- Force-push without `--force-with-lease`
- Pushes rejected and retried with `--force` immediately
- Tags moved or re-created after publication
- `--no-verify` to bypass pre-push hooks
- Push commands committed to scripts without guards

## Verification

- [ ] `ops_enabled=true` confirmed in session context before any push command
- [ ] Branch rebased or merge-committed per team convention before push
- [ ] Local tests pass before push
- [ ] Force-push (if used) was `--force-with-lease`, not `--force`, and not on a protected branch
- [ ] Tags pushed by explicit name, not `--tags` bulk
- [ ] When `ops_enabled=false`: push reported as a follow-up, not executed

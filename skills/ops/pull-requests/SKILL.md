---
name: ops/pull-requests
description: >
  Pull request creation and response discipline. Use when opening a
  PR with `gh pr create`, responding to review comments, selecting a
  merge strategy (squash / merge commit / rebase), marking a draft
  PR ready, or updating a PR description after the branch changes.
  Trigger on phrases like "open a PR", "create the pull request",
  "respond to review comments", "merge this PR", "mark ready", or
  "which merge strategy?". Part of the opt-in `ops-skills` plugin —
  requires `ops_enabled=true` in session context; if disabled,
  report the intended action as a follow-up instead of running it.
  Pair with core/git-workflow §5 for the body content you put
  inside the PR.
---

# Pull Requests

Creating a PR is an announcement: "here is work I want merged." It triggers CI, notifies reviewers, and starts a conversation. This skill covers the mechanics — creation, template selection, review response, merge decision. For the content of a good PR description, see `core/git-workflow` §5.

## When to Use

- Opening a new pull request with `gh pr create`
- Responding to review comments on an open PR
- Deciding between squash / merge / rebase when merging
- Updating a PR description after the branch changes
- Requesting additional reviewers

## When NOT to Use

- Session context has `ops_enabled=false` — **do not create PRs**, report the intended PR as a follow-up
- The branch is not pushed yet — push first (see `ops/git-remote`)
- The change is a draft you are not ready to share — use a draft PR explicitly

## Core Process

### 1. Create, don't rush

Before `gh pr create`:

- The branch is pushed to the remote
- CI is passing on the branch (or you are intentionally opening a draft for early feedback)
- You have a one-line summary and a few bullets for the body — no "update" or "wip" titles
- You know which base branch to target — default is usually `main`, but some repos use `develop` or similar

### 2. Use the repo's template

If the repo has a PR template (`.github/pull_request_template.md`), `gh pr create` will load it. Do not blank it out. Fill every section the template requests. Empty templates are a contributor smell.

If there is no template, the PR body should still cover:

- **What** changed — one paragraph, not the diff
- **Why** — motivation, linked spec or issue
- **How to test** — exact commands the reviewer runs
- **Review focus** — where attention is most valuable

### 3. Draft vs. ready

Use a draft PR when:

- You want early feedback on direction
- CI is not green yet and you are debugging
- Dependencies (other PRs, other teams) need to land first

Mark it ready for review (`gh pr ready`) only when you would be comfortable with it merging as-is.

### 4. Respond, don't argue

When a reviewer leaves a comment, each kind gets a specific response:

- **Agree** — make the fix, push the commit, reply briefly ("done in `<sha>`") and resolve the thread
- **Disagree with reasoning** — cite the design doc, the spec, prior art, or a concrete measurement. Propose an alternative. If text is not working, offer to move to a synchronous channel. Dismissal without evidence ("disagree, moving on") is not a response.
- **Nitpick you would rather not make** — still make it. Silent disagreement ("I will not change it but also will not explain why") wastes the reviewer's time and erodes trust over many PRs.
- **Out of scope** — acknowledge in the thread, file a follow-up issue, link it, then resolve.

Never close a thread without acknowledgment. Never ignore a Critical comment. Never merge with unresolved Critical threads.

### 5. Merge strategy

Three common options:

| Strategy | Use when | Avoid when |
|----------|----------|------------|
| **Squash** | Many small "wip" commits on the feature branch | You would lose meaningful history by squashing |
| **Merge commit** | Feature branch has coherent history worth keeping | A single logical change that should be one commit |
| **Rebase and merge** | Linear-history policy; commits are all clean | Shared branch where rebase would break references |

Match the repo's convention first. Only diverge with team agreement.

### 6. After merge

- Delete the branch (`gh pr merge --delete-branch` or manually)
- Confirm the merge commit or squash commit landed on the base
- Close any linked issues if the PR did not auto-close them

## Common Rationalizations

| Shortcut | Reality |
|----------|---------|
| "I'll just `gh pr create --title 'fix'`." | Lazy titles become lazy merge commits. Invest 30 seconds. |
| "The template is optional." | The template is the team's communication contract. Fill it. |
| "I'll respond to review comments later." | Review freshness decays fast. Respond within the day or unassign. |
| "I disagree with the nitpick but it's not worth arguing." | Then just do it. Silent disagreement wastes both people's time. |
| "Squash is always safe." | Squash loses bisect-useful history when a branch has meaningful intermediate commits. |

## Red Flags

- PRs opened with "fix", "update", "wip" as the title
- Empty PR bodies or templates with unfilled sections
- PRs merged with unresolved Critical review threads
- Review comments ignored or dismissed without explanation
- `gh pr merge --admin` used to bypass review requirements (bypass is a last resort, not a default)
- Feature branches left un-deleted after merge
- Draft PRs left in draft for weeks without updates

## Verification

- [ ] `ops_enabled=true` confirmed in session context before any PR-creation command
- [ ] PR title is a complete sentence in the imperative; body follows the template
- [ ] CI green (or draft explicitly marked) at PR open time
- [ ] Every review comment addressed — fixed, discussed, or tracked
- [ ] Merge strategy matches repo convention
- [ ] Branch deleted post-merge
- [ ] When `ops_enabled=false`: the PR is reported as a follow-up, not created

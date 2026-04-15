# Ops Skills (opt-in)

Guide to the opt-in `ops-skills` plugin for external-write actions.

The framework treats external-write actions — `git push`, `gh pr create`, `docker push`, release publishing — differently from local work. They live in a separate plugin that is not enabled by default. If the plugin is not installed, agents refuse to run those commands and report the intended action as a follow-up.

## Why external writes are separate

External writes have a larger blast radius than local changes:

- A push visible to collaborators
- A PR that triggers CI and notifies reviewers
- A release that downstream consumers will pull
- A container image that production deployments will use

Some projects want Claude to handle these end-to-end. Others never want them to run without human review. The framework respects both by making the external-write skills a separate, opt-in plugin.

## What is in the plugin

Four skills, all under `skills/ops/`:

| Skill | Purpose |
|---|---|
| [git-remote](../skills/ops/git-remote/SKILL.md) | `git push`, force-push policy, upstream tracking, tag push |
| [pull-requests](../skills/ops/pull-requests/SKILL.md) | `gh pr create`, PR templates, review response, merge strategy |
| [release](../skills/ops/release/SKILL.md) | Semver decision, tag creation, changelog, GitHub Releases |
| [registry](../skills/ops/registry/SKILL.md) | `docker push`, tag strategy, image signing, registry authentication |

Each skill follows the same anatomy as a core skill: When to Use, When NOT to Use, Core Process, Common Rationalizations, Red Flags, Verification. The "When NOT to Use" section of every ops skill starts with: "Session context has `ops_enabled=false` — **do not push**, report the intended push as a follow-up instead".

## How detection works

Detection is automatic. The `session-start.sh` hook checks whether `skills/ops/` exists and contains at least one skill directory. If it does, the hook emits `ops_enabled: true` in the session JSON (along with the list of ops skills). If it does not, the hook emits `ops_enabled: false` and `ops_skills: ""`.

The session context (JSON) is visible to every agent. Each code-writing agent checks the flag before running any external-write command.

## Installation

### Via plugin marketplace

```bash
claude plugin add ops-skills
```

This installs the ops plugin from the same repository as the core and language plugins. After installation, `session-start.sh` will detect the populated `skills/ops/` directory and emit `ops_enabled: true`.

### Via local clone

If you cloned this repository directly, `skills/ops/` is already present on disk. No extra steps needed — `session-start.sh` picks it up automatically.

### Uninstalling

Remove the plugin via `claude plugin remove ops-skills`, or simply delete (or rename) the `skills/ops/` directory. The hook detects the change on the next session start.

## Agent guards

Four agents contain an "External Side Effects" section that enforces the gate:

- `builder`
- `cli-builder`
- `shipper`
- `lead`

Each guard has the same structure:

1. Names the external-write actions (push, PR creation, release, registry push, cloud deploy)
2. States the rule: run only when `ops_enabled=true`; report as follow-up when `false`
3. References the relevant ops skill
4. Concludes with "If you are unsure whether an action is an external write, it probably is. Err on the side of reporting, not executing."

Agents without the guard — `critic`, `reviewer`, `tester`, `architect` — do not perform external writes in the first place.

## How to verify the plugin is installed

Inspect the session-start output:

```bash
hooks/session-start.sh | python3 -c "import json, sys; d = json.load(sys.stdin); print(d['ops_enabled'], d['ops_skills'])"
```

Output when enabled:

```
True git-remote,pull-requests,registry,release
```

Output when not enabled:

```
False
```

If you are inside a Claude Code session, you can ask the agent to print `ops_enabled` from the session context.

## What changes when the plugin is disabled

| Action | ops_enabled=true | ops_enabled=false (default) |
|---|---|---|
| `git push` | Runs, following `ops/git-remote` discipline | Reported as follow-up |
| `gh pr create` | Runs, following `ops/pull-requests` discipline | Reported as follow-up |
| Release publishing | Runs, following `ops/release` discipline | Reported as follow-up |
| `docker push` | Runs, following `ops/registry` discipline | Reported as follow-up |
| Writing local commits | Always runs | Always runs |
| Building a Docker image locally | Always runs | Always runs |
| Writing a SPEC file | Always runs | Always runs |
| Writing or modifying source code | Always runs | Always runs |

The gate is only on external writes. Everything local is unaffected.

## Soft vs hard gating

The current implementation is **soft gating**: agents cooperatively check `ops_enabled` in session context and refuse to run external-write commands when the flag is false. Agents with the `Bash` tool could still technically run any shell command they want — the gate relies on instructions being followed.

For stricter enforcement, two options:

1. **Tool-level restriction.** Remove `Bash` from agents that should not run external commands, or add deny patterns to `.claude/settings.local.json` (e.g., block `git push`, `gh pr create`, `docker push`).
2. **Claude Code's tool-approval dialog.** With a suitable permission mode, Claude Code will prompt the user before running any Bash command that matches a risky pattern.

Soft gating is sufficient for most cases. Consider layering on hard gating for adversarial or compliance-heavy environments.

## When to install

Install `ops-skills` when:

- The project authorizes automated pushes, PRs, releases, or registry uploads
- The user is comfortable with Claude running `git push`, `gh pr create`, `docker push`, etc.
- You want Claude to handle the full workflow end-to-end

Do not install `ops-skills` when:

- Any external write would be costly if wrong
- The project requires human approval for every push or release
- You are not sure (default off is always safe)

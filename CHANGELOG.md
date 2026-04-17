# Changelog

All notable changes to this framework are documented here. Format adapted from [Keep a Changelog](https://keepachangelog.com/).

## [3.0.0] — 2026-04-17

### Breaking

- **Removed `lead` subagent.** The previous `agents/lead.md` orchestrator is deleted. Main Claude — running the new `core/orchestration` skill — now drives the spec-driven workflow directly. Anyone scripting against a spawned `lead` subagent must stop; commands have been rewired to load the orchestration skill into the main conversation instead.
- **New skill: `core/orchestration`.** Defines the 4-phase workflow (Analysis, Spec Generation, Execution, Final Verification), 3 human-in-the-loop gates (findings review, spec approval, per-group sign-off), and the audit-trail contract in `docs/specs/<slug>/group-log.md`. Every spec-driven command (`/define`, `/orchestrate`, `/plan`, `/build`, `/ship`) loads this skill.
- **`core/spec-generation` shrunk to an artifact contract.** Workflow instructions moved to `core/orchestration`. This skill now owns only the template layout, frontmatter schema, parallelization markers (`[P]`), and the spec-directory file ownership table.
- **Command rewiring.** All 8 spec-driven commands (`/define`, `/orchestrate`, `/plan`, `/build`, `/ship`, `/ideate`, `/test`, `/review`) were rewritten. `/define` and `/orchestrate` load `core/orchestration` in the main conversation. `/plan`, `/build`, `/ship` have in-orchestration and ad-hoc modes. `/test` and `/review` are standalone specialist spawns.
- **Agent frontmatter: critic got `Write`.** Critic now owns writing `critique.md` directly. Before, critic returned structured text; now it writes its own artifact. This matches scout's pattern.

### Added

- **Gates fire via `AskUserQuestion`.** All 3 gates are explicit hard stops. No auto-advance.
- **Self-contained subagent prompts.** Phase 3 subagents receive prompts with all needed context quoted verbatim — `Files:`, `Done when:`, relevant decisions, verify command. Agents no longer re-read `spec.md`.
- **Mid-Phase-3 revision procedure.** When a builder surfaces that additional files must change, main Claude pauses the group, appends a `_revision_N_` note to `spec.md`, re-gates, and re-spawns with the updated `Files:` list. Recorded in `group-log.md`.
- **Reviewer runs build/test/vet directly** in mini-review mode. A failing command is a Critical finding regardless of code-review verdict.
- **Frontmatter validation in `session-start.sh`.** Specs with invalid `status` or missing `current_group`/`total_groups` are excluded from `active_specs` with a stderr warning rather than silently misreporting.
- **Multi-spec resumption.** When two or more in-progress specs exist, main Claude surfaces all of them; user picks one to resume.
- **Zero-group spec handling.** Specs with `total_groups: 0` (policy-only or doc-only changes) skip Phase 3 cleanly instead of iterating over an empty loop.
- **Constitution invariants passed to critic.** When `project_constitution` is non-empty, the critic spawn prompt includes the invariant list verbatim; critic flags any spec direction that would violate a `critical` invariant as `Blocker: yes`.

### Removed

- `agents/lead.md` (see Breaking).
- Workflow prose from `core/spec-generation/SKILL.md` (duplicated orchestration).

### Docs

- Full sweep of `CLAUDE.md`, `README.md`, `docs/*.md` to remove references to the deleted `lead` agent.
- Updated skill/agent/command counts across `docs/reference.md`.
- Added this `CHANGELOG.md` and a `LICENSE` file at the repo root.


## [2.x and earlier]

Pre-3.0 history is not tracked in this file. Consult `git log` for the pre-refactor state.

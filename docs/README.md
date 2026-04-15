# Documentation

Index of the `claude-resources` framework documentation. Each entry has a one-line description and a link.

## New users — start here

- **[getting-started.md](getting-started.md)** — install the framework, walk through your first workflow (ideate → define → plan → build → test → review), customize for your project
- **[architecture.md](architecture.md)** — the four building blocks (skills, agents, commands, hooks), the three plugin groups, how it all fits together

## Daily use

- **[workflow.md](workflow.md)** — the spec-driven workflow deep dive, SPEC file template, group execution, scope-change protocol
- **[commands.md](commands.md)** — reference for all 10 slash commands, when to use each, example invocations
- **[agents.md](agents.md)** — reference for all 8 specialist agents, their roles, tools, skills, when to use each

## Reference

- **[skills-catalog.md](skills-catalog.md)** — all 38 skills by tier (core / go / ops) and phase, one-line purpose and link to each
- **[skill-anatomy.md](skill-anatomy.md)** — how to write a skill file: frontmatter, sections, style rules, supporting files
- **[agent-reporting.md](agent-reporting.md)** — the structured report schema agents return after their work (Status, Files touched, Evidence, Follow-ups, Blockers)
- **[hooks.md](hooks.md)** — lifecycle hooks (session-start, session-end, learn) and the five validator scripts, with schemas and troubleshooting
- **[operational-learning.md](operational-learning.md)** — the learning capture system: recording learnings, JSONL format, persistence, cross-session injection

## Extending

- **[extending.md](extending.md)** — how to add a new core skill, language tier, agent, or slash command; validation workflow; style rules
- **[skill-anatomy.md](skill-anatomy.md)** — required structure for new skills

## Opt-in plugins

- **[ops-skills.md](ops-skills.md)** — guide to the opt-in `ops-skills` plugin for external-write actions (`git push`, `gh pr create`, `docker push`, release publishing), detection via `ops_enabled` session context, installation, agent guards

## Troubleshooting

- **[troubleshooting.md](troubleshooting.md)** — consolidated troubleshooting for language detection, skill loading, hook failures, validator errors, agent routing, and more
